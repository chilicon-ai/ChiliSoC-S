# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Synthesize the BaseChiliSV modules with Yosys + yosys-slang (generic gates).

  python tools/synth.py                            every file list module
  python tools/synth.py --top basechili_counter    one top (repeatable)
  python tools/synth.py --top basechili_dffe -- -GWIDTH=64    extra read_slang options
  python tools/synth.py -j 4                       parallel tops (default: CPUs)
  python tools/synth.py --liberty asap7 --top m --period 0.8 --uncertainty 0.1
                                                   mapped timing estimate instead

Per top, with default parameters:
  read_slang --keep-hierarchy -> hierarchy -check -> proc; opt; memory; opt
  (check -assert right after proc as well as after opt / synth)
  -> check -assert (undriven, multiple drivers, loops) and no latches
  -> per-module word-level stat -> flatten -> synth (generic gates, abc)
  -> check -assert, no latches -> gate-level stat

Latches: the approved latch modules (LATCH_OK) are the only
modules allowed to hold one. The word-level check skips them, and for a top
built on them the gate-level check (where the hierarchy is gone) is skipped.

Not caught here: an undriven variable (yosys-slang ties it to x); lint reports
it (unassigned-variable). Run lint first.

--liberty <platform> (nangate45, asap7 TT) maps to that cell library and
reports area, the minimum period and the worst paths instead
(tools/timing.py, which says how; outputs in syn/out/<top>/<platform>/).

Tops run in parallel, each Yosys run a "synth" job (tools/jobs.py).

Exit status 1 if any top fails. Logs: syn/out/<top>/yosys.log, stats:
syn/out/<top>/stat.txt. Yosys is $YOSYS, else ~/oss-cad-suite/bin/yosys, else
yosys on PATH (it must have the slang plugin).
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from filelist import RTL_LIST, ROOT, units
from filelist import files as rtl_list_files
from jobs import job

OUT = ROOT / "syn" / "out"
NO_LATCH = "t:$dlatch t:$adlatch t:$dlatchsr t:$_DLATCH_* t:$_DLATCHSR_*"
# Approved latches: the only modules allowed to contain a latch.
LATCH_OK = {"basechili_latch", "basechili_clock_gate"}


def latch_select(top: str, deps: dict[str, list[str]]) -> tuple[str, str]:
    """(word-level, gate-level) no-latch assertions for top."""
    n = len(NO_LATCH.split())
    if not uses_latch(top, deps):
        return (f"select -assert-none {NO_LATCH}",) * 2
    exempt = " ".join(f"{m} {m}$* %u" for m in sorted(LATCH_OK))
    word = f"select -assert-none {NO_LATCH} {'%u ' * (n - 1)}{exempt} {'%u ' * (len(LATCH_OK) - 1)}%d"
    return word, "# gate-level latch check skipped: built on an approved latch"


def uses_latch(top: str, deps: dict[str, list[str]]) -> bool:
    """top is, or depends on, an approved latch module."""
    return top in LATCH_OK or any(uses_latch(d, deps) for d in deps.get(top, []))


def yosys() -> str:
    for cand in (os.environ.get("YOSYS"), Path.home() / "oss-cad-suite" / "bin" / "yosys"):
        if cand and Path(cand).exists():
            return str(cand)
    found = shutil.which("yosys")
    if not found:
        sys.exit("synth.py: yosys not found (set YOSYS or install OSS CAD Suite in ~/oss-cad-suite)")
    return found


def script(top: str, files: list[Path], extra: list[str], out: Path, deps: dict[str, list[str]]) -> str:
    srcs = " ".join(f.as_posix() for f in files)
    word_latch, gate_latch = latch_select(top, deps)
    return f"""
read_slang --keep-hierarchy --top {top} {' '.join(extra)} {srcs}
hierarchy -check -top {top}
proc
check -assert
opt
memory
opt
check -assert
{word_latch}
tee -q -o {out / 'stat_rtl.txt'} stat
flatten
synth -top {top}
check -assert
{gate_latch}
tee -q -o {out / 'stat.txt'} stat
"""


def summary(stat: Path) -> tuple[int, int]:
    """(cells, flop bits) from a flat gate-level stat (no cells line: a top
    that reduces to constants and wires with its default parameters)."""
    text = stat.read_text()
    m = re.search(r"^\s+(\d+) cells$", text, re.M)
    cells = int(m.group(1)) if m else 0
    flops = sum(int(n) for n, _ in re.findall(r"^\s+(\d+)\s+\$_(S?DFF\w*|ALDFF\w*|DLATCH\w*)_?\s*$", text, re.M))
    return cells, flops


def synth_one(exe: str, top: str, files: list[Path], extra: list[str], deps: dict[str, list[str]]) -> tuple[bool, str]:
    """Synthesize one top; (passed, report lines)."""
    out = OUT / top
    out.mkdir(parents=True, exist_ok=True)
    log = out / "yosys.log"
    res = subprocess.run(job("synth", [exe, "-m", "slang", "-q", "-l", str(log), "-s", "/dev/stdin"], name=top),
                         input=script(top, files, extra, out, deps), text=True,
                         capture_output=True)
    lines = log.read_text().splitlines() if log.exists() else []
    warns = [l for l in lines if l.startswith("Warning")]
    if res.returncode or warns:
        first = (warns or [l for l in lines if "ERROR" in l] or [res.stderr.strip() or "?"])[0]
        return False, f"FAIL  {top:28s} {first[:100]}\n      see {log.relative_to(ROOT)}"
    cells, flops = summary(out / "stat.txt")
    return True, f"ok    {top:28s} {cells:6d} cells  {flops:5d} flops"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="top module (repeatable)")
    ap.add_argument("--liberty", metavar="PLATFORM", help="mapped timing estimate (tools/timing.py)")
    ap.add_argument("-j", type=int, default=os.cpu_count() or 1, help="parallel tops")
    argv = sys.argv[1:]
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    head = argv[:len(argv) - len(extra) - (1 if "--" in argv else 0)]
    known, rest = ap.parse_known_args(head)

    files = rtl_list_files()
    tops = known.top or [u["name"] for u, _ in units([RTL_LIST]) if u["kind"] == "module"]
    if known.liberty:
        return mapped(tops, files, extra, known.liberty, rest)
    if rest:
        ap.error(f"unrecognized arguments: {' '.join(rest)} (timing options need --liberty)")
    deps = {u["name"]: u["dependencies"] for u, _ in units([RTL_LIST])}
    exe = yosys()
    failed = 0
    with ThreadPoolExecutor(max_workers=max(1, known.j)) as ex:
        for ok, report in ex.map(lambda t: synth_one(exe, t, files, extra, deps), tops):
            failed += not ok
            print(report, flush=True)
    print(f"synth: {len(tops)} tops, {failed} failed: {'clean' if not failed else 'FAILED'}")
    return 1 if failed else 0


def mapped(tops: list[str], files: list[Path], extra: list[str], platform: str, rest: list[str]) -> int:
    """--liberty: tools/timing.py on every top."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import timing
    tap = argparse.ArgumentParser(prog="synth.py --liberty")
    timing.add_args(tap)
    args = tap.parse_args(rest + ["--platform", platform])
    failed = 0
    for top in tops:
        ok, line = timing.run(top, files, extra, OUT, args)
        failed += not ok
        print(line)
    print(f"synth --liberty {platform}: {len(tops)} tops, {failed} failed: {'clean' if not failed else 'FAILED'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
