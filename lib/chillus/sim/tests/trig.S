/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S trigger test (Sdtrig, mcontrol6 execute-address triggers, action
# 0), compared with Spike (run.py gives Spike the build's NUM_TRIGGERS).
# Covered: tselect enumeration ends at the read-back mismatch; reset and
# "write 0" read type 15 (disabled); tdata2 reads back any value; an execute
# trigger (m, execute) read back; with tcontrol.mte = 0 it does not fire;
# with mte = 1 it fires before the instruction: mcause 3 (breakpoint),
# mepc = mtval = its pc, the instruction does not execute (a load: rd
# unchanged), in the handler mte = 0 / mpte = 1, mret restores mte = 1, hit0
# set; a trigger write directly followed by the matching instruction (and a
# tdata2 write likewise: refetch); a 16-bit instruction; m = 0 never fires;
# action 1 written from M-mode (dmode 0) reads back 0 and fires as a
# breakpoint; the second trigger (if NUM_TRIGGERS > 1) fires on its own
# address while the first stays armed.
# Not compared with Spike, so not used: tinfo (Spike lists more types),
# types other than 6 and 15, match / select / size / chain / load / store.
# mtvec_handler: x29 trap count, x28 mcause, x27 mepc, x26 mtval, x25
# tcontrol; skips the instruction (mepc + its length).
# run.py: needs-triggers

#include "riscv_test.h"
#include "test_macros.h"

#define TYPE6_X     ((6 << 28) | (1 << 6) | (1 << 2))       // mcontrol6, m, execute
#define TYPE6_X_A1  (TYPE6_X | (1 << 12))                     // ... action 1
#define TYPE6_NOM   ((6 << 28) | (1 << 2))                    // execute, m = 0
#define DISABLED    (15 << 28)
#define HIT0        (1 << 22)
#define TC_MTE      (1 << 3)
#define TC_MPTE     (1 << 7)

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x29, 0

  # ---- enumeration: tselect stops at the last trigger ------------------------
  li TESTNUM, 2
  li x10, 0                               # number of triggers
1:
  csrw tselect, x10
  csrr x5, tselect
  bne x5, x10, 2f
  addi x10, x10, 1
  li x7, 8
  bltu x10, x7, 1b
2:
  beqz x10, fail

  # ---- reset value and write 0: disabled (type 15) ---------------------------
  li TESTNUM, 3
  csrw tselect, x0
  csrr x5, tdata1
  li x7, DISABLED
  bne x5, x7, fail
  csrw tdata1, x0
  csrr x5, tdata1
  bne x5, x7, fail
  li x6, 0x12345678
  csrw tdata2, x6
  csrr x5, tdata2
  bne x5, x6, fail
  csrr x5, tdata3
  bnez x5, fail
  csrr x5, tcontrol
  bnez x5, fail

  # ---- execute trigger, mte = 0: no fire -------------------------------------
  li TESTNUM, 4
  la x6, tgt_4
  csrw tdata2, x6
  li x6, TYPE6_X
  csrw tdata1, x6
  csrr x5, tdata1
  bne x5, x6, fail
  li x11, 0
tgt_4:
  addi x11, x11, 1
  li x7, 1
  bne x11, x7, fail
  bnez x29, fail

  # ---- mte = 1: fires before the instruction ---------------------------------
  li TESTNUM, 5
  la x6, tgt_5
  csrw tdata2, x6
  csrsi tcontrol, TC_MTE
  li x11, 0
tgt_5:
  addi x11, x11, 1                        # not executed
  bnez x11, fail
  li x7, 1
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  la x7, tgt_5
  bne x27, x7, fail
  bne x26, x7, fail                       # mtval = pc
  li x7, TC_MPTE
  bne x25, x7, fail                       # in the handler: mte 0, mpte 1
  csrr x5, tcontrol
  li x7, TC_MPTE | TC_MTE
  bne x5, x7, fail                        # mret: mte = mpte
  csrr x5, tdata1
  li x7, TYPE6_X | HIT0
  bne x5, x7, fail                        # hit0 set
  li x6, TYPE6_X
  csrw tdata1, x6                         # clear hit0
  csrr x5, tdata1
  bne x5, x6, fail

  # ---- a load: not executed (rd unchanged) -----------------------------------
  li TESTNUM, 6
  la x6, tgt_6
  csrw tdata2, x6
  la x12, tdat
  li x13, 0x77
tgt_6:
  lw x13, 0(x12)
  li x7, 0x77
  bne x13, x7, fail
  li x7, 2
  bne x29, x7, fail

  # ---- write directly followed by the match (refetch) -----------------------
  li TESTNUM, 7
  la x6, tgt_7a
  li x14, 0
  csrw tdata2, x6
tgt_7a:
  addi x14, x14, 1                        # matched right after the tdata2 write
  csrw tdata1, x0
  la x6, tgt_7b
  csrw tdata2, x6
  li x6, TYPE6_X
  csrw tdata1, x6
tgt_7b:
  addi x14, x14, 2                        # matched right after the tdata1 write
  bnez x14, fail
  li x7, 4
  bne x29, x7, fail

  # ---- a 16-bit instruction -----------------------------------------------
  li TESTNUM, 8
  la x6, tgt_8
  csrw tdata2, x6
  li x15, 0
  .option push
  .option rvc
tgt_8:
  c.addi x15, 1
  .option pop
  bnez x15, fail
  li x7, 5
  bne x29, x7, fail
  la x7, tgt_8
  bne x27, x7, fail

  # ---- m = 0: never fires ------------------------------------------------------
  li TESTNUM, 9
  la x6, tgt_9
  csrw tdata2, x6
  li x6, TYPE6_NOM
  csrw tdata1, x6
  csrr x5, tdata1
  bne x5, x6, fail
  li x16, 0
tgt_9:
  addi x16, x16, 1
  beqz x16, fail
  li x7, 5
  bne x29, x7, fail

  # ---- action 1 from M-mode (dmode 0): reads 0, fires as a breakpoint ------
  li TESTNUM, 10
  li x6, TYPE6_X_A1
  csrw tdata1, x6
  csrr x5, tdata1
  li x7, TYPE6_X
  bne x5, x7, fail
tgt_10:
  addi x16, x16, 1                        # tdata2 = tgt_9: no match here
  la x6, tgt_10b
  csrw tdata2, x6
tgt_10b:
  addi x16, x16, 1
  li x7, 6
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail

  # ---- second trigger: fires on its own address, the first stays armed -------
  li TESTNUM, 11
  li x7, 2
  bltu x10, x7, 3f
  la x6, tgt_11a
  csrw tdata2, x6                         # trigger 0
  li x6, TYPE6_X
  csrw tdata1, x6
  li x5, 1
  csrw tselect, x5
  csrw tdata1, x0
  la x6, tgt_11b
  csrw tdata2, x6
  li x6, TYPE6_X
  csrw tdata1, x6
tgt_11a:
  nop
tgt_11b:
  nop
  li x7, 8
  bne x29, x7, fail
  la x7, tgt_11b
  bne x27, x7, fail
  csrr x5, tdata1
  li x7, TYPE6_X | HIT0
  bne x5, x7, fail                        # trigger 1 hit
  csrw tdata1, x0
  csrw tselect, x0
3:
  csrw tdata1, x0

  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  csrr x26, mtval
  csrr x25, tcontrol
  lhu t5, 0(x27)                          # skip the instruction (16 or 32 bits)
  andi t5, t5, 3
  li t6, 3
  addi x27, x27, 2
  bne t5, t6, 1f
  addi x27, x27, 2
1:
  csrw mepc, x27
  addi x27, x27, -2
  bne t5, t6, 2f
  addi x27, x27, -2
2:
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
tdat: .word 0x5555
RVTEST_DATA_END
