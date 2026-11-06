# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run the BaseChiliSV module testbenches with Verilator, with coverage.

  python tools/sim.py                        every testbench in sim/tests.json
  python tools/sim.py --top basechili_fifo   one module's runs (repeatable)
  python tools/sim.py -j 4                   parallel runs (default: CPUs)

Per module, sim/tests.json lists the parameter sets ("params") its
testbench sim/tb/<module>_tb.sv runs with, and optional coverage minimums
("min_line", "min_toggle", percent; defaults below; "note" says why a
minimum is lowered). Each run builds the
testbench with the file list RTL and every unit's sim/checkers/ file (bound
assertions on; with the Berkeley SoftFloat reference when the testbench
includes softfloat_ref.svh, tools/softfloat.py), and passes when the simulation exits cleanly after printing
TB PASS. Line and toggle coverage of the module's own source file is merged
over its runs and must reach the minimums. Line points inside a function that
no run ever executes are left out: a constant function (a localparam or
generate bound) runs only at elaboration.

Also checked: every tests.json module is a file list module with a
testbench file, and is marked verification "simulation" or higher.
Runs go in parallel, each build a "build" job (one core: --build-jobs 1) and
each simulation a "sim" job (tools/jobs.py).
Exit status 1 on any failure. Output: sim/out/<module>/<run>/ (log,
coverage.dat).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from filelist import RTL_LIST, ROOT, files, units
from jobs import job
import softfloat

TESTS = ROOT / "sim" / "tests.json"
TB_DIR = ROOT / "sim" / "tb"
CHK_DIR = ROOT / "sim" / "checkers"
OUT = ROOT / "sim" / "out"
MIN_LINE = 100.0     # default minimum line coverage of the module's file, %
MIN_TOGGLE = 90.0    # default minimum toggle coverage of the module's file, %
TIMEOUT = 1800       # seconds per build or run (the deep FP32 pipelines of the cores build in ~15 min)
SIMULATED = {"simulation", "formal", "silicon"}
# Verilator lint is not the library's lint (tools/lint.py is); keep its
# output to errors.
VERILATOR_FLAGS = ["--cc", "--exe", "--build", "--timing", "--assert", "--coverage-line", "--coverage-toggle",
                   "-Wno-fatal", "-Wno-lint", "-Wno-style", "-Wno-TIMESCALEMOD", "-Wno-NOLATCH",
                   "--build-jobs", "1"]


def checkers() -> list[Path]:
    return [p for u, _ in units([RTL_LIST]) if (p := CHK_DIR / f"{u['name']}_chk.sv").is_file()]


# C++ main: run until $finish, then write the coverage (the generated --binary
# main of Verilator 5.020 does not).
MAIN_CPP = """#include <memory>
#include <verilated.h>
#include <verilated_cov.h>
#include "V{tb}.h"
int main(int argc, char** argv) {{
  const std::unique_ptr<VerilatedContext> ctx{{new VerilatedContext}};
  ctx->commandArgs(argc, argv);
  const std::unique_ptr<V{tb}> top{{new V{tb}{{ctx.get()}}}};
  while (!ctx->gotFinish()) {{
    top->eval();
    if (!top->eventsPending()) break;
    ctx->time(top->nextTimeSlot());
  }}
  top->final();
  ctx->coveragep()->write("coverage.dat");
  return 0;
}}
"""


def run_one(module: str, idx: int, params: dict) -> tuple[bool, str, Path]:
    """Build and run one parameter set; (passed, message, run dir)."""
    out = OUT / module / str(idx)
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    tb = f"{module}_tb"
    main_cpp = out / "main.cpp"
    main_cpp.write_text(MAIN_CPP.format(tb=tb))
    cmd = ["verilator", *VERILATOR_FLAGS, "--top-module", tb, "-Mdir", str(out / "obj"), str(main_cpp),
           f"+incdir+{TB_DIR}", *(f"-G{k}={v}" for k, v in params.items()),
           *(str(f) for f in files()), *(str(c) for c in checkers()), str(TB_DIR / f"{tb}.sv")]
    if softfloat.uses_softfloat(TB_DIR / f"{tb}.sv"):
        cmd += softfloat.verilator_args()
    log = out / "log.txt"
    with log.open("w") as fh:
        fh.write("$ " + " ".join(cmd) + "\n")
        fh.flush()
        b = subprocess.run(job("build", cmd, cores=1, name=f"{module}#{idx}"), stdout=fh, stderr=subprocess.STDOUT, timeout=TIMEOUT)
        if b.returncode:
            return False, "build failed", out
        r = subprocess.run(job("sim", [str(out / "obj" / f"V{tb}")], name=f"{module}#{idx}"), cwd=out, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, timeout=TIMEOUT)
        fh.write(r.stdout)
    if r.returncode or "TB PASS" not in r.stdout:
        err = next((l for l in r.stdout.splitlines() if "%Error" in l or "CHECK" in l), "no TB PASS")
        return False, err.strip()[:110], out
    return True, "", out


def coverage(source: Path, dats: list[Path]) -> tuple[float, float]:
    """(line %, toggle %) of source over the runs' coverage.dat files; a point
    is covered if any run and any instance hit it."""
    hits: dict[tuple[str, str], int] = defaultdict(int)
    name = source.name
    func_lines: set[int] = set()   # lines inside function ... endfunction
    inside = False
    for no, text in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        code = text.split("//", 1)[0]
        if re.search(r"\bfunction\b", code) and not re.search(r"\bendfunction\b", code):
            inside = True
        if inside:
            func_lines.add(no)
        if re.search(r"\bendfunction\b", code):
            inside = False
    for dat in dats:
        for line in dat.read_text(errors="replace").splitlines():
            m = re.match(r"^C '(.*)' (\d+)$", line)
            if not m:
                continue
            kv = dict(p.split("\x02", 1) for p in m.group(1).split("\x01")[1:] if "\x02" in p)
            if Path(kv.get("f", "")).name != name:
                continue
            kind = kv.get("page", "").split("/")[0]
            point = "\x01".join(kv.get(k, "") for k in ("l", "n", "o"))
            hits[(kind, point)] = max(hits[(kind, point)], int(m.group(2)))

    for (kind, point), c in list(hits.items()):
        if kind == "v_line" and c == 0 and int(point.split("\x01")[0] or 0) in func_lines:
            del hits[(kind, point)]   # elaboration-only constant function

    def pct(kind: str) -> float:
        pts = [c for (k, _), c in hits.items() if k == kind]
        return 100.0 * sum(c > 0 for c in pts) / len(pts) if pts else 100.0
    return pct("v_line"), pct("v_toggle")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="module to simulate (repeatable)")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1, help="parallel runs")
    args = ap.parse_args()

    tests = json.loads(TESTS.read_text())
    mods = {u["name"]: (u, p) for u, p in units([RTL_LIST]) if u["kind"] == "module"}
    errs = []
    for m in tests:
        if m not in mods:
            errs.append(f"sim/tests.json: {m} is not a file list module")
        elif not (TB_DIR / f"{m}_tb.sv").is_file():
            errs.append(f"sim/tests.json: {m}: no sim/tb/{m}_tb.sv")
    for e in errs:
        print(f"  {e}")
    if errs:
        return 1

    sel = args.top or list(tests)
    jobs = [(m, i, p) for m in sel for i, p in enumerate(tests[m].get("params", [{}]))]
    with ThreadPoolExecutor(max_workers=max(1, args.j)) as ex:
        results = list(ex.map(lambda j: (j, run_one(*j)), jobs))

    failed = 0
    for m in sel:
        runs = [(j, r) for j, r in results if j[0] == m]
        bad = [(j, r) for j, r in runs if not r[0]]
        if bad:
            failed += 1
            (_, i, p), (_, msg, out) = bad[0]
            print(f"FAIL  {m:30s} run {i} {p}: {msg}")
            print(f"      see {(out / 'log.txt').relative_to(ROOT)}")
            continue
        line, tog = coverage(mods[m][1], [r[2] / "coverage.dat" for _, r in runs])
        lo_line = tests[m].get("min_line", MIN_LINE)
        lo_tog = tests[m].get("min_toggle", MIN_TOGGLE)
        cov_ok = line >= lo_line and tog >= lo_tog
        failed += not cov_ok
        print(f"{'ok  ' if cov_ok else 'FAIL'}  {m:30s} {len(runs)} runs  line {line:5.1f}%  toggle {tog:5.1f}%"
              + ("" if cov_ok else f"  (minimum {lo_line:.0f}% / {lo_tog:.0f}%)"))
    untested = sorted(set(mods) - set(tests))
    print(f"sim: {len(sel)} modules, {len(jobs)} runs, {failed} failed: {'clean' if not failed else 'FAILED'}"
          + (f"; no testbench yet: {len(untested)}" if untested and not args.top else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
