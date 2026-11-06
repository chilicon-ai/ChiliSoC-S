# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""ChillU-S RTL file list from the file lists (BaseChiliSV submodule + ChillU-S).

  python tools/filelist.py      every RTL file, packages first, one path per line

The file lists are the single list of RTL: tools never glob source/. Reading
them is the library's tools/filelist.py (packages first in dependency order,
then the rest by path). Standard library only: also called from the ORFS
config.mk inside the ORFS Docker image.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT.parent / "BaseChiliSV"  # the sibling lib/BaseChiliSV
RTL_LISTS = [LIB / "rtl.json", ROOT / "source" / "ChillUS" / "rtl.json"]

# The library's tools/filelist.py, loaded under another name (same file name).
_LIB_FILELIST = LIB / "tools" / "filelist.py"
if not _LIB_FILELIST.is_file():
    sys.exit(f"filelist: no BaseChiliSV at {LIB}")
_spec = importlib.util.spec_from_file_location("basechili_filelist", _LIB_FILELIST)
_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lib)


def units() -> list[tuple[dict, Path]]:
    """(file list entry, absolute source path) of every RTL unit."""
    return _lib.units(RTL_LISTS)


def files() -> list[Path]:
    """Every RTL file: packages first, then the rest by path."""
    return _lib.files(RTL_LISTS)


def checkers() -> list[Path]:
    """Simulation-only invariant checkers: the library's and ChillU-S's."""
    return sorted((LIB / "sim" / "checkers").glob("*.sv")) + sorted((ROOT / "sim" / "checkers").glob("*.sv"))


if __name__ == "__main__":
    for f in files():
        print(f.as_posix())
