/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: minstret / instret around everything that retires,
# traps or writes it. Every read value is compared with Spike by sim/run.py
# (instret is compared exactly; cycle / time are not). Covers back-to-back
# reads, reads right after ALU / load / store / multiply / taken branch /
# jal, after a bus-fault trap (the faulting load is counted at retire and
# taken back) and an illegal-instruction trap, writes of minstret and
# minstreth followed at once by reads, and csrrw swapping the value.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la x8, buf
  li x29, 0

  # back to back, after ALU / load / store / mul / branch / jal
  csrr x5, minstret
  csrr x6, minstret
  csrr x7, instret
  addi x1, x0, 1
  csrr x5, minstret
  lw x2, 0(x8)
  csrr x6, minstret
  sw x2, 4(x8)
  csrr x7, minstret
  mul x3, x1, x1
  csrr x5, minstret
  beq x0, x0, 1f
  nop
1:
  csrr x6, minstret
  jal x1, 2f
2:
  csrr x7, minstret

  # bus fault on a load: counted at retire, taken back in the trap
  li x9, 0x40000000
  lw x10, 0(x9)                    # load access fault, handler skips it
  csrr x5, minstret
  sw x10, 0(x9)                    # store access fault
  csrr x6, minstret
  .word 0xc0001073                 # illegal
  csrr x7, minstret

  # writes, read at once
  li x1, 0x12345678
  csrw minstret, x1
  csrr x5, minstret
  csrr x6, minstreth
  li x1, 0xfffffffe
  csrw minstret, x1
  nop
  csrr x5, minstret
  csrr x6, minstreth               # carry into the high half
  li x1, 7
  csrw minstreth, x1
  csrr x5, minstret
  csrr x6, minstreth
  csrrw x7, minstret, x0           # old value in x7, then 0
  csrr x5, minstret
  csrrs x6, minstret, x0
  csrrc x7, minstreth, x1          # clear bits of the high half

  # mcountinhibit.IR stops it
  csrwi mcountinhibit, 4
  csrr x5, minstret
  nop
  csrr x6, minstret
  csrwi mcountinhibit, 0
  csrr x7, minstret

  li x7, 3
  li TESTNUM, 2
  bne x29, x7, fail                # three traps
  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, minstret               # read inside the handler too
  csrr t5, mepc
  lhu t6, 0(t5)                    # skip the trapping instruction: 2 or 4 bytes
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
buf: .fill 4, 4, 0
RVTEST_DATA_END
