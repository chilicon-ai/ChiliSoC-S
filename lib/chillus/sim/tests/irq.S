/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: machine software (MSI) and timer (MTI) interrupts
# from the CLINT. Covered: an interrupt pending while disabled (mstatus.MIE
# = 0 or its mie bit = 0) is not taken but shows in mip, WFI with an
# interrupt pending and globally disabled continues (NOP), the interrupt is
# taken right after the CSR instruction that enables it (via mie and via
# mstatus.MIE) with mepc = the next instruction and mcause = 0x8000_0003 /
# 0x8000_0007, the MIE / MPIE stack (handler sees MPIE = 1, MIE = 0; mret
# restores MIE), priority MSI before MTI when both are enabled at once (MTI
# is taken right after the MSI handler's mret, before the next instruction),
# an interrupt enabled right before an ebreak is taken first (mepc = the
# ebreak, which then traps after mret), and an exception with an interrupt
# pending but disabled (MPIE = 0: mret keeps MIE = 0, no interrupt).
# Determinism (Spike vs RTL): an interrupt is always made pending while it is
# disabled (store, read back from the CLINT, fence) and then enabled with one
# CSR instruction; mtime values are never read. mtimecmp = 0 makes MTI
# pending, mtimecmp hi = 0xffffffff clears it.
# The handler logs every trap: x29 count, x28 mcause, x27 mepc, x26 mstatus
# and x25 a cause log (one nibble per trap, newest lowest). An interrupt is
# cleared at its source (msip = 0 / mtimecmp hi = max, then read back), an
# exception (all 32-bit here) is skipped. It uses only those registers and
# t5 / t6 (clobbered by the env trap vector anyway).
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000
#define IRQ_MSI         0x80000003
#define IRQ_MTI         0x80000007

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x20, CLINT_MSIP                      # x20: msip
  li x21, CLINT_MTIMECMP                  # x21: mtimecmp lo, hi at +4
  li x22, 1
  li x23, -1
  sw x23, 4(x21)                          # mtimecmp hi = max: no timer interrupt
  lw x5, 4(x21)                           # read back: the store is done

  # ---- MSI pending: not taken while MIE = 0 or MSIE = 0; WFI continues -------
  li TESTNUM, 2
  sw x22, 0(x20)                          # msip = 1
  lw x5, 0(x20)
  fence
  csrr x5, mip
  li x7, MIP_MSIP
  bne x5, x7, fail
  csrsi mie, MIP_MSIP                     # locally enabled, MIE = 0: not taken
  wfi                                     # pending, globally disabled: NOP
  csrci mie, MIP_MSIP
  csrsi mstatus, MSTATUS_MIE              # MIE = 1, MSIE = 0: not taken
  nop
  bnez x29, fail

  # ---- taken right after the CSR instruction that enables it (mie.MSIE) ------
  li TESTNUM, 3
  csrsi mie, MIP_MSIP
irq_epc_3:
  li x7, 1
  bne x29, x7, fail
  li x7, IRQ_MSI
  bne x28, x7, fail
  la x7, irq_epc_3
  bne x27, x7, fail
  andi x5, x26, MSTATUS_MIE | MSTATUS_MPIE
  li x7, MSTATUS_MPIE                     # in the handler: MPIE = 1, MIE = 0
  bne x5, x7, fail
  csrr x5, mstatus
  andi x5, x5, MSTATUS_MIE | MSTATUS_MPIE
  li x7, MSTATUS_MIE | MSTATUS_MPIE       # after mret: MIE = 1, MPIE = 1
  bne x5, x7, fail
  csrr x5, mip                            # source cleared
  bnez x5, fail

  # ---- MTI: pending with MIE = 0, taken right after csrsi mstatus.MIE --------
  li TESTNUM, 4
  csrci mstatus, MSTATUS_MIE
  li x5, MIP_MTIP
  csrs mie, x5
  sw x0, 4(x21)                           # mtimecmp = 0 <= mtime (hi, then lo)
  sw x0, 0(x21)
  lw x5, 0(x21)
  fence
  csrr x5, mip
  li x7, MIP_MTIP
  bne x5, x7, fail
  csrsi mstatus, MSTATUS_MIE
irq_epc_4:
  li x7, IRQ_MTI
  bne x28, x7, fail
  la x7, irq_epc_4
  bne x27, x7, fail
  csrr x5, mip
  bnez x5, fail

  # ---- both pending, enabled at once: MSI first, MTI right after its mret ------
  li TESTNUM, 5
  csrci mstatus, MSTATUS_MIE
  sw x22, 0(x20)
  sw x0, 4(x21)
  sw x0, 0(x21)
  lw x5, 0(x21)
  fence
  csrr x5, mip
  li x7, MIP_MSIP | MIP_MTIP
  bne x5, x7, fail
  li x25, 0
  csrsi mstatus, MSTATUS_MIE
irq_epc_5:
  li x7, 0x37                             # MSI, then MTI
  bne x25, x7, fail
  la x7, irq_epc_5
  bne x27, x7, fail

  # ---- interrupt enabled right before an ebreak: interrupt first ------------
  li TESTNUM, 6
  csrci mstatus, MSTATUS_MIE
  sw x0, 4(x21)
  sw x0, 0(x21)
  lw x5, 0(x21)
  fence
  li x25, 0
  csrsi mstatus, MSTATUS_MIE
irq_epc_6:
  ebreak                                  # MTI taken here, then the breakpoint
  li x7, 0x73
  bne x25, x7, fail
  la x7, irq_epc_6
  bne x27, x7, fail

  # ---- exception with an interrupt pending but disabled ------------------
  li TESTNUM, 7
  csrci mstatus, MSTATUS_MIE
  sw x22, 0(x20)
  lw x5, 0(x20)
  fence
  li x25, 0
  ebreak                                  # breakpoint only
  li x7, CAUSE_BREAKPOINT
  bne x25, x7, fail
  andi x5, x26, MSTATUS_MIE | MSTATUS_MPIE
  bnez x5, fail                           # in the handler: MPIE = 0, MIE = 0
  csrr x5, mstatus
  andi x5, x5, MSTATUS_MIE
  bnez x5, fail                           # mret restored MIE = 0
  csrsi mstatus, MSTATUS_MIE              # now taken
irq_epc_7:
  li x7, IRQ_MSI
  bne x28, x7, fail
  la x7, irq_epc_7
  bne x27, x7, fail

  li TESTNUM, 8
  csrci mstatus, MSTATUS_MIE
  li x7, 8                                # traps so far
  bne x29, x7, fail

  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  csrr x26, mstatus
  slli x25, x25, 4
  andi t6, x28, 15
  or x25, x25, t6                         # cause log
  bltz x28, 1f
  addi t5, x27, 4                         # exception: skip it
  csrw mepc, t5
  mret
1:
  li t5, CLINT_MSIP
  addi t6, t6, -3
  bnez t6, 2f
  sw x0, 0(t5)                            # MSI: msip = 0
  lw t6, 0(t5)                            # read back: the clear is done
  mret
2:
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
