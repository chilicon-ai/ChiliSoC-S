# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Zephyr samples and tests on ChiliSoC-S in simulation (board chilisocs_sim).

  python sim/zephyr/run.py              every group in GROUPS
  python sim/zephyr/run.py kernel       one group
  python sim/zephyr/run.py -j 8

Builds the model (as sim/run.py does) and the boot ROM, then runs Zephyr's
twister on the out-of-tree board in sw/zephyr (a Zephyr module) for each
group's test and sample directories: twister builds every scenario and runs
it through the board's "custom" simulator (board.cmake run_custom ->
sim/zephyr/sim.py, the model with the invariant checkers bound), with its
own pass / fail rules (ztest results, sample console patterns, timeouts).
Scenarios whose image does not fit (64 KiB of code in SRAM0, the only SRAM
on the instruction bus, 64 KiB of data in SRAM1), or that need what
the board does not have, are skipped. Any failed or errored scenario fails
the run.

Needs (tools/install_zephyr.sh): Zephyr at $ZEPHYR_BASE (default
~/zephyrproject/zephyr) with sw/zephyr/patches applied, its Python
requirements and west, and the
Zephyr SDK at $ZEPHYR_SDK_INSTALL_DIR (default ~/zephyr-sdk-<SDK_VERSION>,
RISC-V toolchain). Output: sim/out/zephyr/<group>/ (twister's output
directory: twister.json, one build and handler.log per scenario).
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "sim"))
import run as simrun  # noqa: E402

OUT = simrun.OUT / "zephyr"
MODULE = ROOT / "sw" / "zephyr"
PLATFORM = "chilisocs_sim/chilisocs"

# group -> (extra twister arguments, directories under $ZEPHYR_BASE).
# kernel: ztest suites run in supervisor mode (CONFIG_TEST_USERSPACE=n):
# with user mode most of them do not fit the SRAMs (PMP alignment of the
# user partitions). userspace: the user mode / PMP tests as they are.
# (tests/drivers/uart/uart_basic_api needs typed input: not run here.)
GROUPS = {
    "kernel": (["-x=CONFIG_TEST_USERSPACE=n"], [
        "samples/hello_world",
        "samples/synchronization",
        "samples/philosophers",
        "tests/kernel/common",
        "tests/kernel/context",
        "tests/kernel/threads/thread_apis",
        "tests/kernel/sched/schedule_api",
        "tests/kernel/semaphore/semaphore",
        "tests/kernel/mutex/mutex_api",
        "tests/kernel/msgq/msgq_api",
        "tests/kernel/events/event_api",
        "tests/kernel/timer/timer_api",
        "tests/kernel/sleep",
        "tests/kernel/workq/work",
        "tests/kernel/fatal/exception",
        "tests/arch/common/interrupt",
        "tests/arch/riscv/fatal",
        "tests/drivers/gpio/gpio_api_1pin",
    ]),
    "userspace": ([], [
        "samples/userspace/hello_world_user",
        "tests/kernel/mem_protect/userspace",
        "tests/kernel/mem_protect/protection",
        "tests/kernel/mem_protect/syscalls",
    ]),
    # the EEPROM test writes the EEPROM, so Zephyr allows it only on a few
    # boards: force it onto the testbench's EEPROM.
    "eeprom": (["--force-platform", "-s", "drivers.eeprom.api"], [
        "tests/drivers/eeprom/api",
    ]),
}


def zephyr_base() -> Path:
    return Path(os.environ.get("ZEPHYR_BASE", Path.home() / "zephyrproject" / "zephyr"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("groups", nargs="*", help=f"groups (default: all of {', '.join(GROUPS)})")
    ap.add_argument("-j", type=int, default=os.cpu_count(), help="twister jobs (builds and simulations)")
    ap.add_argument("--no-build", action="store_true", help="reuse the model sim/run.py built last")
    args = ap.parse_args()
    groups = args.groups or list(GROUPS)
    unknown = [g for g in groups if g not in GROUPS]
    if unknown:
        sys.exit(f"zephyr: unknown group {', '.join(unknown)}")

    base = zephyr_base()
    ver = (base / "SDK_VERSION").read_text().strip() if (base / "SDK_VERSION").is_file() else "?"
    sdk = Path(os.environ.get("ZEPHYR_SDK_INSTALL_DIR", Path.home() / f"zephyr-sdk-{ver}"))
    if not (base / "scripts" / "twister").is_file() or not (sdk / "gnu" / "riscv64-zephyr-elf").is_dir():
        sys.exit("zephyr: needs Zephyr and the Zephyr SDK with its RISC-V toolchain (tools/install_zephyr.sh)")

    unpatched = [p.name for p in sorted((MODULE / "patches").glob("*.patch"))
                 if subprocess.run(["git", "apply", "--reverse", "--check", p], cwd=base,
                                   capture_output=True).returncode]
    if unpatched:
        sys.exit(f"zephyr: {base} lacks {', '.join(unpatched)} (tools/install_zephyr.sh applies them)")

    model = simrun.OUT / "build" / "obj" / "Vchilisocs_tb"
    if not (args.no_build and model.is_file()):
        model = simrun.build({})
    OUT.mkdir(parents=True, exist_ok=True)
    boot = OUT / "boot.elf"
    simrun.run([simrun.CROSS + "gcc", *simrun.ARCH, "-T", simrun.SW / "boot" / "boot.ld",
                simrun.SW / "boot" / "boot.S", "-o", boot])
    rom = OUT / "rom.hex"
    simrun.write_hex(rom, simrun.elf_segments(boot), simrun.ROM_BASE, 1 << simrun.DEFAULTS["ROM_AW"])
    env = dict(os.environ, ZEPHYR_BASE=str(base), ZEPHYR_SDK_INSTALL_DIR=str(sdk),
               ZEPHYR_TOOLCHAIN_VARIANT="zephyr", ZEPHYR_EXTRA_MODULES=str(MODULE),
               CHILISOCS_MODEL=str(model), CHILISOCS_ROM=str(rom))

    bad, totals = [], {}
    for g in groups:
        extra, dirs = GROUPS[g]
        out = OUT / g
        shutil.rmtree(out, ignore_errors=True)
        cmd = [sys.executable, base / "scripts" / "twister", "-p", PLATFORM, "-O", out, "-j", str(args.j),
               "--inline-logs", "--quarantine-list", HERE / "quarantine.yaml", *extra, *(a for d in dirs for a in ("-T", base / d))]
        print(f"zephyr: {g}: twister on {len(dirs)} directories", flush=True)
        with (OUT / f"{g}.log").open("w") as fh:
            subprocess.run([str(c) for c in cmd], cwd=base, env=env, stdout=fh, stderr=subprocess.STDOUT)
        report = out / "twister.json"
        if not report.is_file():
            bad.append((g, "twister", f"no report, see {(OUT / f'{g}.log').relative_to(ROOT)}"))
            continue
        for s in json.loads(report.read_text())["testsuites"]:
            st = s.get("status", "?")
            if st == "filtered":
                continue
            totals[st] = totals.get(st, 0) + 1
            if st in ("failed", "error"):
                bad.append((g, s["name"], s.get("reason", st)))
            elif st in ("passed", "skipped", "not run"):
                tag = {"passed": "ok  ", "skipped": "skip", "not run": "built"}[st]
                print(f"{tag:5s} {s['name']:52s} "
                      + (f"{s.get('execution_time', '')} s" if st == "passed" else s.get("reason") or "build only"))
    for g, name, why in bad:
        print(f"FAIL  {name:52s} {why} ({g})")
    print("zephyr: " + ", ".join(f"{n} {s}" for s, n in sorted(totals.items()))
          + f": {'clean' if not bad else 'FAILED'} (logs in {OUT.relative_to(ROOT)})")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
