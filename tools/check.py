# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Run every check of ChiliSoC-S, in order.

  python tools/check.py               all checks
  python tools/check.py --keep-going  run every step, report all failures
  python tools/check.py --no-sim      skip the software regression

Steps:
  lint      tools/lint.py, plus chilisocs_top with non-default parameters and
            the FPGA board top (fpga/build.py --lint)
  synth     tools/synth.py
  files     rtl.json: every unit's file exists, names start with chilisocs_,
            dependencies name units of the four file lists
  rules     BaseChiliSV's rules on ChiliSoC-S's own RTL: no always_ff /
            always_latch (storage comes from the libraries), no expression in
            an instance port connection (constant part-selects allowed)
  memmap    every *_BASE of sw/include/chilisocs.h has the same value in
            chilisocs_pkg, and every IRQ_*, N_PWM, N_IRQ and N_DMA_CH of chilisocs_pkg is in
            the header with the same value; the Zephyr devicetree
            (sw/zephyr/dts/riscv/chilicon/chilisocs.dtsi) has the same bases
            and PLIC sources
  sim       sim/run.py: the software regression (sim/tests.list) passes
  xip       the regression with the programs run from the SPI flash (sim/run.py --xip)
  stress    the regression again with random ROM / SRAM wait states
            (--param MEM_WAIT=3) and with the FPGA build's register file in
            flops (--param RF_LATCH=0), and more seeds of the stress test
            (STRESS_RUNS)

Exit status 1 if any step fails.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
import time

from filelist import LIB, RTL_LIST, PREFIX, ROOT, own_units, units

PY = sys.executable
PKG = ROOT / "source" / "pkg" / "chilisocs_pkg.sv"
HEADER = ROOT / "sw" / "include" / "chilisocs.h"
DTSI = ROOT / "sw" / "zephyr" / "dts" / "riscv" / "chilicon" / "chilisocs.dtsi"
LINT_PARAMS = [["-GN_GPIO=1", "-GROM_AW=6", "-GSRAM_AW=8"], ["-GN_GPIO=16", "-GSRAM_AW=12", "-GRF_LATCH=0"]]

_spec = importlib.util.spec_from_file_location("basechili_check", LIB / "tools" / "check.py")
_lib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lib)


def git(*args: str, cwd=ROOT) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True).stdout.strip()


def run_lint() -> bool:
    ok = _lib.run_cmd([PY, "tools/lint.py"])
    for p in LINT_PARAMS:
        ok = _lib.run_cmd([PY, "tools/lint.py", "--top", "chilisocs_top", "--", *p]) and ok
    ok = _lib.run_cmd([PY, "fpga/build.py", "--lint"]) and ok
    return ok


def check_rtl_list() -> list[str]:
    m = json.loads(RTL_LIST.read_text())
    errs = []
    names = {u["name"] for u, _ in units()}
    for u, path in own_units():
        if not path.is_file():
            errs.append(f"rtl.json: {u['name']}: no file {u['path']}")
        if not u["name"].startswith(PREFIX) or path.stem != u["name"]:
            errs.append(f"rtl.json: {u['name']}: name must start with {PREFIX} and match the file name")
        errs += [f"rtl.json: {u['name']}: unknown dependency {d}" for d in u["dependencies"] if d not in names]
    print(f"  {len(m['units'])} units")
    return errs


def check_rules() -> list[str]:
    errs = []
    for u, f in own_units():
        rel = f.relative_to(ROOT)
        for n, line in enumerate(f.read_text().splitlines(), 1):
            code = line.split("//", 1)[0]
            if "always_ff" in code or "always_latch" in code:
                errs.append(f"{rel}:{n}: always_ff / always_latch: use BaseChiliSV storage")
            mt = _lib.PORT_CONN.match(code)
            if mt and _lib.OPERATOR.search(mt.group(1)) and not _lib.PART_SELECT.match(mt.group(1)):
                errs.append(f"{rel}:{n}: expression in port connection: {mt.group(1).strip()}")
    return errs


def check_memmap() -> list[str]:
    rtl = {k: int(v.replace("_", ""), 16) for k, v in
           re.findall(r"localparam logic \[31:0\] (\w+_BASE)\s*=\s*32'h([0-9A-Fa-f_]+);", PKG.read_text())}
    sw = {k: int(v, 16) for k, v in re.findall(r"#define (\w+_BASE)\s+0x([0-9A-Fa-f]+)u", HEADER.read_text())}
    errs = [f"sw/include/chilisocs.h: {k} is {sw[k]:#010x}, chilisocs_pkg has {v:#010x}"
            for k, v in rtl.items() if k in sw and sw[k] != v]
    errs += [f"sw/include/chilisocs.h: {k} not in chilisocs_pkg" for k in sw if k not in rtl]
    rtl_n = {k: int(v) for k, v in re.findall(r"localparam int (IRQ_\w+|N_PWM|N_IRQ|N_DMA_CH)\s*=\s*(\d+);", PKG.read_text())}
    sw_n = {k: int(v) for k, v in re.findall(r"#define (IRQ_\w+|N_PWM|N_IRQ|N_DMA_CH)\s+(\d+)\b", HEADER.read_text())}
    errs += [f"sw/include/chilisocs.h: {k} is {sw_n.get(k)}, chilisocs_pkg has {v}"
             for k, v in rtl_n.items() if sw_n.get(k) != v]
    errs += [f"sw/include/chilisocs.h: {k} not in chilisocs_pkg" for k in sw_n if k not in rtl_n]
    errs += check_dtsi(rtl, rtl_n)
    print(f"  {len(sw)} bases, {len(rtl_n)} interrupt numbers compared (header and devicetree)")
    return errs


def check_dtsi(base: dict[str, int], irq: dict[str, int]) -> list[str]:
    """Node addresses and first PLIC source of each node of the Zephyr dtsi."""
    nodes = {lbl: (int(addr, 16), body) for lbl, addr, body in
             re.findall(r"(\w+): [\w-]+@([0-9a-f]+) \{(.*?)\n\t\t\};", DTSI.read_text(), re.S)}
    want = {"debug": (base["DM_BASE"], None), "bootrom": (base["ROM_BASE"], None),
            "clint": (base["CLINT_BASE"], None), "mtimer": (base["CLINT_BASE"] + 0xBFF8, None),
            "plic": (base["PLIC_BASE"], None), "gpio0": (base["GPIO_BASE"], irq["IRQ_GPIO0"]),
            "uart0": (base["UART0_BASE"], irq["IRQ_UART0"]), "spi0": (base["SPI0_BASE"], irq["IRQ_SPI0"]),
            "wdog0": (base["TIMER_BASE"] + 0x400, irq["IRQ_WDOG"]), "i2c0": (base["I2C0_BASE"], irq["IRQ_I2C0"]),
            "sram0": (base["SRAM0_BASE"], None),
            "sram1": (base["SRAM1_BASE"], None)}
    want |= {f"pwm{k}": (base["TIMER_BASE"] + 0x100 * k, irq["IRQ_PWM0"] + 4 * k) for k in range(irq["N_PWM"])}
    errs = [f"{DTSI.relative_to(ROOT)}: no node {lbl}" for lbl in want if lbl not in nodes]
    for lbl, (addr, src) in want.items():
        if lbl not in nodes:
            continue
        unit, body = nodes[lbl]
        reg = re.search(r"\breg = <0x([0-9a-f]+)", body)
        first = re.search(r"\binterrupts = <(\d+) 1>", body)
        for got in (unit, int(reg.group(1), 16) if reg else None):
            if got != addr:
                errs.append(f"{DTSI.relative_to(ROOT)}: {lbl} at {got and hex(got)}, chilisocs_pkg has {addr:#x}")
        if src is not None and (not first or int(first.group(1)) != src):
            errs.append(f"{DTSI.relative_to(ROOT)}: {lbl} PLIC source {first and first.group(1)}, chilisocs_pkg has {src}")
    ndev = re.search(r"riscv,ndev = <(\d+)>", nodes.get("plic", (0, ""))[1])
    if not ndev or int(ndev.group(1)) != irq["N_IRQ"]:
        errs.append(f"{DTSI.relative_to(ROOT)}: plic riscv,ndev is not N_IRQ ({irq['N_IRQ']})")
    return errs


# extra seeds of sw/tests/stress.c: (seed, top parameters)
STRESS_RUNS = [(2, []), (3, ["--param", "MEM_WAIT=3"])]


def run_stress() -> bool:
    ok = _lib.run_cmd([PY, "sim/run.py", "--param", "MEM_WAIT=3"])
    ok = _lib.run_cmd([PY, "sim/run.py", "--param", "RF_LATCH=0"]) and ok
    for seed, params in STRESS_RUNS:
        ok = _lib.run_cmd([PY, "sim/run.py", "stress", "--seed", str(seed), *params]) and ok
    return ok


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--keep-going", action="store_true", help="do not stop at the first failure")
    ap.add_argument("--no-sim", action="store_true", help="skip the software regression and the stress runs")
    args = ap.parse_args()

    steps = [
        ("lint", run_lint),
        ("synth", lambda: _lib.run_cmd([PY, "tools/synth.py"])),
        ("files", lambda: _lib.run_py(check_rtl_list)),
        ("rules", lambda: _lib.run_py(check_rules)),
        ("memmap", lambda: _lib.run_py(check_memmap)),
        ("sim", lambda: _lib.run_cmd([PY, "sim/run.py"])),
        ("xip", lambda: _lib.run_cmd([PY, "sim/run.py", "--xip"])),
        ("stress", run_stress),
    ]
    if args.no_sim:
        del steps[-3:]
    results = []
    for name, step in steps:
        print(f"\n== {name} ==", flush=True)
        t0 = time.monotonic()
        ok = step()
        results.append((name, ok, time.monotonic() - t0))
        if not ok and not args.keep_going:
            break

    print("\n== summary ==")
    for name, ok, dt in results:
        print(f"{'PASS' if ok else 'FAIL'}  {name:12s} {dt:7.1f} s")
    for name, _ in steps[len(results):]:
        print(f"SKIP  {name}")
    passed = len(results) == len(steps) and all(ok for _, ok, _ in results)
    head = git("rev-parse", "--short", "HEAD") or "this tree"
    print(f"check: {'clean' if passed else 'FAILED'} at {head}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
