/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: local (fast) interrupts, the external interrupt
# input and the NMI, driven by the testbench's interrupt generator (a store
# to the word `irqgen` sets irq_fast [14:0], irq_external [15], irq_nmi [31]).
# Covered: mip shows the fast and external lines; mie has writable bits for
# them (16 to 30, and 3 / 7 / 11); a pending, enabled fast interrupt waits for
# mstatus.MIE; priority irq_fast[0] first, then higher fast lines, then
# MEI; Vectored entry at BASE + 4 * code (16 + i, 11, 31) and Direct entry at
# BASE; the NMI is taken with MIE = 0 and mie = 0 (mcause 0x8000_001f), blocks
# itself and every other interrupt while its handler runs (even with MIE
# set), and its MRET restores mepc / mcause / MPIE of an interrupt handler it
# preempted (MPIE set to 0 there first, so a restore to 1 is caught).
# Spike has no such interrupt lines, so the test checks itself (no trace
# comparison). Each vector slot sets x24 to its number (0x40: the Direct-mode
# entry); mtvec_handler logs every trap: x29 count, x28 mcause, x27 mepc,
# x26 mstatus, x25 a code log (5 bits per trap, newest lowest), and clears
# the source in x19 (the generator's value, stored to irqgen). x18 selects a
# special case in the handler (1: raise an NMI inside a fast handler, 2: try
# to re-enter the NMI handler, 3: raise an NMI inside an exception handler).
# run.py: no-spike

#include "riscv_test.h"
#include "test_macros.h"

#define CLINT_MTIMECMP  0x02004000
#define IRQ_MEI         0x8000000b
#define IRQ_NMI         0x8000001f
#define MIE_ALL         0x7fff0888

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
  li x19, 0
  li x18, 0
  la x5, vec_table
  ori x5, x5, 1
  csrw mtvec, x5                          # Vectored

  # ---- mip / mie: fast lines 16 .. 30, external 11 ----------------------------
  li TESTNUM, 2
  li x19, 0xffff
  GEN_SET(x19)
  csrr x5, mip
  li x7, 0x7fff0800
  bne x5, x7, fail
  li x5, -1
  csrw mie, x5
  csrr x6, mie
  li x7, MIE_ALL
  bne x6, x7, fail
  nop
  bnez x29, fail                          # MIE = 0: nothing taken
  li x19, 0
  GEN_SET(x19)
  csrr x5, mip
  bnez x5, fail

  # ---- priority: fast 2, fast 5, MEI (all pending at once) ------------------
  li TESTNUM, 3
  li x19, (1 << 15) | (1 << 5) | (1 << 2)
  GEN_SET(x19)
  li x25, 0
  csrsi mstatus, MSTATUS_MIE              # taken one after the other
irq_epc_3:
  csrci mstatus, MSTATUS_MIE
  li x7, (18 << 10) | (21 << 5) | 11
  bne x25, x7, fail
  li x7, 11                               # the last one through slot 11
  bne x24, x7, fail
  li x7, IRQ_MEI
  bne x28, x7, fail
  la x7, irq_epc_3
  bne x27, x7, fail
  bnez x19, fail

  # ---- the highest fast line in Vectored mode: slot 30 ----------------------
  li TESTNUM, 4
  li x19, (1 << 14)
  GEN_SET(x19)
  csrsi mstatus, MSTATUS_MIE
  csrci mstatus, MSTATUS_MIE
  li x7, 30
  bne x24, x7, fail
  li x7, 0x8000001e
  bne x28, x7, fail

  # ---- NMI: taken with MIE = 0 and mie = 0, slot 31 ----------------------------
  li TESTNUM, 5
  csrw mie, x0
  li x24, -1
  li x19, 0x80000000
  GEN_SET(x19)
  nop
  nop
  li x7, 31
  bne x24, x7, fail
  li x7, IRQ_NMI
  bne x28, x7, fail
  andi x7, x26, MSTATUS_MPIE
  bnez x7, fail                           # MIE was 0 when it was taken
  bnez x19, fail

  # ---- NMI inside a fast handler: its MRET restores the handler state ------
  li TESTNUM, 6
  li x7, MIE_ALL
  csrw mie, x7
  li x18, 1
  li x19, (1 << 3)
  GEN_SET(x19)
  li x25, 0
  csrsi mstatus, MSTATUS_MIE
irq_epc_6:
  csrci mstatus, MSTATUS_MIE
  bnez x18, fail                          # the handler ran its case 1
  li x7, (19 << 10) | (31 << 5) | 19      # fast 3, NMI, fast 3 (after the NMI's mret)
  bne x25, x7, fail
  la x7, irq_epc_6
  bne x27, x7, fail
  bnez x19, fail

  # ---- the NMI blocks itself and every other interrupt -----------------------
  li TESTNUM, 7
  li x18, 2
  li x25, 0
  li x19, 0x80000000
  GEN_SET(x19)                            # NMI; its handler sets fast 0 and MIE
  nop
  nop
  csrsi mstatus, MSTATUS_MIE              # fast 0, still pending, now taken
  csrci mstatus, MSTATUS_MIE
  bnez x18, fail
  li x7, (31 << 5) | 16                   # NMI, then fast 0 after its mret
  bne x25, x7, fail
  bnez x19, fail

  # ---- NMI inside an exception handler -----------------------------------------
  li TESTNUM, 8
  li x18, 3
  li x25, 0
  ebreak
  bnez x18, fail
  li x7, (3 << 5) | 31                    # breakpoint, NMI
  bne x25, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  bnez x19, fail

  # ---- Direct mode: a fast interrupt enters at BASE --------------------------
  li TESTNUM, 9
  la x5, direct_entry
  csrw mtvec, x5
  li x19, (1 << 7)
  GEN_SET(x19)
  li x24, -1
  csrsi mstatus, MSTATUS_MIE
  csrci mstatus, MSTATUS_MIE
  li x7, 0x40
  bne x24, x7, fail
  li x7, 0x80000017
  bne x28, x7, fail

  li TESTNUM, 10
  li x7, 12                               # traps so far
  bne x29, x7, fail
  csrw mie, x0
  la x5, trap_vector
  csrw mtvec, x5                          # the env's again, for the final ecall
  TEST_PASSFAIL

  # ---- vector table: slot n sets x24 = n --------------------------------------
  .balign 128
vec_table:
  .irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
  j vec_slot_\n
  .endr
  .irp n, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
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
  csrr x26, mstatus
  bltz x28, 1f
  li t5, 3                                # an exception: only case 3's ebreak
  bne x18, t5, fail
  j h_exc
1:
  andi t6, x28, 31
  slli x25, x25, 5
  or x25, x25, t6                         # code log
  li t5, 31
  beq t6, t5, h_nmi
  li t5, 1
  beq x18, t5, h_nested
  li t5, 11
  beq t6, t5, h_mei
  addi t6, t6, -16                        # fast i = code - 16
  li t5, 1
  sll t5, t5, t6
  j h_clear
h_mei:
  li t5, (1 << 15)
  j h_clear
h_nmi:
  li t5, 2
  bne x18, t5, 1f
  # case 2: NMI held, fast 0 pending and enabled, MIE set: nothing taken
  li x18, 0
  li t5, 1
  or x19, x19, t5
  GEN_SET(x19)
  csrsi mstatus, MSTATUS_MIE
  nop
  nop
  nop
  csrci mstatus, MSTATUS_MIE
  li t6, 31                               # only this NMI so far in this case
  bne x25, t6, 2f
  j 1f
2:
  li x25, 0x3ff                           # mark the failure for the main code
1:
  li t5, 0x80000000
  j h_clear
h_nested:
  # case 1: raise the NMI inside this fast handler
  li x18, 0
  mv x17, x28                             # this handler's mcause / mepc
  mv x16, x27
  li t5, MSTATUS_MPIE
  csrc mstatus, t5                        # MPIE = 0: the NMI's MRET must restore 0
  li t5, 0x80000000
  or x19, x19, t5
  GEN_SET(x19)
  nop                                     # the NMI is taken here
  nop
  csrr t5, mcause
  bne t5, x17, fail
  csrr t5, mepc
  bne t5, x16, fail
  csrr t5, mstatus
  andi t5, t5, MSTATUS_MPIE
  bnez t5, fail                           # MPIE restored to 0
  li t5, MSTATUS_MPIE
  csrs mstatus, t5                        # back to 1 for this handler's mret
  bnez x19, 1f                            # the NMI handler cleared its bit only
  j fail
1:
  mv x28, x17                             # log this handler once more
  mv x27, x16
  andi t6, x28, 31
  slli x25, x25, 5
  or x25, x25, t6
  addi t6, t6, -16
  li t5, 1
  sll t5, t5, t6
  j h_clear
h_exc:
  # case 3: raise the NMI inside an exception handler (mcause.Interrupt = 0)
  andi t6, x28, 31
  slli x25, x25, 5
  or x25, x25, t6                         # code log
  li x18, 0
  mv x17, x28
  li t5, 0x80000000
  or x19, x19, t5
  GEN_SET(x19)
  nop                                     # the NMI is taken here
  nop
  csrr t5, mcause
  bne t5, x17, fail                       # breakpoint again, Interrupt = 0
  mv x28, x17
  csrr t5, mepc
  addi t5, t5, 4                          # skip the ebreak
  csrw mepc, t5
  mret
h_clear:
  not t5, t5
  and x19, x19, t5
  GEN_SET(x19)
  mret
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 4
  .global irqgen
irqgen: .word 0
RVTEST_DATA_END
