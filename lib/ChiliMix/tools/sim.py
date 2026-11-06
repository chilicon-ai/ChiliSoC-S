# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run the ChiliMix testbenches with Verilator, with coverage.

  python tools/sim.py                          every testbench in sim/tests.json
  python tools/sim.py --top chilimix_uart      one module's runs (repeatable)
  python tools/sim.py --top m --extra m.sv --tb m_tb.sv   a module outside the
                                               file lists
  python tools/sim.py -j 4                     parallel builds (default: CPUs)

Same flow and rules as BaseChiliSV's tools/sim.py (its run and coverage code
is reused): per module, sim/tests.json lists the parameter sets ("params")
its testbench sim/tb/<module>_tb.sv runs with, and optional coverage minimums
("min_line", "min_toggle", percent; "note" says why one is lowered). Each run
builds the testbench with every file list RTL file and every invariant
checker (the library's and ChiliMix's), and passes on TB PASS. Line and
toggle coverage of the module's own file, merged over its runs, must reach
the minimums. The testbenches include BaseChiliSV's sim/tb/tb_common.svh.
Exit status 1 on any failure. Output: sim/out/<module>/<run>/.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from filelist import LIB, ROOT, checkers, files, own_units

TESTS = ROOT / "sim" / "tests.json"
TB_DIR = ROOT / "sim" / "tb"
OUT = ROOT / "sim" / "out"

_spec = importlib.util.spec_from_file_location("basechili_sim", LIB / "tools" / "sim.py")
_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lib)
MIN_LINE, MIN_TOGGLE, SIMULATED = _lib.MIN_LINE, _lib.MIN_TOGGLE, _lib.SIMULATED


def _run(module: str, idx: int, params: dict, rtl: list[Path], tb: Path):
    import shutil
    import subprocess
    out = OUT / module / str(idx)
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    top = f"{module}_tb"
    main_cpp = out / "main.cpp"
    main_cpp.write_text(_lib.MAIN_CPP.format(tb=top))
    cmd = ["verilator", *_lib.VERILATOR_FLAGS, "--top-module", top, "-Mdir", str(out / "obj"), str(main_cpp),
           f"+incdir+{LIB / 'sim' / 'tb'}", *(f"-G{k}={v}" for k, v in params.items()),
           *(str(f) for f in rtl), *(str(c) for c in checkers()), str(tb)]
    log = out / "log.txt"
    with log.open("w") as fh:
        fh.write("$ " + " ".join(cmd) + "\n")
        fh.flush()
        b = subprocess.run(_lib.job("build", cmd, cores=1), stdout=fh, stderr=subprocess.STDOUT, timeout=_lib.TIMEOUT)
        if b.returncode:
            return False, "build failed", out
        r = subprocess.run(_lib.job("sim", [str(out / "obj" / f"V{top}")]), cwd=out, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, timeout=_lib.TIMEOUT)
        fh.write(r.stdout)
    if r.returncode or "TB PASS" not in r.stdout:
        err = next((ln for ln in r.stdout.splitlines() if "%Error" in ln or "CHECK" in ln), "no TB PASS")
        return False, err.strip()[:110], out
    return True, "", out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="module to simulate (repeatable)")
    ap.add_argument("--extra", action="append", default=[], type=Path, help="RTL file outside the file lists")
    ap.add_argument("--tb", type=Path, help="testbench file for a single --top outside sim/tb/")
    ap.add_argument("--min-toggle", type=float, help="toggle minimum for every --top (overrides sim/tests.json)")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1, help="parallel builds")
    args = ap.parse_args()
    if args.tb and len(args.top) != 1:
        ap.error("--tb needs exactly one --top")

    rtl = files() + [f.resolve() for f in args.extra]
    tests = json.loads(TESTS.read_text()) if TESTS.is_file() else {}
    mods = {u["name"]: (u, p) for u, p in own_units() if u["kind"] == "module"}
    extra_mods = {f.stem: f.resolve() for f in args.extra}
    errs = []
    for m in tests:
        if m not in mods:
            errs.append(f"sim/tests.json: {m} is not a ChiliMix file list module")
        elif not (TB_DIR / f"{m}_tb.sv").is_file():
            errs.append(f"sim/tests.json: {m}: no sim/tb/{m}_tb.sv")
    for e in errs:
        print(f"  {e}")
    if errs:
        return 1

    sel = args.top or list(tests)
    tb_of = {m: (args.tb.resolve() if args.tb else TB_DIR / f"{m}_tb.sv") for m in sel}
    jobs = [(m, i, p) for m in sel for i, p in enumerate(tests.get(m, {}).get("params", [{}]))]
    with ThreadPoolExecutor(max_workers=max(1, args.j)) as ex:
        results = list(ex.map(lambda j: (j, _run(*j, rtl, tb_of[j[0]])), jobs))

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
        src = mods[m][1] if m in mods else extra_mods.get(m)
        line, tog = _lib.coverage(src, [r[2] / "coverage.dat" for _, r in runs]) if src else (100.0, 100.0)
        lo_line = tests.get(m, {}).get("min_line", MIN_LINE)
        lo_tog = args.min_toggle if args.min_toggle is not None else tests.get(m, {}).get("min_toggle", MIN_TOGGLE)
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
