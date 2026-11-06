/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: WFI drains the core and sleeps (chillus_ctrl
# core_sleep; the testbench reports the sleep cycles) until an interrupt is
# pending and enabled in mie.
# Covered: WFI with the timer interrupt enabled in mie but mstatus.MIE = 0
# sleeps until MTIP, then continues without a trap (mip shows MTIP); WFI with
# MIE = 1 sleeps and the interrupt is taken on the next instruction (mepc =
# the WFI + 4), also when that instruction is 16-bit and when the WFI
# follows a load and a divide.
# Determinism (Spike vs RTL): Spike runs WFI as a real wait too (no
# --wfi-as-nop), so the retired instructions match; only the sleep length
# differs. mtimecmp is an absolute value far above mtime at that point in
# both, and mtime is never read.
# Handler as in irq.S: x29 count, x28 mcause, x27 mepc; MTI cleared by
# mtimecmp hi = max.

#include "riscv_test.h"
#include "test_macros.h"

#define CLINT_MTIMECMP  0x02004000
#define IRQ_MTI         0x80000007

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x21, CLINT_MTIMECMP                  # x21: mtimecmp lo, hi at +4
  li x23, -1
  sw x23, 4(x21)                          # mtimecmp hi = max: no timer interrupt
  lw x5, 4(x21)
  li x5, MIP_MTIP
  csrs mie, x5                            # MTIE = 1, MIE = 0

  # ---- MIE = 0: sleeps until MTIP, continues without a trap ----------------
  li TESTNUM, 2
  li x5, 0x4000
  sw x5, 0(x21)                           # mtimecmp = 0x4000 (lo, then hi = 0)
  sw x0, 4(x21)
  lw x5, 4(x21)
  wfi
  csrr x5, mip
  li x7, MIP_MTIP
  bne x5, x7, fail
  bnez x29, fail
  sw x23, 4(x21)                          # clear MTIP
  lw x5, 4(x21)

  # ---- MIE = 1: sleeps, the interrupt is taken after the WFI ----------------
  li TESTNUM, 3
  li x5, 0x8000
  sw x5, 0(x21)
  sw x0, 4(x21)
  lw x5, 4(x21)
  csrsi mstatus, MSTATUS_MIE
  wfi
irq_epc_3:
  csrci mstatus, MSTATUS_MIE
  li x7, 1
  bne x29, x7, fail
  li x7, IRQ_MTI
  bne x28, x7, fail
  la x7, irq_epc_3
  bne x27, x7, fail

  # ---- after a load and a divide, a 16-bit instruction next ----------------
  li TESTNUM, 4
  li x5, 0xc000
  sw x5, 0(x21)
  sw x0, 4(x21)
  lw x5, 4(x21)
  li x6, 1000
  li x8, 7
  csrsi mstatus, MSTATUS_MIE
  lw x9, 0(x21)
  div x10, x6, x8
  wfi
  .option rvc
irq_epc_4:
  c.nop
  .option norvc
  csrci mstatus, MSTATUS_MIE
  li x7, 2
  bne x29, x7, fail
  la x7, irq_epc_4
  bne x27, x7, fail
  li x7, 142
  bne x10, x7, fail
  li x7, 0xc000
  bne x9, x7, fail

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
  li t5, CLINT_MTIMECMP                   # MTI: mtimecmp hi = max
  li t6, -1
  sw t6, 4(t5)
  lw t6, 4(t5)
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
