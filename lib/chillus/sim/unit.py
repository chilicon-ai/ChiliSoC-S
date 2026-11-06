# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run the ChillU-S unit testbenches with Verilator (assertions and checkers on).

  python sim/unit.py                         every testbench in sim/unit_tests.json
  python sim/unit.py --top chillus_icache    one unit's runs

sim/unit_tests.json lists, per unit, the parameter sets ("params") its testbench
sim/tb/<unit>_tb.sv runs with. Each run builds the testbench with the
file list RTL and every checker, and passes when the simulation ends with
TB PASS and no error. Output: sim/out/unit/<unit>/<run>/ (build, log).
Exit status 1 on any failure.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from filelist import ROOT, checkers, files  # noqa: E402
from jobs import job  # noqa: E402

TESTS = ROOT / "sim" / "unit_tests.json"
OUT = ROOT / "sim" / "out" / "unit"


def verilator() -> str:
    found = shutil.which("verilator") or str(Path.home() / "oss-cad-suite" / "bin" / "verilator")
    return os.environ.get("VERILATOR", found)


def run_one(unit: str, idx: int, params: dict) -> bool:
    out = OUT / unit / f"run{idx}"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    tb = ROOT / "sim" / "tb" / f"{unit}_tb.sv"
    gflags = [f"-G{k}={v}" for k, v in params.items()]
    build = subprocess.run(
        job("build", [verilator(), "--binary", "--timing", "--assert", "-j", "0", "--quiet", "-Wno-NOLATCH",
                      "--top-module", f"{unit}_tb", *gflags, "-Mdir", str(out / "obj"),
                      *map(str, files()), *map(str, checkers()), str(tb)]),
        capture_output=True, text=True)
    log = out / "sim.log"
    if build.returncode != 0:
        log.write_text(build.stdout + build.stderr)
        print(f"FAIL  {unit} run{idx} {params}: build (see {log.relative_to(ROOT)})")
        return False
    sim = subprocess.run(job("sim", [str(out / "obj" / f"V{unit}_tb")]), capture_output=True, text=True, cwd=out)
    text = sim.stdout + sim.stderr
    log.write_text(text)
    ok = sim.returncode == 0 and "TB PASS" in text and "%Error" not in text
    last = [ln for ln in text.splitlines() if "TB " in ln or "Error" in ln][-1:] or ["(no output)"]
    print(f"{'PASS' if ok else 'FAIL'}  {unit} run{idx} {params}: {last[0].strip()}")
    return ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", help="unit to run (repeatable; default: all)")
    args = ap.parse_args()
    tests = json.loads(TESTS.read_text())
    units = args.top or list(tests)
    ok = True
    for unit in units:
        if unit not in tests:
            sys.exit(f"unit.py: {unit} has no entry in sim/unit_tests.json")
        for i, params in enumerate(tests[unit]["params"]):
            ok &= run_one(unit, i, params)
    print("unit: " + ("clean" if ok else "FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
