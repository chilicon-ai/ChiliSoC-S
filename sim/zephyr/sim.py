# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Runs a Zephyr ELF on the ChiliSoC-S model (the run_custom target of the
chilisocs_sim board, which twister calls; or by hand).

  python sim/zephyr/sim.py <zephyr.elf>

Splits the ELF into SRAM0 / SRAM1 images next to it and replaces itself with
the model (sim/run.py's build; $CHILISOCS_MODEL), the boot ROM
($CHILISOCS_ROM, written by sim/zephyr/run.py) and +uart_div=1: the console
goes to stdout until the caller stops the model or $CHILISOCS_MAX_CYCLES
(default 10^10) is reached.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sim"))
import run as simrun  # noqa: E402


def main() -> None:
    elf = Path(sys.argv[1]).resolve()
    model = Path(os.environ.get("CHILISOCS_MODEL", simrun.OUT / "build" / "obj" / "Vchilisocs_tb"))
    rom = Path(os.environ.get("CHILISOCS_ROM", simrun.OUT / "zephyr" / "rom.hex"))
    if not model.is_file() or not rom.is_file():
        sys.exit(f"sim.py: no model {model} or boot ROM {rom} (python sim/zephyr/run.py builds them)")
    segs = simrun.elf_segments(elf)
    words = 1 << simrun.DEFAULTS["SRAM_AW"]
    imgs = []
    for k, base in enumerate((simrun.SRAM0_BASE, simrun.SRAM1_BASE)):
        end = base + 4 * words                   # a segment may span SRAM0 and SRAM1: clip it
        part = [(max(a, base), d[max(a, base) - a:end - a]) for a, d in segs if a < end and a + len(d) > base]
        imgs.append(elf.parent / f"sram{k}.hex")
        simrun.write_hex(imgs[-1], part, base, words)
    args = [str(model), f"+rom={rom}", f"+sram0={imgs[0]}", f"+sram1={imgs[1]}", "+uart_div=1",
            f"+max_cycles={os.environ.get('CHILISOCS_MAX_CYCLES', 10**10)}"]
    sys.stdout.flush()
    args = simrun.job("sim", args)
    os.execvp(args[0], args)


if __name__ == "__main__":
    main()
