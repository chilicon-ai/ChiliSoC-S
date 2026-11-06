/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S debug test: a halt request held through reset enters debug mode
# before the first instruction (riscv-debug-specification.pdf 4.6): the
# testbench holds debug_req from time 0 (+debug_req_reset), the mini-DM of
# dbg.h runs once and drops it. Covered: one entry, cause 3 (haltreq: no
# resethaltreq cause), dpc = the reset pc (_start), and the program then runs
# from the start (the entry happened before reset_vector set up mtvec).
# run.py: no-spike; needs-debug; plusarg +debug_req_reset

#include "riscv_test.h"
#include "test_macros.h"
#include "dbg.h"

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  la x21, dbg_mbox

  li TESTNUM, 2
  lw x5, MB_COUNT(x21)
  li x7, 1
  bne x5, x7, fail
  lw x5, MB_DPC(x21)
  la x6, _start
  bne x5, x6, fail
  lw x5, MB_DCSR(x21)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 3
  bne x6, x7, fail

  TEST_PASSFAIL

  DBG_ROM

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  DBG_DATA
RVTEST_DATA_END
