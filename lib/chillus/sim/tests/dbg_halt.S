/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S debug test: debug mode entry by halt request and EBREAK, and the
# rules in debug mode (riscv-debug-specification.pdf 4.1), with the
# testbench mini-DM of dbg.h (code at DM_HALT_ADDR, mailbox dbg_mbox).
# Covered: haltreq entry (cause 3, debugver 4, prv 3, dpc = the next
# instruction, mepc / mcause / mtval / mstatus unchanged, no trap); haltreq
# and an interrupt raised in the same cycle (haltreq first; the interrupt
# is taken after dret with mepc = dpc); EBREAK with dcsr.ebreakm (cause 1,
# dpc = the EBREAK, no trap); in debug mode: EBREAK re-enters the halt
# address (dpc / dcsr unchanged), an illegal instruction and a load access
# fault go to the exception address with no CSR change, dscratch0 and dpc
# read back (dpc[0] = 0), WFI is a nop, an NMI stays pending (dcsr.nmip) and
# is taken after dret (mepc = dpc), dcsr.stopcount stops mcycle / minstret;
# a halt request while asleep in WFI enters with dpc = WFI + 4 (cause 3); a
# load / store right before dret that gets a bus error is an exception in
# debug mode (exception address, dret not executed, no M trap).
# mtvec_handler counts traps in x29, x28 = mcause, x27 = mepc; it skips an
# exception's instruction and clears the interrupt lines.
# run.py: no-spike; needs-debug

#include "riscv_test.h"
#include "test_macros.h"
#include "dbg.h"

#define CLINT_MTIMECMP  0x02004000
#define IRQ_FAST0       0x80000010
#define IRQ_NMI         0x8000001f

#define MB(off, r)      lw r, off(x21)
#define MB_SET(off, v)  li x5, v; sw x5, off(x21)
#define MB_SETL(off, l) la x5, l; sw x5, off(x21)

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

  # ---- haltreq: cause 3, dpc in the spin loop, M CSRs unchanged -------------
  li TESTNUM, 2
  li x5, 0x80001234
  csrw mepc, x5
  li x5, 5
  csrw mcause, x5
  li x5, 0x5555
  csrw mtval, x5
  csrr x8, mstatus
halt_2:
  DBG_HALT
halt_2_end:
  MB(MB_COUNT, x5)
  li x7, 1
  bne x5, x7, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 28
  li x7, 4
  bne x6, x7, fail                        # debugver 4
  andi x6, x5, 3
  li x7, 3
  bne x6, x7, fail                        # prv M
  li x7, DCSR_STOPCOUNT | DCSR_STEP | DCSR_EBREAKM
  and x6, x5, x7
  bnez x6, fail                           # reset values 0
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 3
  bne x6, x7, fail                        # cause haltreq
  MB(MB_DPC, x5)
  la x6, halt_2
  bltu x5, x6, fail
  la x6, halt_2_end
  bgtu x5, x6, fail
  csrr x5, mepc
  li x7, 0x80001234
  bne x5, x7, fail
  csrr x5, mcause
  li x7, 5
  bne x5, x7, fail
  csrr x5, mtval
  li x7, 0x5555
  bne x5, x7, fail
  csrr x5, mstatus
  bne x5, x8, fail
  bnez x29, fail

  # ---- haltreq and an interrupt in the same cycle: haltreq first ------------
  li TESTNUM, 3
  li x5, (1 << 16)
  csrw mie, x5
  csrsi mstatus, MSTATUS_MIE
  MB(MB_COUNT, x7)
  DBG_GEN_OR(DBG_REQ | 1)
1:
  MB(MB_COUNT, x5)
  beq x5, x7, 1b
  csrci mstatus, MSTATUS_MIE
  csrw mie, x0
  li x7, 1
  bne x29, x7, fail                       # the interrupt was taken after dret
  li x7, IRQ_FAST0
  bne x28, x7, fail
  MB(MB_DPC, x5)
  bne x27, x5, fail                       # on the instruction at dpc
  MB(MB_COUNT, x5)
  li x7, 2
  bne x5, x7, fail
  li x29, 0

  # ---- EBREAK with ebreakm: cause 1, dpc = the EBREAK, no trap --------------
  li TESTNUM, 4
  MB_SET(MB_DCSR_WR, DCSR_EBREAKM | DCSR_PRV_M)
  DBG_HALT
  MB_SETL(MB_DPC_WR, ebrk_4 + 4)
  MB_SET(MB_DCSR_WR, DCSR_PRV_M)          # the EBREAK's entry clears ebreakm
  MB(MB_COUNT, x7)
ebrk_4:
  ebreak
  MB(MB_COUNT, x5)
  addi x7, x7, 1
  bne x5, x7, fail
  MB(MB_DPC, x5)
  la x6, ebrk_4
  bne x5, x6, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 1
  bne x6, x7, fail                        # cause ebreak
  bnez x29, fail
  csrr x5, mcause
  li x7, IRQ_FAST0
  bne x5, x7, fail                        # no M trap since test 3

  # ---- EBREAK in debug mode: back to the halt address, no change -----------
  li TESTNUM, 5
  MB_SETL(MB_HOOK, hook_ebreak)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_EBREAK, x5)
  li x7, 1
  bne x5, x7, fail
  MB(MB_USER0, x5)
  MB(MB_DPC, x6)
  bne x5, x6, fail                        # dpc unchanged
  MB(MB_USER1, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 3
  bne x6, x7, fail                        # cause unchanged (haltreq)
  bnez x29, fail

  # ---- exceptions in debug mode: exception address, no CSR change ----------
  li TESTNUM, 6
  li x5, 0x80004320
  csrw mepc, x5
  li x5, 7
  csrw mcause, x5
  csrw mtval, x0
  MB_SETL(MB_HOOK, hook_illegal)
  DBG_HALT
  MB_SETL(MB_HOOK, hook_fault)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_EXC, x5)
  li x7, 2
  bne x5, x7, fail
  csrr x5, mepc
  li x7, 0x80004320
  bne x5, x7, fail
  csrr x5, mcause
  li x7, 7
  bne x5, x7, fail
  csrr x5, mtval
  bnez x5, fail
  bnez x29, fail

  # ---- debug CSRs in debug mode: dscratch0, dpc[0] = 0 ---------------------
  li TESTNUM, 7
  MB_SETL(MB_HOOK, hook_csrs)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_USER0, x5)
  li x7, 0x5a5a1234
  bne x5, x7, fail
  MB(MB_USER1, x5)
  MB(MB_DPC, x6)
  bne x5, x6, fail

  # ---- WFI in debug mode is a nop ------------------------------------------
  li TESTNUM, 8
  MB_SETL(MB_HOOK, hook_wfi)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_USER0, x5)
  li x7, 1
  bne x5, x7, fail

  # ---- NMI in debug mode: pending (nmip), taken after dret -----------------
  li TESTNUM, 9
  MB_SETL(MB_HOOK, hook_nmi)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_USER0, x5)
  andi x5, x5, DCSR_NMIP
  beqz x5, fail
  li x7, 1
  bne x29, x7, fail
  li x7, IRQ_NMI
  bne x28, x7, fail
  MB(MB_DPC, x5)
  bne x27, x5, fail
  li x29, 0

  # ---- stopcount: mcycle / minstret stop in debug mode ----------------------
  li TESTNUM, 10
  MB_SET(MB_DCSR_WR, DCSR_STOPCOUNT | DCSR_PRV_M)
  DBG_HALT
  MB_SETL(MB_HOOK, hook_count)
  MB_SET(MB_DCSR_WR, DCSR_PRV_M)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_USER0, x5)
  bnez x5, fail
  MB(MB_USER1, x5)
  bnez x5, fail
  MB_SETL(MB_HOOK, hook_count)            # stopcount clear: they count
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_USER0, x5)
  beqz x5, fail
  MB(MB_USER1, x5)
  beqz x5, fail

  # ---- haltreq while asleep in WFI: dpc = WFI + 4 ---------------------------
  li TESTNUM, 11
  MB(MB_COUNT, x7)
  DBG_GEN_OR(DBG_WAKE)
wfi_11:
  wfi
  MB(MB_COUNT, x5)
  addi x7, x7, 1
  bne x5, x7, fail
  MB(MB_DPC, x5)
  la x6, wfi_11 + 4
  bne x5, x6, fail
  MB(MB_DCSR, x5)
  srli x6, x5, 6
  andi x6, x6, 7
  li x7, 3
  bne x6, x7, fail
  bnez x29, fail

  # ---- bus error on the access right before dret: caught in debug mode ------
  li TESTNUM, 12
  sw x0, MB_EXC(x21)
  MB_SETL(MB_HOOK, hook_ld_dret)
  DBG_HALT
  MB_SETL(MB_HOOK, hook_st_dret)
  DBG_HALT
  sw x0, MB_HOOK(x21)
  MB(MB_EXC, x5)
  li x7, 2
  bne x5, x7, fail
  bnez x29, fail
  csrr x5, mepc
  li x7, 0x80004320
  bne x5, x7, fail                        # unchanged since test 6

  TEST_PASSFAIL

  # ---- hooks (debug mode; x31 = mailbox, may use x29 / x30) -----------------
hook_ebreak:
  ebreak
  ret
hook_illegal:
  .word 0
  ret
hook_fault:
  lw x30, 0(x0)                           # no memory at 0: load access fault
  ret
hook_ld_dret:                             # the fault must kill the dret
  lw x30, 0(x0)
  dret
hook_st_dret:
  sw x0, 0(x0)
  dret
hook_csrs:
  li x30, 0x5a5a1234
  csrw dscratch0, x30
  csrr x29, dscratch0
  sw x29, MB_USER0(x31)
  csrr x30, dpc
  ori x29, x30, 1
  csrw dpc, x29
  csrr x29, dpc
  sw x29, MB_USER1(x31)
  csrw dpc, x30
  ret
hook_wfi:
  wfi
  li x30, 1
  sw x30, MB_USER0(x31)
  ret
hook_nmi:
  la x29, irqgen
  li x30, 0x80000000
  sw x30, 0(x29)
  lw x30, 0(x29)
  fence
  nop
  nop
  nop
  nop
  csrr x30, dcsr
  sw x30, MB_USER0(x31)
  ret
hook_count:
  csrr x29, mcycle
  nop
  nop
  csrr x30, mcycle
  sub x30, x30, x29
  sw x30, MB_USER0(x31)
  csrr x29, minstret
  nop
  nop
  csrr x30, minstret
  sub x30, x30, x29
  sw x30, MB_USER1(x31)
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
  DBG_DATA
RVTEST_DATA_END
