# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Verilator lint of the BaseChiliSV modules, as the cores' simulation builds see them.

  python tools/vlint.py                          every file list module
  python tools/vlint.py --top basechili_alu_pipe one module (repeatable)
  python tools/vlint.py -j 4                     parallel runs (default: CPUs)

The cores build their simulations with `verilator --binary` and Verilator's
default warnings, which are fatal there. tools/lint.py (slang) is the
library's lint; this step makes sure no module trips a default Verilator
warning the slang lint does not report (e.g. ALWCOMBORDER, WIDTHTRUNC). Each
module is linted (--lint-only) with its default parameters and with every
parameter set of sim/tests.json. Waived: NOLATCH (the approved latch
primitives). Exit status 1 on any warning or error.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from filelist import ROOT, files as rtl_list_files, units

RTL_LIST = ROOT / "rtl.json"
TESTS = ROOT / "sim" / "tests.json"
FLAGS = ["--lint-only", "-Wno-NOLATCH"]


def module_params(path: Path, module: str) -> set[str]:
    """Parameter names in the module's header (sim/tests.json sets also hold testbench-only ones)."""
    text = path.read_text()
    head = text[text.find(f"module {module}"):]
    head = head[:head.find(");")]
    return set(re.findall(r"\bparameter\b[^=;]*?\b(\w+)\s*=", head))


def param_sets(module: str, path: Path, tests: dict) -> list[dict]:
    names = module_params(path, module)
    out = [{}]
    for p in tests.get(module, {}).get("params", []):
        q = {k: v for k, v in p.items() if k in names}
        if q not in out:
            out.append(q)
    return out


def lint(module: str, params: dict, files: list[str]) -> tuple[str, list[str]]:
    gargs = [f"-G{k}={v}" for k, v in params.items()]
    res = subprocess.run(["verilator", *FLAGS, "--top-module", module, *gargs, *files],
                         capture_output=True, text=True)
    msgs = [l for l in res.stderr.splitlines() if l.startswith(("%Warning", "%Error"))]
    if res.returncode and not msgs:
        msgs = res.stderr.splitlines()[-3:] or [f"exit {res.returncode}"]
    tag = module + (" " + " ".join(f"{k}={v}" for k, v in params.items()) if params else "")
    return tag, msgs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="module to lint (repeatable; default: every module)")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1, help="parallel runs")
    args = ap.parse_args()
    paths = {u["name"]: ROOT / u["path"] for u, _ in units([RTL_LIST]) if u["kind"] == "module"}
    mods = list(paths)
    tops = args.top or mods
    unknown = [t for t in tops if t not in mods]
    if unknown:
        print(f"vlint: not file list modules: {', '.join(unknown)}", file=sys.stderr)
        return 1
    tests = json.loads(TESTS.read_text())
    files = [str(f) for f in rtl_list_files()]
    jobs = [(m, p) for m in tops for p in param_sets(m, paths[m], tests)]
    failed = 0
    with ThreadPoolExecutor(max(1, args.j)) as ex:
        for tag, msgs in ex.map(lambda j: lint(j[0], j[1], files), jobs):
            if msgs:
                failed += 1
                print(f"FAIL  {tag}")
                for m in msgs[:6]:
                    print(f"      {m}")
    print(f"vlint: {len(tops)} modules, {len(jobs)} runs, {failed} failed: {'clean' if not failed else 'FAILED'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
