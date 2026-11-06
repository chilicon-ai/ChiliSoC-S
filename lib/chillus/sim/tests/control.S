/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: control flow. Instructions in the shadow of a taken
# branch / jump must not execute (no register write, no memory access: the
# shadow loads use address 0, outside the testbench memory), back-to-back
# taken branches, jumps to jumps, branches on just-computed values, a
# FENCE.I in the middle of a dependent sequence, FENCE.TSO, and FENCE /
# FENCE.I with reserved fields (rd, rs1, fm, imm: ignored).

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  la x8, buf

  # ---- shadow of taken branches / jumps ----------------------------------
  li TESTNUM, 2
  li x4, 0
  beq x0, x0, 1f
  addi x4, x4, 1
  lw x4, 0(x0)
  sw x4, 0(x0)
1:
  addi x4, x4, 4
  li x7, 4
  bne x4, x7, fail

  li TESTNUM, 3
  li x4, 0
  jal x0, 1f
  addi x4, x4, 1
  lw x4, 0(x0)
1:
  la x1, 2f
  jalr x0, 0(x1)
  addi x4, x4, 2
  sw x4, 0(x0)
2:
  bne x4, x0, fail

  # ---- back-to-back taken branches, jump to jump ---------------------------
  li TESTNUM, 4
  li x4, 0
  beq x0, x0, 1f
1:
  beq x0, x0, 2f
2:
  bne x0, x0, fail
  addi x4, x4, 1
  j 3f
3:
  j 4f
  addi x4, x4, 8
4:
  jal x1, 5f
  addi x4, x4, 16          # executed after the return below
  j 6f
5:
  addi x4, x4, 2
  jalr x0, 0(x1)
6:
  li x7, 19
  bne x4, x7, fail

  # ---- branch on just-computed values --------------------------------------
  li TESTNUM, 5
  li x1, 5
  addi x2, x1, -5
  beq x2, x0, 1f
  j fail
1:
  li x1, -1
  sltu x2, x0, x1
  bne x2, x0, 2f
  j fail
2:
  li x1, 3
  li x2, 3
  blt x1, x2, fail
  bge x1, x2, 3f
  j fail
3:

  # ---- loop with a dependent counter ---------------------------------------
  li TESTNUM, 6
  li x1, 10
  li x4, 0
1:
  add x4, x4, x1
  addi x1, x1, -1
  bne x1, x0, 1b
  li x7, 55
  bne x4, x7, fail

  # ---- FENCE.I between dependent instructions ------------------------------
  li TESTNUM, 7
  li x1, 7
  fence.i
  addi x4, x1, 1
  fence.i
  fence.i
  addi x4, x4, 1
  li x7, 9
  bne x4, x7, fail

  # ---- FENCE between a store and a dependent load --------------------------
  TEST_CASE(8, x4, 0x5a, li x1, 0x5a; sb x1, 3(x8); fence; lbu x4, 3(x8))

  # ---- FENCE.TSO; reserved FENCE / FENCE.I fields are ignored --------------
  TEST_CASE(9, x4, 0x77, li x1, 0x77; sw x1, 4(x8); fence.tso; lw x4, 4(x8))
  li TESTNUM, 10
  li x1, 0x66
  sw x1, 8(x8)
  .word 0x0ff0808f                 # fence iorw, iorw with rd = rs1 = x1
  .word 0x1ff0000f                 # fence with fm = 0001 (reserved: a normal fence)
  lw x4, 8(x8)
  .word 0x0000908f                 # fence.i with rd = rs1 = x1
  .word 0x0010100f                 # fence.i with imm = 1
  fence.tso
  bne x4, x1, fail
  li x7, 0x66
  bne x1, x7, fail                 # no rd write

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 16, 4, 0
RVTEST_DATA_END
