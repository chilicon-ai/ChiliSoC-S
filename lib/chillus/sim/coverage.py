#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""ChillU-S coverage report: code coverage (Verilator) and functional coverage
(Spike commit logs) of the tests run with `sim/run.py --coverage`.

  python3 sim/run.py --coverage                       regression, coverage model
  python3 sim/run.py --coverage --istall 40 --dstall 40 --seed 1 --tag stall_s1
  python3 sim/run.py --coverage --param RF_LATCH=0      (sim/out/cov/RF_LATCH0/)
  python3 sim/coverage.py                             merge all of sim/out/cov/, report
  python3 sim/coverage.py sim/out/cov/stall_s1        only these run directories
  python3 sim/coverage.py --holes all                 list every hole (default: 40 per table)
  python3 sim/coverage.py --rank                      also rank the tests (verilator_coverage)

Code coverage: every <test>/coverage.dat below the given directories is
summed into <out>/merged.dat (as verilator_coverage --write, but in
parallel); sources annotated with the counts go to <out>/annotated/
(verilator_coverage --annotate, a line starting with %000000 is a point never
hit). Reported for the RTL only (the testbench and the checkers are not
instrumented, see COV_VLT in sim/run.py): per unit (source sub-directory) line, branch, expression and
toggle coverage, the largest uncovered regions (consecutive never-hit line /
branch points), never-hit branch arms and expression terms, and the signals
with the most never-toggled bits. Not counted: rst_n toggles (reset is
asserted once per run, so 1->0 never happens).
Points are per module, not per instance (Verilator's default): a module
point is hit when any instance hits it.

Functional coverage: the program-order instruction stream of each distinct
program (test.hex; the same program run with other stalls or parameters
counts once) from its Spike commit log up to the store to tohost, which
run.py has checked against the RTL's RVFI trace; only tests whose sim.log
says "TB: PASS" are used. Bins
(category: what):
  insn      every RV32IMC + Zicsr + Zifencei + mret / wfi instruction, every
            compressed form, and illegal encodings (32-bit, SYSTEM, 16-bit),
            executed (retired or trapped)
  fwd       consumer operand x producer class x distance 1..3 retired
            instructions (nearest writer of the register, no trap or taken
            transfer in between): the id/ex operand forwarding paths
  load_use  each load size with its rd read by the next instruction, per
            consumer operand
  branch    each conditional branch x taken / not taken x forward / backward
  jump      jal / jalr / c.j / c.jal / c.jr / c.jalr / ret, taken transfer to
            a 32-bit instruction at pc[1] = 1 (split fetch) per transfer kind,
            back-to-back taken transfers (kind x kind, distance 1)
  pc2       each instruction class as a 32-bit instruction at pc[1] = 1
  trap      every exception / interrupt cause; trap entry with an older
            load / store / mul / div 1 or 2 instructions before it;
            interrupt preempting each instruction class (the one at mepc);
            illegal-instruction kinds
  csr       read / write of every CSR (ranges grouped), write of a read-only
            CSR, each csr op with and without its write, write then read of
            the same CSR at distance 1
  mem       load / store size x address offset (misaligned ones trap),
            region (RAM, CLINT, outside: access fault), store -> load same
            word at distance 1 / 2
  md        div / rem by zero and signed overflow, mulh* operand signs
Bins that cannot be hit by design are listed separately (UNREACHABLE), not
as holes.

Outputs in <out> (default sim/out/coverage/): merged.dat, annotated/,
code.txt, functional.txt, summary.json; the report is also printed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import multiprocessing
import os
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

import rvc

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import filelist  # noqa: E402  (RTL file list from the file lists)

ROOT = Path(__file__).resolve().parent.parent
# RTL roots -> report name prefix: ChillU-S's source/ (units ChillUS/<unit>) and
# the library's (units BaseChiliSV/<unit>).
SRC_ROOTS = {"": ROOT / "source", "BaseChiliSV/": filelist.LIB / "source"}
OUT_COV = ROOT / "sim" / "out" / "cov"
REPORT = ROOT / "sim" / "out" / "coverage"
BASE = 0x8000_0000
RAM_BYTES = 0x10_0000
CLINT = 0x0200_0000


def show(p: Path) -> str:
    """Path for messages: relative to the repository when inside it."""
    return str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p)


def tool(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        sys.exit(f"coverage.py: {name} not found on PATH (VERILATOR_ROOT / PATH)")
    return path


# =============================================================================
# code coverage
# =============================================================================
def _sum_dats(dats: list[Path]) -> Counter:
    total: Counter = Counter()
    for d in dats:
        with open(d, encoding="utf-8", errors="surrogateescape") as f:
            for line in f:
                if line.startswith("C '"):
                    q = line.rindex("'")
                    total[line[:q + 1]] += int(line[q + 1:])
    return total


def merge(dats: list[Path], merged: Path) -> None:
    """Sum the points of the .dat files into merged (the verilator_coverage
    --write format; done here in parallel: verilator_coverage takes ~1.5 s
    per file)."""
    n = max(1, min(len(dats), os.cpu_count() or 1))
    chunks = [dats[i::n] for i in range(n)]
    total: Counter = Counter()
    with multiprocessing.Pool(n) as pool:
        for part in pool.imap_unordered(_sum_dats, chunks):
            total.update(part)
    with open(merged, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write("# SystemC::Coverage-3\n")
        for key, count in total.items():
            f.write(f"{key} {count}\n")


def parse_dat(path: Path) -> list[dict]:
    """Coverage points: {f, l, t, o, page, h, count}."""
    pts = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if not line.startswith("C '"):
                continue
            q = line.rindex("'")
            d = {}
            for field in line[3:q].split("\x01"):
                if "\x02" in field:
                    k, v = field.split("\x02", 1)
                    d[k] = v
            d["count"] = int(line[q + 1:])
            pts.append(d)
    return pts


def rel_src(f: str) -> str | None:
    """Absolute RTL path -> report name, e.g. ChillUS/alu/chillus_alu.sv or
    BaseChiliSV/dff/basechili_dff.sv (None outside the RTL roots)."""
    p = Path(f).resolve()
    for prefix, root in SRC_ROOTS.items():
        if p.is_relative_to(root):
            return prefix + str(p.relative_to(root))
    return None


def src_path(rel: str) -> Path:
    """Report name (rel_src) -> absolute path."""
    for prefix, root in SRC_ROOTS.items():
        if prefix and rel.startswith(prefix):
            return root / rel[len(prefix):]
    return SRC_ROOTS[""] / rel


def unit_of(rel: str) -> str:
    return str(Path(rel).parent)


def pct(h: int, n: int) -> str:
    return f"{100.0 * h / n:5.1f}%" if n else "    - "


TYPES = ("line", "branch", "expr", "toggle")


def code_report(pts: list[dict], nholes: int | None) -> tuple[str, dict]:
    out = []
    by_unit: dict[str, Counter] = defaultdict(Counter)
    noise = Counter()
    src_pts = []
    for p in pts:
        rel = rel_src(p.get("f", ""))
        if rel is None:
            continue
        p["rel"] = rel
        t = p.get("t", "")
        if t == "toggle" and p.get("o", "").startswith("rst_n:"):
            noise["rst"] += 1               # one reset per run: 1->0 never toggles
            continue
        src_pts.append(p)
        u = unit_of(rel)
        by_unit[u][t + "_n"] += 1
        by_unit[u][t + "_h"] += p["count"] > 0
    total = Counter()
    for c in by_unit.values():
        total.update(c)

    out.append("Code coverage (Verilator; hit = count > 0)")
    hdr = f"  {'unit':34s}" + "".join(f"{t:>21s}" for t in TYPES)
    out.append(hdr)
    out.append("  " + "-" * (len(hdr) - 2))

    def row(name, c):
        cells = "".join(f"{pct(c[t + '_h'], c[t + '_n'])} {c[t + '_h']:6d}/{c[t + '_n']:<6d}"
                        for t in TYPES)
        return f"  {name:34s}{cells}"
    for u in sorted(by_unit):
        out.append(row(u, by_unit[u]))
    out.append("  " + "-" * (len(hdr) - 2))
    out.append(row("total", total))
    if noise["rst"]:
        out.append(f"  (not counted: {noise['rst']} rst_n toggle points: one reset per run)")

    # ---- uncovered regions: never-hit line / branch points --------------------
    lines_pts: dict[str, dict[int, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for p in src_pts:
        if p.get("t") in ("line", "branch"):
            lines_pts[p["rel"]][int(p["l"])].append(p)
    regions = []
    for rel, lp in lines_pts.items():
        miss = sorted(l for l, ps in lp.items() if all(q["count"] == 0 for q in ps))
        hit = {l for l, ps in lp.items() if any(q["count"] > 0 for q in ps)}
        cur = None
        for l in miss:
            if cur and l - cur[1] <= 6 and not any(h in hit for h in range(cur[1] + 1, l)):
                cur[1] = l
                cur[2] += len(lp[l])
            else:
                if cur:
                    regions.append((rel, *cur))
                cur = [l, l, len(lp[l])]
        if cur:
            regions.append((rel, *cur))
    regions.sort(key=lambda r: (-r[3], -(r[2] - r[1]), r[0], r[1]))
    src_cache: dict[str, list[str]] = {}

    def src_line(rel, l):
        if rel not in src_cache:
            src_cache[rel] = src_path(rel).read_text(errors="replace").splitlines()
        lines = src_cache[rel]
        return lines[l - 1].strip()[:70] if 0 < l <= len(lines) else ""
    lim = 1 << 30 if nholes is None else nholes
    out.append("")
    out.append(f"Largest uncovered regions (never-hit line / branch points; {len(regions)} regions)")
    for rel, a, b, n in regions[:lim]:
        rng = f"{a}" if a == b else f"{a}-{b}"
        out.append(f"  {n:3d} pts  {rel}:{rng:9s} {src_line(rel, a)}")

    # ---- toggle holes: per signal --------------------------------------------
    sig = defaultdict(lambda: [0, 0, None])   # (rel, page, name) -> [bits missed, bits, line]
    bits = defaultdict(lambda: [0, 0])
    for p in src_pts:
        if p.get("t") != "toggle":
            continue
        m = re.match(r"(.*?)(\[\d+\])?:([01])->([01])$", p.get("o", ""))
        name = m.group(1) if m else p.get("o", "")
        bitkey = (p["rel"], p.get("page", ""), name, m.group(2) if m else "")
        bits[bitkey][0] += 1
        bits[bitkey][1] += p["count"] > 0
        sig[(p["rel"], p.get("page", ""), name)][2] = p.get("l")
    for (rel, page, name, _b), (n, h) in bits.items():
        s = sig[(rel, page, name)]
        s[1] += 1
        s[0] += h < n
    tog = [(rel, page, name, *v) for (rel, page, name), v in sig.items() if v[0]]
    tog.sort(key=lambda r: (-r[3], r[0], r[2]))
    out.append("")
    out.append(f"Signals with never-toggled bits (0->1 or 1->0 missing; {len(tog)} signals)")
    for rel, page, name, miss, nb, l in tog[:lim]:
        mod = page.split("/", 1)[-1]
        out.append(f"  {miss:4d}/{nb:<4d} bits  {rel}:{l}  {mod}.{name}")

    # ---- expression / branch terms never hit ------------------------------------
    ex = sorted((p["rel"], int(p["l"]), p.get("t"), p.get("o", "")) for p in src_pts
                if p.get("t") in ("expr", "branch") and p["count"] == 0)
    out.append("")
    out.append(f"Never-hit branch arms and expression terms ({len(ex)}; annotated/ has the context)")
    for rel, l, t, o in ex[:lim]:
        out.append(f"  {rel}:{l:<5d} {t:6s} {o[:90]}")
    if len(ex) > lim:
        out.append(f"  ... {len(ex) - lim} more (--holes all)")

    summary = {"units": {u: dict(c) for u, c in sorted(by_unit.items())},
               "total": dict(total),
               "regions": [dict(file=r[0], first=r[1], last=r[2], points=r[3]) for r in regions],
               "toggle_holes": [dict(file=t[0], module=t[1], signal=t[2], missed=t[3], bits=t[4])
                                for t in tog]}
    return "\n".join(out), summary


# =============================================================================
# functional coverage
# =============================================================================
BR_NAMES = {0: "beq", 1: "bne", 4: "blt", 5: "bge", 6: "bltu", 7: "bgeu"}
LD_NAMES = {0: "lb", 1: "lh", 2: "lw", 4: "lbu", 5: "lhu"}
ST_NAMES = {0: "sb", 1: "sh", 2: "sw"}
OPI_NAMES = {0: "addi", 2: "slti", 3: "sltiu", 4: "xori", 6: "ori", 7: "andi"}
OP_NAMES = {0: "add", 1: "sll", 2: "slt", 3: "sltu", 4: "xor", 5: "srl", 6: "or", 7: "and"}
MD_NAMES = ["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"]
CSR_OPS = {1: "csrrw", 2: "csrrs", 3: "csrrc", 5: "csrrwi", 6: "csrrsi", 7: "csrrci"}
SIZE = {"lb": 1, "lbu": 1, "sb": 1, "lh": 2, "lhu": 2, "sh": 2, "lw": 4, "sw": 4}

INSN_32 = (["lui", "auipc", "jal", "jalr"] + list(BR_NAMES.values()) + list(LD_NAMES.values())
           + list(ST_NAMES.values()) + list(OPI_NAMES.values()) + ["slli", "srli", "srai"]
           + ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
           + ["fence", "fence.tso", "fence.i", "ecall", "ebreak", "mret", "wfi"]
           + MD_NAMES + list(CSR_OPS.values()) + ["illegal", "illegal.system"])
INSN_16 = ["c.addi4spn", "c.lw", "c.sw", "c.nop", "c.addi", "c.jal", "c.li", "c.addi16sp",
           "c.lui", "c.srli", "c.srai", "c.andi", "c.sub", "c.xor", "c.or", "c.and", "c.j",
           "c.beqz", "c.bnez", "c.slli", "c.lwsp", "c.jr", "c.mv", "c.ebreak", "c.jalr",
           "c.add", "c.swsp", "c.illegal"]


def c_name(c: int) -> str:
    """Mnemonic of a 16-bit instruction (c.illegal: illegal / reserved)."""
    if rvc.expand(c) is None:
        return "c.illegal"
    q, f3, b12 = c & 3, (c >> 13) & 7, (c >> 12) & 1
    rd, rs2 = (c >> 7) & 31, (c >> 2) & 31
    if q == 0:
        return {0: "c.addi4spn", 2: "c.lw", 6: "c.sw"}[f3]
    if q == 1:
        if f3 == 0:
            return "c.nop" if rd == 0 else "c.addi"
        if f3 == 3:
            return "c.addi16sp" if rd == 2 else "c.lui"
        if f3 == 4:
            f2 = (c >> 10) & 3
            if f2 < 3:
                return ["c.srli", "c.srai", "c.andi"][f2]
            return ["c.sub", "c.xor", "c.or", "c.and"][(c >> 5) & 3]
        return {1: "c.jal", 2: "c.li", 5: "c.j", 6: "c.beqz", 7: "c.bnez"}[f3]
    if f3 == 0:
        return "c.slli"
    if f3 == 2:
        return "c.lwsp"
    if f3 == 6:
        return "c.swsp"
    if b12 == 0:
        return "c.jr" if rs2 == 0 else "c.mv"
    if rd == 0 and rs2 == 0:
        return "c.ebreak"
    return "c.jalr" if rs2 == 0 else "c.add"


class Insn:
    """One instruction (raw: 16- or 32-bit) decoded to its 32-bit form."""
    __slots__ = ("raw", "c", "x", "name", "cname", "cls", "rd", "rs1", "rs2", "len", "imm")

    def __init__(self, raw: int):
        self.c = (raw & 3) != 3
        self.raw = raw & 0xFFFF if self.c else raw
        self.len = 2 if self.c else 4
        self.cname = c_name(self.raw) if self.c else None
        x = rvc.expand(self.raw) if self.c else raw
        self.x = x = x or 0
        opc, f3, f7 = x & 0x7F, (x >> 12) & 7, x >> 25
        rd, rs1, rs2 = (x >> 7) & 31, (x >> 15) & 31, (x >> 20) & 31
        u1 = u2 = False
        wr = True
        self.imm = 0
        name, cls = "illegal", "illegal"
        if self.c and self.cname == "c.illegal":
            wr = False
        elif opc == 0x37:
            name, cls = "lui", "alu"
        elif opc == 0x17:
            name, cls = "auipc", "alu"
        elif opc == 0x6F:
            name, cls = "jal", "jal"
            self.imm = sext((x >> 31) << 20 | ((x >> 12) & 0xFF) << 12 | ((x >> 20) & 1) << 11
                            | ((x >> 21) & 0x3FF) << 1, 21)
        elif opc == 0x67 and f3 == 0:
            name, cls, u1 = "jalr", "jalr", True
        elif opc == 0x63 and f3 in BR_NAMES:
            name, cls, u1, u2, wr = BR_NAMES[f3], "branch", True, True, False
            self.imm = sext((x >> 31) << 12 | ((x >> 7) & 1) << 11 | ((x >> 25) & 0x3F) << 5
                            | ((x >> 8) & 0xF) << 1, 13)
        elif opc == 0x03 and f3 in LD_NAMES:
            name, cls, u1 = LD_NAMES[f3], "load", True
        elif opc == 0x23 and f3 in ST_NAMES:
            name, cls, u1, u2, wr = ST_NAMES[f3], "store", True, True, False
        elif opc == 0x13 and f3 in OPI_NAMES:
            name, cls, u1 = OPI_NAMES[f3], "alu", True
        elif opc == 0x13 and f3 == 1 and f7 == 0:
            name, cls, u1 = "slli", "alu", True
        elif opc == 0x13 and f3 == 5 and f7 in (0, 0x20):
            name, cls, u1 = ("srai" if f7 else "srli"), "alu", True
        elif opc == 0x33 and f7 == 1:
            name, u1, u2 = MD_NAMES[f3], True, True
            cls = "mul" if f3 < 4 else "div"
        elif opc == 0x33 and (f7 == 0 or (f7 == 0x20 and f3 in (0, 5))):
            name = ("sub" if f3 == 0 else "sra") if f7 else OP_NAMES[f3]
            cls, u1, u2 = "alu", True, True
        elif opc == 0x0F and f3 == 0:
            name, cls, wr = ("fence.tso" if (x >> 28) == 8 else "fence"), "fence", False
        elif opc == 0x0F and f3 == 1:
            name, cls, wr = "fence.i", "fence", False
        elif opc == 0x73 and f3 in CSR_OPS:
            name, cls, u1 = CSR_OPS[f3], "csr", f3 < 4
        elif opc == 0x73:
            name = {0x30200073: "mret", 0x10500073: "wfi", 0x73: "ecall",
                    0x100073: "ebreak"}.get(x, "illegal.system")
            cls, wr = ("system" if name != "illegal.system" else "illegal"), False
        if cls == "illegal":
            wr = False
        self.name, self.cls = name, cls
        self.rd = rd if wr else 0
        self.rs1 = rs1 if u1 else 0
        self.rs2 = rs2 if u2 else 0

    @property
    def mnem(self) -> str:
        return self.cname or self.name


def sext(x: int, w: int) -> int:
    return x - (1 << w) if x >> (w - 1) & 1 else x


def s32(x: int) -> int:
    return sext(x & 0xFFFFFFFF, 32)


# ---- CSRs --------------------------------------------------------------------
CSR_NAMES = {0x300: "mstatus", 0x301: "misa", 0x304: "mie", 0x305: "mtvec", 0x310: "mstatush",
             0x320: "mcountinhibit", 0x340: "mscratch", 0x341: "mepc", 0x342: "mcause",
             0x343: "mtval", 0x344: "mip", 0xB00: "mcycle", 0xB02: "minstret",
             0xB80: "mcycleh", 0xB82: "minstreth", 0xC00: "cycle", 0xC01: "time",
             0xC02: "instret", 0xC80: "cycleh", 0xC81: "timeh", 0xC82: "instreth",
             0xF11: "mvendorid", 0xF12: "marchid", 0xF13: "mimpid", 0xF14: "mhartid",
             0xF15: "mconfigptr"}
CSR_RANGES = [(0xB03, 0xB1F, "mhpmcounter3..31"), (0xB83, 0xB9F, "mhpmcounter3h..31h"),
              (0x323, 0x33F, "mhpmevent3..31"), (0x3A0, 0x3AF, "pmpcfg0..15"),
              (0x3B0, 0x3EF, "pmpaddr0..63")]


def csr_name(a: int) -> str | None:
    if a in CSR_NAMES:
        return CSR_NAMES[a]
    for lo, hi, n in CSR_RANGES:
        if lo <= a <= hi:
            return n
    return None


ALL_CSRS = list(CSR_NAMES.values()) + [r[2] for r in CSR_RANGES]


def csr_ro(name: str) -> bool:
    a = next((k for k, v in CSR_NAMES.items() if v == name), None)
    if a is None:
        a = next(lo for lo, hi, n in CSR_RANGES if n == name)
    return (a >> 10) == 3


# ---- traps ---------------------------------------------------------------------
EXC_NAMES = {"trap_instruction_address_misaligned": "exc0 instr_misaligned",
             "trap_instruction_access_fault": "exc1 instr_access_fault",
             "trap_illegal_instruction": "exc2 illegal_instruction",
             "trap_breakpoint": "exc3 breakpoint",
             "trap_load_address_misaligned": "exc4 load_misaligned",
             "trap_load_access_fault": "exc5 load_access_fault",
             "trap_store_address_misaligned": "exc6 store_misaligned",
             "trap_store_access_fault": "exc7 store_access_fault",
             "trap_machine_ecall": "exc11 ecall_m"}
IRQ_NAMES = {3: "irq3 machine_software", 7: "irq7 machine_timer", 11: "irq11 machine_external"}

# ---- bin space -------------------------------------------------------------------
PRODUCERS = ["alu", "load", "mul", "div", "csr", "link"]
PORTS = ["alu.rs1", "alu.rs2", "branch.rs1", "branch.rs2", "load.rs1", "store.rs1",
         "store.rs2", "jalr.rs1", "mul.rs1", "mul.rs2", "div.rs1", "div.rs2", "csr.rs1"]
XFER = ["branch", "jal", "jalr", "mret"]
CLASSES = ["alu", "load", "store", "branch", "jal", "jalr", "mul", "div", "csr", "fence", "system"]

UNREACHABLE = {
    "trap/cause/exc0 instr_misaligned":
        "C is always on (misa read-only): every jump target is 2-byte aligned",
    "trap/cause/irq11 machine_external": "testbench ties irq_external to 0 (no PLIC model)",
    "jump/to 32-bit at pc[1]=1 after trap": "mtvec is 4-byte aligned (direct mode only)",
    **{f"trap/irq with older {o} d1":
       "not reachable in lockstep with Spike: Spike takes an interrupt only after a "
       "serializing instruction (CSR, mret) or a trap, so the instruction before it is "
       "always one of those (needs asynchronous interrupt injection)"
       for o in ("load", "store", "mul", "div")},
    **{f"load_use/{ld} -> {c}":
       "a byte / halfword value (plus a 12-bit offset) is never a RAM address: the "
       "access faults and does not retire (jalr: the target fetch faults)"
       for ld in ("lb", "lh", "lbu", "lhu") for c in ("load.rs1", "store.rs1", "jalr.rs1")},
}


def bin_space() -> dict[str, list[str]]:
    b: dict[str, list[str]] = defaultdict(list)
    b["insn"] = INSN_32 + INSN_16
    for port in PORTS:
        for prod in PRODUCERS:
            for d in (1, 2, 3):
                b["fwd"].append(f"{port} <- {prod} d{d}")
    for ld in LD_NAMES.values():
        for port in PORTS:
            b["load_use"].append(f"{ld} -> {port}")
    for br in list(BR_NAMES.values()) + ["c.beqz", "c.bnez"]:
        for t in ("taken", "not_taken"):
            for d in ("fwd", "bwd"):
                b["branch"].append(f"{br} {t} {d}")
    for j in ("jal", "jalr", "ret", "c.j", "c.jal", "c.jr", "c.jalr", "c.ret"):
        b["jump"].append(f"{j}")
    for k in XFER + ["trap"]:
        b["jump"].append(f"to 32-bit at pc[1]=1 after {k}")
    for k1 in XFER:
        for k2 in XFER:
            b["jump"].append(f"back-to-back taken {k1} -> {k2}")
    for c in CLASSES:
        b["pc2"].append(f"{c} 32-bit at pc[1]=1")
    for n in list(EXC_NAMES.values()) + list(IRQ_NAMES.values()):
        b["trap"].append(f"cause/{n}")
    for kind in ("exc", "irq"):
        for older in ("load", "store", "mul", "div"):
            for d in (1, 2):
                b["trap"].append(f"{kind} with older {older} d{d}")
    for c in CLASSES:
        b["trap"].append(f"irq preempts {c}")
    for k in ("unknown 32-bit encoding", "system funct12 (sret, dret, ...)",
              "c.illegal (incl. 0x0000)", "csr unimplemented", "csr write read-only"):
        b["trap"].append(f"illegal: {k}")
    for n in ALL_CSRS:
        b["csr"].append(f"{n} read")
        b["csr"].append(f"{n} write" + (" (illegal)" if csr_ro(n) else ""))
    for op in CSR_OPS.values():
        b["csr"].append(f"{op} writes")
        b["csr"].append(f"{op} " + ("no read (rd=x0)" if op in ("csrrw", "csrrwi") else "no write"))
    b["csr"].append("write then read same csr d1")
    for op in list(LD_NAMES.values()) + list(ST_NAMES.values()):
        for off in range(4):
            al = off % SIZE[op] == 0
            b["mem"].append(f"{op} offset {off}" + ("" if al else " (misaligned trap)"))
    for kind in ("load", "store"):
        for reg in ("ram", "clint", "fault"):
            b["mem"].append(f"{kind} region {reg}")
    for d in (1, 2):
        b["mem"].append(f"store -> load same word d{d}")
    for op in ("div", "divu", "rem", "remu"):
        b["md"].append(f"{op} by zero")
    for op in ("div", "rem"):
        b["md"].append(f"{op} overflow (-2^31 / -1)")
    for op in ("mul", "mulh", "mulhsu", "mulhu", "div", "rem"):
        for s in ("++", "+-", "-+", "--"):
            b["md"].append(f"{op} signs {s}")
    return b


# ---- Spike log -> event stream -----------------------------------------------------
SPIKE_DIS = re.compile(r"^core\s+\d+: 0x([0-9a-f]+) \(0x([0-9a-f]+)\)")
SPIKE_COMMIT = re.compile(r"^core\s+\d+: \d 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)$")
SPIKE_EXC = re.compile(r"^core\s+\d+: exception (\S+?)(?: #(\d+))?, epc 0x([0-9a-f]+)")
SPIKE_TVAL = re.compile(r"^core\s+\d+:\s+tval 0x([0-9a-f]+)")


def read_mem(hexfile: Path) -> list[int]:
    return [int(l, 16) for l in hexfile.read_text().split()]


def fetch(mem: list[int], pc: int) -> int | None:
    i = (pc - BASE) >> 2
    if pc < BASE or i >= len(mem):
        return None
    w = mem[i] | ((mem[i + 1] if i + 1 < len(mem) else 0) << 32)
    raw = (w >> (8 * (pc & 3))) & 0xFFFFFFFF
    return raw & 0xFFFF if raw & 3 != 3 else raw


def events(log: Path):
    """Yields ("I", pc, raw, rd_val | None, mem_addr | None, store) for a retired
    instruction and ("T", cause, epc, tval, raw | None) for a trap entry."""
    last_dis = {}
    pending = None
    with open(log, errors="replace") as f:
        for line in f:
            if pending is not None:
                m = SPIKE_TVAL.match(line)
                yield ("T", pending[0], pending[1], int(m.group(1), 16) if m else None, pending[2])
                pending = None
                if m:
                    continue
            m = SPIKE_COMMIT.match(line)
            if m:
                pc = int(m.group(1), 16)
                if pc < BASE:
                    continue
                tok = m.group(3).split()
                rdv = addr = None
                store = False
                for i, t in enumerate(tok):
                    if re.fullmatch(r"x\d+", t):
                        rdv = int(tok[i + 1], 16)
                    elif t == "mem":
                        addr = int(tok[i + 1], 16)
                        store = i + 2 < len(tok) and tok[i + 2].startswith("0x")
                yield ("I", pc, int(m.group(2), 16), rdv, addr, store)
                continue
            m = SPIKE_DIS.match(line)
            if m:
                last_dis = (int(m.group(1), 16), int(m.group(2), 16))
                continue
            m = SPIKE_EXC.match(line)
            if m:
                epc = int(m.group(3), 16)
                if epc < BASE:
                    continue
                if m.group(1) == "interrupt":
                    cause = IRQ_NAMES.get(int(m.group(2)), f"irq{m.group(2)}")
                    raw = None
                else:
                    cause = EXC_NAMES.get(m.group(1), m.group(1))
                    raw = last_dis[1] if last_dis and last_dis[0] == epc else None
                pending = (cause, epc, raw)
    if pending is not None:
        yield ("T", pending[0], pending[1], None, pending[2])


def region(a: int) -> str:
    if BASE <= a < BASE + RAM_BYTES:
        return "ram"
    if a >> 16 == CLINT >> 16:
        return "clint"
    return "fault"


def ports(ins: Insn) -> list[tuple[str, int]]:
    """Consumer operand ports (name, register) of an instruction."""
    c = ins.cls
    out = []
    if ins.rs1:
        out.append((f"{c}.rs1", ins.rs1))
    if ins.rs2:
        out.append((f"{c}.rs2", ins.rs2))
    return [(p, r) for p, r in out if p in PORTS]


def producer(ins: Insn) -> str | None:
    if not ins.rd:
        return None
    if ins.cls in ("jal", "jalr"):
        return "link"
    return ins.cls if ins.cls in ("alu", "load", "mul", "div", "csr") else None


def xfer_kind(ins: Insn) -> str | None:
    if ins.cls in ("branch", "jal", "jalr"):
        return ins.cls
    if ins.name == "mret":
        return "mret"
    return None


def tohost_addr(elf: Path) -> int | None:
    """The tohost symbol's address (None: unknown)."""
    nm = shutil.which("riscv64-unknown-elf-nm")
    if nm is None or not elf.exists():
        return None
    r = subprocess.run([nm, str(elf)], capture_output=True, text=True)
    m = re.search(r"^([0-9a-f]+) \w tohost$", r.stdout, re.M)
    return int(m.group(1), 16) if m else None


def collect(log: Path, mem: list[int], hits: Counter, tohost: int | None = None) -> int:
    """Count functional bins of one program up to and including the first
    store to tohost (Spike keeps looping on it); returns retired
    instructions."""
    regs = [0] * 32
    hist: list[Insn] = []           # straight-line history (no trap / taken transfer)
    prev: tuple[int, Insn] | None = None    # last retired (pc, insn)
    recent: list[str] = []          # classes of the last retired instructions (any flow)
    last_xfer_taken: str | None = None  # the previous retired instruction was this taken transfer
    pending_redirect: str | None = None  # next instruction is a transfer target (kind)
    stores: list[int | None] = []   # word addresses of the last 2 retired (store or None)
    last_csr_write: str | None = None
    n = 0
    cache: dict[int, Insn] = {}

    def dec(raw):
        ins = cache.get(raw)
        if ins is None:
            ins = cache[raw] = Insn(raw)
        return ins

    def resolve(pc: int, next_ins: Insn | None) -> None:
        """The previous retired instruction is followed by pc (next_ins there,
        None: a trap entry): its branch direction, taken-transfer bins."""
        nonlocal last_xfer_taken
        if prev is None:
            return
        ppc, pins = prev
        k = xfer_kind(pins)
        taken = pc != ppc + pins.len
        if pins.cls == "branch":
            nm = pins.cname or pins.name
            hits[f"branch/{nm} {'taken' if taken else 'not_taken'} "
                 f"{'bwd' if pins.imm < 0 else 'fwd'}"] += 1
        if k and taken:
            if last_xfer_taken:
                hits[f"jump/back-to-back taken {last_xfer_taken} -> {k}"] += 1
            last_xfer_taken = k
            if next_ins is not None and not next_ins.c and pc & 2:
                hits[f"jump/to 32-bit at pc[1]=1 after {k}"] += 1
            hist.clear()
        else:
            last_xfer_taken = None

    for ev in events(log):
        if ev[0] == "T":
            _, cause, epc, tval, raw = ev
            resolve(epc, None)
            prev = None
            hits[f"trap/cause/{cause}"] += 1
            kind = "irq" if cause.startswith("irq") else "exc"
            for d in (1, 2):
                if len(recent) >= d and recent[-d] in ("load", "store", "mul", "div"):
                    hits[f"trap/{kind} with older {recent[-d]} d{d}"] += 1
            if kind == "irq":
                r = fetch(mem, epc)
                if r is not None:
                    hits[f"trap/irq preempts {dec(r).cls}"] += 1
            elif raw is not None:
                ins = dec(raw)
                hits[f"insn/{ins.mnem}"] += 1
                if ins.cls in ("load", "store") and tval is not None:
                    off = tval & 3
                    if "misaligned" in cause:
                        hits[f"mem/{ins.name} offset {off} (misaligned trap)"] += 1
                    else:
                        hits[f"mem/{ins.name} offset {off}"] += 1
                    if "access_fault" in cause:
                        hits[f"mem/{ins.cls} region {region(tval)}"] += 1
                if cause.startswith("exc2"):
                    if ins.c and ins.cname == "c.illegal":
                        k = "c.illegal (incl. 0x0000)"
                    elif ins.cls == "csr":
                        a = ins.x >> 20
                        k = "csr unimplemented" if csr_name(a) is None else "csr write read-only"
                        if csr_name(a) is not None:
                            hits[f"csr/{csr_name(a)} write (illegal)"] += 1
                    elif ins.name == "illegal.system":
                        k = "system funct12 (sret, dret, ...)"
                    else:
                        k = "unknown 32-bit encoding"
                    hits[f"trap/illegal: {k}"] += 1
            hist.clear()
            pending_redirect = "trap"
            last_xfer_taken = None
            continue

        _, pc, raw, rdv, addr, is_store = ev
        ins = dec(raw)
        n += 1
        hits[f"insn/{ins.mnem}"] += 1
        resolve(pc, ins)
        if ins.c and ins.cname in ("c.jr", "c.jalr") and ins.rs1 in (1, 5) and ins.rd == 0:
            hits["jump/c.ret"] += 1
        # transfer target
        if pending_redirect and not ins.c and pc & 2:
            hits[f"jump/to 32-bit at pc[1]=1 after {pending_redirect}"] += 1
        if not ins.c and pc & 2 and ins.cls in CLASSES:
            hits[f"pc2/{ins.cls} 32-bit at pc[1]=1"] += 1
        # forwarding (straight-line history, nearest writer)
        for port, r in ports(ins):
            for d in (1, 2, 3):
                if len(hist) < d:
                    break
                p = hist[-d]
                if p.rd == r:
                    pk = producer(p)
                    if pk:
                        hits[f"fwd/{port} <- {pk} d{d}"] += 1
                        if pk == "load" and d == 1:
                            hits[f"load_use/{p.name} -> {port}"] += 1
                    break
        # operands for M
        a, b = regs[ins.rs1] if ins.rs1 else 0, regs[ins.rs2] if ins.rs2 else 0
        if ins.cls in ("mul", "div"):
            sa, sb = "-" if s32(a) < 0 else "+", "-" if s32(b) < 0 else "+"
            if ins.name in ("mul", "mulh", "mulhsu", "mulhu", "div", "rem"):
                hits[f"md/{ins.name} signs {sa}{sb}"] += 1
            if ins.cls == "div" and b == 0:
                hits[f"md/{ins.name} by zero"] += 1
            if ins.name in ("div", "rem") and a == 0x80000000 and b == 0xFFFFFFFF:
                hits[f"md/{ins.name} overflow (-2^31 / -1)"] += 1
        # memory
        if ins.cls in ("load", "store") and addr is not None:
            hits[f"mem/{ins.name} offset {addr & 3}"] += 1
            hits[f"mem/{ins.cls} region {region(addr)}"] += 1
            if ins.cls == "load":
                for d in (1, 2):
                    if len(stores) >= d and stores[-d] == addr >> 2:
                        hits[f"mem/store -> load same word d{d}"] += 1
        stores = (stores + [addr >> 2 if ins.cls == "store" and addr is not None else None])[-2:]
        # CSR
        if ins.cls == "csr":
            a12 = ins.x >> 20
            nm = csr_name(a12)
            f3 = (ins.x >> 12) & 7
            src = (ins.x >> 15) & 31
            writes = f3 in (1, 5) or src != 0
            reads = not (f3 in (1, 5) and ins.rd == 0)
            if nm:
                if reads:
                    hits[f"csr/{nm} read"] += 1
                    if last_csr_write == nm:
                        hits["csr/write then read same csr d1"] += 1
                if writes and not csr_ro(nm):
                    hits[f"csr/{nm} write"] += 1
            if writes:
                hits[f"csr/{ins.name} writes"] += 1
            elif f3 not in (1, 5):
                hits[f"csr/{ins.name} no write"] += 1
            if f3 in (1, 5) and ins.rd == 0:
                hits[f"csr/{ins.name} no read (rd=x0)"] += 1
            last_csr_write = nm if writes else None
        else:
            last_csr_write = None
        # control flow: taken = the next retired pc is not pc + len (decided below)
        if ins.cls == "jal":
            hits[f"jump/{ins.cname or 'jal'}"] += 1
        elif ins.cls == "jalr":
            if not ins.c:
                hits["jump/" + ("ret" if ins.rs1 in (1, 5) and ins.rd == 0 else "jalr")] += 1
            else:
                hits[f"jump/{ins.cname}"] += 1
        hist.append(ins)
        del hist[:-3]
        recent = (recent + [ins.cls])[-2:]
        prev = (pc, ins)
        pending_redirect = None
        if ins.rd and rdv is not None:
            regs[ins.rd] = rdv
        if is_store and addr == tohost:
            break
    # a branch at the very end: direction unknown (ignored)
    return n


def find_runs(dirs: list[Path]) -> list[Path]:
    """Test output directories (with a spike.log or coverage.dat) below dirs."""
    found = set()
    for d in dirs:
        for f in list(d.rglob("spike.log")) + list(d.rglob("coverage.dat")):
            found.add(f.parent)
    return sorted(found)


def functional(runs: list[Path], nholes: int | None) -> tuple[str, dict]:
    space = bin_space()
    hits: Counter = Counter()
    seen = set()
    used = skipped = dup = retired = 0
    for d in runs:
        log, hexf, simlog = d / "spike.log", d / "test.hex", d / "sim.log"
        if not (log.exists() and hexf.exists()):
            continue
        if not simlog.exists() or not re.search(r"^TB: PASS", simlog.read_text(errors="replace"), re.M):
            skipped += 1
            continue
        h = hashlib.sha1(hexf.read_bytes()).hexdigest()
        if h in seen:
            dup += 1
            continue
        seen.add(h)
        used += 1
        retired += collect(log, read_mem(hexf), hits, tohost_addr(d / "test.elf"))

    out = [f"Functional coverage ({used} distinct programs, {retired} retired instructions; "
           f"{dup} repeated programs and {skipped} non-passing tests not counted)"]
    out.append(f"  {'category':10s} {'bins':>6s} {'hit':>6s} {'holes':>6s} {'unreach':>8s} {'cov':>7s}")
    summ = {"categories": {}, "holes": {}, "unreachable": UNREACHABLE, "hits": {}}
    hole_lines = []
    tot = Counter()
    for cat, bins in space.items():
        keys = [f"{cat}/{b}" for b in bins]
        unr = [k for k in keys if k in UNREACHABLE]
        live = [k for k in keys if k not in UNREACHABLE]
        hit = [k for k in live if hits[k]]
        holes = [k for k in live if not hits[k]]
        unexpected = [k for k in unr if hits[k]]
        out.append(f"  {cat:10s} {len(keys):6d} {len(hit):6d} {len(holes):6d} {len(unr):8d} "
                   f"{pct(len(hit), len(live)):>7s}")
        tot.update(bins=len(keys), hit=len(hit), holes=len(holes), unr=len(unr))
        summ["categories"][cat] = dict(bins=len(keys), hit=len(hit), holes=len(holes),
                                       unreachable=len(unr))
        summ["holes"][cat] = [k.split("/", 1)[1] for k in holes]
        summ["hits"][cat] = {k.split("/", 1)[1]: hits[k] for k in keys}
        lim = len(holes) if nholes is None else nholes
        hole_lines.append(f"  {cat} ({len(holes)} holes)")
        for k in holes[:lim]:
            hole_lines.append(f"    {k.split('/', 1)[1]}")
        if len(holes) > lim:
            hole_lines.append(f"    ... {len(holes) - lim} more (--holes all)")
        for k in unexpected:
            hole_lines.append(f"    NOTE: unreachable bin hit: {k} ({hits[k]})")
    out.append(f"  {'total':10s} {tot['bins']:6d} {tot['hit']:6d} {tot['holes']:6d} "
               f"{tot['unr']:8d} {pct(tot['hit'], tot['bins'] - tot['unr']):>7s}")
    out.append("")
    out.append("Functional holes (bins never hit)")
    out += hole_lines
    out.append("")
    out.append("Unreachable by design (not counted)")
    for k, why in UNREACHABLE.items():
        out.append(f"  {k}: {why}")
    extra = sorted(k for k in hits if k.split("/", 1)[0] in space
                   and k.split("/", 1)[1] not in space[k.split("/", 1)[0]])
    if extra:
        out.append("")
        out.append("Hit outside the bin space (check the model): " + ", ".join(extra))
    return "\n".join(out), summ


# =============================================================================
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("dirs", nargs="*", type=Path,
                    help="run directories to merge (default: sim/out/cov)")
    ap.add_argument("--out", type=Path, default=REPORT, help="report directory (sim/out/coverage)")
    ap.add_argument("--holes", default="40", help="holes listed per table: a number or 'all'")
    ap.add_argument("--no-code", action="store_true", help="skip code coverage")
    ap.add_argument("--no-func", action="store_true", help="skip functional coverage")
    ap.add_argument("--rank", action="store_true",
                    help="verilator_coverage --rank: tests in order of coverage contribution")
    args = ap.parse_args()
    nholes = None if args.holes == "all" else int(args.holes)
    dirs = [d.resolve() for d in (args.dirs or [OUT_COV])]
    for d in dirs:
        if not d.is_dir():
            sys.exit(f"coverage.py: no directory {d} (run sim/run.py --coverage first)")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    runs = find_runs(dirs)
    summary = {"dirs": [str(d) for d in dirs], "tests": len(runs)}
    report = []

    if not args.no_code:
        dats = [r / "coverage.dat" for r in runs if (r / "coverage.dat").exists()]
        if not dats:
            sys.exit("coverage.py: no coverage.dat found (sim/run.py --coverage)")
        oldest = min(d.stat().st_mtime for d in dats)
        changed = sorted(rel_src(str(f)) for f in filelist.files()
                         if f.stat().st_mtime > oldest)
        if changed:
            print("WARNING: sources changed after the oldest coverage.dat (line numbers, "
                  "annotation and region text may be off; rerun the coverage runs): "
                  + ", ".join(changed), flush=True)
        merged = out / "merged.dat"
        print(f"merge: {len(dats)} coverage.dat -> {show(merged)}", flush=True)
        merge(dats, merged)
        ann = out / "annotated"
        if ann.exists():
            shutil.rmtree(ann)
        subprocess.run([tool("verilator_coverage"), "--annotate", str(ann), "--annotate-min", "1",
                        str(merged)], check=True, stdout=subprocess.DEVNULL)
        text, csum = code_report(parse_dat(merged), nholes)
        text = f"{len(dats)} coverage.dat merged; annotated sources: {show(ann)}/\n\n" + text
        (out / "code.txt").write_text(text + "\n")
        report.append(text)
        summary["code"] = csum
        if args.rank:
            r = subprocess.run([tool("verilator_coverage"), "--rank", *map(str, dats)],
                               check=True, capture_output=True, text=True)
            (out / "rank.txt").write_text(r.stdout)
            report.append("Test rank (verilator_coverage --rank): see "
                          f"{show(out / 'rank.txt')}")

    if not args.no_func:
        text, fsum = functional(runs, nholes)
        (out / "functional.txt").write_text(text + "\n")
        report.append(text)
        summary["functional"] = fsum

    (out / "summary.json").write_text(json.dumps(summary, indent=1) + "\n")
    print("\n\n".join(report))
    print(f"\nreport: {show(out)}/ "
          "(code.txt, functional.txt, summary.json, annotated/)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
