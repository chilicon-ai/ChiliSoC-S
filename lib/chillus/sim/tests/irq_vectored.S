/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: mtvec Vectored mode with the
# CLINT's machine software (MSI) and timer (MTI) interrupts. Covered: mtvec
# MODE reads back as written for 0 / 1, a write of 2 / 3 keeps only bit 0 (as
# Spike); in Vectored mode an interrupt enters at BASE + 4 * code (slot 3
# MSI, slot 7 MTI) with the usual mcause / mepc, and an exception enters at
# BASE (slot 0, which jumps to the env trap vector and so to mtvec_handler);
# back in Direct mode an interrupt enters at BASE.
# Determinism (Spike vs RTL): as irq.S, an interrupt is made pending while
# disabled (store, read back from the CLINT, fence) and then enabled with
# one CSR instruction; mtime values are never read.
# Each vector slot sets x24 to its number (0x40: the Direct-mode entry)
# and jumps to the env trap vector (slot 0) or to mtvec_handler, which logs
# every trap: x29 count, x28 mcause, x27 mepc and clears the source.
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

  li x20, CLINT_MSIP
  li x21, CLINT_MTIMECMP
  li x22, 1
  li x23, -1
  sw x23, 4(x21)                          # mtimecmp hi = max: no timer interrupt
  lw x5, 4(x21)
  la x18, vec_table                       # x18: BASE

  # ---- mtvec MODE: WARL bit 0 ------------------------------------------------
  li TESTNUM, 2
  ori x5, x18, 1
  csrw mtvec, x5
  csrr x6, mtvec
  bne x5, x6, fail                        # Vectored
  ori x5, x18, 3
  csrw mtvec, x5
  csrr x6, mtvec
  ori x7, x18, 1
  bne x6, x7, fail                        # 3 -> 1
  ori x5, x18, 2
  csrw mtvec, x5
  csrr x6, mtvec
  bne x6, x18, fail                       # 2 -> 0
  ori x5, x18, 1
  csrw mtvec, x5                          # Vectored from here on

  # ---- MSI enters at slot 3 ----------------------------------------------
  li TESTNUM, 3
  sw x22, 0(x20)                          # msip = 1
  lw x5, 0(x20)
  fence
  csrsi mie, MIP_MSIP
  li x24, -1
  csrsi mstatus, MSTATUS_MIE              # taken on the next instruction
irq_epc_3:
  li x7, 3
  bne x24, x7, fail
  li x7, IRQ_MSI
  bne x28, x7, fail
  la x7, irq_epc_3
  bne x27, x7, fail
  csrci mstatus, MSTATUS_MIE
  csrci mie, MIP_MSIP

  # ---- MTI enters at slot 7 ----------------------------------------------
  li TESTNUM, 4
  sw x0, 4(x21)
  sw x0, 0(x21)                           # mtimecmp = 0: MTI pending
  lw x5, 0(x21)
  fence
  li x7, MIP_MTIP
  csrs mie, x7
  li x24, -1
  csrsi mstatus, MSTATUS_MIE
irq_epc_4:
  li x7, 7
  bne x24, x7, fail
  li x7, IRQ_MTI
  bne x28, x7, fail
  la x7, irq_epc_4
  bne x27, x7, fail
  csrci mstatus, MSTATUS_MIE
  li x7, MIP_MTIP
  csrc mie, x7

  # ---- an exception enters at BASE (slot 0) --------------------------------
  li TESTNUM, 5
  li x24, -1
  ebreak
  bnez x24, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail

  # ---- Direct mode: an interrupt enters at BASE ------------------------------
  li TESTNUM, 6
  la x5, direct_entry
  csrw mtvec, x5
  sw x22, 0(x20)
  lw x5, 0(x20)
  fence
  csrsi mie, MIP_MSIP
  li x24, -1
  csrsi mstatus, MSTATUS_MIE
irq_epc_6:
  li x7, 0x40
  bne x24, x7, fail
  li x7, IRQ_MSI
  bne x28, x7, fail
  la x7, irq_epc_6
  bne x27, x7, fail
  csrci mstatus, MSTATUS_MIE
  csrci mie, MIP_MSIP

  li TESTNUM, 7
  li x7, 4                                # traps so far
  bne x29, x7, fail
  la x5, trap_vector
  csrw mtvec, x5                          # the env's again, for the final ecall
  TEST_PASSFAIL

  # ---- vector table: slot n sets x24 = n --------------------------------------
  .balign 128
vec_table:
  .irp n, 0,1,2,3,4,5,6,7,8,9,10,11
  j vec_slot_\n
  .endr
  .irp n, 1,2,3,4,5,6,7,8,9,10,11
vec_slot_\n:
  li x24, \n
  j mtvec_handler
  .endr
vec_slot_0:
  li x24, 0
  j trap_vector                           # env: ecall -> tohost, else mtvec_handler
direct_entry:
  li x24, 0x40
  j mtvec_handler

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  bltz x28, 1f
  addi t5, x27, 4                         # exception: skip it
  csrw mepc, t5
  mret
1:
  andi t6, x28, 15
  li t5, CLINT_MSIP
  addi t6, t6, -3
  bnez t6, 2f
  sw x0, 0(t5)                            # MSI: msip = 0
  lw t6, 0(t5)
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
