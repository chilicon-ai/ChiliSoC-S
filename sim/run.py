# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run software on the ChiliSoC-S top (chilisocs_top) in Verilator.

  python sim/run.py                     the regression (sim/tests.list)
  python sim/run.py hello bus           some tests (sw/tests/<name>.c, or coremark)
  python sim/run.py coremark --iterations 10
  python sim/run.py --param SRAM_AW=12  other top parameters (rebuilds)
  python sim/run.py stress --seed 7 --param MEM_WAIT=3   the stress test, another seed, wait states
  python sim/run.py --xip               programs linked to run from the SPI flash (sw/lib/link_xip.ld)
  python sim/run.py hello --gls syn/orfs/out/chilisocs_p2.4/results/nangate45/chilisocs/base/6_final.v
                                        on an ORFS gate-level netlist (zero delay)

Builds sim/tb/chilisocs_tb.sv with every file list RTL file and every
invariant checker (BaseChiliSV, ChiliMix, ChillU-S, ChiliSoC-S), assertions
on. Per test: compiles the boot ROM (sw/boot) and the program (sw/lib +
sw/tests/<name>.c, linked by sw/lib/link.ld) with riscv64-unknown-elf-gcc,
splits the program's ELF into SRAM0 / SRAM1 / SPI flash images, and runs the model; a
test passes on TEST PASS (the program printed "*** PASS" on UART0) with no
assertion error; a test in SLEEP_TESTS must also have slept (core_sleep), and
the core's unprivileged (user-mode) transfers per phase must match USER_PHASES
(none at all for a test not listed), and only the tests in FLASH_TESTS /
EEPROM_TESTS may (and must) use the SPI flash / I2C EEPROM models. coremark uses ChillU-S's CoreMark port
(lib/chillus/sim/coremark) and the sources in $COREMARK (default
~/coremark; skipped when absent unless named), and reports CoreMark/MHz.
--xip links every program with sw/lib/link_xip.ld (code and read-only data
in the SPI flash, executed in place; writable data copied to the SRAMs by
crt0), skips the tests in XIP_SKIP, expects every test to read the flash and
passes +xip (the debugger's halt PCs are in the flash);
outputs in sim/out/<test>_xip[_<params>]/.
--seed sets the random seed of the seeded tests (SEED_TESTS: compiled with
-DSEED=<n>; the testbench's random choices follow +verilator+seed+<n>).

--gls <netlist>: the model is the netlist of syn/orfs/run.sh chilisocs (top
parameters at their defaults; --param is not allowed), the Nangate45 cells
as Verilog models that Yosys writes from the platform liberty (taken from
the ORFS image of syn/orfs/run.sh, or $NANGATE45_LIB) with every flop and
latch starting at 1, and sim/gls/fakeram45_1024x32.sv (fakeram45_small.sv: cache arrays) for the memory
macros; no checkers (they need RTL names), no user-transfer check; each
result line gives the wall-clock time and simulated cycles per second.

Needs: verilator (5.x) and riscv64-unknown-elf-gcc on PATH. Output:
sim/out/build*/ (models), sim/out/<test>[_s<seed>][_<params>]/ (images, sim.log).
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from filelist import CPU, MIX, checkers, files  # noqa: E402
from jobs import job  # noqa: E402

SIM = ROOT / "sim"
SW = ROOT / "sw"
OUT = SIM / "out"
TB = SIM / "tb" / "chilisocs_tb.sv"
TESTS = SIM / "tests.list"
COREMARK_PORT = CPU / "sim" / "coremark"

CROSS = "riscv64-unknown-elf-"
ARCH = ["-march=rv32imc_zicsr_zifencei_zicntr", "-mabi=ilp32", "-static", "-mcmodel=medany",
        "-nostdlib", "-nostartfiles"]
CFLAGS = ["-O2", "-ffreestanding", "-fno-common"]
INCS = [SW / "include", SW / "lib", MIX / "sw" / "include"]
VERILATOR_FLAGS = ["--binary", "--timing", "--assert", "-j", "0", "-Wno-fatal", "-Wno-lint", "-Wno-style",
                   "-Wno-NOLATCH", "-Wno-TIMESCALEMOD", "-Wno-UNOPTFLAT"]

# memory map (chilisocs_pkg) and the top's default sizes
ROM_BASE, SRAM0_BASE, SRAM1_BASE, XIP_BASE = 0x0001_0000, 0x8000_0000, 0x8001_0000, 0x2000_0000
DEFAULTS = {"ROM_AW": 10, "SRAM_AW": 14, "ICACHE_KB": 2}   # top parameters the software sees
FLASH_WORDS = 16384                  # the testbench's SPI flash model (64 KiB)
# tests that must put the core to sleep (the testbench counts core_sleep cycles)
SLEEP_TESTS = {"wfi", "wdog", "dma"}
# tests run with the testbench's JTAG debugger session (+debugger); it must finish
DEBUG_TESTS = {"debug"}
# seeded tests (--seed), run with the debugger's system bus traffic (+sba_stress); it must finish
SEED_TESTS = {"stress"}
# phases of a test with user-mode transfers (the testbench's "user phase" lines):
# phase -> which of (fetch, data, APB) must be nonzero; every other count is 0
# tests that use the testbench's SPI flash / I2C EEPROM models ("flash
# instructions" / "eeprom" line): they must reach the device (and the EEPROM
# must have stretched scl); every other test must leave both alone
FLASH_TESTS = {"spi", "dma", "debug", "xip"}   # debug: the debugger reads XIP
EEPROM_TESTS = {"i2c"}
# tests that cannot run from the flash (--xip), with the reason
XIP_SKIP = {"spi": "drives SPI0 directly, the flash the code runs from",
            "regs": "writes SPI0's registers, the flash the code runs from",
            "openocd": "GDB loads the program and cannot write the flash",
            "pmp": "its PMP map makes SRAM0 the code region",
            "clint": "cycle-count windows that assume code in SRAM",
            "wfi": "cycle-count windows that assume code in SRAM",
            "wdog": "cycle-count windows that assume code in SRAM",
            "dma": "the transfers finish before the WFI that should sleep through them",
            "stress": "the debugger's SBA bursts expect each transfer done within a DMI access"}
# tests run under a real OpenOCD + GDB session over remote_bitbang (sim/openocd):
# the SRAMs start empty, GDB loads the program; skipped when OpenOCD or GDB is
# missing unless named
OPENOCD_TESTS = {"openocd"}
OPENOCD_CFG = SIM / "openocd" / "chilisocs.cfg"
GDB_SESSION = SIM / "openocd" / "session.py"
USER_PHASES = {"umode": {1: (True, True, True), 2: (False, True, False)},
               "pmp": {1: (True, True, True), 2: (True, False, False)},
               "stress": {1: (True, True, False)}}


def run(cmd: list, **kw) -> None:
    r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True, **kw)
    if r.returncode:
        raise RuntimeError(" ".join(map(str, cmd)) + "\n" + r.stdout + r.stderr)


def build(params: dict[str, str]) -> Path:
    """The model (sim/out/build*/obj/Vchilisocs_tb)."""
    tag = "_".join(f"{k}{v}" for k, v in sorted(params.items()))
    out = OUT / ("build" + (f"_{tag}" if tag else ""))
    out.mkdir(parents=True, exist_ok=True)
    srcs = [*files(), *checkers(), TB, SIM / "tb" / "rbb.c"]
    cmd = ["verilator", *VERILATOR_FLAGS, "--top-module", "chilisocs_tb", "-Mdir", out / "obj",
           *(f"-G{k}={v}" for k, v in params.items()), *srcs]
    print(f"build: verilator {len(srcs)} files" + (f" {params}" if params else ""), flush=True)
    log = out / "build.log"
    with log.open("w") as fh:
        r = subprocess.run(job("build", [str(c) for c in cmd]), stdout=fh, stderr=subprocess.STDOUT)
    if r.returncode:
        sys.exit(f"run.py: Verilator build failed, see {log.relative_to(ROOT)}")
    return out / "obj" / "Vchilisocs_tb"


def gls_cells(out: Path) -> Path:
    """Verilog models of the Nangate45 cells (out/cells.v), from the liberty:
    Yosys read_liberty imports each cell's function, flop and latch; every
    flop and latch then starts at 1, so the first fall of a reset pin is a
    falling edge on every reset net (the RTL testbench forces that instead)."""
    cells = out / "cells.v"
    if cells.is_file():
        return cells
    lib = Path(os.environ.get("NANGATE45_LIB", out / "NangateOpenCellLibrary_typical.lib"))
    if not lib.is_file():
        image = re.search(r"orfs:[\w.-]+", (ROOT / "syn" / "orfs" / "run.sh").read_text()).group(0)
        rel = "flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib"
        sif = Path(os.environ.get("ORFS_SIF", ""))
        if os.environ.get("ORFS_SIF") and sif.is_file() and shutil.which("apptainer"):   # an Apptainer image (as syn/orfs/run.sh)
            cmd = ["apptainer", "exec", "--containall", str(sif), "cat", f"/OpenROAD-flow-scripts/{rel}"]
        else:
            cmd = ["docker", "run", "--rm", f"openroad/{image}", "cat", rel]
        with lib.open("w") as fh:
            r = subprocess.run(cmd, stdout=fh)
        if r.returncode:
            lib.unlink()
            sys.exit("run.py: no Nangate45 liberty: set $NANGATE45_LIB or get the ORFS image of syn/orfs/run.sh")
    yosys = os.environ.get("YOSYS") or shutil.which("yosys", path=f"{Path.home() / 'oss-cad-suite' / 'bin'}") or "yosys"
    raw = out / "cells_raw.v"
    run([yosys, "-q", "-p", f"read_liberty -ignore_miss_func {lib}; write_verilog -noattr {raw}"])
    text = re.sub(r"^(\s*)reg (\w+);$", r"\1reg \2;\n\1initial \2 = 1'b1;", raw.read_text(), flags=re.M)
    cells.write_text("// GENERATED by sim/run.py --gls from the Nangate45 liberty: do not edit\n" + text)
    return cells


def build_gls(netlist: Path) -> Path:
    """The gate-level model (sim/out/build_gls/obj/Vchilisocs_tb) of an ORFS netlist."""
    out = OUT / "build_gls"
    out.mkdir(parents=True, exist_ok=True)
    pkgs = [f for f in files() if f.name.endswith("_pkg.sv")]   # the testbench's constants
    srcs = [*pkgs, gls_cells(out), SIM / "gls" / "fakeram45_1024x32.sv", SIM / "gls" / "fakeram45_small.sv", netlist.resolve(), TB, SIM / "tb" / "rbb.c"]
    cmd = ["verilator", *VERILATOR_FLAGS, "-Wno-MULTIDRIVEN", "+define+GLS", "--top-module", "chilisocs_tb",
           "-Mdir", out / "obj", *srcs]
    print(f"build: verilator gate level {netlist}", flush=True)
    t0 = time.monotonic()
    log = out / "build.log"
    with log.open("w") as fh:
        r = subprocess.run(job("build", [str(c) for c in cmd]), stdout=fh, stderr=subprocess.STDOUT)
    if r.returncode:
        sys.exit(f"run.py: Verilator build failed, see {log.relative_to(ROOT)}")
    print(f"build: {time.monotonic() - t0:.0f} s", flush=True)
    return out / "obj" / "Vchilisocs_tb"


def elf_segments(elf: Path) -> list[tuple[int, bytes]]:
    """(address, bytes) of the PT_LOAD segments of an ELF32 little-endian file."""
    d = elf.read_bytes()
    phoff, = struct.unpack_from("<I", d, 28)
    phentsize, phnum = struct.unpack_from("<HH", d, 42)
    segs = []
    for i in range(phnum):
        ptype, off, _, paddr, filesz, _, _, _ = struct.unpack_from("<8I", d, phoff + i * phentsize)
        if ptype == 1 and filesz:
            segs.append((paddr, d[off:off + filesz]))
    return segs


def write_hex(path: Path, segs: list[tuple[int, bytes]], base: int, words: int) -> None:
    mem = bytearray(words * 4)
    for addr, data in segs:
        if base <= addr < base + len(mem):
            if addr + len(data) > base + len(mem):
                raise RuntimeError(f"{path.name}: segment at {addr:#x} does not fit ({len(data)} bytes)")
            mem[addr - base:addr - base + len(data)] = data
    path.write_text("".join(f"{w:08x}\n" for w, in struct.iter_unpack("<I", mem)))


def coremark_dir() -> Path:
    return Path(os.environ.get("COREMARK", Path.home() / "coremark"))


def coremark_report(text: str) -> tuple[bool, str]:
    """CoreMark's self-check (known seeds, no CRC error; the 'at least 10
    secs' error is expected in simulation) and CoreMark/MHz from its ticks."""
    errors = [ln for ln in text.splitlines() if "ERROR!" in ln and "at least 10 secs" not in ln]
    known = re.search(r"^2K performance run parameters", text, re.M)
    ticks = re.search(r"^Total ticks\s*:\s*(\d+)", text, re.M)
    iters = re.search(r"^Iterations\s*:\s*(\d+)", text, re.M)
    if errors or not (known and ticks and iters):
        return False, "; ".join(errors) or "incomplete or unknown-seed report"
    n, cyc = int(iters.group(1)), int(ticks.group(1))
    return True, f"CoreMark/MHz {n * 1e6 / cyc:.3f} ({n} iterations, {cyc} cycles)"


def compile_test(name: str, out: Path, sizes: dict[str, int], iterations: int, seed: int = 1,
                 extra_defs: tuple[str, ...] = (), link: Path | None = None, xip: bool = False) -> None:
    gcc = [CROSS + "gcc", *ARCH]
    boot = out / "boot.elf"
    run([*gcc, "-T", SW / "boot" / "boot.ld", SW / "boot" / "boot.S", "-o", boot])
    incs = list(INCS)
    defs = [f"-DICACHE_KB={sizes['ICACHE_KB']}", *extra_defs]
    if name == "coremark":
        cm = coremark_dir()
        srcs = [cm / f"{f}.c" for f in ("core_list_join", "core_main", "core_matrix", "core_state", "core_util")]
        srcs.append(COREMARK_PORT / "core_portme.c")
        incs += [COREMARK_PORT, cm]
        defs += [f"-DITERATIONS={iterations}", f'-DFLAGS_STR="{" ".join(CFLAGS)}"']
    else:
        srcs = [SW / "tests" / f"{name}.c"]
        if name in SEED_TESTS:
            defs += [f"-DSEED={seed}u"]
    elf = out / f"{name}.elf"
    run([*gcc, *CFLAGS, *(f"-I{i}" for i in incs), *defs, "-T", link or SW / "lib" / ("link_xip.ld" if xip else "link.ld"),
         SW / "lib" / "crt0.S", SW / "lib" / "runtime.c", *srcs, "-lgcc", "-Wl,--no-warn-rwx-segments",
         "-o", elf])
    write_hex(out / "rom.hex", elf_segments(boot), ROM_BASE, 1 << sizes["ROM_AW"])
    segs = elf_segments(elf)
    write_hex(out / "sram0.hex", segs, SRAM0_BASE, 1 << sizes["SRAM_AW"])
    write_hex(out / "sram1.hex", segs, SRAM1_BASE, 1 << sizes["SRAM_AW"])
    write_hex(out / "flash.hex", segs, XIP_BASE, FLASH_WORDS)


def gdb_exe() -> str | None:
    """GDB for RISC-V: $GDB, riscv64-unknown-elf-gdb or gdb-multiarch."""
    for g in (os.environ.get("GDB"), CROSS + "gdb", "gdb-multiarch"):
        if g and shutil.which(g):
            return g
    return None


def openocd_exe() -> str | None:
    """OpenOCD: $OPENOCD, ~/openocd/bin/openocd (tools/install_openocd.sh) or openocd on PATH."""
    for o in (os.environ.get("OPENOCD"), str(Path.home() / "openocd" / "bin" / "openocd"), "openocd"):
        if o and shutil.which(o):
            return o
    return None


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def wait_port(port: int, proc: subprocess.Popen, timeout: float) -> bool:
    end = time.monotonic() + timeout
    while time.monotonic() < end and proc.poll() is None:
        with socket.socket() as s:
            if s.connect_ex(("127.0.0.1", port)) == 0:
                return True
        time.sleep(0.2)
    return False


def run_openocd(cmd: list, out: Path, elf: Path) -> str:
    """The model with +rbb_port, OpenOCD on it, then GDB with the session
    script; returns the model's output followed by the OpenOCD and GDB logs."""
    rbb, gdbp = free_port(), free_port()
    logs = {k: (out / f"{k}.log").open("w") for k in ("openocd", "gdb")}
    sim = subprocess.Popen([str(c) for c in [*cmd, f"+rbb_port={rbb}"]], cwd=out, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, errors="replace")
    procs = [sim]
    try:
        if not wait_port(rbb, sim, 30):
            return sim.communicate()[0] + "\nopenocd: the model did not listen\n"
        ocd = subprocess.Popen([openocd_exe(), "-c", f"set RBB_PORT {rbb}; gdb_port {gdbp}; telnet_port disabled; "
                                "tcl_port disabled", "-f", str(OPENOCD_CFG)],
                               cwd=out, stdout=logs["openocd"], stderr=subprocess.STDOUT)
        procs.append(ocd)
        if not wait_port(gdbp, ocd, 600):
            sim.kill()
            return sim.communicate()[0] + "\nopenocd: no GDB port, see openocd.log\n"
        gdb = subprocess.run([gdb_exe(), "-q", "-nx", "-batch", "-ex", f"set $gdb_port = {gdbp}", "-x",
                              str(GDB_SESSION), str(elf)], cwd=out, stdout=logs["gdb"],
                             stderr=subprocess.STDOUT, timeout=3600)
        if gdb.returncode or "gdb session done" not in (out / "gdb.log").read_text():
            sim.kill()                            # the program never got its go: stop now
        text = sim.communicate(timeout=1800)[0]
        return text + f"\ngdb exit {gdb.returncode}\n" + (out / "gdb.log").read_text()
    except subprocess.TimeoutExpired:
        sim.kill()
        return sim.communicate()[0] + "\nopenocd: session timed out\n" + (out / "gdb.log").read_text()
    finally:
        for p in procs:
            if p.poll() is None:
                p.kill()
                p.wait()
        for f in logs.values():
            f.close()


def run_test(name: str, model: Path, sizes: dict[str, int], iterations: int,
             seed: int = 1, tag: str = "", gls: bool = False,
             xip: bool = False) -> tuple[bool, str]:
    out = OUT / (name + (f"_s{seed}" if name in SEED_TESTS and seed != 1 else "") + ("_xip" if xip else "")
                 + (f"_{tag}" if tag else ""))
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    try:
        compile_test(name, out, sizes, iterations, seed, xip=xip)
    except RuntimeError as e:
        (out / "compile.log").write_text(str(e))
        return False, f"compile failed, see {(out / 'compile.log').relative_to(ROOT)}"
    max_cycles = (1_000_000 * (iterations + 1) if name == "coremark" else
                  500_000_000 if name in OPENOCD_TESTS else 8_000_000 if name in SEED_TESTS else 2_000_000)
    cmd = [model, f"+rom={out / 'rom.hex'}", f"+sram0={out / 'sram0.hex'}", f"+sram1={out / 'sram1.hex'}",
           f"+flash={out / 'flash.hex'}", "+uart_div=1", *(["+xip"] if xip else []), f"+max_cycles={max_cycles}", *(["+debugger"] if name in DEBUG_TESTS else []),
           *(["+sba_stress", f"+verilator+seed+{seed}"] if name in SEED_TESTS else [])]
    if name in OPENOCD_TESTS:                      # empty SRAMs: GDB loads the program
        cmd = [c for c in cmd if not str(c).startswith(("+sram0=", "+sram1="))]
        text = run_openocd(cmd, out, out / f"{name}.elf")
    else:
        t0 = time.monotonic()
        r = subprocess.run(job("sim", [str(c) for c in cmd]), cwd=out, capture_output=True, text=True, errors="replace")
        text = r.stdout + r.stderr
        secs = time.monotonic() - t0
    log = out / "sim.log"
    log.write_text(text)
    m = re.search(r"^TEST (PASS|FAIL|TIMEOUT).*?(\d+)$", text, re.M)
    errors = [ln for ln in text.splitlines() if "%Error" in ln or "Assertion failed" in ln]
    if errors:
        return False, errors[0].strip()[:120]
    if not m or m.group(1) != "PASS":
        fail = re.search(r"^\*\*\* FAIL.*$", text, re.M)
        return False, (fail.group(0) if fail else (m.group(0) if m else "no result")) + f", see {log.relative_to(ROOT)}"
    if name == "coremark":
        ok, msg = coremark_report(text)
        return ok, msg
    if name in OPENOCD_TESTS and not re.search(r"^gdb session done", text, re.M):
        failed = re.search(r"^gdb check FAILED.*$", text, re.M)
        return False, (failed.group(0) if failed else "GDB session did not finish") + f", see {log.relative_to(ROOT)}"
    if name in DEBUG_TESTS and not re.search(r"^debugger done", text, re.M):
        return False, f"debugger session did not finish, see {log.relative_to(ROOT)}"
    sba = re.search(r"^sba stress done: (\d+) bursts, (\d+) halts", text, re.M)
    if name in SEED_TESTS and not sba:
        return False, f"debugger traffic did not finish, see {log.relative_to(ROOT)}"
    phases = {int(p): tuple(int(n) for n in c) for p, *c in
              re.findall(r"^user phase (\d+) i (\d+) d (\d+) apb (\d+)$", text, re.M)}
    want = {} if gls else USER_PHASES.get(name, {})
    if len(phases) != 8:
        return False, f"no user transfer counts, see {log.relative_to(ROOT)}"
    for p, counts in ([] if gls else sorted(phases.items())):
        if tuple(n > 0 for n in counts) != want.get(p, (False, False, False)):
            return False, f"user transfers (i, d, apb) {counts} in phase {p}, see {log.relative_to(ROOT)}"
    dev = re.search(r"^flash instructions (\d+) reads (\d+); eeprom starts (\d+) stops (\d+) stretches (\d+)$",
                    text, re.M)
    if not dev:
        return False, f"no device counts, see {log.relative_to(ROOT)}"
    reads, starts, stretches = int(dev.group(2)), int(dev.group(3)), int(dev.group(5))
    flash = name in FLASH_TESTS or xip
    if (reads > 0) != flash or (int(dev.group(1)) > 0 and not flash):
        return False, f"flash instructions {dev.group(1)} reads {reads}, see {log.relative_to(ROOT)}"
    if (starts > 0) != (name in EEPROM_TESTS) or (name in EEPROM_TESTS and not stretches):
        return False, f"eeprom starts {starts} stretches {stretches}, see {log.relative_to(ROOT)}"
    sleep = re.search(r"^core_sleep cycles (\d+)$", text, re.M)
    if name in SLEEP_TESTS and not (sleep and int(sleep.group(1))):
        return False, f"core_sleep never high, see {log.relative_to(ROOT)}"
    user = [f"phase {p} i/d/apb {'/'.join(map(str, phases[p]))}" for p in sorted(want)]
    return True, (f"{int(m.group(2))} cycles" + (f", {int(sleep.group(1))} asleep" if sleep and int(sleep.group(1)) else "")
                  + (f", seed {seed}, debugger {sba.group(1)} bursts {sba.group(2)} halts" if sba else "")
                  + (f", user {'; '.join(user)}" if user else "")
                  + (f", {reads} flash reads" if reads else "")
                  + (f", {starts} I2C starts, {stretches} stretches" if starts else "")
                  + (f", {secs:.0f} s ({int(m.group(2)) / secs:.0f} cycles/s)" if gls else ""))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tests", nargs="*", help="tests (default: sim/tests.list)")
    ap.add_argument("--param", action="append", default=[], help="top parameter NAME=VALUE (repeatable)")
    ap.add_argument("--iterations", type=int, default=1, help="CoreMark iterations")
    ap.add_argument("--seed", type=int, default=1, help="seed of the seeded tests (stress)")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1, help="parallel tests")
    ap.add_argument("--gls", type=Path, metavar="NETLIST", help="gate-level model of an ORFS netlist")
    ap.add_argument("--xip", action="store_true", help="programs run from the SPI flash (sw/lib/link_xip.ld)")
    args = ap.parse_args()
    if args.gls and args.param:
        sys.exit("run.py: --gls runs the netlist as built (no --param)")

    params = dict(p.split("=", 1) for p in args.param)
    sizes = {k: int(params.get(k, v)) for k, v in DEFAULTS.items()}
    names = args.tests or [ln.strip() for ln in TESTS.read_text().splitlines()
                           if ln.strip() and not ln.startswith("#")]
    skipped = []
    if "coremark" in names and not args.tests and not (coremark_dir() / "core_main.c").is_file():
        names.remove("coremark")
        skipped.append("coremark (no $COREMARK)")
    if not (openocd_exe() and gdb_exe()):
        for n in sorted(OPENOCD_TESTS & set(names)):
            if not args.tests:
                names.remove(n)
                skipped.append(f"{n} (no openocd or RISC-V gdb)")
    if args.xip:
        for n in sorted(set(XIP_SKIP) & set(names)):
            names.remove(n)
            skipped.append(f"{n} ({XIP_SKIP[n]})")
    for n in names:
        if n != "coremark" and not (SW / "tests" / f"{n}.c").is_file():
            sys.exit(f"run.py: no test {n} (sw/tests/{n}.c)")

    if args.gls:
        model, tag = build_gls(args.gls), "gls"
    else:
        model = build(params)
        tag = "_".join(f"{k}{v}" for k, v in sorted(params.items()))   # output directories per build
    with ThreadPoolExecutor(max_workers=max(1, args.j)) as ex:
        results = list(ex.map(lambda n: (n, run_test(n, model, sizes, args.iterations, args.seed, tag,
                                                     bool(args.gls), args.xip)), names))
    failed = 0
    for n, (ok, msg) in results:
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'}  {n:12s} {msg}")
    print(f"run: {len(names)} tests, {failed} failed: {'clean' if not failed else 'FAILED'}"
          + (f"; skipped {', '.join(skipped)}" if skipped else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
