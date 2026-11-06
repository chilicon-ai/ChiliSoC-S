# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""RISCOF DUT plugin: ChillU-S on its Verilator model (sim/tb/chillus_tb.sv).

build:    the default chillus_core model with sim/run.py's rtl_files /
          build_sim, in its own directory sim/out/conformance/build/obj (no
          race with run.py's sim/build/obj).
runTests: per test (in parallel, $ACT_JOBS): compile (act_lib, the same as
          the reference) -> dut.elf, dut.dis, test.hex (one 32-bit word per
          line from 0x8000_0000, as run.py) -> Vchillus_tb +hex +trace +tohost
          (+ $ACT_SIM_ARGS: run_act.py's +istall / +dstall / seed) ->
          rtl.trace, sim.log -> DUT-chillus.signature.

Signature: the testbench is not changed, so the final memory of the signature
region [begin_signature, end_signature) is rebuilt from the ELF image plus
every retired store in the RVFI trace (byte address, wmask, wdata; trap
entries do no access), in retirement order, and written one 32-bit word per
line (hex), as Sail's --signature-granularity 4. chillus.status holds the
testbench result ("TB: PASS" when the test stored 1 to tohost).
"""

import logging
import os
import subprocess
import sys
from pathlib import Path

from riscof.pluginTemplate import pluginTemplate

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))         # act_lib
import act_lib  # noqa: E402

sys.path.insert(0, str(act_lib.ROOT / "sim"))                            # run.py
import run as simrun  # noqa: E402

logger = logging.getLogger()

MAX_CYCLES = 2_000_000         # per test, unless $ACT_MAX_CYCLES


def build_model(force: bool = False) -> Path:
    """Build (if stale) the default-parameter model; returns the binary."""
    params = {"MEM_WORDS": str(act_lib.MEM_WORDS)}
    simrun.BUILD = act_lib.OUT / "build" / f"obj_{simrun.params_tag(params)}"
    simrun.SIM_BIN = simrun.BUILD / "Vchillus_tb"
    simrun.set_ram(act_lib.RAM_BYTES)
    simrun.build_sim(force, params)
    return simrun.SIM_BIN


def write_hex(elf: Path, work: Path) -> Path:
    """$readmemh image from BASE, as sim/run.py's compile_test."""
    lo = min(a for a in act_lib.symbols(elf).values() if a >= simrun.BASE)
    if lo != simrun.BASE:
        raise RuntimeError(f"{elf}: image does not start at {simrun.BASE:#x}")
    binf = work / "test.bin"
    subprocess.run([act_lib.tool(act_lib.CROSS + "objcopy"), "-O", "binary", str(elf),
                    str(binf)], check=True)
    data = binf.read_bytes()
    data += bytes(-len(data) % 4)
    if len(data) > simrun.RAM_BYTES:
        raise RuntimeError(f"{elf}: image larger than the testbench RAM")
    hexf = work / "test.hex"
    with open(hexf, "w") as f:
        for i in range(0, len(data), 4):
            f.write(f"{int.from_bytes(data[i:i + 4], 'little'):08x}\n")
    return hexf


def signature(binf: Path, trace: Path, begin: int, end: int) -> list[int]:
    """Final words of [begin, end): ELF image, then the trace's stores."""
    image = binf.read_bytes()
    mem = bytearray(end - begin)
    lo = begin - simrun.BASE
    chunk = image[lo:lo + len(mem)]
    mem[:len(chunk)] = chunk
    if trace.exists():
        for e in simrun.parse_rtl(trace):
            if e.st is None:
                continue
            addr, data, n = e.st
            for b in range(n):
                if begin <= addr + b < end:
                    mem[addr + b - begin] = (data >> (8 * b)) & 0xFF
    return [int.from_bytes(mem[i:i + 4], "little") for i in range(0, len(mem), 4)]


class chillus(pluginTemplate):
    __model__ = "chillus"
    __version__ = "1.0"

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)
        config = kwargs.get("config")
        if config is None:
            raise SystemExit("chillus plugin: config node missing")
        cfg_dir = kwargs.get("config_dir", ".")
        self.cfg = config
        self.isa_spec = os.path.join(cfg_dir, config["ispec"])
        self.platform_spec = os.path.join(cfg_dir, config["pspec"])
        self.target_run = config.get("target_run", "1") != "0"
        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite = suite
        self.archtest_env = archtest_env

    def build(self, isa_yaml, platform_yaml):
        if self.target_run:
            self.sim_bin = build_model()

    def run_one(self, entry: dict) -> None:
        work = Path(entry["work_dir"])
        sig_file = work / (self.name[:-1] + ".signature")
        status = work / "chillus.status"
        elf, msg = act_lib.compile_test(entry["test_path"], entry["isa"], entry["macros"],
                                        self.archtest_env, work, "dut")
        if elf is None:
            sig_file.write_text("")
            status.write_text("COMPILE ERROR\n" + msg)
            return
        if not self.target_run:
            sig_file.write_text("")
            return
        try:
            write_hex(elf, work)
        except RuntimeError as err:
            sig_file.write_text("")
            status.write_text(f"ERROR {err}\n")
            return
        syms = act_lib.symbols(elf)
        trace = work / "rtl.trace"
        max_cycles = int(os.environ.get("ACT_MAX_CYCLES", MAX_CYCLES))
        cmd = [str(self.sim_bin), f"+hex={work / 'test.hex'}", f"+trace={trace}",
               f"+tohost={syms['tohost']:08x}", f"+max_cycles={max_cycles}",
               *os.environ.get("ACT_SIM_ARGS", "").split()]
        sim = subprocess.run(act_lib.job("sim", cmd), text=True, capture_output=True, timeout=3600)
        (work / "sim.log").write_text(" ".join(cmd) + "\n" + sim.stdout + sim.stderr)
        tb = [l for l in sim.stdout.splitlines() if l.startswith("TB: ")]
        status.write_text("\n".join(tb or ["TB: no result (see sim.log)"]) + "\n")
        words = signature(work / "test.bin", trace, syms["begin_signature"],
                          syms["end_signature"])
        sig_file.write_text("".join(f"{w:08x}\n" for w in words))

    def runTests(self, testList):
        n = act_lib.jobs(self.cfg)
        logger.info(f"chillus: {len(testList)} tests, {n} jobs")
        act_lib.parallel(self.run_one, list(testList.values()), n)
