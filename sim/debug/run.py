# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""riscv-tests debug suite (debug/gdbserver.py) on ChiliSoC-S in simulation.

  python sim/debug/run.py               every test, 3 at a time
  python sim/debug/run.py Hwbp1 StepTest
  python sim/debug/run.py -j 4

Builds the model (as sim/run.py does) and the boot ROM, then runs
gdbserver.py on the target sim/debug/chilisocs.py: every test starts a fresh
model, OpenOCD on its JTAG pins (remote_bitbang) and GDB, loads a program
and debugs it. Tests the target does not support (multiple harts, F / V,
S-mode and the MMU, load / store / icount / interrupt / exception triggers,
memory sampling) report not_applicable; any other result than pass fails
the run. DownloadTest (about 120 KiB over JTAG) is the slow one.

Needs (tools/install_debug_tests.sh): riscv-tests at $RISCV_TESTS (default
~/riscv-tests) with its env submodule, the xPack RISC-V toolchain at
$XPACK_RISCV (default ~/xpack-riscv; riscv-tests' own CI toolchain: its gdb
steps with the hardware, distribution gdb builds step with breakpoints),
Python pexpect and PyYAML; and OpenOCD (tools/install_openocd.sh, or
$OPENOCD). Output: sim/out/debug/ (logs<k>/ per shard, one log per test).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "sim"))
import run as simrun  # noqa: E402

OUT = simrun.OUT / "debug"
TARGET = HERE / "chilisocs.py"
RESULT = re.compile(r"^\[(\w+)\] (\w+) in ", re.M)


def suite_dir() -> Path:
    return Path(os.environ.get("RISCV_TESTS", Path.home() / "riscv-tests")) / "debug"


def toolchain(tool: str) -> Path:
    return Path(os.environ.get("XPACK_RISCV", Path.home() / "xpack-riscv")) / "bin" / f"riscv-none-elf-{tool}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tests", nargs="*", help="test names (default: every test)")
    ap.add_argument("-j", type=int, default=3, help="tests at a time (each runs a model, OpenOCD and GDB)")
    ap.add_argument("--no-build", action="store_true", help="reuse the model sim/run.py built last")
    args = ap.parse_args()

    suite, openocd = suite_dir(), simrun.openocd_exe()
    missing = [str(p) for p in (suite / "gdbserver.py", suite.parent / "env" / "encoding.h",
                                toolchain("gcc"), toolchain("gdb")) if not p.is_file()]
    if missing or not openocd:
        sys.exit("debug: missing " + ", ".join(missing + ["OpenOCD"] * (not openocd))
                 + " (tools/install_debug_tests.sh, tools/install_openocd.sh)")

    model = simrun.OUT / "build" / "obj" / "Vchilisocs_tb"
    if not (args.no_build and model.is_file()):
        model = simrun.build({})
    OUT.mkdir(parents=True, exist_ok=True)
    boot = OUT / "boot.elf"
    simrun.run([simrun.CROSS + "gcc", *simrun.ARCH, "-T", simrun.SW / "boot" / "boot.ld",
                simrun.SW / "boot" / "boot.S", "-o", boot])
    rom = OUT / "rom.hex"
    simrun.write_hex(rom, simrun.elf_segments(boot), simrun.ROM_BASE, 1 << simrun.DEFAULTS["ROM_AW"])

    env = dict(os.environ, CHILISOCS_SIM=f"{model} +rom={rom} +uart_div=1 +max_cycles=100000000000")
    gdbserver = [sys.executable, "gdbserver.py", "--isolate", "--gcc", str(toolchain("gcc")),
                 "--gdb", str(toolchain("gdb")), "--server_cmd", openocd]
    tests = args.tests or subprocess.run([*gdbserver, "--list-tests", str(TARGET)], cwd=suite, env=env,
                                         capture_output=True, text=True, check=True).stdout.split()
    tests = [t for t in tests if re.fullmatch(r"\w+", t)]
    shards = [tests[k::max(1, args.j)] for k in range(max(1, args.j))]

    def shard(k: int) -> str:
        if not shards[k]:
            return ""
        r = subprocess.run(simrun.job("sim", [*gdbserver, "--logs", str(OUT / f"logs{k}"), str(TARGET), *shards[k]]),
                           cwd=suite, env=env, capture_output=True, text=True)
        (OUT / f"shard{k}.log").write_text(r.stdout + r.stderr)
        return r.stdout

    print(f"debug: {len(tests)} tests, {len(shards)} at a time", flush=True)
    with ThreadPoolExecutor(max_workers=len(shards)) as ex:
        text = "".join(ex.map(shard, range(len(shards))))
    results = dict(RESULT.findall(text))
    bad = {t: results.get(t, "no result") for t in tests if results.get(t) not in ("pass", "not_applicable")}
    counts = {r: list(results.values()).count(r) for r in sorted(set(results.values()))}
    for t, r in sorted(bad.items()):
        print(f"FAIL  {t:32s} {r}")
    print(f"debug: {len(tests)} tests, " + ", ".join(f"{n} {r}" for r, n in counts.items())
          + f": {'clean' if not bad else 'FAILED'} (logs in {OUT.relative_to(ROOT)})")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
