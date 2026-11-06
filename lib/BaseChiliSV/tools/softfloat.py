# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Berkeley SoftFloat 3 as the reference model of the IEEE FP testbenches.

  python tools/softfloat.py     print the SoftFloat library and headers used

The reference is the SoftFloat copy inside Spike (riscv-isa-sim, the cores'
ISA reference, built by their tools/install_sim_tools.sh): RISCV
specialization (default NaN positive, quiet, zero payload; no NaN
propagation), which is what the basechili_fp_* units implement. Its source
tree is $SPIKE_SRC (default ~/riscv-isa-sim), with the library at
build/libsoftfloat.a; without that tree, the Spike installed next to `spike` on
PATH (lib/libsoftfloat.so, include/softfloat),
linked with its rpath. tools/sim.py builds a testbench that includes
sim/tb/softfloat_ref.svh with sim/tb/softfloat_ref.c (DPI-C wrappers) and
this library.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from filelist import ROOT

SPIKE = Path(os.environ.get("SPIKE_SRC", Path.home() / "riscv-isa-sim"))
LIB = SPIKE / "build" / "libsoftfloat.a"
INCLUDE = SPIKE / "softfloat"


def installed() -> tuple[Path, Path] | None:
    """(libsoftfloat.so, include dir) of the Spike installed next to `spike` on PATH (an install
    tree: bin/spike, lib/libsoftfloat.so, include/softfloat/softfloat.h), used when there is no Spike source tree."""
    import shutil
    exe = shutil.which("spike")
    if not exe:
        return None
    prefix = Path(exe).resolve().parent.parent
    lib, inc = prefix / "lib" / "libsoftfloat.so", prefix / "include" / "softfloat"
    return (lib, inc) if lib.is_file() and (inc / "softfloat.h").is_file() else None
DPI_C = ROOT / "sim" / "tb" / "softfloat_ref.c"
SVH = "softfloat_ref.svh"


def uses_softfloat(tb: Path) -> bool:
    """The testbench includes softfloat_ref.svh (needs the DPI reference)."""
    return f'`include "{SVH}"' in tb.read_text(encoding="utf-8")


def verilator_args() -> list[str]:
    """Verilator arguments that add the DPI wrappers and SoftFloat to a build."""
    if LIB.is_file() and (INCLUDE / "softfloat.h").is_file():
        return [str(DPI_C), "-CFLAGS", f"-I{INCLUDE}", "-LDFLAGS", str(LIB)]
    inst = installed()
    if inst is None:
        sys.exit(f"softfloat: no {LIB} / {INCLUDE}/softfloat.h and no installed Spike with lib/libsoftfloat.so "
                 "next to `spike` on PATH (build Spike, set SPIKE_SRC, or install Spike)")
    lib, inc = inst
    return [str(DPI_C), "-CFLAGS", f"-I{inc}", "-LDFLAGS", f"{lib} -Wl,-rpath,{lib.parent}"]


if __name__ == "__main__":
    print(verilator_args())
