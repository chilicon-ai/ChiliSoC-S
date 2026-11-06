#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""ChillU-S architectural tests: the RISC-V Architectural Compatibility Tests
(riscv-arch-test 3.x, old-framework-3.x branch) through RISCOF, with ChillU-S
(Verilator) as the DUT and the Sail RISC-V model as the reference.

  python3 sim/conformance/run_act.py                     all of rv32i_m (RISCOF
                                                         selects ChillU-S's tests)
  python3 sim/conformance/run_act.py --suite rv32i_m/I   one suite (I, M, C,
                                                         Zifencei, privilege, hints)
  python3 sim/conformance/run_act.py --jobs 8            parallel tests (default: CPUs)
  python3 sim/conformance/run_act.py --istall 40 --dstall 40 --seed 3   random memory stalls
  python3 sim/conformance/run_act.py --ref spike         Spike instead of Sail as the reference
  python3 sim/conformance/run_act.py --report            summary of the last run only

RISCOF selects the tests from chillus/chillus_isa.yaml (RV32IMC Zicsr Zifencei
Zicntr, M and U modes, misaligned loads / stores trap, 4 PMP entries): I, M, C (Zca),
Zifencei, privilege (ecall, ebreak, misaligned accesses / jumps) and hints.
Each test is compiled once per model with env/model_test.h and env/link.ld
(4 MiB RAM at 0x8000_0000, act_lib.RAM_BYTES); Sail runs with a configuration matching ChillU-S
(sail_cSim/riscof_sail_cSim.py: chillus_config). ChillU-S's signature is
rebuilt from the ELF image and the stores of the RVFI trace (the testbench
is unchanged; chillus/riscof_chillus.py). A test passes when the signatures
match and the testbench ended with "TB: PASS" (the store to tohost);
WAIVED lists the expected failures (XFAIL).

Outputs in sim/out/conformance/: build/obj_MEM_WORDS<n> (the Verilator model), per run
<suite>[_spike].log (RISCOF output) and the RISCOF work dir <suite>[_spike]/
with report.html and per test <group>/src/<test>.S/
  dut/  dut.elf, dut.dis, test.hex, rtl.trace, sim.log, chillus.status,
        DUT-chillus.signature
  ref/  ref.elf, ref.dis, sail.log, Reference-sail_c_simulator.signature
        (Spike: spike.log, Reference-spike.signature)

Tools (outside the repository; environment variable, default):
  RISCOF      ~/riscof-venv/bin/riscof     (pip install git+https://github.com/riscv/riscof)
  ARCH_TEST   ~/riscv-arch-test            (riscv-non-isa/riscv-arch-test, branch old-framework-3.x)
  SAIL_RISCV  ~/sail-riscv/current/bin/sail_riscv_sim   (riscv/sail-riscv release binary)
  plus riscv64-unknown-elf-gcc and Verilator on PATH (as sim/run.py).
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

CONF = Path(__file__).resolve().parent
sys.path.insert(0, str(CONF))
sys.path.insert(0, str(CONF.parent))
import act_lib  # noqa: E402
import run as simrun  # noqa: E402  (sim/run.py)

HOME = Path.home()
RISCOF = Path(os.environ.get("RISCOF", HOME / "riscof-venv" / "bin" / "riscof"))
ARCH_TEST = Path(os.environ.get("ARCH_TEST", HOME / "riscv-arch-test"))
SUITES = ARCH_TEST / "riscv-test-suite"

# Expected failures: <group>/<test>.S -> reason. Listed in the summary as
# XFAIL, not counted as failures.
WAIVED: dict[str, str] = {
}


def build() -> None:
    """The DUT model the chillus plugin uses (act_lib.RAM_BYTES of RAM)."""
    params = {"MEM_WORDS": str(act_lib.MEM_WORDS)}
    simrun.BUILD = act_lib.OUT / "build" / f"obj_{simrun.params_tag(params)}"
    simrun.SIM_BIN = simrun.BUILD / "Vchillus_tb"
    simrun.set_ram(act_lib.RAM_BYTES)
    simrun.build_sim(False, params)


def tag(suite: str, ref: str) -> str:
    return suite.strip("/").replace("/", "_") + ("" if ref == "sail" else f"_{ref}")


def run_riscof(suite: str, ref: str, jobs: int, sim_args: list[str]) -> int:
    work = act_lib.OUT / tag(suite, ref)
    log = act_lib.OUT / f"{tag(suite, ref)}.log"
    env = dict(os.environ, ACT_JOBS=str(jobs), ACT_SIM_ARGS=" ".join(sim_args))
    config = CONF / ("config.ini" if ref == "sail" else f"config_{ref}.ini")
    cmd = [str(RISCOF), "run", "--config", str(config),
           "--suite", str(SUITES / suite), "--env", str(SUITES / "env"),
           "--work-dir", str(work), "--no-browser"]
    print(f"riscof: {suite} -> {work.relative_to(act_lib.ROOT)}/ "
          f"(log {log.relative_to(act_lib.ROOT)})", flush=True)
    t0 = time.time()
    with open(log, "w") as f:
        rc = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, env=env).returncode
    print(f"riscof: done in {time.time() - t0:.0f} s (exit {rc})", flush=True)
    return rc


def first_diff(dut: list[str], ref: list[str], begin: int | None) -> str:
    for i, (a, b) in enumerate(zip(dut, ref)):
        if a != b:
            where = f" @ {begin + 4 * i:08x}" if begin is not None else ""
            return f"word {i}{where}: dut {a.strip()} ref {b.strip()}"
    return f"length: dut {len(dut)} ref {len(ref)} words"


def sig_begin(dut_dir: Path) -> int | None:
    elf = dut_dir / "dut.elf"
    if not elf.exists():
        return None
    return act_lib.symbols(elf).get("begin_signature")


def report(suite: str, ref: str) -> tuple[int, int, int]:
    """Print per-test results of a finished run; (passed, failed, waived)."""
    work = act_lib.OUT / tag(suite, ref)
    tests = sorted(p for p in work.rglob("*.S") if (p / "dut").is_dir())
    if not tests:
        print(f"  no tests in {work} (see {tag(suite, ref)}.log)")
        return 0, 1, 0
    passed = failed = waived = 0
    groups: dict[str, list[int]] = {}
    for t in tests:
        # <suite>/<group>/src/<test>.S -> <group>/<test>.S
        full = f"{suite.strip('/')}/{t.relative_to(work)}"
        group = full.split("/src/")[0].split("/")[-1]
        rel = f"{group}/{t.name}"
        dut_dir, ref_dir = t / "dut", t / "ref"
        dsig = dut_dir / "DUT-chillus.signature"
        rsig = next(ref_dir.glob("Reference-*.signature"), ref_dir / "none")
        dut = dsig.read_text().splitlines(True) if dsig.exists() else []
        ref = rsig.read_text().splitlines(True) if rsig.exists() else []
        st = dut_dir / "chillus.status"
        status = st.read_text().splitlines()[0] if st.exists() else "TB: no status"
        tb_ok = status == "TB: PASS"
        sig_ok = bool(ref) and dut == ref
        g = groups.setdefault(group, [0, 0, 0])
        if tb_ok and sig_ok:
            passed += 1
            g[0] += 1
            continue
        why = []
        if not tb_ok:
            why.append(status.replace("TB: ", "testbench "))
        if not ref:
            why.append("no reference signature (see ref/)")
        elif dut != ref:
            why.append("signature " + first_diff(dut, ref, sig_begin(dut_dir)))
        if rel in WAIVED:
            waived += 1
            g[2] += 1
            print(f"  XFAIL {rel:32s} {WAIVED[rel]}")
        else:
            failed += 1
            g[1] += 1
            print(f"  FAIL  {rel:32s} {'; '.join(why)}")
            print(f"        {t.relative_to(act_lib.ROOT)}/")
    for name, (p, f, w) in sorted(groups.items()):
        print(f"  {name:10s} {p:3d} passed, {f:3d} failed" + (f", {w} waived" if w else ""))
    return passed, failed, waived


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--suite", action="append",
                    help="suite directory under riscv-test-suite (repeatable; "
                         "default rv32i_m)")
    ap.add_argument("--jobs", type=int, default=len(os.sched_getaffinity(0)), help="parallel tests (default: this process's cores)")
    ap.add_argument("--ref", choices=("sail", "spike"), default="sail",
                    help="reference model (spike: sim/run.py's Spike configuration; "
                         "outputs in <suite>_spike/)")
    ap.add_argument("--istall", type=int, default=0, help="random fetch stall %% (testbench)")
    ap.add_argument("--dstall", type=int, default=0, help="random data stall %% (testbench)")
    ap.add_argument("--seed", type=int, help="Verilator random seed")
    ap.add_argument("--report", action="store_true", help="only summarize the last run")
    args = ap.parse_args()
    sim_args = [f"+istall={args.istall}", f"+dstall={args.dstall}"]
    if args.seed is not None:
        sim_args.append(f"+verilator+seed+{args.seed}")
    suites = args.suite or ["rv32i_m"]

    for path, what in ((RISCOF, "RISCOF (set RISCOF)"), (SUITES, "riscv-arch-test (set ARCH_TEST)")):
        if not path.exists():
            sys.exit(f"run_act.py: {what} not found at {path}")
    for s in suites:
        if not (SUITES / s).is_dir():
            sys.exit(f"run_act.py: no suite {SUITES / s}")
    act_lib.OUT.mkdir(parents=True, exist_ok=True)
    if not args.report:
        build()

    tot = [0, 0, 0]
    for s in suites:
        if not args.report:
            run_riscof(s, args.ref, args.jobs, sim_args)
        print(f"{s} (reference {args.ref}):")
        for i, n in enumerate(report(s, args.ref)):
            tot[i] += n
    print(f"{tot[0]} passed, {tot[1]} failed" + (f", {tot[2]} waived" if tot[2] else ""))
    return 1 if tot[1] else 0


if __name__ == "__main__":
    sys.exit(main())
