# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""riscv-tests debug suite target: ChiliSoC-S in simulation (Verilator model).

gdbserver.py imports this file (it needs targets / testlib from riscv-tests
debug/ on sys.path, which gdbserver.py provides). sim/debug/run.py builds the
model and the boot ROM and passes them in CHILISOCS_SIM (the model command
without +rbb_port). Each test starts a fresh model: the boot ROM jumps to the
empty SRAM0 until OpenOCD halts the hart and GDB loads the test program.
"""

import os
import shlex
import socket
import subprocess
import tempfile
import time

import targets
import testlib


WORK_AREA = 0x8000_0000                # first 8 KiB of SRAM0 (chilisocs.cfg)


class chilisocs_hart(targets.Hart):
    xlen = 32
    # SRAM0 + SRAM1 (2 x 64 KiB at 0x8000_0000) after the 8 KiB OpenOCD work
    # area (WORK_AREA), where programs link (chilisocs.lds). Only 50 KiB of the
    # 120 KiB are declared: DownloadTest loads ram_size - 2 KiB, and OpenOCD's
    # on-target CRC of it (compare-sections) has a 20 s wall-clock timeout,
    # which the model (roughly 70k cycles/s) misses beyond about 100 KiB.
    ram = 0x8000_2000
    ram_size = 0xC800
    bad_address = 0x4000_0000          # no region: the default subordinate faults
    instruction_hardware_breakpoint_count = 2
    reset_vectors = [0x1_0000]         # boot ROM
    link_script_path = "chilisocs.lds"


class ChiliSim:
    """The Verilator model serving its JTAG pins on a free port."""

    def __init__(self, cmd: list[str], work_area: int, timeout: float = 120):
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0))
            self.port = s.getsockname()[1]
        # pylint: disable-next=consider-using-with
        self.logfile = tempfile.NamedTemporaryFile(prefix="chilisocs-", suffix=".log")
        self.lognames = [self.logfile.name]
        cmd = [*cmd, f"+rbb_port={self.port}"]
        self.logfile.write(("+ " + " ".join(cmd) + "\n").encode())
        self.logfile.flush()
        # pylint: disable-next=consider-using-with
        self.process = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=self.logfile,
                                        stderr=subprocess.STDOUT)
        start = time.time()
        while True:
            with open(self.logfile.name, encoding="utf-8", errors="replace") as f:
                if "rbb: listening" in f.read():
                    break
            if self.process.poll() is not None or time.time() - start > timeout:
                testlib.print_log(self.logfile.name)
                raise testlib.TestLibError("the ChiliSoC-S model did not listen for remote_bitbang")
            time.sleep(0.1)
        os.environ["REMOTE_BITBANG_HOST"] = "127.0.0.1"
        os.environ["REMOTE_BITBANG_PORT"] = str(self.port)
        os.environ["WORK_AREA"] = f"0x{work_area:x}"

    def __del__(self):
        try:
            self.process.kill()
            self.process.wait()
        except (OSError, AttributeError):
            pass

    def wait(self, *args, **kwargs):
        return self.process.wait(*args, **kwargs)


class chilisocs(targets.Target):
    harts = [chilisocs_hart(misa=0x4010_1104, progbufsize=8)]     # RV32 I M C U
    openocd_config_path = "chilisocs.cfg"
    timeout_sec = 60                   # per GDB operation (ops scale it): the model is slow
    server_timeout_sec = 600
    clint_addr = 0x0200_0000           # chilimix_aclint: SiFive CLINT layout
    support_hasel = False              # one hart
    support_memory_sampling = False
    implements_page_virtual_memory = False
    support_mcontrol = False           # triggers: mcontrol6 execute-address only
    support_icount = False
    support_itrigger = False
    support_etrigger = False
    support_unavailable_control = False
    # need load / store address triggers (the core matches execute addresses)
    skip_tests = ["ProgramHwWatchpoint", "Mcontrol6Test", "TriggerLoadAddressInstant",
                  "TriggerStoreAddressInstant"]

    def create(self):
        return ChiliSim(shlex.split(os.environ["CHILISOCS_SIM"]), WORK_AREA)
