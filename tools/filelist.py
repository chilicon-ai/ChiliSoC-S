# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""ChiliSoC-S RTL file list from the file lists (BaseChiliSV, ChiliMix, ChillU-S, ChiliSoC-S).

  python tools/filelist.py      every RTL file, packages first, one path per line

The file lists are the single list of RTL: tools never glob source/. Reading
them is the library's tools/filelist.py (packages first in dependency order,
then the rest by path). Only this repository's submodules are used: every part
sees the one lib/BaseChiliSV. Standard library only.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib" / "BaseChiliSV"
MIX = ROOT / "lib" / "ChiliMix"
CPU = ROOT / "lib" / "chillus"
RTL_LIST = ROOT / "rtl.json"
DEPS = {"BaseChiliSV": LIB / "rtl.json", "ChiliMix": MIX / "rtl.json",
        "ChillU-S": CPU / "source" / "ChillUS" / "rtl.json"}
RTL_LISTS = [*DEPS.values(), RTL_LIST]
PREFIX = "chilisocs_"

# The library's tools/filelist.py, loaded under another name (same file name).
_LIB_FILELIST = LIB / "tools" / "filelist.py"
for _name, _m in DEPS.items():
    if not _m.is_file():
        sys.exit(f"filelist: no {_name} in {_m.relative_to(ROOT).parts[:2]}: git submodule update --init")
_spec = importlib.util.spec_from_file_location("basechili_filelist", _LIB_FILELIST)
_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lib)


def units(rtl_lists: list[Path] | None = None) -> list[tuple[dict, Path]]:
    """(file list entry, absolute source path) of every RTL unit."""
    return _lib.units(rtl_lists or RTL_LISTS)


def own_units() -> list[tuple[dict, Path]]:
    """ChiliSoC-S's own units."""
    return _lib.units([RTL_LIST])


def files() -> list[Path]:
    """Every RTL file: packages first, then the rest by path."""
    return _lib.files(RTL_LISTS)


def checkers() -> list[Path]:
    """Simulation-only invariant checkers of every part, then ChiliSoC-S's."""
    dirs = [LIB / "sim" / "checkers", MIX / "sim" / "checkers", CPU / "sim" / "checkers",
            ROOT / "sim" / "checkers"]
    return [f for d in dirs for f in sorted(d.glob("*.sv"))]


if __name__ == "__main__":
    for f in files():
        print(f.as_posix())
