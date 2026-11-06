# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Build ChiliSoC-S for the Digilent Arty A7-100T (chilisocs_arty) with Vivado, or lint it.

  python fpga/build.py --lint               slang lint of the board top (no Vivado)
  python fpga/build.py                      bitstream at 50 MHz, ICACHE_KB 4 (fpga/out/arty/)
  python fpga/build.py --clkout-div 13.375  another clock: 1000 MHz / CLKOUT_DIV
  python fpga/build.py --icache-kb 2        another chilisocs_top ICACHE_KB (board default 4)
  python fpga/build.py --program hello      a sw/tests program for the board (fpga/out/arty/hello/)
  python fpga/build.py --program hello --xip  the same, run from the flash (sw/lib/link_xip.ld)

The file list is the SoC's (tools/filelist.py) with two BaseChiliSV
modules swapped for their FPGA versions (SWAPS: the BUFGCE clock gate and
the block RAM with an initial image), then the board top
fpga/arty/chilisocs_arty.sv. --lint adds fpga/lint/unisim.sv (port models of
the Xilinx primitives) and runs slang with tools/lint.py's warnings and waivers.

The build compiles the boot ROM (sw/boot) into fpga/out/arty/rom.hex, writes
the file list, and runs fpga/arty/build.tcl in Vivado batch mode (through
tools/jobs.py): synthesis, place and route for xc7a100tcsg324-1,
reports (timing, utilization, clocks) and chilisocs_arty.bit plus
chilisocs_arty.bin for the configuration flash. Exit status 1 on a failed
lint, a failed Vivado run or negative slack (WNS < 0 in timing.rpt).

--program compiles a regression program as sim/run.py does, with the
console divisor for the board clock (UART_DIV = clk / (16 * 115200),
rounded) and FPGA defined, into <name>.elf for OpenOCD / GDB to load (fpga/README.md),
with its flash part (.xip) linked at FLASH_OFFSET into the window and written
to <name>.flash.bin for the board's flash (empty when it has none), and its
SRAM part to <name>.boot.bin, the image the board's boot ROM copies from the
flash at BOOT_OFFSET (flash boot: fpga/regress.py --flash-boot). With --xip
the program is linked by sw/lib/link_xip.ld: its code, read-only data and the
load image of its writable data go to the flash part, and its SRAM part (the
boot image) is only the jump at SRAM0 into the flash.

The board's boot ROM is sw/boot with FPGA defined: unless the debugger reset
the SoC, it copies a boot image from the flash (BOOT_OFFSET) to SRAM first.
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FPGA = ROOT / "fpga"
BOARD = FPGA / "arty"
OUT = FPGA / "out" / "arty"
XILINX = Path("/opt/Xilinx")     # the workstation's shared Vivado install
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "sim"))

from filelist import files as rtl_list_files  # noqa: E402
from jobs import job  # noqa: E402

TOP = "chilisocs_arty"
PART = "xc7a100tcsg324-1"
BAUD = 115200                        # the console
# programs' flash part (.xip) in the board's QSPI flash: past the bitstream
# (about 2 MiB compressed, 3.8 MiB not), so the window address is XIP_BASE + it
FLASH_OFFSET = 0x40_0000
# flash boot (sw/boot/boot.S under FPGA): the boot image at BOOT_OFFSET in the flash
BOOT_OFFSET = 0x80_0000
BOOT_MAGIC = 0xC41B_007A
# library file name -> the FPGA version in fpga/arty
SWAPS = {"basechili_clock_gate.sv": BOARD / "basechili_clock_gate.sv",
         "basechili_sram_sp.sv": BOARD / "basechili_sram_sp.sv"}


def rtl_files() -> list[Path]:
    """The SoC's RTL with the FPGA swaps, then the board top."""
    fs = [SWAPS.get(f.name, f) for f in rtl_list_files()]
    missing = set(SWAPS) - {f.name for f in rtl_list_files()}
    if missing:
        sys.exit(f"build: swapped files not in the SoC file list: {sorted(missing)}")
    return fs + [BOARD / f"{TOP}.sv"]


def lint() -> int:
    from pyslang.driver import Driver
    from lint import WAIVED
    files = [FPGA / "lint" / "unisim.sv", *rtl_files()]
    cmd = ["slang", "-Weverything", *(f"-Wno-{w}" for w in WAIVED), "-Wno-unused-def", f"--top={TOP}"]
    cmd += [f.as_posix() for f in files]
    d = Driver()
    d.addStandardArgs()
    if not d.parseCommandLine(shlex.join(cmd)) or not d.processOptions():
        return 2
    parsed = d.parseAllSources()
    d.runFullCompilation(False)
    errors, warnings = d.diagEngine.numErrors, d.diagEngine.numWarnings
    status = "clean" if parsed and not errors and not warnings else "FAILED"
    print(f"fpga lint: {len(files)} files, top {TOP}, {errors} errors, {warnings} warnings: {status}")
    return 0 if status == "clean" else 1


def rom_image(out: Path, rom_aw: int) -> Path:
    """sw/boot as a $readmemh image of the ROM (2 ** rom_aw words)."""
    import run as simrun   # sim/run.py: the cross compiler flags and the hex writer
    elf = out / "boot.elf"
    simrun.run([simrun.CROSS + "gcc", *simrun.ARCH, "-DFPGA", f"-DBOOT_IMAGE={simrun.XIP_BASE + BOOT_OFFSET:#x}",
                f"-DBOOT_MAGIC={BOOT_MAGIC:#x}", "-T", simrun.SW / "boot" / "boot.ld",
                simrun.SW / "boot" / "boot.S", "-o", elf])
    hexf = out / "rom.hex"
    simrun.write_hex(hexf, simrun.elf_segments(elf), simrun.ROM_BASE, 1 << rom_aw)
    return hexf


def program(name: str, clkout_div: float, icache_kb: int, iterations: int = 1, xip: bool = False) -> int:
    """A sw/tests program (or coremark) built for the board's clock."""
    import run as simrun
    out = OUT / name
    out.mkdir(parents=True, exist_ok=True)
    clk_hz = 1e9 / clkout_div
    div = round(clk_hz / (16 * BAUD))
    err = abs(clk_hz / (16 * div) - BAUD) / BAUD
    sizes = {**simrun.DEFAULTS, "ICACHE_KB": icache_kb}
    script = "link_xip.ld" if xip else "link.ld"
    link = out / script                       # the sw/lib link script with FLASH at FLASH_OFFSET into the window
    link.write_text(re.sub(r"(FLASH \(rx\)\s*: ORIGIN = )0x20000000",
                           rf"\g<1>{simrun.XIP_BASE + FLASH_OFFSET:#x}", (simrun.SW / "lib" / script).read_text()))
    simrun.compile_test(name, out, sizes, iterations=iterations, extra_defs=(f"-DUART_DIV={div}", "-DFPGA"),
                        link=link)
    flash_image(out / f"{name}.elf", out / f"{name}.flash.bin")
    boot_image(out / f"{name}.elf", out / f"{name}.boot.bin")
    print(f"program: {out / f'{name}.elf'} (UART_DIV {div}: {BAUD} baud {err:.1%} off at {clk_hz / 1e6:.2f} MHz)")
    return 0 if err < 0.02 else 1


def flash_image(elf: Path, out: Path) -> None:
    """The ELF's segments in the flash window, as the raw bytes to write at FLASH_OFFSET (empty: none)."""
    import run as simrun
    base = simrun.XIP_BASE + FLASH_OFFSET
    mem = bytearray()
    for addr, data in simrun.elf_segments(elf):
        if base <= addr < base + (16 << 20):
            end = addr - base + len(data)
            mem.extend(b"\xff" * max(0, end - len(mem)))
            mem[addr - base:end] = data
    out.write_bytes(bytes(mem))


def boot_image(elf: Path, out: Path) -> None:
    """The ELF's SRAM segments as the boot ROM's flash boot image (sw/boot/boot.S), for BOOT_OFFSET."""
    import struct
    import run as simrun
    segs = [(a, d + b"\0" * (-len(d) % 4)) for a, d in simrun.elf_segments(elf) if a >= simrun.SRAM0_BASE]
    out.write_bytes(struct.pack("<II", BOOT_MAGIC, len(segs))
                    + b"".join(struct.pack("<II", a, len(d)) + d for a, d in segs))


def wns(report: Path) -> float | None:
    """Worst negative slack of a Vivado timing summary (the Design Timing Summary row)."""
    text = report.read_text() if report.is_file() else ""
    m = re.search(r"WNS\(ns\).*?\n[\s-]+\n\s*(-?\d+\.\d+)", text)
    return float(m.group(1)) if m else None


def find_vivado() -> str | None:
    """$VIVADO, else vivado on PATH, else the newest shared install under /opt/Xilinx.

    bin/vivado sets up its own environment, so settings64.sh need not be sourced.
    Both install layouts: /opt/Xilinx/<version>/Vivado (2025.1 on) and
    /opt/Xilinx/Vivado/<version> (before).
    """
    if os.environ.get("VIVADO"):
        return os.environ["VIVADO"]
    if shutil.which("vivado"):
        return shutil.which("vivado")
    found = {}
    for exe in [*XILINX.glob("*/Vivado/bin/vivado"), *XILINX.glob("Vivado/*/bin/vivado")]:
        ver = next((x for x in exe.parts if re.fullmatch(r"\d{4}\.\d+", x)), None)
        if ver:
            found[tuple(int(n) for n in ver.split("."))] = exe
    return str(found[max(found)]) if found else None


def build(clkout_div: float, icache_kb: int) -> int:
    vivado = find_vivado()
    if not vivado:
        sys.exit(f"build: no Vivado ($VIVADO, PATH or {XILINX}/<version>/Vivado; fpga/README.md)")
    OUT.mkdir(parents=True, exist_ok=True)
    rom = rom_image(OUT, rom_aw=10)   # chilisocs_top ROM_AW default (the board top keeps it)
    (OUT / "files.f").write_text("".join(f"{f.as_posix()}\n" for f in rtl_files()))
    generics = {"ROM_INIT": f'"{rom.as_posix()}"', "CLKOUT_DIV": f"{clkout_div:.3f}", "ICACHE_KB": str(icache_kb)}
    cmd = [vivado, "-mode", "batch", "-nojournal", "-log", str(OUT / "vivado.log"),
           "-source", str(BOARD / "build.tcl"), "-tclargs", str(OUT), PART, TOP, str(BOARD / f"{TOP}.xdc"),
           " ".join(f"{k}={v}" for k, v in generics.items())]
    mhz = 1000.0 / clkout_div
    print(f"build: {vivado}\nbuild: {TOP} on {PART} at {mhz:.2f} MHz, ICACHE_KB {icache_kb}; log {OUT / 'vivado.log'}", flush=True)
    r = subprocess.run(job("synth", cmd, cores=4), cwd=OUT)
    slack = wns(OUT / "timing.rpt")
    ok = r.returncode == 0 and (OUT / f"{TOP}.bit").is_file() and slack is not None and slack >= 0
    print(f"build: WNS {slack} ns, bitstream {OUT / f'{TOP}.bit'}: {'ok' if ok else 'FAILED'}")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lint", action="store_true", help="slang lint of the board top only")
    ap.add_argument("--clkout-div", type=float, default=20.0,
                    help="MMCM CLKOUT0 divide (1000 MHz / it; a multiple of 0.125): 20 = 50 MHz")
    ap.add_argument("--icache-kb", type=int, default=4, help="chilisocs_top ICACHE_KB (0, 2 or 4; the board default 4)")
    ap.add_argument("--program", metavar="NAME", help="build sw/tests/NAME.c (or coremark) for the board instead")
    ap.add_argument("--iterations", type=int, default=1,
                    help="CoreMark iterations for --program coremark (a valid score runs >= 10 s)")
    ap.add_argument("--xip", action="store_true", help="with --program: run it from the flash (sw/lib/link_xip.ld)")
    args = ap.parse_args()
    if args.lint:
        return lint()
    if (args.clkout_div * 8) % 1 or not 1.0 <= args.clkout_div <= 128.0:
        sys.exit("build: --clkout-div must be a multiple of 0.125 in 1 .. 128")
    if args.program:
        return program(args.program, args.clkout_div, args.icache_kb, args.iterations, args.xip)
    return build(args.clkout_div, args.icache_kb)


if __name__ == "__main__":
    sys.exit(main())
