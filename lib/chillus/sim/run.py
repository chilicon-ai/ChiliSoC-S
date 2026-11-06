#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""ChillU-S sim runner: run RISC-V test programs on chillus_core (Verilator) and
compare its RVFI retirement trace with the Spike commit log.

  python sim/run.py                       the regression list (sim/tests/regression.list)
  python sim/run.py rv32ui/add            one riscv-tests test
  python sim/run.py rv32ui                every test in the suite
  python sim/run.py chillus               ChillU-S tests (sim/tests/*.S, *.c)
  python sim/run.py chillus/hazards       one of them
  python sim/run.py coremark              CoreMark ($COREMARK, --iterations N)
  python sim/run.py random:50             random sequences, seeds 1..50
  python sim/run.py random/17             random sequence, seed 17
  python sim/run.py prog.S                own program (riscv-tests p env)
  python sim/run.py rv32ui --istall 30 --dstall 30 --seed 5
  python sim/run.py coremark --param RF_LATCH=0       other core parameters

Per test: compile (riscv64-unknown-elf-gcc; .S with the riscv-tests env/p,
C with the sim/sw runtime) -> Spike (--log-commits) and the testbench (+hex,
+tohost, +console, +trace) -> compare both traces up to and including the
store to tohost. Outputs go to sim/out/<test>/: test.elf, test.dis, test.hex,
spike.log, rtl.trace, sim.log, console.log (C programs).

--param NAME=VALUE (repeatable) sets a chillus_core parameter (chillus_tb
forwards RF_LATCH; Verilator -G), the testbench's AHB (chillus_ahb behind
AHB-Lite models) or its RAM size MEM_WORDS (default 1 MiB; Spike's RAM follows it). Each parameter
set has its own build, sim/build/obj_<NAME><VALUE>[_...] (sorted by name),
and its outputs go to sim/out/<tag>/<test>/, the tag being the same
<NAME><VALUE>[_...] unless --tag <tag> names it. Without --param / --tag:
sim/build/obj and sim/out/<test>/ as above.

Compared per retired instruction: pc, instruction bits, rd and its value,
store address / data / size, load address, privilege mode; traps by pc. Spike's boot ROM
(pc < BASE) is skipped. Cycle counter values differ by design (Spike: CPI 1):
values derived from them are not compared, and the comparison ends at the
first branch / address that depends on one (CycleTaint).

--coverage: a coverage-instrumented model (Verilator --coverage: line,
branch, expression, toggle; not the testbench, the checkers), own build sim/build/obj[_<tag>]_cov, outputs under
sim/out/cov/[<tag>/]<test>/,
each test also writing coverage.dat there. sim/coverage.py merges them and
reports code and functional coverage.

A ChillU-S test (.S / .c) can carry the directive line
  # run.py: no-spike                  no Spike run or trace comparison: the
                                      test checks itself (tohost); for the
                                      testbench's +irqgen interrupt lines,
                                      which Spike does not model
  # run.py: plusarg +<name>[=<value>]  extra testbench plusarg (e.g.
                                      +debug_req_reset: halt request held
                                      through reset)
  # run.py: needs-debug               needs debug mode: skipped in a
                                      --param DEBUG=0 build
  # run.py: needs-triggers            needs triggers: skipped unless the build
                                      has --param NUM_TRIGGERS=<n>, n > 0
Spike gets the build's trigger count (--triggers=NUM_TRIGGERS, default 0 as
chillus_core).
Debug tests (sim/tests/dbg.h) link their mini-DM code (section .dbg_rom) at
DM_ROM, the testbench's DM_HALT_ADDR (DM_EXCEPTION_ADDR = DM_ROM + 8).
A program symbol `irqgen` is passed to the testbench as +irqgen.

Environment: RISCV_TESTS (default ~/riscv-tests), COREMARK (default
~/coremark), VERILATOR_ROOT, and spike / riscv64-unknown-elf-* on PATH.
"""

import argparse
import fcntl
import os
import re
import shutil
import subprocess
import sys
from collections.abc import Callable
from dataclasses import dataclass, replace
from pathlib import Path

import gen_random
import rvc

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import filelist  # noqa: E402  (RTL file list from the file lists)
from jobs import job  # noqa: E402

SIM = ROOT / "sim"
BUILD = SIM / "build" / "obj"
OUT = SIM / "out"
TB = SIM / "tb" / "chillus_tb.sv"
TESTS = SIM / "tests"
SW = SIM / "sw"
COREMARK_PORT = SIM / "coremark"
REGRESSION = TESTS / "regression.list"
SIM_BIN = BUILD / "Vchillus_tb"

BASE = 0x8000_0000
RAM_BYTES = 0x10_0000                       # testbench memory (chillus_tb MEM_WORDS default; set_ram)
ISA = "rv32imc_zicsr_zifencei_zicntr"
ABI = "ilp32"
CROSS = "riscv64-unknown-elf-"
# Spike configured like ChillU-S: RV32IMC + Zicsr + Zifencei + Zicntr, M and
# U modes, the build's PMP entries (PMP_REGIONS, default 4) with a 4-byte
# grain (chillus_pmp). With PMP_REGIONS = 0 ChillU-S has legal PMP CSRs
# (read 0, writes ignored) and U-mode reaches all memory; Spike traps on
# them with --pmpregions=0, so it gets one region, which its reset opens to
# U-mode for all memory: it only differs when a test reads a PMP CSR back
# (needs-pmp tests and rv32mi/pmpaddr are skipped then).
# WFI waits for (mie & mip) != 0 in both (Spike's default), so the retired
# instruction stream matches; only the cycles differ. RAM: the testbench's
# 1 MiB, so a stray access faults in both.
SPIKE_CFG = [f"--isa={ISA}", "--priv=mu", "--pmpregions=4", "--triggers=0",
             f"-m{BASE:#x}:{RAM_BYTES:#x}"]


def set_triggers(n: int) -> None:
    """Spike's trigger count follows the build's NUM_TRIGGERS (chillus_core
    default 0). With 0, Spike still has tselect and read-only tdata*, while
    ChillU-S makes them illegal: tests must not touch them then."""
    SPIKE_CFG[3] = f"--triggers={n}"


def set_pmp(n: int) -> None:
    """Spike's PMP entry count follows the build's PMP_REGIONS (chillus_core
    default 4); 0 -> 1 (see SPIKE_CFG)."""
    SPIKE_CFG[2] = f"--pmpregions={max(n, 1)}"


def set_ram(ram_bytes: int) -> None:
    """Testbench RAM size (chillus_tb MEM_WORDS * 4): Spike gets the same, so
    a stray access faults in both."""
    global RAM_BYTES
    RAM_BYTES = ram_bytes
    SPIKE_CFG[-1] = f"-m{BASE:#x}:{RAM_BYTES:#x}"
CFLAGS = ["-O2", "-ffreestanding", "-fno-common"]
MAX_CYCLES = 200000            # default --max-cycles
DM_ROM = BASE + 0x1_0000       # chillus_tb DM_ROM: mini-DM halt address (.dbg_rom)

# riscv-tests that need PMP entries (skipped with PMP_REGIONS = 0)
NEEDS_PMP = {"rv32mi/pmpaddr"}

# riscv-tests that need features ChillU-S does not have (by design)
SKIP = {
    "rv32ui/ma_data": "needs hardware misaligned access (ChillU-S and Spike trap)",
    "rv32mi/ma_fetch": "clears misa.C: Spike's misa is writable, ChillU-S's read-only (WARL)",
    "rv32mi/breakpoint": "needs mcontrol (type 2) and load / store triggers: ChillU-S has mcontrol6 execute triggers only (sim/tests/trig.S)",
}


@dataclass(frozen=True)
class Event:
    """One retired instruction (or trap) in a comparable form."""
    pc: int
    insn: int | None          # None for a trap entry
    rd: int | None = None     # register written (None: no write / x0)
    rd_val: int | None = None
    st: tuple | None = None   # (addr, data, size_bytes)
    ld: int | None = None     # load address
    mode: int | None = None   # privilege mode it ran in (3 M, 0 U)

    def __str__(self) -> str:
        if self.insn is None:
            return f"pc {self.pc:08x}  TRAP"
        s = f"pc {self.pc:08x}  insn {self.insn:08x}"
        if self.mode is not None and self.mode != 3:
            s += f"  mode {self.mode}"
        if self.rd is not None:
            s += f"  x{self.rd}={self.rd_val:08x}"
        if self.st is not None:
            a, d, n = self.st
            s += f"  store[{n}] {a:08x} <- {d:0{2 * n}x}"
        if self.ld is not None:
            s += f"  load {self.ld:08x}"
        return s


@dataclass(frozen=True)
class Test:
    """A test program: one riscv-tests style .S, or C sources on sim/sw."""
    tid: str
    srcs: tuple[Path, ...]
    c: bool = False                     # C program (sim/sw runtime)
    incs: tuple[Path, ...] = ()         # extra include directories (C)
    defs: tuple[str, ...] = ()          # extra -D defines (C)
    max_cycles: int = MAX_CYCLES        # unless --max-cycles is given
    # console.log text -> (ok, summary) for programs that check themselves
    report: Callable[[str], tuple[bool, str]] | None = None
    spike: bool = True                  # compare with Spike (no-spike: self-check only)
    plusargs: tuple[str, ...] = ()      # extra testbench plusargs (directive)
    needs_debug: bool = False           # skipped with --param DEBUG=0 (directive)
    needs_triggers: bool = False        # skipped without --param NUM_TRIGGERS=<n > 0> (directive)
    needs_pmp: bool = False             # skipped with --param PMP_REGIONS=0 (directive)


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, **kw)


def tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        sys.exit(f"run.py: {name} not found on PATH")
    return path


# -----------------------------------------------------------------------------
# build
# -----------------------------------------------------------------------------
def rtl_files() -> list[Path]:
    """RTL (the file lists' units, packages first), the testbench, and the
    invariant checkers (../BaseChiliSV/sim/checkers/ and sim/checkers/, bound
    into the RTL with SystemVerilog bind; not RTL themselves)."""
    return filelist.files() + [TB] + filelist.checkers()


def parse_params(specs: list[str]) -> dict[str, str]:
    """--param NAME=VALUE list -> {NAME: VALUE}, sorted by name."""
    params = {}
    for spec in specs:
        m = re.fullmatch(r"([A-Za-z_]\w*)=(\S+)", spec)
        if not m:
            sys.exit(f"run.py: --param {spec}: expected NAME=VALUE")
        params[m.group(1)] = m.group(2)
    return dict(sorted(params.items()))


def params_tag(params: dict[str, str]) -> str:
    """{RF_LATCH: 0} -> RF_LATCH0 (build directory and default out tag)."""
    return "_".join(re.sub(r"[^\w.-]", "_", f"{k}{v}") for k, v in params.items())


# --coverage: Verilator flags and config. Expression coverage makes Verilator
# see false combinational loops between vector bits (UNOPTFLAT, speed only).
# Not instrumented: the testbench and the checkers.
COV_FLAGS = ["--coverage", "-Wno-UNOPTFLAT"]
COV_VLT = """`verilator_config
coverage_off -file "*/sim/tb/*"
coverage_off -file "*/sim/checkers/*"
"""


def build_sim(force: bool, params: dict[str, str], coverage: bool = False) -> None:
    """Build (or reuse) the model. A lock file serializes runs that share the
    build directory, so parallel runs never build it at the same time."""
    BUILD.mkdir(parents=True, exist_ok=True)
    with open(BUILD / ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        _build_sim(force, params, coverage)


def _build_sim(force: bool, params: dict[str, str], coverage: bool) -> None:
    files = rtl_files()
    vlt = BUILD / "coverage.vlt"
    if coverage and not (vlt.exists() and vlt.read_text() == COV_VLT):
        force = True
    if not force and SIM_BIN.exists():
        newest = max(f.stat().st_mtime for f in files)
        if SIM_BIN.stat().st_mtime > newest:
            return
    print("build: verilator" + " (coverage)" * coverage
          + "".join(f" {k}={v}" for k, v in params.items()), flush=True)
    cov = []
    if coverage:
        vlt.write_text(COV_VLT)
        cov = [*COV_FLAGS, str(vlt)]
    # -Wno-NOLATCH: Verilator does not see a latch in basechili_latch's
    # always_latch (the library's tools/sim.py waives it the same way).
    run(job("build", [tool("verilator"), "--binary", "--timing", "--assert", "-j", "0", "--quiet",
                      "-Wno-NOLATCH", "--top-module", "chillus_tb",
                      *(f"-G{k}={v}" for k, v in params.items()),
                      *cov, "-Mdir", str(BUILD), *map(str, files)]),
        stdout=subprocess.DEVNULL)


# -----------------------------------------------------------------------------
# test program
# -----------------------------------------------------------------------------
def riscv_tests() -> Path:
    return Path(os.environ.get("RISCV_TESTS", Path.home() / "riscv-tests"))


def random_test(seed: int, length: int) -> Test:
    tid = f"random/{seed}" if length == 400 else f"random/{seed}_len{length}"
    src = OUT / tid / "test.S"
    src.parent.mkdir(parents=True, exist_ok=True)
    src.write_text(gen_random.generate(seed, length))
    return Test(tid, (src,))


def chillus_test(src: Path) -> Test:
    """A ChillU-S test with its '# run.py:' / '// run.py:' directives."""
    spike = True
    plusargs = []
    needs_debug = False
    needs_triggers = False
    needs_pmp = False
    for line in src.read_text().splitlines():
        m = re.match(r"\s*(?:#|//)\s*run\.py:\s*(.*)$", line)
        if not m:
            continue
        for part in m.group(1).split(";"):
            words = part.split()
            if words == ["no-spike"]:
                spike = False
            elif words == ["needs-debug"]:
                needs_debug = True
            elif words == ["needs-triggers"]:
                needs_triggers = True
            elif words == ["needs-pmp"]:
                needs_pmp = True
            elif len(words) == 2 and words[0] == "plusarg" and words[1].startswith("+"):
                plusargs.append(words[1])
            elif words:
                sys.exit(f"run.py: {src}: unknown directive '{part.strip()}'")
    return Test(f"chillus/{src.stem}", (src,), c=src.suffix == ".c", spike=spike,
                plusargs=tuple(plusargs), needs_debug=needs_debug,
                needs_triggers=needs_triggers, needs_pmp=needs_pmp)


def coremark_report(text: str) -> tuple[bool, str]:
    """CoreMark's self-check: known seeds, no CRC error (the 'at least 10
    secs' error is expected in simulation); CoreMark/MHz from its ticks."""
    errors = [l for l in text.splitlines() if "ERROR!" in l and "at least 10 secs" not in l]
    known = re.search(r"^2K performance run parameters", text, re.M)
    ticks = re.search(r"^Total ticks\s*:\s*(\d+)", text, re.M)
    iters = re.search(r"^Iterations\s*:\s*(\d+)", text, re.M)
    if errors or not (known and ticks and iters):
        return False, "; ".join(errors) or "incomplete or unknown-seed report (see console.log)"
    n, cyc = int(iters.group(1)), int(ticks.group(1))
    return True, f"CoreMark/MHz {n * 1e6 / cyc:.3f} ({n} iterations, {cyc} cycles)"


def coremark_test(iterations: int) -> Test:
    cm = Path(os.environ.get("COREMARK", Path.home() / "coremark"))
    if not (cm / "core_main.c").exists():
        sys.exit(f"run.py: CoreMark not found at {cm} (set COREMARK; "
                 "git clone https://github.com/eembc/coremark)")
    srcs = [cm / f"{f}.c" for f in ("core_list_join", "core_main", "core_matrix",
                                     "core_state", "core_util")]
    flags = " ".join(CFLAGS)
    return Test("coremark", (*srcs, COREMARK_PORT / "core_portme.c"), c=True,
                incs=(COREMARK_PORT, cm),
                defs=(f"ITERATIONS={iterations}", f'FLAGS_STR="{flags}"'),
                max_cycles=1_000_000 * (iterations + 1), report=coremark_report)


def resolve(name: str, args) -> list[Test]:
    """Test name -> tests."""
    p = Path(name)
    if p.suffix in (".S", ".c"):
        return [Test(p.stem, (p.resolve(),), c=p.suffix == ".c")]
    if m := re.fullmatch(r"random:(\d+)", name):
        return [random_test(i, args.length) for i in range(1, int(m.group(1)) + 1)]
    if m := re.fullmatch(r"random/(\d+)", name):
        return [random_test(int(m.group(1)), args.length)]
    if name == "coremark":
        return [coremark_test(args.iterations)]
    if name == "chillus":
        return [chillus_test(s) for s in sorted([*TESTS.glob("*.S"), *TESTS.glob("*.c")])]
    if name.startswith("chillus/"):
        stem = name.split("/", 1)[1]
        srcs = [s for s in (TESTS / f"{stem}.S", TESTS / f"{stem}.c") if s.exists()]
        if not srcs:
            sys.exit(f"run.py: no test {name} (sim/tests/{stem}.S or .c)")
        return [chillus_test(srcs[0])]
    isa = riscv_tests() / "isa"
    if (isa / name).is_dir():
        return [Test(f"{name}/{s.stem}", (s,)) for s in sorted((isa / name).glob("*.S"))]
    src = isa / f"{name}.S"
    if not src.exists():
        sys.exit(f"run.py: no test {name} ({src})")
    return [Test(name, (src,))]


def compile_test(test: Test, out: Path) -> tuple[Path, dict[str, int]]:
    """Build test.elf / .dis / .hex; returns the ELF and its tohost and
    console (C programs) addresses."""
    elf = out / "test.elf"
    gcc = [tool(CROSS + "gcc"), f"-march={ISA}", f"-mabi={ABI}", "-static",
           "-mcmodel=medany", "-nostdlib", "-nostartfiles"]
    if test.c:
        run([*gcc, *CFLAGS, "-I", str(SW), *(f"-I{i}" for i in test.incs),
             *(f"-D{d}" for d in test.defs), "-T", str(SW / "link.ld"),
             str(SW / "crt0.S"), str(SW / "runtime.c"), *map(str, test.srcs),
             "-lgcc", "-Wl,--no-warn-rwx-segments", "-o", str(elf)])
    else:
        rt = riscv_tests()
        run([*gcc, "-fvisibility=hidden",
             "-I", str(rt / "env" / "p"), "-I", str(rt / "isa" / "macros" / "scalar"),
             "-I", str(TESTS), f"-Wl,--section-start=.dbg_rom={DM_ROM:#x}",
             "-T", str(rt / "env" / "p" / "link.ld"), *map(str, test.srcs), "-o", str(elf)])
    with open(out / "test.dis", "w") as f:
        run([tool(CROSS + "objdump"), "-d", str(elf)], stdout=f)

    # $readmemh image: one 32-bit word per line from BASE
    binf = out / "test.bin"
    run([tool(CROSS + "objcopy"), "-O", "binary", str(elf), str(binf)])
    data = binf.read_bytes()
    data += bytes(-len(data) % 4)
    with open(out / "test.hex", "w") as f:
        for i in range(0, len(data), 4):
            f.write(f"{int.from_bytes(data[i:i + 4], 'little'):08x}\n")

    nm = run([tool(CROSS + "nm"), str(elf)], capture_output=True).stdout
    syms = {m.group(2): int(m.group(1), 16)
            for m in re.finditer(r"^([0-9a-f]+) \w (tohost|console|irqgen)$", nm, re.M)}
    if "tohost" not in syms:
        sys.exit(f"run.py: no tohost symbol in {elf}")
    return elf, syms


# -----------------------------------------------------------------------------
# traces
# -----------------------------------------------------------------------------
SPIKE_COMMIT = re.compile(r"^core\s+\d+: (\d) 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)$")
SPIKE_TRAP = re.compile(r"^core\s+\d+: exception (\S+), epc 0x([0-9a-f]+)")


def spike_boot_count(path: Path) -> int:
    """Instructions Spike retires in its boot ROM (pc < BASE) before the
    program: they count in Spike's minstret but have no RTL counterpart."""
    n = 0
    for line in path.read_text().splitlines():
        m = SPIKE_COMMIT.match(line)
        if m and int(m.group(2), 16) < BASE:
            n += 1
    return n


def parse_spike(path: Path) -> list[Event]:
    events = []
    for line in path.read_text().splitlines():
        if m := SPIKE_TRAP.match(line):
            pc = int(m.group(2), 16)
            if pc >= BASE:
                events.append(Event(pc, None))
            continue
        m = SPIKE_COMMIT.match(line)
        if not m:
            continue
        pc, insn, mode = int(m.group(2), 16), int(m.group(3), 16), int(m.group(1))
        if pc < BASE:
            continue
        tok = m.group(4).split()
        rd = rd_val = st = ld = None
        i = 0
        while i < len(tok):
            t = tok[i]
            if re.fullmatch(r"x\d+", t):
                rd, rd_val = int(t[1:]), int(tok[i + 1], 16)
                i += 2
            elif t == "mem":
                addr = int(tok[i + 1], 16)
                if i + 2 < len(tok) and tok[i + 2].startswith("0x"):
                    d = tok[i + 2][2:]
                    st = (addr, int(d, 16), len(d) // 2)
                    i += 3
                else:
                    ld = addr
                    i += 2
            else:   # CSR write (c<num>_<name> value) or other: not compared
                i += 2
        events.append(Event(pc, insn, rd, rd_val, st, ld, mode))
    return events


def parse_rtl(path: Path) -> list[Event]:
    events = []
    for line in path.read_text().splitlines():
        (_order, pc, insn, trap, rd, rd_wdata, maddr, rmask, wmask,
         _rdata, wdata, mode) = line.split()
        pc = int(pc, 16)
        if int(trap):
            events.append(Event(pc, None))
            continue
        rd_i = int(rd)
        rmask, wmask = int(rmask, 16), int(wmask, 16)
        st = ld = None
        if wmask:
            n = bin(wmask).count("1")
            st = (int(maddr, 16), int(wdata, 16) & ((1 << 8 * n) - 1), n)
        if rmask:
            ld = int(maddr, 16)
        events.append(Event(pc, int(insn, 16), rd_i or None,
                            int(rd_wdata, 16) if rd_i else None, st, ld, int(mode)))
    return events


def upto_tohost(events: list[Event], tohost: int) -> list[Event]:
    for i, e in enumerate(events):
        if e.st is not None and e.st[0] == tohost:
            return events[:i + 1]
    return events


# mcycle, mcycleh, cycle, cycleh: Spike models CPI 1, the RTL counts cycles;
# time, timeh: CLINT mtime (Spike: per instruction count, RTL: per clock)
CYCLE_CSRS = {0xB00, 0xB80, 0xC00, 0xC80, 0xC01, 0xC81}
# mvendorid, marchid, mimpid: implementation-defined (Spike: marchid = 5)
IMPL_ID_CSRS = {0xF11, 0xF12, 0xF13}
# CSR reads whose value is not compared (tracked like a cycle count)
UNCOMPARED_CSRS = CYCLE_CSRS | IMPL_ID_CSRS
LOAD_SIZE = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2}       # funct3 -> bytes


class CycleTaint:
    """Registers and memory bytes holding a value derived from a cycle
    counter or implementation-ID CSR read (UNCOMPARED_CSRS), tracked along
    the Spike trace (RV32IM + Zicsr). Such rd
    values and store data are not compared; the comparison ends at the first
    branch, JALR or memory address that depends on one."""

    def __init__(self):
        self.regs: set[int] = set()
        self.mem: set[int] = set()

    def _t(self, r: int) -> bool:
        return r in self.regs

    def check(self, e: Event) -> tuple[bool, str | None]:
        """Before comparing e: (mask its rd value / store data, stop reason)."""
        insn = None if e.insn is None else rvc.expand(e.insn)   # 32-bit form of a C instruction
        if insn is None or not (self.regs or self.mem or (insn & 0x7F) == 0x73):
            return False, None
        op, f3 = insn & 0x7F, (insn >> 12) & 7
        rs1, rs2 = (insn >> 15) & 31, (insn >> 20) & 31
        if op == 0x63 and (self._t(rs1) or self._t(rs2)):
            return False, "branch"
        if op == 0x67 and self._t(rs1):
            return False, "jalr"
        if op in (0x03, 0x23) and self._t(rs1):
            return False, "address"
        if op == 0x03 and e.ld is not None:
            return any(a in self.mem for a in range(e.ld, e.ld + LOAD_SIZE.get(f3, 4))), None
        if op == 0x23:
            return self._t(rs2), None
        if op == 0x13:
            return self._t(rs1), None
        if op == 0x33:
            return self._t(rs1) or self._t(rs2), None
        if op == 0x73 and f3 & 3:
            return (insn >> 20) in UNCOMPARED_CSRS, None
        return False, None

    def update(self, e: Event, tainted: bool) -> None:
        if e.rd is not None:
            (self.regs.add if tainted else self.regs.discard)(e.rd)
        if e.st is not None:
            addrs = range(e.st[0], e.st[0] + e.st[2])
            if tainted:
                self.mem.update(addrs)
            else:
                self.mem.difference_update(addrs)


def masked(e: Event) -> Event:
    return replace(e, rd_val=None, st=None if e.st is None else (e.st[0], None, e.st[2]))


INSTRET_CSRS = {0xB02, 0xC02}           # minstret, instret (low halves)


def instret_access(insn: int | None) -> tuple[bool, bool]:
    """(reads minstret / instret low half, writes minstret low half)."""
    insn = None if insn is None else rvc.expand(insn)
    if insn is None or (insn & 0x7F) != 0x73 or (insn >> 12) & 3 == 0:
        return False, False
    csr, src = insn >> 20, (insn >> 15) & 31
    writes = (insn >> 12) & 3 == 1 or src != 0      # csrrw[i], or a nonzero rs1 / uimm
    return csr in INSTRET_CSRS, writes and csr == 0xB02


def compare(ref: list[Event], dut: list[Event], boot: int = 0) -> tuple[str | None, str]:
    """(None when equal, else a mismatch report; note on a cycle-dependent end).
    boot: Spike's boot-ROM instruction count, added to the RTL's minstret
    reads until software first writes minstret."""
    taint = CycleTaint()
    offset = boot
    for i in range(min(len(ref), len(dut))):
        mask, stop = taint.check(ref[i])
        if stop:
            return None, f"; cycle-dependent from #{i}: {stop} at pc {ref[i].pc:08x}"
        reads, writes = instret_access(dut[i].insn)
        if reads and offset and dut[i].rd_val is not None:
            dut[i] = replace(dut[i], rd_val=(dut[i].rd_val + offset) & 0xFFFFFFFF)
        if writes:
            offset = 0
        r, d = (masked(ref[i]), masked(dut[i])) if mask else (ref[i], dut[i])
        if r != d:
            lines = [f"mismatch at retired #{i}"]
            for j in range(max(0, i - 4), i):
                lines.append(f"  ok    {ref[j]}")
            lines.append(f"  spike {ref[i]}")
            lines.append(f"  rtl   {dut[i]}")
            return "\n".join(lines), ""
        taint.update(ref[i], mask)
    if len(ref) != len(dut):
        return (f"length: spike {len(ref)}, rtl {len(dut)} entries; next "
                f"{'spike ' + str(ref[len(dut)]) if len(ref) > len(dut) else 'rtl ' + str(dut[len(ref)])}"), ""
    return None, ""


# -----------------------------------------------------------------------------
# one test
# -----------------------------------------------------------------------------
def run_spike(elf: Path, log: Path, max_lines: int) -> int | str:
    """Run Spike with its commit log on stderr -> log. Returns the exit code
    (0 = tohost PASS) or "limit" when the log exceeds max_lines (runaway
    program). Spike's own --instructions limit is not used: it ends runs early
    with exit code 0, and a --log=<file> loses its tail at exit."""
    proc = subprocess.Popen(job("sim", [tool("spike"), *SPIKE_CFG, "-l", "--log-commits", str(elf)], quiet=True),
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    lines = 0
    with open(log, "w") as f:
        for line in proc.stderr:
            f.write(line)
            lines += 1
            if lines > max_lines:
                proc.kill()
                proc.wait()
                return "limit"
    return proc.wait()


def run_test(test: Test, args) -> bool:
    tid = test.tid
    out = OUT / tid
    out.mkdir(parents=True, exist_ok=True)
    elf, syms = compile_test(test, out)
    tohost = syms["tohost"]
    max_cycles = args.max_cycles or test.max_cycles

    spike_log = out / "spike.log"
    spike_log.unlink(missing_ok=True)
    spike_rc = run_spike(elf, spike_log, max_lines=4 * max_cycles) if test.spike else 0

    trace = out / "rtl.trace"
    console = out / "console.log"
    cmd = [str(SIM_BIN), f"+hex={out / 'test.hex'}", f"+trace={trace}",
           f"+tohost={tohost:08x}", f"+max_cycles={max_cycles}",
           f"+istall={args.istall}", f"+dstall={args.dstall}"]
    if "console" in syms:
        cmd += [f"+console={syms['console']:08x}", f"+console_log={console}"]
    if "irqgen" in syms:
        cmd.append(f"+irqgen={syms['irqgen']:08x}")
    cmd += test.plusargs
    if args.seed is not None:
        cmd.append(f"+verilator+seed+{args.seed}")
    if args.coverage:
        (out / "coverage.dat").unlink(missing_ok=True)
        cmd.append(f"+verilator+coverage+file+{out / 'coverage.dat'}")
    sim = subprocess.run(job("sim", cmd), text=True, capture_output=True, timeout=3600)
    (out / "sim.log").write_text(sim.stdout + sim.stderr)
    m = re.search(r"^TB: (.*)$", sim.stdout, re.M)
    status = m.group(1) if m else "no result (see sim.log)"
    stats = re.search(r"^TB: cycles (\d+) retired (\d+)$", sim.stdout, re.M)
    slept = re.search(r"^TB: sleep cycles (\d+)$", sim.stdout, re.M)

    dut = upto_tohost(parse_rtl(trace), tohost) if trace.exists() else []
    if test.spike:
        ref = upto_tohost(parse_spike(spike_log), tohost)
        diff, note = compare(ref, dut, spike_boot_count(spike_log))
    else:
        diff, note = None, ", self-checking"
    rep_ok, rep_msg = True, ""
    if test.report:
        rep_ok, rep_msg = test.report(console.read_text() if console.exists() else "")

    ok = status == "PASS" and spike_rc == 0 and diff is None and rep_ok
    perf = ""
    if stats:
        cyc, ret = int(stats.group(1)), int(stats.group(2))
        perf = f"  ({ret} instr, {cyc} cycles, CPI {cyc / max(ret, 1):.2f})"
        if slept and int(slept.group(1)):
            perf += f", {slept.group(1)} asleep"
    print(f"{'PASS' if ok else 'FAIL'}  {tid:24s} rtl {status}, spike rc "
          f"{spike_rc if test.spike else '-'}, trace "
          f"{('match' if test.spike else 'not compared') if diff is None else 'MISMATCH'}"
          f" [{len(dut)} entries{note}]{perf}")
    if rep_msg:
        print(f"      {rep_msg}")
    if diff:
        print("      " + diff.replace("\n", "\n      "))
        print(f"      see {out.relative_to(ROOT)}/ (test.dis, spike.log, rtl.trace)")
    return ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("tests", nargs="*",
                    help="rv32ui[/add], rv32mi[/...], chillus[/name], random:N, random/SEED, "
                         "coremark, or a .S / .c file (default: the regression list)")
    ap.add_argument("--length", type=int, default=400, help="random sequence length")
    ap.add_argument("--istall", type=int, default=0, help="random fetch stall %%")
    ap.add_argument("--dstall", type=int, default=0, help="random data stall %%")
    ap.add_argument("--seed", type=int, help="Verilator random seed")
    ap.add_argument("--max-cycles", type=int,
                    help=f"RTL cycle limit (default {MAX_CYCLES}; CoreMark: 1M per iteration)")
    ap.add_argument("--iterations", type=int, default=1, help="CoreMark iterations")
    ap.add_argument("--rebuild", action="store_true", help="force the Verilator build")
    ap.add_argument("--param", action="append", default=[], metavar="NAME=VALUE",
                    help="chillus_core parameter (repeatable); own build and out directory")
    ap.add_argument("--tag", help="outputs in sim/out/<tag>/ (default with --param: "
                                  "<NAME><VALUE>[_...])")
    ap.add_argument("--coverage", action="store_true",
                    help="coverage model (own build), outputs in sim/out/cov/; "
                         "report: sim/coverage.py")
    args = ap.parse_args()

    global BUILD, OUT, SIM_BIN
    params = parse_params(args.param)
    if "MEM_WORDS" in params:
        set_ram(4 * int(params["MEM_WORDS"], 0))
    n_trig = int(params.get("NUM_TRIGGERS", "0"), 0)
    set_triggers(n_trig)
    n_pmp = int(params.get("PMP_REGIONS", "4"), 0)
    set_pmp(n_pmp)
    if params:
        BUILD = BUILD.with_name(f"obj_{params_tag(params)}")
        SIM_BIN = BUILD / SIM_BIN.name
    if args.coverage:
        BUILD = BUILD.with_name(f"{BUILD.name}_cov")
        SIM_BIN = BUILD / SIM_BIN.name
        OUT = OUT / "cov"
    tag = args.tag or params_tag(params)
    if tag:
        OUT = OUT / tag
    build_sim(args.rebuild, params, args.coverage)
    names = args.tests or [l.split("#")[0].strip() for l in REGRESSION.read_text().splitlines()
                           if l.split("#")[0].strip()]
    todo = [t for name in names for t in resolve(name, args)]
    passed = failed = 0
    for test in todo:
        if test.tid in SKIP:
            print(f"SKIP  {test.tid:24s} {SKIP[test.tid]}")
            continue
        if test.needs_debug and params.get("DEBUG", "1") in ("0", "1'b0", "0'b0"):
            print(f"SKIP  {test.tid:24s} needs debug mode (DEBUG=0 build)")
            continue
        if test.needs_triggers and n_trig == 0:
            print(f"SKIP  {test.tid:24s} needs triggers (--param NUM_TRIGGERS=<n>)")
            continue
        if (test.needs_pmp or test.tid in NEEDS_PMP) and n_pmp == 0:
            print(f"SKIP  {test.tid:24s} needs PMP entries (PMP_REGIONS=0 build)")
            continue
        if run_test(test, args):
            passed += 1
        else:
            failed += 1
    print(f"{passed} passed, {failed} failed")
    if args.coverage:
        print("coverage: python3 sim/coverage.py   (merges sim/out/cov/**/coverage.dat)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
