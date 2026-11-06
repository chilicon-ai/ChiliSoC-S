/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: exceptions inside instruction sequences.
# The handler (mtvec_handler, entered from the env trap vector) counts traps
# in x29 and resumes after the trapping instruction (mepc + 2 or + 4).
# Checked: the trapping instruction has no
# effect (no rd write, no store), younger instructions do not execute before
# the trap, older instructions (a load or store just before) complete, and
# mepc / mcause / mtval are right (Spike compares every CSR read).
# Illegal SYSTEM encodings (sret, dret, uret, sfence.vma, other funct12
# values, mret / ecall / ebreak / wfi with nonzero rd / rs1, funct3 = 100)
# trap as illegal instructions with mtval = the instruction bits.

#include "riscv_test.h"
#include "test_macros.h"

#define ILL_SYS(n, bits) \
  li TESTNUM, n; li x28, 0; li x27, 0; .word bits; \
  li x7, CAUSE_ILLEGAL_INSTRUCTION; bne x28, x7, fail; \
  li x7, bits; bne x27, x7, fail

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la x8, buf
  li x29, 0
  li x1, 0x11223344
  sw x1, 0(x8)

  # ---- illegal instruction: younger instructions wait --------------------
  li TESTNUM, 2
  li x4, 0
  .word 0xc0001073                 # unimp (32-bit): illegal
  addi x4, x4, 1                   # runs once, after the handler
  li x7, 1
  bne x4, x7, fail
  li x7, 1
  bne x29, x7, fail

  # ---- older load / store complete, the illegal one does not -------------
  li TESTNUM, 3
  lw x5, 0(x8)
  .word 0xc0001073
  bne x5, x1, fail
  li x2, 0x77
  sw x2, 4(x8)
  .word 0xc0001073
  lw x4, 4(x8)
  bne x4, x2, fail

  # ---- misaligned load: rd unchanged; misaligned store: memory unchanged --
  li TESTNUM, 4
  li x2, 0x99
  lw x2, 1(x8)
  li x7, 0x99
  bne x2, x7, fail
  sw x7, 2(x8)
  lw x4, 0(x8)
  bne x4, x1, fail
  lh x2, 3(x8)
  addi x4, x2, 0                   # uses the unchanged x2 at once
  bne x4, x7, fail

  # ---- illegal CSR access: rd unchanged ---------------------------------
  li TESTNUM, 5
  li x2, 0x42
  csrr x2, 0x7ff
  li x7, 0x42
  bne x2, x7, fail
  csrw mhartid, x1                 # read-only CSR (mhartid: mvendorid's value
  csrr x4, mhartid                 # is not compared, a branch on it would end
  bne x4, x0, fail                 # the trace comparison)

  # (instruction-address-misaligned cannot occur with C: IALIGN = 16, and
  #  JALR clears bit 0; sim/tests/rvc.S covers halfword targets)

  # ---- ebreak, then a dependent sequence ---------------------------------
  li TESTNUM, 7
  li x4, 1
  ebreak
  add x4, x4, x4
  li x7, 2
  bne x4, x7, fail

  # ---- back-to-back traps --------------------------------------------------
  li TESTNUM, 8
  .word 0xc0001073
  .word 0xc0001073
  ebreak
  li x7, 12                        # traps so far
  bne x29, x7, fail

  # ---- illegal SYSTEM encodings: mtval = the instruction bits ---------------
  # (no S / U / debug mode, no H, Smrnmi, Zawrs; SYSTEM instructions with a
  # nonzero rd / rs1 field are reserved)
  ILL_SYS( 9, 0x10200073)          # sret
  ILL_SYS(10, 0x7b200073)          # dret
  ILL_SYS(11, 0x00200073)          # uret (N extension, removed)
  ILL_SYS(12, 0x12000073)          # sfence.vma x0, x0
  ILL_SYS(13, 0x22000073)          # hfence.vvma
  ILL_SYS(14, 0x70200073)          # mnret (Smrnmi)
  ILL_SYS(15, 0x00d00073)          # wrs.nto (Zawrs)
  ILL_SYS(16, 0x00300073)          # unknown funct12
  ILL_SYS(17, 0x30300073)          # funct12 = mret + 1
  ILL_SYS(18, 0x10600073)          # funct12 = wfi + 1
  ILL_SYS(19, 0xfff00073)          # funct12 all ones
  ILL_SYS(20, 0x302000f3)          # mret, rd = x1
  ILL_SYS(21, 0x30208073)          # mret, rs1 = x1
  ILL_SYS(22, 0x000000f3)          # ecall, rd = x1
  ILL_SYS(23, 0x00008073)          # ecall, rs1 = x1
  ILL_SYS(24, 0x001000f3)          # ebreak, rd = x1
  ILL_SYS(25, 0x10508073)          # wfi, rs1 = x1
  ILL_SYS(26, 0x60004073)          # funct3 = 100: hlv.b (H)
  ILL_SYS(27, 0x00004073)          # funct3 = 100, all else 0
  li TESTNUM, 28
  li x7, 12 + 19
  bne x29, x7, fail

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mtval
  csrr t5, mepc
  lhu t6, 0(t5)                    # skip the trapping instruction: 2 or 4 bytes (C)
  andi t6, t6, 3
  addi t5, t5, 2
  xori t6, t6, 3
  bnez t6, 1f
  addi t5, t5, 2
1:
  csrw mepc, t5
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 16, 4, 0
RVTEST_DATA_END
