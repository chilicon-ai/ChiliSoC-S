# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Lint the ChiliSoC-S RTL (with BaseChiliSV, ChiliMix and ChillU-S) with slang (pyslang).

  python tools/lint.py                        every file list unit; ChiliSoC-S modules as tops
  python tools/lint.py --top chilisocs_top     elaborate one top (all files still parsed)
  python tools/lint.py --extra f.sv --top m   also parse a file outside the file lists
  python tools/lint.py -- -GWIDTH=64 ...      extra slang options after --

Runs slang's full compilation and analysis with every warning enabled except
WAIVED (the library's waivers and ChillU-S's). Exit status 1 on any error or warning.
"""

from __future__ import annotations

import argparse
import shlex
import sys
from pathlib import Path

from pyslang.driver import Driver

from filelist import files as rtl_list_files
from filelist import own_units

# Project-wide waivers, each with its reason: BaseChiliSV's, plus the one
# ChillU-S needs. Keep in sync with .slang/server.json.
WAIVED = {
    "empty-output-connection": "unused outputs are left open on purpose: .full ()",
    "useless-cast": "explicit width casts are the house style (WIDTH'(x))",
    "unused-package-parameter": "protocol / decoder packages define complete encoding tables",
    "unused-but-set-variable": "ChillU-S keeps debug-only wires for waveforms (its own waiver)",
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="top module to elaborate (repeatable)")
    ap.add_argument("--extra", action="append", default=[], type=Path, help="also parse this file (repeatable)")
    argv = sys.argv[1:]
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    args = ap.parse_args(argv[:len(argv) - len(extra) - (1 if "--" in argv else 0)])

    files = rtl_list_files() + [f.resolve() for f in args.extra]
    tops = args.top or [u["name"] for u, _ in own_units() if u["kind"] == "module"]
    cmd = ["slang", "-Weverything", *(f"-Wno-{w}" for w in WAIVED), "-Wno-unused-def"]
    cmd += [f"--top={t}" for t in tops]
    cmd += extra
    cmd += [f.as_posix() for f in files]
    if not tops:
        print("lint: no ChiliSoC-S modules yet; linting the library files only")
        cmd.remove("-Wno-unused-def")

    d = Driver()
    d.addStandardArgs()
    if not d.parseCommandLine(shlex.join(cmd)) or not d.processOptions():
        return 2
    parsed = d.parseAllSources()
    d.runFullCompilation(False)

    errors, warnings = d.diagEngine.numErrors, d.diagEngine.numWarnings
    status = "clean" if parsed and not errors and not warnings else "FAILED"
    print(f"lint: {len(files)} files, {len(tops)} tops, {errors} errors, {warnings} warnings: {status}")
    return 0 if status == "clean" else 1


if __name__ == "__main__":
    sys.exit(main())
