# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Helpers shared by the RISCOF plugins (chillus, sail_cSim) and run_act.py.

Both plugins compile every test the same way (riscv64-unknown-elf-gcc,
sim/conformance/env/model_test.h and link.ld) so the DUT and reference ELFs
are identical; only the execution differs.
"""

import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from jobs import job  # noqa: E402,F401  (machine job queue: the plugins' simulations)

CONF = Path(__file__).resolve().parent          # sim/conformance
ROOT = CONF.parent.parent                       # repository root
ENV = CONF / "env"                              # model_test.h, link.ld
OUT = ROOT / "sim" / "out" / "conformance"      # work dirs and the model build
CROSS = "riscv64-unknown-elf-"
# RAM of every model for the architectural tests: 4 MiB at 0x8000_0000 (some
# tests, e.g. I/jal-01 with +-1 MiB jumps, do not fit the default 1 MiB);
# chillus_tb MEM_WORDS, env/link.ld LENGTH, Sail and Spike all use it.
RAM_BYTES = 0x40_0000
MEM_WORDS = RAM_BYTES // 4


def jobs(config: dict) -> int:
    """Parallel tests: $ACT_JOBS (run_act.py --jobs), else config 'jobs', else
    the CPU count."""
    return int(os.environ.get("ACT_JOBS") or config.get("jobs") or os.cpu_count() or 1)


def tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise SystemExit(f"act: {name} not found on PATH")
    return path


def compile_test(src: str, isa: str, macros: list[str], archtest_env: str,
                 work: Path, name: str) -> tuple[Path | None, str]:
    """Compile one test to <work>/<name>.elf and .dis. Returns (elf or None
    on a compile error, compiler output)."""
    elf = work / f"{name}.elf"
    cmd = [tool(CROSS + "gcc"), f"-march={isa.lower()}", "-mabi=ilp32", "-static",
           "-mcmodel=medany", "-fvisibility=hidden", "-nostdlib", "-nostartfiles",
           "-T", str(ENV / "link.ld"), "-I", str(ENV), "-I", archtest_env,
           *(f"-D{m}" for m in macros), src, "-o", str(elf)]
    cc = subprocess.run(cmd, text=True, capture_output=True)
    (work / "compile.log").write_text(" ".join(cmd) + "\n" + cc.stdout + cc.stderr)
    if cc.returncode != 0:
        return None, cc.stdout + cc.stderr
    with open(work / f"{name}.dis", "w") as f:
        subprocess.run([tool(CROSS + "objdump"), "-D", str(elf)], stdout=f, check=True)
    return elf, cc.stdout + cc.stderr


def symbols(elf: Path) -> dict[str, int]:
    """Global symbol name -> address (nm)."""
    nm = subprocess.run([tool(CROSS + "nm"), str(elf)], text=True, capture_output=True,
                        check=True).stdout
    syms = {}
    for line in nm.splitlines():
        parts = line.split()
        if len(parts) == 3:
            syms[parts[2]] = int(parts[0], 16)
    return syms


def parallel(fn, items, n: int) -> list:
    """fn over items with n worker threads (fn runs subprocesses)."""
    with ThreadPoolExecutor(max_workers=max(1, n)) as ex:
        return list(ex.map(fn, items))
