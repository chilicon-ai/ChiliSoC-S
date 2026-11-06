# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""RISCOF reference plugin (optional second reference): Spike, configured as
sim/run.py configures it for ChillU-S (run.SPIKE_CFG: rv32imc Zicsr Zifencei
Zicntr, M-mode only, the conformance RAM (act_lib.RAM_BYTES), WFI as a NOP; 4 PMP
regions, sim/run.py's SPIKE_CFG).

runTests: per test (in parallel, $ACT_JOBS): compile (act_lib, the same as
the DUT) -> ref.elf, ref.dis -> spike +signature (granularity 4) ->
Reference-spike.signature, spike.log (commit log).
"""

import logging
import subprocess
import sys
from pathlib import Path

from riscof.pluginTemplate import pluginTemplate

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))         # act_lib
import act_lib  # noqa: E402

sys.path.insert(0, str(act_lib.ROOT / "sim"))                            # run.py
import run as simrun  # noqa: E402

logger = logging.getLogger()

MAX_LOG_LINES = 8_000_000      # runaway guard (commit log lines)


class spike(pluginTemplate):
    __model__ = "spike"
    __version__ = "1.0"

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)
        self.cfg = kwargs.get("config") or {}
        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.archtest_env = archtest_env

    def build(self, isa_yaml, platform_yaml):
        self.spike = act_lib.tool("spike")

    def run_one(self, entry: dict) -> None:
        work = Path(entry["work_dir"])
        sig_file = work / (self.name[:-1] + ".signature")
        elf, _ = act_lib.compile_test(entry["test_path"], entry["isa"], entry["macros"],
                                      self.archtest_env, work, "ref")
        if elf is not None:
            simrun.set_ram(act_lib.RAM_BYTES)
            cmd = [self.spike, *simrun.SPIKE_CFG, "-l", "--log-commits",
                   f"+signature={sig_file}", "+signature-granularity=4", str(elf)]
            with open(work / "spike.log", "w") as log:
                log.write(" ".join(cmd) + "\n")
                proc = subprocess.Popen(act_lib.job("sim", cmd, quiet=True), stdout=log, stderr=subprocess.PIPE, text=True)
                for n, line in enumerate(proc.stderr):
                    log.write(line)
                    if n > MAX_LOG_LINES:
                        proc.kill()
                        break
                proc.wait()
        if not sig_file.exists():
            sig_file.write_text("")

    def runTests(self, testList, cgf_file=None, header_file=None):
        n = act_lib.jobs(self.cfg)
        logger.info(f"spike: {len(testList)} tests, {n} jobs")
        act_lib.parallel(self.run_one, list(testList.values()), n)
