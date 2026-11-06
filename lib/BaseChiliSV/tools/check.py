# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run every check of BaseChiliSV, fast ones first.

  python tools/check.py               every check
  python tools/check.py --keep-going  run every step, report all failures

Steps:
  lint        tools/lint.py
  vlint       tools/vlint.py: Verilator's default warnings (fatal in the cores'
              simulation builds) on every module, every parameter set
  files       rtl.json: every unit's file exists, dependencies name library
              units
  rules       always_ff only in storage primitives, always_latch only in
              approved latch modules; no expression in an instance port
              connection (constant part-selects allowed)
  synth       tools/synth.py
  sim         tools/sim.py: the testbenches (sim/tests.json) pass and meet
              their coverage minimums

The cores that use the library also simulate it (their regressions bind
sim/checkers/ into every instance). Exit status 1 if any step fails.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time

from filelist import RTL_LIST, ROOT, files, units
from synth import LATCH_OK  # approved latches: the only always_latch

PY = sys.executable

# Storage primitives: the only modules allowed to contain always_ff.
ALWAYS_FF_OK = {"basechili_dff", "basechili_dffe", "basechili_dff_sclr", "basechili_sram_sp", "basechili_sram_2p"}
PORT_CONN = re.compile(r"^\s*\.\w+\s*\((.*)\)")
OPERATOR = re.compile(r"[|&!~^?+*<>=-]")
PART_SELECT = re.compile(r"^\s*\w+\s*\[[^\]]+[+-]:[^\]]+\]\s*$")
PREFIX = "basechili_"


def check_rtl_list() -> list[str]:
    m = json.loads(RTL_LIST.read_text())
    errs = []
    names = {u["name"] for u in m["units"]}
    for u, path in units([RTL_LIST]):
        if not path.is_file():
            errs.append(f"rtl.json: {u['name']}: no file {u['path']}")
        if not u["name"].startswith(PREFIX) or path.stem != u["name"]:
            errs.append(f"rtl.json: {u['name']}: name must start with {PREFIX} and match the file name")
        errs += [f"rtl.json: {u['name']}: unknown dependency {d}" for d in u["dependencies"] if d not in names]
    return errs


def check_rules() -> list[str]:
    errs = []
    for f in files():
        rel = f.relative_to(ROOT)
        for n, line in enumerate(f.read_text().splitlines(), 1):
            code = line.split("//", 1)[0]
            if "always_ff" in code and f.stem not in ALWAYS_FF_OK:
                errs.append(f"{rel}:{n}: always_ff outside a storage primitive")
            if "always_latch" in code and f.stem not in LATCH_OK:
                errs.append(f"{rel}:{n}: always_latch outside an approved latch module")
            m = PORT_CONN.match(code)
            if m and OPERATOR.search(m.group(1)) and not PART_SELECT.match(m.group(1)):
                errs.append(f"{rel}:{n}: expression in port connection: {m.group(1).strip()}")
    return errs


def run_py(fn) -> bool:
    errs = fn()
    for e in errs:
        print(f"  {e}")
    return not errs


def run_cmd(cmd: list[str]) -> bool:
    print("$ " + " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT).returncode == 0


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--keep-going", action="store_true", help="do not stop at the first failure")
    args = ap.parse_args()

    mods = [u["name"] for u, _ in units([RTL_LIST]) if u["kind"] == "module"]

    steps = [
        ("lint", lambda: run_cmd([PY, "tools/lint.py"])),
        ("vlint", lambda: run_cmd([PY, "tools/vlint.py"])),
        ("files", lambda: run_py(check_rtl_list)),
        ("rules", lambda: run_py(check_rules)),
        ("synth", lambda: run_cmd([PY, "tools/synth.py"])),
        ("sim", lambda: run_cmd([PY, "tools/sim.py"])),
    ]
    results = []
    for name, step in steps:
        print(f"\n== {name} ==", flush=True)
        t0 = time.monotonic()
        ok = step()
        results.append((name, ok, time.monotonic() - t0))
        if not ok and not args.keep_going:
            break

    print("\n== summary ==")
    for name, ok, dt in results:
        print(f"{'PASS' if ok else 'FAIL'}  {name:12s} {dt:7.1f} s")
    for name, _ in steps[len(results):]:
        print(f"SKIP  {name}")
    passed = len(results) == len(steps) and all(ok for _, ok, _ in results)
    head = git("rev-parse", "--short", "HEAD") or "this tree"
    print(f"check: {'clean' if passed else 'FAILED'} at {head} ({len(mods)} modules)")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
