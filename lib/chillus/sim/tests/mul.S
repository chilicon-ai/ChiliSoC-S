/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: the multiplier (MUL, MULH, MULHU, MULHSU). Every result is compared with Spike by sim/run.py:
#   - all four operations on every pair of a corner-value table (0, +-1,
#     min / max signed, all ones, single bits, alternating patterns) in a
#     loop: signed x signed, unsigned x unsigned, signed x unsigned;
#   - dependent use of the result at distance 1, 2, 3 (ALU, store data,
#     address, branch, jalr) without NOPs, back-to-back multiplies (the
#     second depending on the first), multiply / divide mixes.
# Self-checks on a few known values; the loop results are checked by Spike.

#include "riscv_test.h"
#include "test_macros.h"

#define NCORNER 16                 /* entries in the corners table */

RVTEST_RV32U
RVTEST_CODE_BEGIN

  la x8, buf

  # ---- dependent sequences, no NOPs ----------------------------------------
  TEST_CASE( 2, x6, 45,          li x1, 6; li x2, 7; mul x5, x1, x2; addi x6, x5, 3)
  TEST_CASE( 3, x6, 43,          li x1, 6; li x2, 7; mul x5, x1, x2; nop; addi x6, x5, 1)
  TEST_CASE( 4, x6, 43,          li x1, 6; li x2, 7; mul x5, x1, x2; nop; nop; addi x6, x5, 1)
  TEST_CASE( 5, x6, 2058,        li x1, 6; li x2, 7; mul x5, x1, x2; mul x6, x5, x5; addi x6, x6, 294)
  TEST_CASE( 6, x6, 0xffffffff,  li x1, -1; li x2, 1; mulh x5, x1, x2; mv x6, x5)
  TEST_CASE( 7, x6, 0,           li x1, -1; li x2, 1; mulhu x5, x1, x2; mv x6, x5)
  TEST_CASE( 8, x6, 0xffffffff,  li x1, -1; li x2, 1; mulhsu x5, x1, x2; mv x6, x5)
  TEST_CASE( 9, x6, 0x40000000,  li x1, 0x80000000; li x2, 0x80000000; mulhu x6, x1, x2)
  TEST_CASE(10, x6, 0x40000000,  li x1, 0x80000000; li x2, 0x80000000; mulh x6, x1, x2)
  TEST_CASE(11, x6, 0xc0000000,  li x1, 0x80000000; li x2, 0x80000000; mulhsu x6, x1, x2)

  # result as store data, as an address, into a branch and a jalr
  TEST_CASE(12, x6, 42,          li x1, 6; li x2, 7; mul x5, x1, x2; sw x5, 0(x8); lw x6, 0(x8))
  TEST_CASE(13, x6, 42,          li x1, 1; mul x9, x8, x1; lw x6, 0(x9))
  li TESTNUM, 14
  li x1, 3
  li x2, 0
  mul x5, x1, x2
  bne x5, x0, fail
  li TESTNUM, 15
  la x1, 1f
  li x2, 1
  mulhu x9, x1, x2                 # 0
  mul x5, x1, x2
  add x5, x5, x9
  jalr x0, 0(x5)
  j fail
1:
  # multiply / divide mix, back to back
  TEST_CASE(16, x6, 7,           li x1, 6; li x2, 7; mul x5, x1, x2; divu x6, x5, x1)
  TEST_CASE(17, x6, 42,          li x1, 84; li x2, 2; divu x5, x1, x2; mul x6, x5, x0; add x6, x6, x5)

  # ---- every operation on every corner pair (results checked by Spike) ------
  li TESTNUM, 18
  la x10, corners
  li x11, 0                        # i * 4
  li x14, 0                        # running xor of all results
2:
  add x12, x10, x11
  lw x1, 0(x12)
  li x13, 0                        # j * 4
3:
  add x12, x10, x13
  lw x2, 0(x12)
  mul    x5, x1, x2
  mulh   x6, x1, x2
  mulhu  x7, x1, x2
  mulhsu x9, x1, x2
  mulhsu x15, x2, x1
  xor x14, x14, x5
  xor x14, x14, x6
  xor x14, x14, x7
  xor x14, x14, x9
  xor x14, x14, x15
  addi x13, x13, 4
  li x12, NCORNER * 4
  bne x13, x12, 3b
  addi x11, x11, 4
  bne x11, x12, 2b
  sw x14, 4(x8)                    # the combined value is compared with Spike

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 4, 4, 0
corners:
  .word 0x00000000, 0x00000001, 0xffffffff, 0x7fffffff
  .word 0x80000000, 0x80000001, 0x00000002, 0xfffffffe
  .word 0x55555555, 0xaaaaaaaa, 0x0000ffff, 0xffff0000
  .word 0x00010000, 0x12345678, 0xedcba987, 0x40000000
RVTEST_DATA_END
