/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: data hazards between neighbouring instructions.
# Forwarding at distance 1 (ex), 2 (mem), 3 (wb) and 4 (register file), x0,
# two writers in flight, load-use into every consumer (ALU, store data, store
# address, branch, jalr, CSR) and CSR results used at once.
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la x8, buf                              # x8: data buffer base, kept

  # ---- ALU -> ALU forwarding distances --------------------------------------
  TEST_CASE( 2, x1, 4,  li x1, 1; addi x1, x1, 1; addi x1, x1, 1; addi x1, x1, 1)
  TEST_CASE( 3, x4, 12, li x1, 5; li x2, 7; add x4, x1, x2)
  TEST_CASE( 4, x4, 6,  li x1, 3; nop; nop; add x4, x1, x1)
  TEST_CASE( 5, x4, 9,  li x1, 9; nop; nop; nop; add x4, x1, x0)
  TEST_CASE( 6, x4, 7,  li x5, 2; li x6, 3; add x5, x5, x6; add x5, x5, x5; sub x4, x5, x6)
  TEST_CASE( 7, x4, 0,  li x1, 5; addi x0, x1, 1; add x4, x0, x0)
  TEST_CASE( 8, x4, 2,  li x1, 1; li x1, 2; add x4, x1, x0)
  TEST_CASE( 9, x4, 40, li x1, 10; li x1, 20; nop; add x4, x1, x1)
  TEST_CASE(10, x4, 3,  li x1, 1; li x2, 2; li x1, 1; add x4, x1, x2)

  # ---- load-use ---------------------------------------------------------------
  li x1, 0x11223344
  sw x1, 0(x8)
  TEST_CASE(11, x4, 0x11223345, lw x2, 0(x8); addi x4, x2, 1)
  TEST_CASE(12, x4, 0x11223345, lw x2, 0(x8); nop; addi x4, x2, 1)
  TEST_CASE(13, x4, 0x11223345, lw x2, 0(x8); nop; nop; addi x4, x2, 1)
  TEST_CASE(14, x4, 0x22446688, lw x2, 0(x8); add x4, x2, x2)
  TEST_CASE(15, x4, 0x11223344, lw x2, 0(x8); sw x2, 4(x8); lw x4, 4(x8))
  TEST_CASE(16, x4, 0x11223344, sw x8, 8(x8); lw x9, 8(x8); lw x4, 0(x9))
  TEST_CASE(17, x4, 0x22446688, lw x5, 0(x8); lw x6, 4(x8); add x4, x5, x6)
  TEST_CASE(18, x4, 0x11225544, li x1, 0x55; sb x1, 1(x8); lw x4, 0(x8))
  TEST_CASE(19, x4, 0,          lw x0, 0(x8); add x4, x0, x0)
  TEST_CASE(20, x4, 0x11223344, lw x9, 8(x8); nop; lw x4, 4(x9))

  # load-use into a branch (not taken, then taken)
  li TESTNUM, 21
  lw x2, 0(x8)
  beq x2, x0, fail
  lw x2, 0(x8)
  bne x2, x0, 1f
  j fail
1:
  # load-use into jalr
  li TESTNUM, 22
  la x1, 2f
  sw x1, 12(x8)
  lw x2, 12(x8)
  jalr x0, 0(x2)
  j fail
2:
  # link register used at once
  li TESTNUM, 23
  la x5, 3f
  jal x1, 3f
3:
  bne x1, x5, fail

  # ---- CSR ------------------------------------------------------------------
  TEST_CASE(24, x4, 0x1235,     li x1, 0x1234; csrw mscratch, x1; csrr x2, mscratch; addi x4, x2, 1)
  TEST_CASE(25, x4, 0x11225544, lw x2, 0(x8); csrrw x0, mscratch, x2; csrr x4, mscratch)
  TEST_CASE(26, x4, 4,          csrwi mscratch, 0; csrrsi x0, mscratch, 5; csrrci x0, mscratch, 1; csrr x4, mscratch)
  TEST_CASE(27, x4, 8,          csrwi mscratch, 4; csrrsi x2, mscratch, 0; add x4, x2, x2)

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 16, 4, 0
RVTEST_DATA_END
