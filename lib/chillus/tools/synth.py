# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Synthesize the SystemVerilog sources with Yosys + yosys-slang (generic gates).

  python tools/synth.py                     chillus_core and every ChillU-S module (source/ChillUS file list)
  python tools/synth.py --all               plus every BaseChiliSV module
  python tools/synth.py --top chillus_alu   one top (repeatable)
  python tools/synth.py --top chillus_rf -- -GXLEN=64    extra read_slang options
  python tools/synth.py -j 2                parallel tops (default: the job's cores)

The library's modules are checked by BaseChiliSV's own tools/check.py at
every library release; --all checks them here as well, with this repository's
tools.

Per top, with default parameters:
  read_slang --keep-hierarchy -> hierarchy -check -> proc; opt; memory; opt
  (check -assert right after proc as well as after opt / synth)
  -> check -assert (undriven, multiple drivers, loops) and no latches
  -> per-module word-level stat -> flatten -> synth (generic gates, abc)
  -> check -assert, no latches -> gate-level stat

Latches: only the library's approved latch modules (LATCH_OK) may hold one; for a top built on them the gate-level check is
skipped (as in the library's tools/synth.py).

For chillus_core the rvfi_* ports are removed before synth (verification only;
the SoC leaves them unconnected), so its numbers exclude chillus_rvfi.

Not caught here: an undriven variable (yosys-slang ties it to x); lint reports
it (unassigned-variable). Run lint first.

Job queue: with a job runner (tools/jobs.py runner()), the script runs
itself again as one job (SYNTH_CORES / SYNTH_MEM size it); the tops run in
parallel on its cores, each command through tools/jobs.py job().

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

from filelist import ROOT, files as rtl_list_files, units
from jobs import job, runner

OUT = ROOT / "syn" / "out"
CORE = "chillus_core"
NO_LATCH = "t:$dlatch t:$adlatch t:$dlatchsr t:$_DLATCH_* t:$_DLATCHSR_*"
# Approved latches: the only modules allowed to contain a latch; same
# set and checks as the library's tools/synth.py.
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


def rtl_list_modules(everything: bool = False) -> list[str]:
    """The ChillU-S file list's modules (under source/); everything: the library's too."""
    own = (ROOT / "source").resolve()
    return [u["name"] for u, f in units() if u["kind"] == "module" and (everything or own in Path(f).resolve().parents)]


def script(top: str, files: list[Path], extra: list[str], out: Path, deps: dict[str, list[str]]) -> str:
    srcs = " ".join(f.as_posix() for f in files)
    word_latch, gate_latch = latch_select(top, deps)
    rvfi = (f"delete -port {top}/rvfi_*\nopt_clean -purge\n") if top == CORE else ""
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
{rvfi}synth -top {top}
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


IN_JOB = os.environ.get("CHILI_JOBS_ACTIVE") == "1" or bool(os.environ.get("SLURM_JOB_ID"))


def as_job() -> None:
    """Outside a job, with a job runner: run this script again as one queue job (does not return)."""
    r = None if IN_JOB else runner()
    if r is None:
        return
    cores = os.environ.get("SYNTH_CORES", "4")
    mem = os.environ.get("SYNTH_MEM", "8G")
    cmd = [r, "--kind", "synth", "--cores", cores, "--mem", mem, "--name", "chillus:synth-all",
           "--", sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]]
    print("synth: as a queue job: " + " ".join(cmd), flush=True)
    os.chdir(ROOT)
    os.execvp(cmd[0], cmd)


def synth_top(top: str, exe: str, files: list[Path], extra: list[str], deps: dict) -> tuple[bool, str]:
    """One top: (passed, result lines)."""
    out = OUT / top
    out.mkdir(parents=True, exist_ok=True)
    log = out / "yosys.log"
    res = subprocess.run(job("synth", [exe, "-m", "slang", "-q", "-l", str(log), "-s", "/dev/stdin"], name=top),
                         input=script(top, files, extra, out, deps), text=True,
                         capture_output=True)
    text = log.read_text() if log.is_file() else res.stdout + res.stderr
    warns = [l for l in text.splitlines() if l.startswith("Warning")]
    if res.returncode or warns:
        first = (warns or [l for l in text.splitlines() if "ERROR" in l] or ["?"])[0]
        return False, f"FAIL  {top:24s} {first[:100]}\n      see {log.relative_to(ROOT)}"
    cells, flops = summary(out / "stat.txt")
    return True, f"ok    {top:24s} {cells:6d} cells  {flops:5d} flops"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--top", action="append", default=[], help="top module (repeatable)")
    ap.add_argument("--all", action="store_true", help="every file list module, the library's too")
    ap.add_argument("-j", type=int, default=len(os.sched_getaffinity(0)) if IN_JOB else 1,
                    help="parallel tops (default: the job's cores; 1 without a job runner)")
    argv = sys.argv[1:]
    extra = argv[argv.index("--") + 1:] if "--" in argv else []
    args = ap.parse_args(argv[:len(argv) - len(extra) - (1 if "--" in argv else 0)])

    files = rtl_list_files()
    deps = {u["name"]: u.get("dependencies", []) for u, _ in units()}
    tops = args.top or [CORE] + [m for m in rtl_list_modules(args.all) if m != CORE]
    if len(tops) > 1:
        as_job()
    exe = yosys()
    with ThreadPoolExecutor(max_workers=max(1, args.j)) as ex:
        results = list(ex.map(lambda t: synth_top(t, exe, files, extra, deps), tops))
    failed = 0
    for ok, lines in results:
        failed += not ok
        print(lines)
    print(f"synth: {len(tops)} tops, {failed} failed: {'clean' if not failed else 'FAILED'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
