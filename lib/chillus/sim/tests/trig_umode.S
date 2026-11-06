/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S trigger test: the mcontrol6 u bit (Sdtrig with U-mode).
# Covered: tdata1.u reads back; an execute trigger with u = 1 (action 0)
# raises a breakpoint exception in U (mcause 3, mepc = its pc) and not in M;
# with m = 1 alone (and mte) it fires in M and not in U; with m = u = 0 it
# never fires.
# Handler as in umode.S: ECALL with a7 = 0 returns to M at x22 (TO_M), a7 =
# 93 goes to trap_vector; other traps: x29 count, x28 mcause, x27 mepc;
# exceptions skip the instruction.
# run.py: no-spike; needs-triggers

#include "riscv_test.h"
#include "test_macros.h"

#define TYPE6_X     ((6 << 28) | (1 << 2))  // mcontrol6, execute
#define TRIG_M      (1 << 6)
#define TRIG_U      (1 << 3)

# M -> U: MRET with MPP = U to the next instruction
#define TO_U \
  la t0, 1f; csrw mepc, t0; li t0, MSTATUS_MPP; csrc mstatus, t0; mret; 1:

# U -> M: service ECALL, continues at the next instruction in M-mode
#define TO_M \
  la x22, 1f; li a7, 0; ecall; j fail; 1:

# call tgt in M and in U: x10 = times its addi ran, x29 = traps
#define RUN_BOTH \
  li x10, 0; li x29, 0; jal tgt; TO_U; jal tgt; TO_M

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  la t0, handler
  csrw mtvec, t0
  csrw tselect, x0
  la x5, tgt
  csrw tdata2, x5

  # ---- u = 1: fires in U only ------------------------------------------------
  li TESTNUM, 2
  li x5, TYPE6_X | TRIG_U
  csrw tdata1, x5
  csrr x6, tdata1
  bne x6, x5, fail                        # u reads back
  RUN_BOTH
  li x7, 1
  bne x10, x7, fail                       # ran in M only
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  la x7, tgt
  bne x27, x7, fail

  # ---- m = 1 (mte): fires in M only -----------------------------------------
  li TESTNUM, 3
  li x5, TYPE6_X | TRIG_M
  csrw tdata1, x5
  csrsi tcontrol, 8                       # mte
  RUN_BOTH
  li x7, 1
  bne x10, x7, fail                       # ran in U only
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail

  # ---- m = u = 0: never fires -------------------------------------------------
  li TESTNUM, 4
  li x5, TYPE6_X
  csrw tdata1, x5
  csrsi tcontrol, 8                       # mte
  RUN_BOTH
  li x7, 2
  bne x10, x7, fail
  bnez x29, fail
  csrw tdata1, x0

  la t0, trap_vector                      # RVTEST_PASS / FAIL from M-mode
  csrw mtvec, t0
  TEST_PASSFAIL

tgt:
  addi x10, x10, 1
  ret

  .pushsection .text, "ax"                # own section: 4-byte aligned for mtvec
  .balign 4
handler:
  csrr t5, mcause
  li t6, CAUSE_USER_ECALL
  bne t5, t6, 1f
  li t6, 93                               # RVTEST_PASS / FAIL in U-mode
  beq a7, t6, trap_vector
  csrw mepc, x22                          # TO_M: back to M at x22
  li t6, MSTATUS_MPP
  csrs mstatus, t6
  mret
1:
  li t6, CAUSE_MACHINE_ECALL
  beq t5, t6, trap_vector
  addi x29, x29, 1
  mv x28, t5
  csrr x27, mepc
  csrr t5, mepc                           # exception: skip the instruction
  addi t5, t5, 4
  csrw mepc, t5
  mret
  .popsection

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
