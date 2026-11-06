#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Summarize the PPA of a finished ORFS run (WORK_HOME of syn/orfs/run.sh).

  python3 syn/orfs/ppa.py syn/orfs/out/chillus_p5.0
  python3 syn/orfs/ppa.py syn/orfs/out/chillus_p1.8 --json

Reads the per-stage metrics JSON (logs/<platform>/<design>/base/*.json) and
the final timing report. Fmax is OpenSTA's report_clock_min_period
(1 / (period - WNS) for the worst path), not a separate sweep.
"""

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class PpaError(Exception):
    """The run has no (complete) results."""


def find_base(work: Path, kind: str) -> Path:
    hits = sorted(work.glob(f"{kind}/*/*/base"))
    if not hits:
        raise PpaError(f"no {kind}/<platform>/<design>/base under {work}")
    return hits[0]


def load(path: Path) -> dict:
    return json.loads(path.read_text()) if path.exists() else {}


def critical_path(rpt: Path) -> tuple[str, str, float | None]:
    if not rpt.exists():
        return "?", "?", None
    text = rpt.read_text()
    sec = text[text.find("report_checks -path_delay max"):]
    start = re.search(r"Startpoint: (\S+)", sec)
    end = re.search(r"Endpoint: (\S+)", sec)
    arr = re.search(r"^\s+(-?[\d.]+)\s+data arrival time", sec, re.M)
    return (start.group(1) if start else "?", end.group(1) if end else "?",
            float(arr.group(1)) if arr else None)


def collect(work: Path) -> dict:
    """PPA of the finished run in WORK_HOME work (PpaError if none)."""
    logs = find_base(work, "logs")
    reports = find_base(work, "reports")
    synth = load(logs / "1_synth.json")
    route = load(logs / "5_2_route.json")
    fin = load(logs / "6_report.json")
    if not fin:
        raise PpaError(f"{logs}/6_report.json missing (flow not finished?)")
    sdc = (work / "results").glob("*/*/base/6_final.sdc")
    period = None
    for f in sdc:
        m = re.search(r"create_clock .*-period ([\d.]+)", f.read_text())
        period = float(m.group(1)) if m else None
    start, end, arrival = critical_path(reports / "6_finish.rpt")

    p = {
        "design": logs.parent.name,
        "period_ns": period,
        "synth_cells": synth.get("synth__design__instance__count"),
        "synth_area_um2": synth.get("synth__design__instance__area"),
        "cells": fin.get("finish__design__instance__count__stdcell"),
        "flops": fin.get("finish__design__instance__count__class:sequential_cell"),
        "cell_area_um2": fin.get("finish__design__instance__area__stdcell"),
        "die_area_um2": fin.get("finish__design__die__area"),
        "util": fin.get("finish__design__instance__utilization"),
        "wns_ns": fin.get("finish__timing__setup__ws"),
        "tns_ns": fin.get("finish__timing__setup__tns"),
        "hold_wns_ns": fin.get("finish__timing__hold__ws"),
        "fmax_mhz": (fin.get("finish__timing__fmax") or 0) / 1e6,
        "power_mw": (fin.get("finish__power__total") or 0) * 1e3,
        "drc": route.get("detailedroute__route__drc_errors"),
        "crit_start": start,
        "crit_end": end,
        "crit_arrival_ns": arrival,
    }
    return p


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("work", type=Path, help="ORFS WORK_HOME of one run")
    ap.add_argument("--md", action="store_true", help="print one Markdown table row")
    ap.add_argument("--json", action="store_true", help="print the metrics as JSON")
    a = ap.parse_args()

    try:
        p = collect(a.work)
    except PpaError as e:
        sys.exit(f"ppa.py: {e}")
    if a.json:
        print(json.dumps(p, indent=2))
    elif a.md:
        print(f"| {p['design']} | {p['period_ns']} | {p['cells']} | {p['flops']} | "
              f"{p['cell_area_um2']:.0f} | {p['wns_ns']:.3f} | {p['tns_ns']:.3f} | "
              f"{p['fmax_mhz']:.0f} | {p['power_mw']:.2f} | {p['drc']} |")
    else:
        w = max(map(len, p))
        for k, v in p.items():
            print(f"{k:{w}s}  {v:.4g}" if isinstance(v, float) else f"{k:{w}s}  {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
