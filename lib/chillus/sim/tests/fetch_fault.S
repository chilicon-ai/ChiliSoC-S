/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: instruction access faults (mcause 1) at the end of
# RAM. The testbench and Spike (sim/run.py) both end RAM at BASE + 1 MiB =
# 0x8010_0000 (END): a fetch from END or above faults in both. The last
# eight bytes of RAM (the .data block below, placed by .org) hold:
#
#   END-8  c.addi x21, 1           16-bit
#   END-6  addi   x22, x22, 1      32-bit straddling two good words
#   END-2  low half of addi x20, x20, 1 (0x0a13): a 32-bit instruction whose
#          upper half lies in the faulting word at END
#
# Checked (mcause, mepc, mtval; riscv-privileged "mtval": for a fetch access
# fault of a variable-length instruction mtval is the address of the
# portion that faulted, mepc the start of the instruction):
#   2  fall-through from END-8 into the straddling instruction:
#      mepc = END-2, mtval = END (= pc + 2); older instructions complete
#   3  jump straight to the straddling instruction: the same
#   4  jump to END (pc[1] = 0): mepc = mtval = END
#   5  jump to END+2 (pc[1] = 1, the first half faults): mepc = mtval = END+2
#   6  END-2 rewritten to c.addi x20, 1 (sh + fence.i): the 16-bit
#      instruction in the last good word executes (no fault although the next
#      word, prefetched, faulted), then the fall-through to END faults with
#      mepc = mtval = END
#
# The handler counts traps in x29, records mcause in x28, mtval in x27 and
# mepc in x26, and resumes at x25 (set before each jump). Every CSR read and
# retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

#define END 0x80100000

# last trap: mcause 1, mepc = END + epc_off, mtval = END + tval_off
#define CHECK_FETCH_FAULT(epc_off, tval_off) \
  li x7, CAUSE_FETCH_ACCESS; bne x28, x7, fail; \
  li x7, END + (epc_off); bne x26, x7, fail; \
  li x7, END + (tval_off); bne x27, x7, fail

# jump to END + off, resume at label 1 below the macro
#define JUMP_END(off) la x25, 1f; li x7, END + (off); jr x7; 1:

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li x20, 0
  li x21, 0
  li x22, 0
  li x29, 0

  # ---- layout: the block ends exactly at END ----------------------------------
  li TESTNUM, 1
  la x7, end_block
  li x8, END - 8
  bne x7, x8, fail

  # ---- fall-through into a 32-bit instruction straddling into END -------------
  li TESTNUM, 2
  JUMP_END(-8)
  CHECK_FETCH_FAULT(-2, 0)
  li x7, 1
  bne x21, x7, fail                       # c.addi at END-8 ran once
  bne x22, x7, fail                       # addi at END-6 ran once
  bnez x20, fail                          # the faulting instruction did not

  # ---- jump straight to the straddling instruction ----------------------------
  li TESTNUM, 3
  JUMP_END(-2)
  CHECK_FETCH_FAULT(-2, 0)

  # ---- jump to END: the whole first word faults --------------------------------
  li TESTNUM, 4
  JUMP_END(0)
  CHECK_FETCH_FAULT(0, 0)

  # ---- jump to END+2: the first half faults -----------------------------------
  li TESTNUM, 5
  JUMP_END(2)
  CHECK_FETCH_FAULT(2, 2)

  # ---- 16-bit instruction in the last good halfword, then END -----------------
  li TESTNUM, 6
  li x8, END - 2
  li x9, 0x0a05                           # c.addi x20, 1
  sh x9, 0(x8)
  fence.i
  JUMP_END(-2)
  CHECK_FETCH_FAULT(0, 0)
  li x7, 1
  bne x20, x7, fail                       # c.addi at END-2 ran once

  # ---- unchanged registers, trap count -------------------------------------
  li TESTNUM, 7
  li x7, 1
  bne x21, x7, fail
  bne x22, x7, fail
  li x7, 5
  bne x29, x7, fail

  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mtval
  csrr x26, mepc
  csrw mepc, x25
  mret

RVTEST_CODE_END

  .data
  .balign 0x80000                         # .data starts at BASE + 512 KiB
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END

  # last 8 bytes of RAM: .data offset 512 KiB - 8 = END - 8
  .org 0x80000 - 8
end_block:
  c.addi x21, 1                           # END-8
  .option push
  .option norvc
  addi x22, x22, 1                        # END-6: straddles two good words
  .option pop
  .half 0x0a13                            # END-2: addi x20, x20, 1, low half only
