/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S debug test: triggers with debug mode (Sdtrig + Sdext), with the
# testbench mini-DM of dbg.h. Covered: tinfo (version 1, types 6 and 15);
# tdata3 reads 0 and ignores writes; an action-1 trigger configured in debug
# mode (dmode 1) enters debug mode before the instruction (cause 2, dpc = its
# pc, no M trap), sets hit0, and the instruction executes once after the DM
# disarms it; M-mode writes to a dmode trigger's tdata1 / tdata2 are
# ignored; triggers do not fire in debug mode (action 0 with mte and action
# 1); stepping onto an action-1 trigger enters with cause 2 (above step);
# a stepped instruction taken by an action-0 trigger (mte) traps and enters
# on the handler (dpc = mtvec, cause 4, mcause 3); an action-1 trigger on the
# second trigger (if NUM_TRIGGERS > 1).
# mtvec_handler counts traps in x29 (x28 mcause, x27 mepc), skips the
# instruction.
# run.py: no-spike; needs-debug; needs-triggers

#include "riscv_test.h"
#include "test_macros.h"
#include "dbg.h"

#define TYPE6_X     ((6 << 28) | (1 << 6) | (1 << 2))       // mcontrol6, m, execute
#define DMODE       (1 << 27)
#define ACTION1     (1 << 12)
#define HIT0        (1 << 22)
#define TINFO_VAL   ((1 << 24) | (1 << 15) | (1 << 6))

#define MB(off, r)      lw r, off(x21)
#define MB_SET(off, v)  li x5, v; sw x5, off(x21)
#define MB_SETL(off, l) la x5, l; sw x5, off(x21)

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  la x20, irqgen
  la x21, dbg_mbox
  csrw mie, x0
  li x29, 0

  # ---- tinfo, tdata3 -----------------------------------------------------------
  li TESTNUM, 2
  csrw tselect, x0
  csrr x5, tinfo
  li x7, TINFO_VAL
  bne x5, x7, fail
  li x6, -1
  csrw tdata3, x6
  csrr x5, tdata3
  bnez x5, fail

  # ---- action 1 (dmode, set in debug mode): cause 2, dpc = the instruction ---
  li TESTNUM, 3
  MB_SETL(MB_USER1, tgt_3)
  MB_SETL(MB_HOOK, hook_arm)
  DBG_HALT
  MB_SETL(MB_HOOK, hook_disarm)           # disarm on the trigger's entry
  MB(MB_COUNT, x7)
  li x10, 0
tgt_3:
  addi x10, x10, 1                        # executed once, after the DM disarmed
  li x6, 1
  bne x10, x6, fail
  MB(MB_COUNT, x5)
  addi x7, x7, 1
  bne x5, x7, fail
  MB(MB_DPC, x5)
  la x6, tgt_3
  bne x5, x6, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 2
  bne x6, x7, fail                        # cause trigger
  MB(MB_USER0, x5)
  li x7, TYPE6_X | DMODE | ACTION1 | HIT0
  bne x5, x7, fail                        # hit0 seen by the DM before disarming
  bnez x29, fail

  # ---- dmode trigger: M-mode writes ignored ---------------------------------
  li TESTNUM, 4
  MB_SETL(MB_USER1, tgt_4)
  MB_SETL(MB_HOOK, hook_arm)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  csrw tdata1, x0                         # ignored (dmode)
  la x6, tgt_3
  csrw tdata2, x6                         # ignored (dmode)
  csrr x5, tdata1
  li x7, TYPE6_X | DMODE | ACTION1
  bne x5, x7, fail
  csrr x5, tdata2
  la x7, tgt_4
  bne x5, x7, fail
  MB_SETL(MB_HOOK, hook_disarm)
  li x10, 0
tgt_4:
  addi x10, x10, 1
  li x6, 1
  bne x10, x6, fail
  MB(MB_DPC, x5)
  la x6, tgt_4
  bne x5, x6, fail                        # it still fired
  csrr x5, tdata1
  li x7, (15 << 28)
  bne x5, x7, fail                        # disarmed by the DM

  # ---- no trigger fires in debug mode ----------------------------------------
  li TESTNUM, 5
  MB_SETL(MB_USER1, hook_body)            # action 1 on an instruction in a hook
  MB_SETL(MB_HOOK, hook_arm)
  DBG_HALT
  csrw tdata1, x0                         # (dmode: ignored) second trigger: action 0
  li x5, 1
  csrw tselect, x5
  csrr x6, tselect
  bne x5, x6, 1f                          # one trigger only: skip the action-0 part
  la x6, hook_body
  csrw tdata2, x6
  li x6, TYPE6_X
  csrw tdata1, x6
  csrsi tcontrol, 8                       # mte
1:
  csrw tselect, x0
  MB(MB_COUNT, x7)
  MB(MB_EXC, x8)
  MB_SETL(MB_HOOK, hook_run)
  DBG_HALT
  MB(MB_USER0, x5)
  li x6, 1
  bne x5, x6, fail                        # the hook body ran
  MB(MB_COUNT, x5)
  addi x7, x7, 1
  bne x5, x7, fail                        # no re-entry
  MB(MB_EXC, x5)
  bne x5, x8, fail                        # no exception in debug mode
  bnez x29, fail
  MB_SETL(MB_HOOK, hook_clear)            # clear both triggers
  DBG_HALT
  sw x0, MB_HOOK(x21)
  csrci tcontrol, 8

  # ---- step onto an action-1 trigger: cause 2 (above step) ------------------
  li TESTNUM, 6
  MB_SETL(MB_USER1, s6_2)
  MB_SETL(MB_HOOK, hook_arm)
  DBG_HALT
  MB_SETL(MB_HOOK, hook_disarm)
  sw x0, MB_COUNT(x21)
  MB_SETL(MB_DPC_WR, seq_6)
  MB_SET(MB_DCSR_WR, DCSR_STEP | DCSR_PRV_M)
  MB_SET(MB_STEPS, 2)
  DBG_HALT
  j fail
seq_6:
s6_1: nop
s6_2: nop
  MB(MB_COUNT, x5)
  li x7, 2
  bne x5, x7, fail
  MB(MB_LOG + 4, x5)
  la x6, s6_2
  bne x5, x6, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 2
  bne x6, x7, fail
  sw x0, MB_HOOK(x21)
  bnez x29, fail

  # ---- step into an action-0 trigger: trap, entry on the handler -----------
  li TESTNUM, 7
  csrw tselect, x0
  csrw tdata1, x0
  la x6, s7_1
  csrw tdata2, x6
  li x6, TYPE6_X
  csrw tdata1, x6
  csrsi tcontrol, 8                       # mte
  sw x0, MB_COUNT(x21)
  MB_SETL(MB_DPC_WR, seq_7)
  MB_SET(MB_DCSR_WR, DCSR_STEP | DCSR_PRV_M)
  MB_SET(MB_STEPS, 2)
  DBG_HALT
  j fail
seq_7:
s7_1: nop                                 # breakpoint (skipped by the handler)
  csrw tdata1, x0
  csrci tcontrol, 8
  MB(MB_COUNT, x5)
  li x7, 2
  bne x5, x7, fail
  csrr x6, mtvec
  MB(MB_LOG + 4, x5)
  bne x5, x6, fail                        # entry on the handler
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 4
  bne x6, x7, fail                        # cause step
  li x7, 1
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  la x7, s7_1
  bne x27, x7, fail
  li x29, 0

  # ---- action 1 on the second trigger ---------------------------------------
  li TESTNUM, 8
  li x5, 1
  csrw tselect, x5
  csrr x6, tselect
  csrw tselect, x0
  bne x5, x6, 2f                          # one trigger only
  MB_SETL(MB_USER1, tgt_8)
  MB_SETL(MB_HOOK, hook_arm1)
  DBG_HALT
  MB_SETL(MB_HOOK, hook_disarm1)
  MB(MB_COUNT, x7)
  li x10, 0
tgt_8:
  addi x10, x10, 1
  li x6, 1
  bne x10, x6, fail
  MB(MB_COUNT, x5)
  addi x7, x7, 1
  bne x5, x7, fail
  MB(MB_DPC, x5)
  la x6, tgt_8
  bne x5, x6, fail
  MB(MB_USER0, x5)
  li x7, TYPE6_X | DMODE | ACTION1 | HIT0
  bne x5, x7, fail
  sw x0, MB_HOOK(x21)
2:
  bnez x29, fail

  TEST_PASSFAIL

  # ---- hooks (debug mode; x31 = mailbox, may use x29 / x30) -----------------
hook_arm:                                 # trigger 0: action 1, dmode, at MB_USER1
  csrw tselect, x0
  csrw tdata1, x0
  lw x30, MB_USER1(x31)
  csrw tdata2, x30
  li x30, TYPE6_X | DMODE | ACTION1
  csrw tdata1, x30
  ret
hook_disarm:                              # on a trigger entry (cause 2): disarm
  csrr x30, dcsr
  srli x30, x30, 6
  andi x30, x30, 7
  li x29, 2
  bne x30, x29, 1f
  csrw tselect, x0
  csrr x30, tdata1
  sw x30, MB_USER0(x31)
  csrw tdata1, x0
1:
  ret
hook_arm1:                                # trigger 1: action 1, dmode, at MB_USER1
  li x30, 1
  csrw tselect, x30
  csrw tdata1, x0
  lw x30, MB_USER1(x31)
  csrw tdata2, x30
  li x30, TYPE6_X | DMODE | ACTION1
  csrw tdata1, x30
  csrw tselect, x0
  ret
hook_disarm1:                             # on a trigger entry: disarm trigger 1
  csrr x30, dcsr
  srli x30, x30, 6
  andi x30, x30, 7
  li x29, 2
  bne x30, x29, 1f
  li x30, 1
  csrw tselect, x30
  csrr x30, tdata1
  sw x30, MB_USER0(x31)
  csrw tdata1, x0
  csrw tselect, x0
1:
  ret
hook_run:
  sw x0, MB_USER0(x31)
hook_body:
  li x30, 1                               # trigger address (both triggers)
  sw x30, MB_USER0(x31)
  ret
hook_clear:
  li x30, 1
  csrw tselect, x30
  csrw tdata1, x0
  csrw tselect, x0
  csrw tdata1, x0
  ret

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret

  DBG_ROM

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  DBG_DATA
RVTEST_DATA_END
