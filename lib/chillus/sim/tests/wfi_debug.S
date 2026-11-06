/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: debug_req wakes the core from WFI. With nothing
# enabled in mie (and MIE = 0) only debug_req ends the sleep: the testbench
# raises it DEBUG_WAKE (16) cycles after core_sleep rises when irqgen bit 30
# arms it (chillus_tb) and holds it until the mini-DM of dbg.h clears the
# bit. Covered: the core sleeps (mcycle advances by at least 16 across the
# WFI), wakes on debug_req and enters debug mode before the next instruction
# (one entry, cause 3, dpc = WFI + 4, no trap), then resumes there; with the
# debug wake disarmed, a WFI with a local interrupt pending and enabled in
# mie but MIE = 0 resumes (irq_wake: otherwise the test times out) without a
# trap.
# Spike has no debug_req line, so the test checks itself.
# run.py: no-spike; needs-debug

#include "riscv_test.h"
#include "test_macros.h"
#include "dbg.h"

#define CLINT_MTIMECMP  0x02004000

#define GEN_SET(r)  sw r, 0(x20); lw x5, 0(x20); fence

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x5, CLINT_MTIMECMP
  li x6, -1
  sw x6, 4(x5)                            # mtimecmp hi = max: no timer interrupt
  lw x6, 4(x5)
  la x20, irqgen
  la x21, dbg_mbox
  csrw mie, x0
  li x29, 0

  # ---- debug_req wakes a WFI with nothing enabled ---------------------------
  li TESTNUM, 2
  li x19, DBG_WAKE
  GEN_SET(x19)
  csrr x8, mcycle
wfi_2:
  wfi
  csrr x9, mcycle
  sub x9, x9, x8
  li x7, 16
  bltu x9, x7, fail                       # slept at least DEBUG_WAKE cycles
  bnez x29, fail                          # no trap
  lw x5, MB_COUNT(x21)
  li x7, 1
  bne x5, x7, fail                        # one debug entry
  lw x5, MB_DPC(x21)
  la x6, wfi_2 + 4
  bne x5, x6, fail                        # before the next instruction
  lw x5, MB_DCSR(x21)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 3
  bne x6, x7, fail                        # cause haltreq
  lw x5, 0(x20)
  bnez x5, fail                           # the DM code disarmed the wake

  # ---- local interrupt pending in mie, MIE = 0: WFI resumes, no trap -------
  li TESTNUM, 3
  li x5, (1 << 16)
  csrw mie, x5                            # irq_fast[0] enabled, MIE = 0
  li x19, 1
  GEN_SET(x19)
  wfi
  bnez x29, fail
  li x19, 0
  GEN_SET(x19)
  csrw mie, x0

  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  bltz x28, 1f
  j fail                                  # no exceptions expected
1:
  j fail                                  # no interrupts expected

  DBG_ROM

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  DBG_DATA
RVTEST_DATA_END
