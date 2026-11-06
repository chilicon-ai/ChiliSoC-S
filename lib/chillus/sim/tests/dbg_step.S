/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S debug test: single step (dcsr.step, riscv-debug-specification.pdf
# 4.5.1) with the testbench mini-DM of dbg.h. A halt redirects dpc to a
# sequence and sets dcsr.step; each step re-enters with cause 4 and the DM
# logs dpc (MB_LOG); MB_STEPS clears step after the last one.
# Covered: dpc after ALU, forward taken branch (mispredicted), backward
# not-taken branch (predicted taken: mispredicted), JAL, JALR, load, store,
# CSR, MUL, DIV, WFI (a nop: no sleep), a 16-bit instruction; an interrupt
# raised in debug mode stays masked while stepping and is taken after the
# last step (mepc = the next instruction); a stepped illegal instruction and
# EBREAK (ebreakm clear) enter on the trap handler (dpc = mtvec, mcause /
# mepc updated, no handler instruction executed); a stepped EBREAK with
# ebreakm enters with cause 1 (dpc = the EBREAK); a jump to an address whose
# fetch faults enters with dpc = that address and no trap.
# mtvec_handler counts traps in x29, x28 = mcause, x27 = mepc; it skips an
# exception's instruction and clears the interrupt lines.
# run.py: no-spike; needs-debug

#include "riscv_test.h"
#include "test_macros.h"
#include "dbg.h"

#define CLINT_MTIMECMP  0x02004000
#define IRQ_FAST0       0x80000010
#define FAULT_PC        0x80100000      // just past the testbench RAM (1 MiB)

#define MB(off, r)      lw r, off(x21)
#define MB_SET(off, v)  li x5, v; sw x5, off(x21)
#define MB_SETL(off, l) la x5, l; sw x5, off(x21)

# check MB_LOG[i] == the address at expected table entry i (x22 = table)
#define LOG_IS(i)       lw x5, MB_LOG + 4 * (i)(x21); lw x6, 4 * (i)(x22); bne x5, x6, fail

# start a step session: dpc = seq, step for n steps, count from 0
#define STEP_START(seq, n) \
  sw x0, MB_COUNT(x21); \
  MB_SETL(MB_DPC_WR, seq); \
  MB_SET(MB_DCSR_WR, DCSR_STEP | DCSR_PRV_M); \
  MB_SET(MB_STEPS, (n) + 1); \
  DBG_HALT

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

  # ---- instruction classes; an interrupt raised at the halt waits ------------
  li TESTNUM, 2
  li x5, (1 << 16)
  csrw mie, x5
  csrsi mstatus, MSTATUS_MIE
  MB_SETL(MB_HOOK, hook_irq)
  la x13, a14
  li x8, 0
  STEP_START(seq_a, 12)
  # not reached: seq_a ends at done_a
  j fail

seq_a:
a1: addi x8, x0, 3
a2: beq x8, x8, a4                        # forward taken (predicted not taken)
a3: j fail
a4: bne x8, x8, a3                        # backward not taken (predicted taken)
a5: jal x9, a7
a6: j fail
a7: lw x10, MB_COUNT(x21)
a8: sw x10, MB_USER1(x21)
a9: csrr x11, mscratch
a10: mul x12, x8, x8
a11: div x12, x12, x8
a12: wfi
a13: jalr x0, 0(x13)
a14:
  .option push
  .option rvc
  c.addi x8, 1
  .option pop
a15:
  j done_a

done_a:
  csrci mstatus, MSTATUS_MIE
  csrw mie, x0
  la x22, exp_a
  LOG_IS(1); LOG_IS(2); LOG_IS(3); LOG_IS(4); LOG_IS(5); LOG_IS(6); LOG_IS(7)
  LOG_IS(8); LOG_IS(9); LOG_IS(10); LOG_IS(11); LOG_IS(12)
  MB(MB_COUNT, x5)
  li x7, 13
  bne x5, x7, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 4
  bne x6, x7, fail                        # last entry: cause step
  li x7, 4
  bne x8, x7, fail                        # every instruction ran once
  li x7, 3
  bne x12, x7, fail
  li x7, 1
  bne x29, x7, fail                       # the interrupt: once, after the steps
  li x7, IRQ_FAST0
  bne x28, x7, fail
  la x7, a15
  bne x27, x7, fail
  li x29, 0

  # ---- stepped traps: entry on the handler (dpc = mtvec), no handler code ----
  li TESTNUM, 3
  sw x0, MB_HOOK(x21)
  STEP_START(seq_b, 1)
  j fail
seq_b:
b1: .word 0                               # illegal
b2: j done_b
done_b:
  csrr x6, mtvec
  MB(MB_LOG + 4, x5)
  bne x5, x6, fail
  li x7, 1
  bne x29, x7, fail                       # the handler ran after the step ended
  li x7, CAUSE_ILLEGAL_INSTRUCTION
  bne x28, x7, fail
  la x7, b1
  bne x27, x7, fail
  li x29, 0

  li TESTNUM, 4
  STEP_START(seq_c, 1)
  j fail
seq_c:
c1: ebreak                                # ebreakm clear: breakpoint exception
c2: j done_c
done_c:
  csrr x6, mtvec
  MB(MB_LOG + 4, x5)
  bne x5, x6, fail
  li x7, 1
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  la x7, c1
  bne x27, x7, fail
  li x29, 0

  # ---- stepped EBREAK with ebreakm: cause 1, dpc = the EBREAK ---------------
  li TESTNUM, 5
  sw x0, MB_COUNT(x21)
  MB_SETL(MB_DPC_WR, seq_d)
  MB_SET(MB_DCSR_WR, DCSR_STEP | DCSR_EBREAKM | DCSR_PRV_M)
  MB_SET(MB_STEPS, 2)
  MB_SETL(MB_USER1, done_d)
  MB_SETL(MB_HOOK, hook_resume)           # entry 1: resume at done_d
  DBG_HALT
  j fail
seq_d:
d1: ebreak
  j fail
done_d:
  sw x0, MB_HOOK(x21)
  MB(MB_COUNT, x5)
  li x7, 2
  bne x5, x7, fail
  MB(MB_LOG + 4, x5)
  la x6, d1
  bne x5, x6, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 1
  bne x6, x7, fail                        # ebreak above step
  bnez x29, fail
  MB_SET(MB_DCSR_WR, DCSR_PRV_M)          # ebreakm off
  DBG_HALT

  # ---- step into a faulting fetch: dpc = the address, no trap --------------
  li TESTNUM, 6
  li x14, FAULT_PC
  MB_SETL(MB_USER1, done_e)
  MB_SETL(MB_HOOK, hook_resume)
  sw x0, MB_COUNT(x21)
  MB_SETL(MB_DPC_WR, seq_e)
  MB_SET(MB_DCSR_WR, DCSR_STEP | DCSR_PRV_M)
  MB_SET(MB_STEPS, 2)
  DBG_HALT
  j fail
seq_e:
e1: jalr x0, 0(x14)
  j fail
done_e:
  sw x0, MB_HOOK(x21)
  MB(MB_LOG + 4, x5)
  li x6, FAULT_PC
  bne x5, x6, fail
  bnez x29, fail                          # no access fault raised

  TEST_PASSFAIL

  # ---- hooks (debug mode; x31 = mailbox, may use x29 / x30) -----------------
hook_irq:                                 # raise irq_fast[0], once
  la x29, irqgen
  li x30, 1
  sw x30, 0(x29)
  lw x30, 0(x29)
  fence
  sw x0, MB_HOOK(x31)
  ret
hook_resume:                              # from the second entry: dpc = MB_USER1
  lw x30, MB_COUNT(x31)
  li x29, 2
  bltu x30, x29, 1f
  lw x30, MB_USER1(x31)
  csrw dpc, x30
1:
  ret

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  bltz x28, 1f
  addi t5, x27, 4                         # exception: skip the instruction
  csrw mepc, t5
  mret
1:
  sw x0, 0(x20)                           # interrupt: clear the lines
  lw t5, 0(x20)
  fence
  mret

  DBG_ROM

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 4
exp_a:                                    # dpc logged by step entries 1 .. 12
  .word 0, a2, a4, a5, a7, a8, a9, a10, a11, a12, a13, a14, a15
  DBG_DATA
RVTEST_DATA_END
