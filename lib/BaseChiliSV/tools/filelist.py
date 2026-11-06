# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""RTL file list from library file lists (the file list is the single list).

  python tools/filelist.py                  the BaseChiliSV RTL, one path per line
  python tools/filelist.py a.json b.json    the units of other file lists

Packages come first (in dependency order), then every other unit by path, so
order-sensitive tools (Verilator) see a package before its users. Each
unit's path is relative to its file list's directory. Standard library only:
also called from Makefiles (e.g. an ORFS config.mk in a Docker image).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTL_LIST = ROOT / "rtl.json"


def units(rtl_lists: list[Path]) -> list[tuple[dict, Path]]:
    """(unit, absolute source path) of every unit in the file lists."""
    out = []
    for m in rtl_lists:
        m = Path(m).resolve()
        for u in json.loads(m.read_text(encoding="utf-8"))["units"]:
            out.append((u, m.parent / u["path"]))
    return out


def files(rtl_lists: list[Path] | None = None) -> list[Path]:
    """Source files of the file lists' units: packages first (dependencies
    before users), then the rest sorted by path."""
    us = units(rtl_lists or [RTL_LIST])
    pkgs = {u["name"]: (u, p) for u, p in us if u["kind"] == "package"}
    ordered: list[Path] = []
    done: set[str] = set()

    def visit(name: str) -> None:
        if name in done or name not in pkgs:
            return
        done.add(name)
        u, p = pkgs[name]
        for d in u["dependencies"]:
            visit(d)
        ordered.append(p)

    for name in sorted(pkgs):
        visit(name)
    return ordered + sorted(p for u, p in us if u["kind"] != "package")


def main() -> int:
    for f in files([Path(a) for a in sys.argv[1:]] or None):
        print(f.as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
