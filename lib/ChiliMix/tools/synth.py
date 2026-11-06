# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Synthesize the ChiliMix modules with Yosys + yosys-slang (generic gates).

  python tools/synth.py                          every ChiliMix module
  python tools/synth.py --top chilimix_uart      one top (repeatable)
  python tools/synth.py --extra f.sv --top m     also read a file outside the file lists
  python tools/synth.py --top m -- -GN=4         extra read_slang options

The flow and the checks are BaseChiliSV's (../BaseChiliSV/tools/synth.py):
per top read_slang --keep-hierarchy, proc / opt / memory, check -assert,
no latches outside the library's approved latch modules, flatten, synth,
check -assert, stats. Exit status 1 if any top fails. Logs:
syn/out/<top>/yosys.log, stats: syn/out/<top>/stat.txt. Yosys is $YOSYS,
else ~/oss-cad-suite/bin/yosys, else yosys on PATH (with the slang plugin).
"""

from __future__ import annotations

import argparse
import importlib.util
import subprocess
import sys
from pathlib import Path

from filelist import LIB, ROOT, own_units, units
from filelist import files as rtl_list_files

OUT = ROOT / "syn" / "out"

# Tops synthesized at small parameters: their storage is flops in generic
# synthesis (an SRAM macro on silicon), and the default sizes only multiply
# the same logic (chilimix_l2 at 8 ways x 256 sets needs over 8 GB). Extra
# read_slang options after "--" come after these and override them.
SYNTH_PARAMS = {
    "chilimix_l2": ["-GWAYS=2", "-GSETS=4"],
}

# The library's synth.py (script, latch rules, Yosys lookup, stat summary).
# Its own 'from filelist import ...' resolves to this repository's filelist
# (already imported); the functions used here do not depend on it.
_spec = importlib.util.spec_from_file_location("basechili_synth", LIB / "tools" / "synth.py")
_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lib)
LATCH_OK = _lib.LATCH_OK


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="top module (repeatable)")
    ap.add_argument("--extra", action="append", default=[], type=Path, help="also read this file (repeatable)")
    argv = sys.argv[1:]
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    args = ap.parse_args(argv[:len(argv) - len(extra) - (1 if "--" in argv else 0)])

    files = rtl_list_files() + [f.resolve() for f in args.extra]
    tops = args.top or [u["name"] for u, _ in own_units() if u["kind"] == "module"]
    deps = {u["name"]: u["dependencies"] for u, _ in units()}
    exe = _lib.yosys()
    failed = 0
    for top in tops:
        out = OUT / top
        out.mkdir(parents=True, exist_ok=True)
        log = out / "yosys.log"
        res = subprocess.run([exe, "-m", "slang", "-q", "-l", str(log), "-s", "/dev/stdin"],
                             input=_lib.script(top, files, SYNTH_PARAMS.get(top, []) + extra, out, deps), text=True,
                             capture_output=True, cwd=ROOT)
        text = log.read_text() if log.is_file() else res.stdout + res.stderr
        warns = [ln for ln in text.splitlines() if ln.startswith("Warning")]
        if res.returncode or warns:
            failed += 1
            first = (warns or [ln for ln in text.splitlines() if "ERROR" in ln] or ["?"])[0]
            print(f"FAIL  {top:28s} {first[:100]}")
            print(f"      see {log.relative_to(ROOT)}")
            continue
        cells, flops = _lib.summary(out / "stat.txt")
        print(f"ok    {top:28s} {cells:6d} cells  {flops:5d} flops")
    print(f"synth: {len(tops)} tops, {failed} failed: {'clean' if not failed else 'FAILED'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
