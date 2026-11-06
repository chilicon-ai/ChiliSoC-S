/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: M instructions in the pipeline. The multiply / divide
# unit holds ex for XLEN + 3 cycles, so check what flows around that hold:
# operands forwarded into it (ALU, load-use, CSR), its result forwarded out
# (distance 1-3, store data, address, branch, jalr), back-to-back M
# instructions, special cases, and a trap right after an M instruction.
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la x8, buf
  li x29, 0

  # ---- operands forwarded into the unit ------------------------------------
  TEST_CASE( 2, x4, 42,         li x1, 6; li x2, 7; mul x4, x1, x2)
  TEST_CASE( 3, x4, 42,         li x1, 6; li x2, 7; nop; mul x4, x1, x2)
  TEST_CASE( 4, x4, 0x30,       li x1, 0x18; sw x1, 0(x8); lw x2, 0(x8); slli x4, x2, 0; mul x4, x2, x0; add x4, x4, x2; add x4, x4, x2)
  TEST_CASE( 5, x4, 6,          li x1, 4; lw x2, 0(x8); divu x4, x2, x1)
  TEST_CASE( 6, x4, 0x2a,       li x5, 2; li x1, 0x15; csrw mscratch, x1; csrr x2, mscratch; mul x4, x2, x5)

  # ---- result forwarded out ---------------------------------------------
  TEST_CASE( 7, x4, 43,         li x1, 6; li x2, 7; mul x5, x1, x2; addi x4, x5, 1)
  TEST_CASE( 8, x4, 43,         li x1, 6; li x2, 7; mul x5, x1, x2; nop; addi x4, x5, 1)
  TEST_CASE( 9, x4, 43,         li x1, 6; li x2, 7; mul x5, x1, x2; nop; nop; addi x4, x5, 1)
  TEST_CASE(10, x4, 42,         li x1, 6; li x2, 7; mul x5, x1, x2; sw x5, 4(x8); lw x4, 4(x8))
  TEST_CASE(11, x4, 0x18,       li x1, 1; mul x9, x8, x1; lw x4, 0(x9))

  # result into a branch and a jalr
  li TESTNUM, 12
  li x1, 3
  li x2, 3
  rem x5, x1, x2
  bne x5, x0, fail
  li TESTNUM, 13
  la x1, 1f
  li x2, 1
  mul x5, x1, x2
  jalr x0, 0(x5)
  j fail
1:

  # ---- back to back ----------------------------------------------------
  TEST_CASE(14, x4, 24,         li x1, 2; li x2, 3; mul x5, x1, x2; mul x4, x5, x1; add x4, x4, x4)
  TEST_CASE(15, x4, 8,          li x1, 100; li x2, 7; div x5, x1, x2; rem x6, x1, x2; sub x4, x5, x6; addi x4, x4, -4)
  TEST_CASE(16, x4, 4,          li x1, 20; li x2, 5; divu x4, x1, x2; mulhu x5, x1, x2; add x4, x4, x5)

  # ---- special cases ---------------------------------------------------
  TEST_CASE(17, x4, -1,         li x1, 7; div x4, x1, x0)
  TEST_CASE(18, x4, 7,          li x1, 7; rem x4, x1, x0)
  TEST_CASE(29, x4, -1,         li x1, -7; div x4, x1, x0)
  TEST_CASE(30, x4, -7,         li x1, -7; rem x4, x1, x0)
  TEST_CASE(19, x4, 0x80000000, li x1, 0x80000000; li x2, -1; div x4, x1, x2)
  TEST_CASE(20, x4, 0,          li x1, 0x80000000; li x2, -1; rem x4, x1, x2)
  TEST_CASE(21, x4, -1,         li x1, -7; li x2, 7; mulh x4, x1, x2)
  TEST_CASE(22, x4, -1,         li x1, -1; li x2, 1; mulhsu x4, x1, x2)
  TEST_CASE(23, x4, 0,          li x1, 0; li x2, -1; mul x4, x1, x2)
  TEST_CASE(24, x4, -2,         li x1, -7; li x2, 3; div x4, x1, x2)
  TEST_CASE(25, x4, -1,         li x1, -7; li x2, 3; rem x4, x1, x2)

  # ---- writes to x0 and an M instruction killed by a taken branch ---------
  TEST_CASE(26, x4, 0,          li x1, 5; mul x0, x1, x1; add x4, x0, x0)
  li TESTNUM, 27
  li x4, 1
  beq x0, x0, 2f
  mul x4, x4, x0
  div x4, x4, x0
2:
  li x7, 1
  bne x4, x7, fail

  # ---- trap right after an M instruction ----------------------------------
  li TESTNUM, 28
  li x1, 9
  li x2, 3
  divu x5, x1, x2
  .word 0xc0001073                 # unimp (32-bit), illegal: handler skips it
  li x7, 3
  bne x5, x7, fail
  li x7, 1
  bne x29, x7, fail

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
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
