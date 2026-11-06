#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""Random instruction-sequence generator for ChillU-S (riscv-tests p env).

  python sim/gen_random.py --seed 7 --length 400 -o test.S

The sequence is not self-checking: sim/run.py compares every retired
instruction with Spike. Registers come from a small pool so neighbouring
instructions depend on each other (forwarding, load-use; sources are often
one of the last three destinations). Mix: ALU reg / imm, M multiply / divide
(with corner operands 0, +-1, min / max int), LUI / AUIPC, loads / stores
into a 256-byte buffer (x8 = base), forward branches / JAL / JALR that skip
0-3 instructions (also as c.j / c.jal / c.jr / c.jalr / c.ret), mscratch CSR
operations, FENCE / FENCE.I, and (with --traps) illegal instructions
(read-only CSR write, unknown opcode, sret, c.illegal), EBREAK / C.EBREAK
and misaligned accesses, resumed after the trapping instruction (mepc + 2 or
+ 4) by mtvec_handler, which reaches its mret by a taken branch (C) or, per
seed, fall-through / jal / jalr (32-bit).

Snippets for the forwarding paths into addresses and other rare pairs (each
emitted as one unit, so no forward branch lands inside it; the producer is
1-3 instructions before its consumer, with only non-transfer, non-trapping
fillers that write pool registers in between):
  - memory base from mul / divu by one (x11 = 1), a csrw + csrr mscratch
    round trip, addi, a load of the buffer address (word after the buffer),
    or a jal link (not-taken `jal x12, 1f; 1:`) into a data island in the
    code (.option norvc, so the offsets are known);
  - jalr target from la (+ mul / divu / csr round trip), a load from the
    jump table after the buffer, or a jal link (jalr off(link));
  - taken jalr right after a taken branch / jal / jalr / trap return;
  - bounded loops (x13 = counter, 1-3 iterations, x14 = flag) closed by a
    backward branch (incl. c.bnez / c.beqz); pending forward labels are
    placed before a loop starts and the counter is decremented at its top,
    so no branch skips the decrement and every loop terminates;
  - mul / div / branch / csr operands from a jal link, csr rs1 from a div
    result.
Reserved: x3 (TESTNUM), x8 (buffer), x11 (= 1), x12 (derived base / target),
x13 / x14 (loop), x15 (la temp), x27-x31 (trap handler / env).
"""

import argparse
import random

# x3 = gp (TESTNUM), x8 = buffer base, x27-x31 used by the trap handler / env
POOL = ["x1", "x2", "x4", "x5", "x6", "x7", "x9", "x10"]
ONE = "x11"         # always 1 (mul / divu by one keep a value)
XB = "x12"          # derived memory base / jalr target / link
CNT = "x13"         # loop counter (c.bnez-able)
FLAG = "x14"        # loop flag: seqz CNT (c.beqz-able)
XT = "x15"          # la temp
BUF_BYTES = 256
BUFPTR = BUF_BYTES          # buf + BUFPTR holds the address of buf
JTAB = BUF_BYTES + 4        # jump table (absolute code addresses) after it
JTAB_MAX = 256              # entries (offsets stay within the 12-bit immediate)

ALU_R = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
MULDIV = ["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"]
CORNERS = [0, 1, -1, -2, 0x7FFFFFFF, -0x80000000]
ALU_I = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SHIFT_I = ["slli", "srli", "srai"]
LOADS = {"lb": 1, "lbu": 1, "lh": 2, "lhu": 2, "lw": 4}
STORES = {"sb": 1, "sh": 2, "sw": 4}
BRANCHES = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
CSR_OPS = ["csrrw", "csrrs", "csrrc"]
CSR_IOPS = ["csrrwi", "csrrsi", "csrrci"]
# always taken with ONE = 1 or XT = a RAM (code) address (bit 31 set)
TAKEN = [f"beq {ONE}, {ONE}", f"bne {ONE}, x0", f"blt x0, {ONE}", f"bge {ONE}, x0",
         f"bltu x0, {ONE}", f"bgeu {ONE}, x0", f"bnez {ONE}", f"beq {XT}, {XT}",
         f"bne {XT}, x0", f"blt {XT}, x0", f"bge {XT}, {XT}", f"bltu x0, {XT}",
         f"bgeu {XT}, {ONE}"]


class Gen:
    def __init__(self, rng: random.Random, traps: bool):
        self.rng = rng
        self.traps = traps
        self.lines: list[str] = []
        self.pending: list[list] = []   # [label, instructions left before it]
        self.nlabel = 0
        self.items = 0                  # random items emitted (--length)
        self.in_loop = False
        self.jtab: list[str] = []       # jump-table labels (.word after buf)
        self.recent: list[str] = []     # last pool registers written (src bias)
        self.wr: str | None = None      # rd of the instruction being emitted

    def reg(self, allow_x0: bool = False, avoid: tuple = ()) -> str:
        if allow_x0 and self.rng.random() < 0.05:
            return "x0"
        return self.rng.choice([x for x in POOL if x not in avoid])

    def dst(self, allow_x0: bool = True) -> str:
        """Destination of the next emitted instruction (remembered by emit)."""
        self.wr = self.reg(allow_x0)
        return self.wr

    def src(self) -> str:
        """Source operand: often one of the last 3 destinations, so producer /
        consumer pairs at distance 1-3 are frequent."""
        if self.recent and self.rng.random() < 0.3:
            return self.rng.choice(self.recent[-3:])
        return self.reg(True)

    def emit(self, text: str, count: int = 1) -> None:
        """Emit one instruction or snippet (count = machine instructions it
        expands to) and place any forward labels that are now due (after
        it: a snippet is never entered in the middle)."""
        self.lines.append(f"  {text}")
        if self.wr not in (None, "x0"):
            self.recent = (self.recent + [self.wr])[-3:]
        self.wr = None
        for p in self.pending:
            p[1] -= count
        due = [p for p in self.pending if p[1] <= 0]
        self.pending = [p for p in self.pending if p[1] > 0]
        for label, _ in due:
            self.lines.append(f"{label}:")

    def unit(self, insns: list[str], count: int | None = None) -> None:
        """Emit lines as one unit (count: machine instructions, default:
        lines that are neither labels nor directives)."""
        if count is None:
            count = sum(1 for s in insns if not s.endswith(":") and not s.startswith("."))
        self.emit("\n  ".join(insns), count)

    def flush(self) -> None:
        """Place every pending forward label here (earlier than planned)."""
        for label, _ in self.pending:
            self.lines.append(f"{label}:")
        self.pending = []

    def label(self, skip: int) -> str:
        self.nlabel += 1
        name = f"L{self.nlabel}"
        self.pending.append([name, skip])
        return name

    def new_name(self) -> str:
        self.nlabel += 1
        return f"L{self.nlabel}"

    # ---- building blocks ---------------------------------------------------
    def filler(self, avoid: tuple = ()) -> str:
        """One 4-byte (in .option norvc) instruction that writes a pool
        register not in avoid: no transfer, no trap, no reserved register."""
        r = self.rng
        rd = self.reg(avoid=avoid)
        k = r.choice(["alu_r", "alu_i", "shift", "lui", "muldiv", "load", "store"])
        if k == "alu_r":
            return f"{r.choice(ALU_R)} {rd}, {self.reg(True)}, {self.reg(True)}"
        if k == "alu_i":
            return f"{r.choice(ALU_I)} {rd}, {self.reg(True)}, {r.randint(-2048, 2047)}"
        if k == "shift":
            return f"{r.choice(SHIFT_I)} {rd}, {self.reg(True)}, {r.randint(0, 31)}"
        if k == "lui":
            return f"lui {rd}, {r.randint(0, 0xFFFFF):#x}"
        if k == "muldiv":
            return f"{r.choice(MULDIV)} {rd}, {self.reg(True)}, {self.reg(True)}"
        if k == "load":
            op, n = r.choice(list(LOADS.items()))
            return f"{op} {rd}, {r.randrange(0, BUF_BYTES, n)}(x8)"
        op, n = r.choice(list(STORES.items()))
        return f"{op} {self.reg(True)}, {r.randrange(0, BUF_BYTES, n)}(x8)"

    def fillers(self, n: int, avoid: tuple = ()) -> list[str]:
        return [self.filler(avoid) for _ in range(n)]

    def access(self, base: str, off: int) -> str:
        """A load or store at base + off (base is word aligned; off is
        rounded down to the access size)."""
        r = self.rng
        if r.random() < 0.6:
            op, n = r.choice(list(LOADS.items()))
            return f"{op} {self.reg(True)}, {off - off % n}({base})"
        op, n = r.choice(list(STORES.items()))
        return f"{op} {self.reg(True)}, {off - off % n}({base})"

    def jalr(self, rd: str, base: str) -> str:
        """jalr rd, 0(base), sometimes in a form the assembler compresses
        (c.jr / c.jalr; c.ret needs base x1)."""
        if self.rng.random() < 0.4:
            if rd == "x0":
                return "ret" if base == "x1" else f"jr {base}"
            if base != "x1":
                return f"jalr {base}"           # rd = x1
        return f"jalr {rd}, 0({base})"

    def jalr_target(self) -> tuple[str, int]:
        """A forward label for a jalr (placed 1-3 instructions after the
        unit that is emitted next) and that skip."""
        return self.new_name(), self.rng.randint(1, 3)

    def place_after(self, name: str, unit_count: int, skip: int) -> None:
        self.pending.append([name, unit_count + skip])

    # ---- snippets ----------------------------------------------------------
    def mem_base(self) -> None:
        """Load / store whose base register (XB) is produced 1-3 instructions
        before by mul / div / csr / alu / load / jal link."""
        r = self.rng
        src = r.choice(["mul", "div", "csr", "csr", "alu", "load", "link", "link"])
        f = r.randint(0, 2)
        if src == "link":
            # link = 1b; [f fillers][access][j 2f] then a 16-byte island
            n = r.choice([1, 2, 4])
            off = 4 * (f + 2) + r.randrange(0, 16, n)
            ins = [".balign 4", ".option push", ".option norvc", f"jal {XB}, 1f", "1:",
                   *self.fillers(f, (XB,)), self.access(XB, off), "j 2f",
                   *[f".word {r.getrandbits(32):#010x}" for _ in range(4)],
                   "2:", ".option pop"]
            self.unit(ins, f + 3)
            return
        a = r.randrange(0, BUF_BYTES, 4)          # access address: buf + a (+ 0..3)
        a += r.randrange(0, 4)
        if src == "mul":
            pre = [r.choice([f"mul {XB}, x8, {ONE}", f"mul {XB}, {ONE}, x8"])]
        elif src == "div":
            pre = [f"{r.choice(['div', 'divu'])} {XB}, x8, {ONE}"]
        elif src == "csr":
            pre = ["csrw mscratch, x8", f"csrr {XB}, mscratch"]
            if r.random() < 0.3:            # csr.rs1 <- div d1
                pre = [f"divu {XB}, x8, {ONE}", f"csrw mscratch, {XB}", f"csrr {XB}, mscratch"]
        elif src == "alu":
            k = 4 * r.randint(-128, 128)            # base stays word aligned
            pre = [f"addi {XB}, x8, {k}"]
            a -= k
        else:
            pre = [f"lw {XB}, {BUFPTR}(x8)"]
        self.unit([*pre, *self.fillers(f, (XB,)), self.access(XB, a)])

    def jalr_var(self) -> None:
        """Taken jalr whose target register is produced 1-3 instructions
        before by mul / div / csr / load (jump table) / jal link."""
        r = self.rng
        src = r.choice(["alu", "mul", "div", "csr", "load", "link"])
        f = r.randint(0, 2)
        rd = self.reg(True)
        if src == "link":
            lk = r.choice([XB, XB, "x1", "x5"])      # x1 / x5 + rd x0: "ret"
            if lk != XB and r.random() < 0.5:
                rd = "x0"
            sb = r.choice([2, 4, 6, 8])             # skipped bytes after the jalr
            ins = [".option push", ".option norvc", f"jal {lk}, 1f", "1:",
                   *self.fillers(f, (lk,)), f"jalr {rd}, {4 * (f + 1) + sb}({lk})",
                   *[".half 0x0001"] * (sb // 2), ".option pop"]
            self.unit(ins, f + 2)
            return
        name, skip = self.jalr_target()
        if src == "load" and len(self.jtab) < JTAB_MAX:
            pre = [f"lw {XB}, {JTAB + 4 * len(self.jtab)}(x8)"]
            self.jtab.append(name)
        elif src == "alu":
            pre = [f"la {XB}, {name}"]
        elif src == "mul":
            pre = [f"la {XT}, {name}", r.choice([f"mul {XB}, {XT}, {ONE}", f"mul {XB}, {ONE}, {XT}"])]
        elif src == "div":
            pre = [f"la {XT}, {name}", f"{r.choice(['div', 'divu'])} {XB}, {XT}, {ONE}"]
        else:
            pre = [f"la {XT}, {name}", f"csrw mscratch, {XT}", f"csrr {XB}, mscratch"]
        ins = [*pre, *self.fillers(f, (XB,)), self.jalr(rd, XB)]
        n = len(ins) + sum(1 for s in ins if s.startswith("la "))
        self.unit(ins, n)
        self.place_after(name, 0, skip)

    def back_to_back(self) -> None:
        """A taken branch / jal / jalr / trap return directly followed by a
        taken jalr (back-to-back transfers)."""
        r = self.rng
        kinds = ["branch", "branch", "jal", "jalr"] + (["mret"] if self.traps else [])
        k = r.choice(kinds)
        name, skip = self.jalr_target()
        skipped = r.choice([".half 0x0001", "nop", self.filler()])
        if k == "branch":
            first = [f"{r.choice(TAKEN)}, 1f", skipped, "1:"]
        elif k == "jal":
            first = [f"jal {self.reg(True)}, 1f", skipped, "1:"]
        elif k == "jalr":
            first = [f"la {XB}, 1f", f"jalr {self.reg(True)}, 0({XB})", skipped, "1:"]
        else:
            first = [r.choice(["ebreak", ".word 0xc0001073"])]
        ins = [f"la {XT}, {name}", *first, self.jalr(self.reg(True), XT)]
        self.unit(ins, 6)
        self.place_after(name, 0, skip)

    def loop(self) -> None:
        """Bounded loop: 1-3 iterations of 2-6 random items, closed by a
        backward branch on the counter (decremented at the top)."""
        r = self.rng
        self.flush()
        top = self.new_name()
        self.emit(f"li {CNT}, {r.randint(1, 3)}")
        self.lines.append(f"{top}:")
        self.emit(f"addi {CNT}, {CNT}, -1")
        self.in_loop = True
        for _ in range(r.randint(2, 6)):
            self.one()
        self.in_loop = False
        tail = r.choice([
            [f"bnez {CNT}, {top}"],                                  # c.bnez
            [f"seqz {FLAG}, {CNT}", f"beqz {FLAG}, {top}"],          # c.beqz
            [".option push", ".option norvc", f"bne {CNT}, x0, {top}", ".option pop"],
            [f"seqz {FLAG}, {CNT}", ".option push", ".option norvc",
             f"beq {FLAG}, x0, {top}", ".option pop"],
            [f"blt x0, {CNT}, {top}"], [f"bltu x0, {CNT}, {top}"],
            [f"bge {CNT}, {ONE}, {top}"], [f"bgeu {CNT}, {ONE}, {top}"]])
        self.unit(tail)

    def link_use(self) -> None:
        """mul / div / branch / csr with an operand from a not-taken jal
        link 1-3 instructions before."""
        r = self.rng
        lk = self.reg()
        f = r.randint(0, 2)
        a, b = self.reg(True), lk
        if r.random() < 0.3:
            a, b = b, a
        use = r.choice(["md", "md", "branch", "csr"])
        if use == "md":
            last = f"{r.choice(MULDIV)} {self.reg(True)}, {a}, {b}"
        elif use == "csr":
            last = f"{r.choice(CSR_OPS)} {self.reg(True)}, mscratch, {lk}"
        else:
            last = f"{r.choice(BRANCHES)} {a}, {b}, {self.label(f + 2 + r.randint(0, 3))}"
        self.unit([f"jal {lk}, 1f", "1:", *self.fillers(f, (lk,)), last])

    def div_csr(self) -> None:
        """csr op whose rs1 is a div / rem result 1-3 instructions before."""
        r = self.rng
        rd = self.reg()
        f = r.choice([0, 0, 1, 2])
        ins = [f"{r.choice(MULDIV[4:])} {rd}, {self.reg(True)}, {self.reg(True)}",
               *self.fillers(f, (rd,)),
               f"{r.choice(CSR_OPS)} {self.reg(True)}, mscratch, {rd}"]
        self.unit(ins)

    # ---- one random item ---------------------------------------------------
    def one(self) -> None:
        r = self.rng
        self.items += 1
        k = r.choices(
            ["alu_r", "alu_i", "shift", "lui", "auipc", "load", "store",
             "branch", "jal", "jalr", "csr", "csri", "fence", "trap",
             "muldiv", "corner", "mem_base", "jalr_var", "b2b", "loop",
             "link_use", "div_csr"],
            weights=[20, 14, 6, 3, 2, 12, 8, 8, 3, 2, 4, 2, 1,
                     3 if self.traps else 0, 8, 2, 6, 3, 2,
                     0 if self.in_loop else 2, 1, 1])[0]
        if k == "muldiv":
            op, a, b = r.choice(MULDIV), self.src(), self.src()
            self.emit(f"{op} {self.dst()}, {a}, {b}")
        elif k == "corner":   # operands for the M special cases (x / 0, overflow)
            self.emit(f"li {self.dst(False)}, {r.choice(CORNERS)}", count=2)
        elif k == "alu_r":
            op, a, b = r.choice(ALU_R), self.src(), self.src()
            self.emit(f"{op} {self.dst()}, {a}, {b}")
        elif k == "alu_i":
            op, a = r.choice(ALU_I), self.src()
            self.emit(f"{op} {self.dst()}, {a}, {r.randint(-2048, 2047)}")
        elif k == "shift":
            op, a = r.choice(SHIFT_I), self.src()
            self.emit(f"{op} {self.dst()}, {a}, {r.randint(0, 31)}")
        elif k == "lui":
            self.emit(f"lui {self.dst(False)}, {r.randint(0, 0xFFFFF):#x}")
        elif k == "auipc":
            self.emit(f"auipc {self.dst(False)}, {r.randint(0, 0xFFFFF):#x}")
        elif k == "load":
            op, n = r.choice(list(LOADS.items()))
            self.emit(f"{op} {self.dst()}, {r.randrange(0, BUF_BYTES, n)}(x8)")
        elif k == "store":
            op, n = r.choice(list(STORES.items()))
            self.emit(f"{op} {self.src()}, {r.randrange(0, BUF_BYTES, n)}(x8)")
        elif k == "branch":
            lab = self.label(1 + r.randint(0, 3))   # 1: the branch itself
            if r.random() < 0.15:                   # c.beqz / c.bnez on x9 / x10
                self.emit(f"{r.choice(['beqz', 'bnez'])} {self.src()}, {lab}")
            else:
                self.emit(f"{r.choice(BRANCHES)} {self.src()}, {self.src()}, {lab}")
        elif k == "jal":
            lab = self.label(1 + r.randint(0, 3))   # 1: the branch itself
            rd = self.reg(True)
            if rd in ("x0", "x1") and r.random() < 0.5:     # c.j / c.jal
                self.emit(f"{'j' if rd == 'x0' else 'jal'} {lab}")
            else:
                self.emit(f"jal {rd}, {lab}")
        elif k == "jalr":
            base = self.reg()
            lab = self.label(3 + r.randint(0, 3))   # 3: la (2) + jalr itself
            # one unit: no branch target may land between la and jalr
            if r.random() < 0.1:                    # c.ret
                base, rd = "x1", "x0"
            else:
                rd = self.reg(True)
            self.emit(f"la {base}, {lab}\n  {self.jalr(rd, base)}", count=3)
        elif k == "csr":
            op, a = r.choice(CSR_OPS), self.src()
            self.emit(f"{op} {self.dst()}, mscratch, {a}")
        elif k == "csri":
            self.emit(f"{r.choice(CSR_IOPS)} {self.dst()}, mscratch, {r.randint(0, 31)}")
        elif k == "fence":
            self.emit(r.choice(["fence", "fence.i", "fence rw, rw", "nop"]))
        elif k == "mem_base":
            self.mem_base()
        elif k == "jalr_var":
            self.jalr_var()
        elif k == "b2b":
            self.back_to_back()
        elif k == "loop":
            self.loop()
        elif k == "link_use":
            self.link_use()
        elif k == "div_csr":
            self.div_csr()
        else:   # trap
            t = r.choice(["illegal", "illegal", "ebreak", "ebreak", "mis_load", "mis_store"])
            if t == "illegal":
                self.emit(r.choice([
                    ".word 0xc0001073",     # unimp: csrrw x0, cycle, x0 (read-only CSR)
                    ".word 0x0000000b",     # custom-0 opcode: unknown 32-bit encoding
                    ".word 0x10200073",     # sret: no S-mode
                    ".half 0x0000"]))       # c.illegal
            elif t == "ebreak":
                self.emit(r.choice(["ebreak", ".word 0x00100073"]))    # c.ebreak / 32-bit
            elif t == "mis_load":
                op = r.choice(["lh", "lhu", "lw"])
                self.emit(f"{op} {self.reg(True)}, {r.randrange(1, BUF_BYTES - 4, 2) | 1}(x8)")
            else:
                op = r.choice(["sh", "sw"])
                self.emit(f"{op} {self.reg(True)}, {r.randrange(1, BUF_BYTES - 4, 2) | 1}(x8)")

    def program(self, length: int) -> str:
        r = self.rng
        head = [
            "# GENERATED by sim/gen_random.py",
            '#include "riscv_test.h"',
            '#include "test_macros.h"',
            "",
            "RVTEST_RV32M",
            "RVTEST_CODE_BEGIN",
            "  la x8, buf",
            f"  li {ONE}, 1",
        ]
        head += [f"  li {x}, {r.getrandbits(32):#010x}" for x in POOL]
        while self.items < length:
            self.one()
        while self.pending:
            self.emit("nop")
        ret32 = r.choice([[], ["  jal t6, 1f", "  nop"], ["  la t6, 1f", "  jr t6", "  nop"]])
        tail = [
            "  RVTEST_PASS",
            "",
            "  .align 2",
            "  .global mtvec_handler",
            "mtvec_handler:",
            "  addi x29, x29, 1",
            "  csrr x28, mcause",
            "  csrr x27, mtval",
            "  csrr t5, mepc",
            "  lhu t6, 0(t5)",          # resume after the trapping instruction:
            "  andi t6, t6, 3",         # 2 bytes if compressed (C), else 4
            "  addi t5, t5, 2",
            "  xori t6, t6, 3",
            "  csrw mepc, t5",
            "  bnez t6, 1f",            # C: taken branch -> mret
            "  addi t5, t5, 2",
            "  csrw mepc, t5",
            *ret32,                     # 32-bit: fall through / jal / jalr -> mret
            "1:",
            "  mret",
            "",
            "RVTEST_CODE_END",
            "",
            "  .data",
            "RVTEST_DATA_BEGIN",
            "  TEST_DATA",
            "  .align 4",
            "buf:",
        ]
        tail += [f"  .word {r.getrandbits(32):#010x}" for _ in range(BUF_BYTES // 4)]
        tail += ["  .word buf"]                             # buf + BUFPTR
        tail += [f"  .word {name}" for name in self.jtab]  # buf + JTAB
        tail += ["RVTEST_DATA_END", ""]
        return "\n".join(head + self.lines + tail)


def generate(seed: int, length: int = 400, traps: bool = True) -> str:
    return Gen(random.Random(seed), traps).program(length)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--length", type=int, default=400, help="random items (a loop body's count)")
    ap.add_argument("--no-traps", action="store_true")
    ap.add_argument("-o", "--output", required=True)
    a = ap.parse_args()
    with open(a.output, "w") as f:
        f.write(generate(a.seed, a.length, not a.no_traps))


if __name__ == "__main__":
    main()
