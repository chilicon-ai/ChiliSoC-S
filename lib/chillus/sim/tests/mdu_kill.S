/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: an M instruction (multiply / divide) directly after a
# load / store that gets a bus error. With data stalls (sim/run.py --dstall)
# the M operation starts while the faulting access waits in mem and is then
# killed by the bus-fault trap (the MDU abandons it; it re-executes after the
# handler). Without stalls it checks the same sequence without the kill.
# Every retired instruction is compared with Spike.
#include "riscv_test.h"
#include "test_macros.h"
  .option norelax
RVTEST_RV32M
RVTEST_CODE_BEGIN
  la x8, buf
  li x6, 0x40000000
  li x12, 1000
  li x13, 7
  li x20, 20                              # iterations
1:
  lw x5, 0(x6)                            # fault
  div x14, x12, x13
  sw x5, 4(x6)                            # fault
  mul x15, x12, x13
  lw x16, 0(x8)
  lw x5, 8(x6)                            # fault
  divu x17, x12, x13
  rem x18, x12, x13
  lb x5, 1(x6)                            # fault
  mulh x19, x12, x13
  addi x20, x20, -1
  bnez x20, 1b
  li TESTNUM, 2
  li x7, 80
  bne x29, x7, fail
  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr t5, mepc
  lhu t6, 0(t5)
  andi t6, t6, 3
  addi t5, t5, 2
  xori t6, t6, 3
  bnez t6, 2f
  addi t5, t5, 2
2:
  csrw mepc, t5
  mret
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 16, 4, 0
RVTEST_DATA_END
