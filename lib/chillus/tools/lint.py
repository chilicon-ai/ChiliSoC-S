# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Lint the SystemVerilog sources with slang (pyslang).

  python tools/lint.py                      every file list unit, every top elaborated
  python tools/lint.py --top chillus_alu    elaborate one top (all files still parsed)
  python tools/lint.py -- -GXLEN=64 ...     extra slang options after --

The files are the units of both file lists (tools/filelist.py: the
BaseChiliSV submodule and ChillU-S). Runs slang's full compilation and analysis with every warning enabled except
WAIVED below. Exit status 1 on any error or warning, so it can gate commits and CI. Uses the same engine as the
VS Code Slang extension but checks every file, not only the ones the editor
has analyzed.
"""

from __future__ import annotations

import argparse
import shlex
import sys
from pathlib import Path

from pyslang.driver import Driver

from filelist import files as rtl_list_files

# Project-wide waivers, each with its reason. Keep in sync with the VS Code
# Slang flags in .slang/server.json.
WAIVED = {
    "empty-output-connection": "unused outputs are left open on purpose: .full ()",
    "useless-cast": "explicit width casts are the house style (WIDTH'(x))",
    "unused-package-parameter": "protocol / decoder packages define complete encoding tables",
    "unused-but-set-variable": "debug-only wires for waveforms (e.g. chillus_rf x10_a0)",
}
# Waivers are project-wide only: no diagnostic pragmas in RTL.


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="top module to elaborate (repeatable)")
    ap.add_argument("files", nargs="*", type=Path, help="files to lint (default: every file list unit)")
    argv = sys.argv[1:]
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    args = ap.parse_args(argv[:len(argv) - len(extra) - (1 if "--" in argv else 0)])

    files = [f.resolve() for f in args.files] or rtl_list_files()
    cmd = ["slang", "-Weverything", *(f"-Wno-{w}" for w in WAIVED)]
    cmd += [f"--top={t}" for t in args.top]
    if args.top:
        cmd.append("-Wno-unused-def")  # other modules are unused by design with --top
    cmd += extra
    cmd += [f.as_posix() for f in files]

    d = Driver()
    d.addStandardArgs()
    if not d.parseCommandLine(shlex.join(cmd)) or not d.processOptions():
        return 2
    parsed = d.parseAllSources()
    d.runFullCompilation(False)

    errors, warnings = d.diagEngine.numErrors, d.diagEngine.numWarnings
    status = "clean" if parsed and not errors and not warnings else "FAILED"
    print(f"lint: {len(files)} files, {errors} errors, {warnings} warnings: {status}")
    return 0 if status == "clean" else 1


if __name__ == "__main__":
    sys.exit(main())
