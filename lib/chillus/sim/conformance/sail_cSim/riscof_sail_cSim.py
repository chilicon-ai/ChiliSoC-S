# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""RISCOF reference plugin: the Sail RISC-V model (sail_riscv_sim, sail-riscv
0.15 release binary), configured like ChillU-S.

Executable: $SAIL_RISCV, else config 'PATH'/sail_riscv_sim, else
~/sail-riscv/current/bin/sail_riscv_sim, else sail_riscv_sim on PATH.

build:    writes <work_dir>/sail_chillus.json: Sail's default RV32 configuration
          (--rv32 --print-default-config) with chillus_config() applied, checked
          with --validate-config.
runTests: per test (in parallel, $ACT_JOBS): compile (act_lib, the same as
          the DUT) -> ref.elf, ref.dis -> sail_riscv_sim --test-signature
          (granularity 4) -> Reference-sail_c_simulator.signature, sail.log
          (instruction, register, memory, CSR and exception trace).
"""

import json
import logging
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from riscof.pluginTemplate import pluginTemplate

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))         # act_lib
import act_lib  # noqa: E402

logger = logging.getLogger()

INST_LIMIT = 4_000_000

# Extensions ChillU-S implements (everything else is turned off). C is Zca
# here (no F / D, so no Zcf / Zcd).
CHILLUS_EXT = {"M", "C", "U", "Zca", "Zicsr", "Zifencei", "Zicntr"}



def chillus_config(cfg: dict) -> dict:
    """Sail's default RV32 configuration -> ChillU-S (sim/tb/chillus_tb.sv +
    source/ChillUS/csr, trap): RV32IMC Zicsr Zifencei Zicntr, M and U modes."""
    base, mem, plat, ext = cfg["base"], cfg["memory"], cfg["platform"], cfg["extensions"]
    # extensions: only ChillU-S's; misa read-only (no mutable_misa)
    def only_chillus(nodes: dict) -> None:
        for name, node in nodes.items():
            if not isinstance(node, dict):
                continue
            if "supported" in node:
                node["supported"] = name in CHILLUS_EXT
            if "support_level" in node:                  # V
                node["support_level"] = "Disabled"
            if "mutable_misa" in node:
                node["mutable_misa"] = False
            if name == "Stateen":                        # Smstateen, Ssstateen
                only_chillus(node)
    only_chillus(ext)
    # mtvec: Direct mode only (MODE read-only 0), BASE 4-byte aligned
    base["mtvec"]["vectored"]["supported"] = False
    # no Zihpm, mhpmcounters read 0; mcountinhibit CY / IR only
    base["writable_hpm_counters"]["value"] = "0x0"
    base["hpmevent_width_bits"] = 1                      # schema minimum (ChillU-S: 0)
    plat["event_selectors"] = []                         # no HPM events
    base["mcountinhibit"]["writable_bits"]["value"] = "0x5"
    base["mcounteren_writable_bits"]["value"] = "0x7"   # CY, TM, IR
    base["scounteren_writable_bits"]["value"] = "0x0"
    base["hcounteren_writable_bits"]["value"] = "0x0"
    base["writable_fiom"] = False
    base["mstatus"]["fs_legal_states"] = "ExtContext_Off"
    base["mstatus"]["vs_legal_states"] = "ExtContext_Off"
    base["medeleg"]["delegatable_bits"]["value"] = "0x0"
    base["mideleg"]["delegatable_bits"]["value"] = "0x0"
    # memory: 4 PMP entries (grain 4 bytes, OFF / TOR / NA4 / NAPOT; Sail's count
    # is 0 / 16 / 64, the CSRs beyond usable_count read 0), no MMU, misaligned
    # loads / stores trap
    mem["physaddr_bits"] = 32
    mem["asidlen"] = 0
    mem["vmidlen"] = 0
    mem["pmp"]["count"] = 16
    mem["pmp"]["usable_count"] = 4
    mem["pmp"]["grain"] = 0
    mem["pmp"]["tor_supported"] = True
    mem["pmp"]["na4_supported"] = True
    mem["pmp"]["napot_supported"] = True
    trap = {"Some": "AlignmentException"}
    mem["misaligned"]["exceptions"]["load_store"] = trap
    mem["misaligned"]["exceptions"]["amo"] = trap
    # regions: the testbench's RAM (act_lib.RAM_BYTES) at 0x8000_0000 (a stray access
    # faults, as in ChillU-S) and the CLINT (64 KiB I/O)
    regions = []
    for r in mem["regions"]:
        b = int(r["base"]["value"].replace("_", ""), 16)
        if b == 0x8000_0000:
            r["size"]["value"] = hex(act_lib.RAM_BYTES)
        elif b != 0x200_0000:
            continue                                     # ROM (no boot ROM in ChillU-S)
        else:
            r["size"]["value"] = hex(0x1_0000)
        r["attributes"]["misaligned_exceptions"]["load_store"] = trap
        regions.append(r)
    mem["regions"] = regions
    # platform: CLINT (msip, mtimecmp, mtime) at 0x0200_0000, IDs 0, WFI a NOP
    plat["vendorid"] = plat["archid"] = plat["impid"] = plat["hartid"] = 0
    plat["clint"]["base"] = 0x200_0000
    plat["simple_interrupt_generator"]["supported"] = False
    plat["wfi_is_nop"] = True
    return cfg


def sail_exe(config: dict) -> str:
    cands = [os.environ.get("SAIL_RISCV"),
             os.path.join(config["PATH"], "sail_riscv_sim") if "PATH" in config else None,
             str(Path.home() / "sail-riscv" / "current" / "bin" / "sail_riscv_sim"),
             shutil.which("sail_riscv_sim")]
    for c in cands:
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    raise SystemExit("sail_cSim: sail_riscv_sim not found (set SAIL_RISCV or unpack a "
                     "release to ~/sail-riscv/current)")


class sail_cSim(pluginTemplate):
    __model__ = "sail_c_simulator"
    __version__ = "0.15"

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)
        config = kwargs.get("config")
        if config is None:
            raise SystemExit("sail_cSim plugin: config node missing")
        self.cfg = config
        self.sail = sail_exe(config)
        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite = suite
        self.archtest_env = archtest_env

    def build(self, isa_yaml, platform_yaml):
        out = subprocess.run([self.sail, "--rv32", "--print-default-config"], text=True,
                             capture_output=True, check=True).stdout
        cfg = json.loads(re.sub(r"^\s*//.*$", "", out, flags=re.M))
        self.sail_cfg = Path(self.work_dir) / "sail_chillus.json"
        self.sail_cfg.write_text(json.dumps(chillus_config(cfg), indent=2) + "\n")
        chk = subprocess.run([self.sail, "--config", str(self.sail_cfg), "--validate-config"],
                             text=True, capture_output=True)
        if chk.returncode != 0:
            raise SystemExit(f"sail_cSim: {self.sail_cfg} invalid:\n{chk.stdout}{chk.stderr}")
        ver = subprocess.run([self.sail, "--version"], text=True, capture_output=True).stdout
        logger.info(f"sail_cSim: {self.sail} ({ver.strip()}), config {self.sail_cfg}")

    def run_one(self, entry: dict) -> None:
        work = Path(entry["work_dir"])
        sig_file = work / (self.name[:-1] + ".signature")
        elf, msg = act_lib.compile_test(entry["test_path"], entry["isa"], entry["macros"],
                                        self.archtest_env, work, "ref")
        if elf is None:
            sig_file.write_text("")
            return
        cmd = [self.sail, "--config", str(self.sail_cfg), "--inst-limit", str(INST_LIMIT),
               "--signature-granularity", "4", "--test-signature", str(sig_file),
               "--trace-instr", "--trace-reg", "--trace-mem", "--trace-csr",
               "--trace-exception", "--trace-interrupt", str(elf)]
        with open(work / "sail.log", "w") as log:
            log.write(" ".join(cmd) + "\n")
            log.flush()
            subprocess.run(act_lib.job("sim", cmd, quiet=True), stdout=log, stderr=subprocess.STDOUT, timeout=3600)
        if not sig_file.exists():
            sig_file.write_text("")

    def runTests(self, testList, cgf_file=None, header_file=None):
        n = act_lib.jobs(self.cfg)
        logger.info(f"sail_cSim: {len(testList)} tests, {n} jobs")
        act_lib.parallel(self.run_one, list(testList.values()), n)
