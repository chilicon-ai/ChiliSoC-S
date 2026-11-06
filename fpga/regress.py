# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run regression programs on the Arty A7-100T over JTAG and read the result on its UART.

  python fpga/regress.py                    every board program of sim/tests.list
  python fpga/regress.py hello pmp          these programs
  python fpga/regress.py --bitstream        load fpga/out/arty/chilisocs_arty.bit first (openFPGALoader)
  python fpga/regress.py --flash-boot hello the bitstream and hello into the flash, then boot from it
  python fpga/regress.py --xip              the programs run from the flash (sw/lib/link_xip.ld)

Each program is built for the board clock (fpga/build.py --program), loaded
by OpenOCD through the JTAG-HS2 (fpga/arty/openocd.cfg: reset halt,
load_image, verify_image, resume at the entry) and passes when the console
(the Arty's USB UART, FT2232 channel B) prints "*** PASS" within --timeout.
A program with a flash part (.xip, linked at build.FLASH_OFFSET into the
window, past the bitstream) has it written to the board's QSPI flash first.
POR_TESTS get a power-on reset first (the bitstream reloaded).
SKIP lists the programs that need the testbench (its EEPROM,
GPIO loopback, external reset or debugger), with the reason; they are not run.
--flash-boot writes the bitstream (offset 0), the program's boot image
(build.BOOT_OFFSET) and its flash part into the flash, lets the FPGA configure
from it and waits for the result with no debugger: the board's boot ROM
copies the image to SRAM (sw/boot/boot.S under FPGA). The board keeps
booting that program at power-on until the flash is written again.
--xip links every program by sw/lib/link_xip.ld (fpga/build.py --xip): all
of it is in the flash part, OpenOCD loads only the jump at SRAM0, and the
tests sim/run.py lists in XIP_SKIP are skipped too. With --flash-boot the
board then boots a program that runs from the flash.
Exit status 1 when a program fails or times out.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import select
import shutil
import subprocess
import sys
import termios
import time
from pathlib import Path

FPGA = Path(__file__).resolve().parent
ROOT = FPGA.parent
sys.path.insert(0, str(FPGA))

import build  # noqa: E402  fpga/build.py: program(), OUT, BAUD
import run as simrun  # noqa: E402  sim/run.py (on the path through build): XIP_SKIP

CFG = FPGA / "arty" / "openocd.cfg"
TESTS = ROOT / "sim" / "tests.list"
# programs that need the testbench, and what they need from it
SKIP = {
    "sysrst": "the testbench's external reset request",
    "wdog": "a power-on first boot (the debugger's reset halt adds dbg)",
    "debug": "the testbench's JTAG debugger session and SPI flash model",
    "i2c": "the testbench's I2C EEPROM",
    "plic": "the GPIO loopback",
    "openocd": "the simulation's remote_bitbang OpenOCD session",
    "stress": "the testbench's +sba_stress debugger traffic (its load also times out)",
}
# programs that check power-on reset values (socctl's scratch registers keep
# what an earlier program left): the bitstream is reloaded before them
POR_TESTS = {"regs"}
# OpenOCD loads the SRAM part of a program; its flash part (.xip) is written to
# the flash first, and verify_image then reads it back through XIP
SRAM_BASE, SRAM_SIZE = 0x8000_0000, 0x2_0000
RESULT = re.compile(rb"\*\*\* (PASS|FAIL [0-9]+)")


def load_bitstream() -> int:
    """The bitstream into the FPGA over the Arty's own JTAG: a power-on reset of the SoC."""
    bit = build.OUT / f"{build.TOP}.bit"
    return subprocess.run(["openFPGALoader", "-b", "arty_a7_100t", str(bit)],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode


def flash(image: Path, offset: int, reset: bool) -> int:
    """image into the board's flash at offset; reset: the FPGA configures from the flash afterwards."""
    return subprocess.run(["openFPGALoader", "-b", "arty_a7_100t", "-f", "-o", f"{offset:#x}",
                           *([] if reset else ["--skip-reset"]), str(image)],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode


def read_result(fd: int, timeout: float) -> tuple[str, bytes]:
    out, end = b"", time.monotonic() + timeout
    while (m := RESULT.search(out)) is None and time.monotonic() < end:
        if select.select([fd], [], [], 0.2)[0]:
            out += os.read(fd, 4096)
    return (m.group(1).decode() if m else "TIMEOUT"), out


def flash_boot(name: str, tty: str, timeout: float, log_dir: Path) -> str:
    """The bitstream, name's boot image and flash part into the flash; the result of booting from it."""
    d = build.OUT / name
    if flash(build.OUT / f"{build.TOP}.bit", 0, False):
        return "BITSTREAM FLASH FAILED"
    if (d / f"{name}.flash.bin").stat().st_size and flash(d / f"{name}.flash.bin", build.FLASH_OFFSET, False):
        return "FLASH WRITE FAILED"
    fd = open_tty(tty)
    try:
        if flash(d / f"{name}.boot.bin", build.BOOT_OFFSET, True):     # then configures from the flash
            return "BOOT IMAGE FLASH FAILED"
        result, out = read_result(fd, timeout)
        (log_dir / f"{name}.flash_boot.uart.log").write_bytes(out)
        return result
    finally:
        os.close(fd)


def write_flash(image: Path) -> int:
    """A program's flash part to the board's flash at build.FLASH_OFFSET (openFPGALoader loads its
    own SPI bridge bitstream for it, so the SoC's bitstream is loaded again afterwards)."""
    return flash(image, build.FLASH_OFFSET, True) or load_bitstream()


def board_tests() -> list[str]:
    names = [ln.split("#")[0].strip() for ln in TESTS.read_text().splitlines()]
    return [n for n in names if n and n not in SKIP]


def find_openocd() -> str:
    cad = sorted(glob.glob("/opt/oss-cad-suite*/bin/openocd"))[-1:]     # an OSS CAD Suite in /opt
    for o in (os.environ.get("OPENOCD"), str(Path.home() / "openocd" / "bin" / "openocd"), "openocd", *cad):
        if o and shutil.which(o):
            return o
    sys.exit("run: no OpenOCD (set $OPENOCD or put openocd on PATH)")


def find_tty() -> str:
    # the Arty's FT2232: channel A is its JTAG, channel B (interface 1) the UART
    ttys = sorted(glob.glob("/dev/serial/by-id/usb-Digilent_*-if01-port0"))
    if not ttys:
        sys.exit("run: no Arty UART in /dev/serial/by-id (pass --tty)")
    return ttys[0]


def open_tty(path: str) -> int:
    fd = os.open(path, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    attr = termios.tcgetattr(fd)
    attr[0] = attr[1] = attr[3] = 0                                   # raw: no input, output or local processing
    attr[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attr[4] = attr[5] = getattr(termios, f"B{build.BAUD}")
    termios.tcsetattr(fd, termios.TCSANOW, attr)
    termios.tcflush(fd, termios.TCIFLUSH)
    return fd


def run_one(name: str, openocd: str, tty: str, timeout: float, log_dir: Path) -> str:
    elf = build.OUT / name / f"{name}.elf"
    entry = subprocess.run(["readelf", "-h", str(elf)], capture_output=True, text=True, check=True).stdout
    entry = re.search(r"Entry point address:\s+(0x[0-9a-f]+)", entry).group(1)
    fd = open_tty(tty)
    try:
        r = subprocess.run([openocd, "-f", str(CFG), "-c", "init", "-c", "reset halt",
                            "-c", f"load_image {elf} 0 elf {SRAM_BASE:#x} {SRAM_SIZE:#x}",
                            "-c", f"verify_image {elf}",
                            "-c", f"resume {entry}", "-c", "shutdown"],
                           capture_output=True, text=True, timeout=120)
        (log_dir / f"{name}.openocd.log").write_text(r.stdout + r.stderr)
        if r.returncode or "verified" not in r.stdout + r.stderr:
            return "LOAD FAILED"
        result, out = read_result(fd, timeout)
        (log_dir / f"{name}.uart.log").write_bytes(out)
        return result
    finally:
        os.close(fd)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tests", nargs="*", help="programs (default: sim/tests.list without SKIP)")
    ap.add_argument("--bitstream", action="store_true", help="load the bitstream first (after a power cycle)")
    ap.add_argument("--clkout-div", type=float, default=20.0, help="the bitstream's MMCM divide (fpga/build.py)")
    ap.add_argument("--icache-kb", type=int, default=4, help="the bitstream's ICACHE_KB (fpga/build.py; default 4)")
    ap.add_argument("--iterations", type=int, default=1,
                    help="CoreMark iterations (1500: a valid score, about 12 s at 50 MHz)")
    ap.add_argument("--timeout", type=float, default=30.0, help="seconds to wait for a program's result")
    ap.add_argument("--flash-boot", metavar="NAME", help="write the bitstream and NAME into the flash and boot it")
    ap.add_argument("--tty", help="the Arty's UART (default: found in /dev/serial/by-id)")
    ap.add_argument("--xip", action="store_true",
                    help="programs run from the flash (sw/lib/link_xip.ld); skips sim/run.py's XIP_SKIP too")
    args = ap.parse_args()
    if args.bitstream and load_bitstream():
        return 1
    openocd, tty = find_openocd(), args.tty or find_tty()
    log_dir = build.OUT / "run"
    log_dir.mkdir(parents=True, exist_ok=True)
    if args.flash_boot:
        name = args.flash_boot
        if build.program(name, args.clkout_div, args.icache_kb, args.iterations, args.xip):
            return 1
        result = flash_boot(name, tty, args.timeout, log_dir)
        print(f"{name:10s} {result} (flash boot)")
        return 0 if result == "PASS" else 1
    results = {}
    for name in args.tests or board_tests():
        skip = SKIP.get(name) or (simrun.XIP_SKIP.get(name) if args.xip else None)
        if skip:
            print(f"{name:10s} SKIP ({skip})")
            continue
        if build.program(name, args.clkout_div, args.icache_kb, args.iterations, args.xip):
            results[name] = "BUILD FAILED"
        elif (image := build.OUT / name / f"{name}.flash.bin").stat().st_size and write_flash(image):
            results[name] = "FLASH WRITE FAILED"
        elif name in POR_TESTS and load_bitstream():
            results[name] = "BITSTREAM LOAD FAILED"
        else:
            results[name] = run_one(name, openocd, tty, args.timeout, log_dir)
        print(f"{name:10s} {results[name]}", flush=True)
    bad = [n for n, r in results.items() if r != "PASS"]
    print(f"run: {len(results) - len(bad)} / {len(results)} passed" + (f"; failed: {' '.join(bad)}" if bad else "")
          + f" (logs in {log_dir})")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
