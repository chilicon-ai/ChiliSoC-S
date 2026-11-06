# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""RV32C expander: the same expansion as source/ChillUS/rvc/chillus_rvc.sv.

expand(insn) returns the 32-bit base-ISA equivalent of a 16-bit RV32C
instruction (insn[1:0] != 0b11), or None for an illegal / reserved encoding
(no F / D, no Zcb, RV32 shamt[5] = 1). HINTs expand to their base form,
C.MV to add rd, x0, rs2. A 32-bit instruction is returned unchanged.
"""

from __future__ import annotations


def _bits(x: int, hi: int, lo: int) -> int:
    return (x >> lo) & ((1 << (hi - lo + 1)) - 1)


def _sext(x: int, width: int) -> int:
    return x - (1 << width) if x >> (width - 1) else x


# 32-bit format packers (imm as a signed or unsigned Python int)
def _r(f7, rs2, rs1, f3, rd, op): return f7 << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | rd << 7 | op
def _i(imm, rs1, f3, rd, op): return (imm & 0xFFF) << 20 | rs1 << 15 | f3 << 12 | rd << 7 | op
def _s(imm, rs2, rs1, f3): return _bits(imm, 11, 5) << 25 | rs2 << 20 | rs1 << 15 | f3 << 12 | _bits(imm, 4, 0) << 7 | 0x23
def _u(imm, rd): return (imm & 0xFFFFF) << 12 | rd << 7 | 0x37


def _b(imm, rs1, f3):
    return (_bits(imm, 12, 12) << 31 | _bits(imm, 10, 5) << 25 | rs1 << 15 | f3 << 12
            | _bits(imm, 4, 1) << 8 | _bits(imm, 11, 11) << 7 | 0x63)


def _j(imm, rd):
    return (_bits(imm, 20, 20) << 31 | _bits(imm, 10, 1) << 21 | _bits(imm, 11, 11) << 20
            | _bits(imm, 19, 12) << 12 | rd << 7 | 0x6F)


LOAD, OP_IMM, OP, JALR, EBREAK = 0x03, 0x13, 0x33, 0x67, 0x00100073


def expand(insn: int) -> int | None:
    if insn & 3 == 3:
        return insn
    c = insn & 0xFFFF
    b = lambda hi, lo=None: _bits(c, hi, hi if lo is None else lo)  # noqa: E731
    quadrant, funct3, bit12 = b(1, 0), b(15, 13), b(12)
    rd_rs1, rs2 = b(11, 7), b(6, 2)                  # full registers
    rd_rs1_p, rs2_p = 8 + b(9, 7), 8 + b(4, 2)       # x8..x15
    shamt = bit12 << 5 | b(6, 2)
    imm_ci = _sext(shamt, 6)                         # C.ADDI / C.LI / C.ANDI / C.LUI
    imm_addi4spn = b(10, 7) << 6 | b(12, 11) << 4 | b(5) << 3 | b(6) << 2
    imm_lw = b(5) << 6 | b(12, 10) << 3 | b(6) << 2
    imm_addi16sp = _sext(bit12 << 9 | b(4, 3) << 7 | b(5) << 6 | b(2) << 5 | b(6) << 4, 10)
    imm_j = _sext(bit12 << 11 | b(8) << 10 | b(10, 9) << 8 | b(6) << 7 | b(7) << 6
                  | b(2) << 5 | b(11) << 4 | b(5, 3) << 1, 12)
    imm_b = _sext(bit12 << 8 | b(6, 5) << 6 | b(2) << 5 | b(11, 10) << 3 | b(4, 3) << 1, 9)
    imm_lwsp = b(3, 2) << 6 | bit12 << 5 | b(6, 4) << 2
    imm_swsp = b(8, 7) << 6 | b(12, 9) << 2

    if quadrant == 0:
        if funct3 == 0b000:                          # C.ADDI4SPN
            return _i(imm_addi4spn, 2, 0, rs2_p, OP_IMM) if imm_addi4spn else None
        if funct3 == 0b010:                          # C.LW
            return _i(imm_lw, rd_rs1_p, 2, rs2_p, LOAD)
        if funct3 == 0b110:                          # C.SW
            return _s(imm_lw, rs2_p, rd_rs1_p, 2)
        return None                                  # F / D, reserved
    if quadrant == 1:
        if funct3 == 0b000:                          # C.ADDI / C.NOP
            return _i(imm_ci, rd_rs1, 0, rd_rs1, OP_IMM)
        if funct3 == 0b001:                          # C.JAL
            return _j(imm_j, 1)
        if funct3 == 0b010:                          # C.LI
            return _i(imm_ci, 0, 0, rd_rs1, OP_IMM)
        if funct3 == 0b011:
            if rd_rs1 == 2:                          # C.ADDI16SP
                return _i(imm_addi16sp, 2, 0, 2, OP_IMM) if imm_addi16sp else None
            return _u(imm_ci, rd_rs1) if imm_ci else None  # C.LUI
        if funct3 == 0b100:
            funct2 = b(11, 10)
            if funct2 in (0b00, 0b01):               # C.SRLI / C.SRAI
                f7 = 0x20 if funct2 else 0
                return None if bit12 else _i(f7 << 5 | shamt, rd_rs1_p, 5, rd_rs1_p, OP_IMM)
            if funct2 == 0b10:                       # C.ANDI
                return _i(imm_ci, rd_rs1_p, 7, rd_rs1_p, OP_IMM)
            if bit12:                                # RV64 / reserved / Zcb
                return None
            f7, f3 = ((0x20, 0), (0, 4), (0, 6), (0, 7))[b(6, 5)]  # SUB XOR OR AND
            return _r(f7, rs2_p, rd_rs1_p, f3, rd_rs1_p, OP)
        if funct3 == 0b101:                          # C.J
            return _j(imm_j, 0)
        return _b(imm_b, rd_rs1_p, funct3 & 1)       # C.BEQZ / C.BNEZ
    # quadrant 2
    if funct3 == 0b000:                              # C.SLLI
        return None if bit12 else _i(shamt, rd_rs1, 1, rd_rs1, OP_IMM)
    if funct3 == 0b010:                              # C.LWSP
        return _i(imm_lwsp, 2, 2, rd_rs1, LOAD) if rd_rs1 else None
    if funct3 == 0b100:
        if not bit12:
            if rs2 == 0:                             # C.JR
                return _i(0, rd_rs1, 0, 0, JALR) if rd_rs1 else None
            return _r(0, rs2, 0, 0, rd_rs1, OP)      # C.MV
        if rs2 == 0:                                 # C.EBREAK / C.JALR
            return _i(0, rd_rs1, 0, 1, JALR) if rd_rs1 else EBREAK
        return _r(0, rs2, rd_rs1, 0, rd_rs1, OP)     # C.ADD
    if funct3 == 0b110:                              # C.SWSP
        return _s(imm_swsp, rs2, 2, 2)
    return None                                      # F / D
