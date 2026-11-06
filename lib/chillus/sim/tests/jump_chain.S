/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: chains of back-to-back taken control transfers,
# each one the target of the previous (no instruction in between): every
# ordered pair of {taken branch, jal, jalr, mret} (mret -> mret is in
# irq_classes.S: it needs an interrupt to leave the second mret), a taken
# branch to a ret, a jal to a ret (call / return), a jalr to a jalr, an mret
# whose mepc points at a jalr, the same chains in compressed form (c.beqz,
# c.bnez, c.j, c.jal, c.jr, c.jalr) with targets at pc[1] = 1, and backward
# taken c.beqz / c.bnez loops. Every fall-through slot is a "j fail", so a
# transfer that is not taken, or an instruction in its shadow that executes,
# fails. mret runs in the main code with mepc set by csrw and MPP = M (mie =
# 0: no interrupt; MIE = MPIE = 1 afterwards).
# Layout: .option norvc, compressed instructions wrapped in C16(); "@2"
# marks a target at an address = 2 mod 4 (checked with objdump).
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

#define C16(...) .option push; .option rvc; __VA_ARGS__; .option pop

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x4, 0                                # x4: counts the code reached after each chain
  li x13, MSTATUS_MPP                     # x13: mstatus.MPP (M)

  # ---- every pair without mret: B B J J R R B R J B ------------------------
  # (pairs BB BJ JJ JR RR RB BR RJ JB; the second R is a ret)
  li TESTNUM, 2
  la x11, a5
  la x1, a6
  la x12, a8
  beq x0, x0, a1                          # B
  j fail
a1:
  beq x4, x4, a2                          # B -> B
  j fail
a2:
  j a3                                    # B -> J
  j fail
a3:
  jal x0, a4                              # J -> J
  j fail
a4:
  jalr x0, 0(x11)                         # J -> R
  j fail
a5:
  ret                                     # R -> R (ret)
  j fail
a6:
  bge x4, x0, a7                          # R -> B
  j fail
a7:
  jalr x0, 0(x12)                         # B -> R
  j fail
a8:
  j a9                                    # R -> J
  j fail
a9:
  bltu x0, x11, a10                       # J -> B
  j fail
a10:
  addi x4, x4, 1

  # ---- pairs with mret: B M J, J M R, R M B -----------------------------------
  li TESTNUM, 3
  la x5, b2
  csrs mstatus, x13                       # MPP = M: mret stays in M-mode
  csrw mepc, x5
  bne x11, x0, b1                         # B
  j fail
b1:
  mret                                    # B -> M
  j fail
b2:
  j b3                                    # M -> J
  j fail
b3:
  addi x4, x4, 1

  li TESTNUM, 4
  la x5, c2
  csrs mstatus, x13                       # MPP = M: mret stays in M-mode
  csrw mepc, x5
  la x11, c3
  j c1                                    # J
  j fail
c1:
  mret                                    # J -> M
  j fail
c2:
  jalr x0, 0(x11)                         # M -> R (mepc points at a jalr)
  j fail
c3:
  addi x4, x4, 1

  li TESTNUM, 5
  la x5, d2
  csrs mstatus, x13                       # MPP = M: mret stays in M-mode
  csrw mepc, x5
  la x11, d1
  jalr x0, 0(x11)                         # R
  j fail
d1:
  mret                                    # R -> M
  j fail
d2:
  bgeu x11, x0, d3                        # M -> B
  j fail
d3:
  addi x4, x4, 1

  # ---- taken branch to a ret, jal to a ret (call / return), jalr to a jalr ---------
  li TESTNUM, 6
  la x1, 2f
  beq x0, x0, 1f
  j fail
1:
  ret                                     # branch -> ret
  j fail
2:
  jal x1, 3f                              # call: jal -> ret
  addi x4, x4, 1                          # returned here
  j 4f
3:
  ret
  j fail
4:
  la x11, 5f
  jalr x1, 0(x11)                         # call through jalr -> ret (jalr -> jalr)
  addi x4, x4, 1
  j 6f
5:
  jalr x0, 0(x1)
  j fail
6:
  la x11, 7f
  la x12, 8f
  la x13, 9f
  jalr x0, 0(x11)                         # R
  j fail
7:
  jalr x5, 0(x12)                         # R -> R
  j fail
8:
  jalr x0, 0(x13)                         # R -> R
  j fail
9:
  addi x4, x4, 1

  # ---- compressed: c.beqz c.j c.jr c.jalr c.bnez c.jal, then a 32-bit branch -----
  # (each slot 6 bytes: every other target is at pc[1] = 1)
  li TESTNUM, 7
  li x14, 0
  li x15, 1
  la x11, h3
  la x12, h4
  C16(.balign 4)
  C16(c.beqz x14, h1)                     # B
  j fail
h1:                                       # @2
  C16(c.j h2)                             # B -> J
  j fail
h2:
  C16(c.jr x11)                           # J -> R
  j fail
h3:                                       # @2
  C16(c.jalr x12)                         # R -> R
  j fail
h4:
  C16(c.bnez x15, h5)                     # R -> B
  j fail
h5:                                       # @2
  C16(c.jal h6)                           # B -> J
  j fail
h6:
  beq x0, x0, h7                          # J -> B
  j fail
h7:
  addi x4, x4, 1
  la x7, h5 + 2
  bne x1, x7, fail                        # c.jal link

  # ---- backward taken c.beqz / c.bnez loops ------------------------------------
  li TESTNUM, 8
  li x9, 4
  li x13, 0
1:
  C16(c.addi x13, 1)
  addi x9, x9, -1
  seqz x10, x9
  C16(c.beqz x10, 1b)                     # taken backward while x9 != 0
  li x7, 4
  bne x13, x7, fail

  li TESTNUM, 9
  li x9, 3
1:
  C16(c.addi x9, -1)
  C16(c.bnez x9, 1b)                      # two-instruction compressed loop
  bnez x9, fail
  C16(.balign 4)
  li x10, 2
1:                                        # loop body at pc[1] = 0 and 1 mixed
  C16(c.addi x10, -1)
  li x5, 0
  C16(c.beqz x10, 2f)
  C16(c.j 1b)                             # backward c.j
2:
  bnez x10, fail

  li TESTNUM, 10
  li x7, 8
  bne x4, x7, fail

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
