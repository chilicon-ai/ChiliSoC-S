/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S debug test: debug mode with U-mode (riscv-debug-specification.pdf
# 4.9.1 dcsr), with the testbench mini-DM of dbg.h.
# Covered: a halt request in U enters with dcsr.prv = 0 and dret returns to
# U; the DM writing dcsr.prv = 3 makes dret return to M, prv = 0 from an M
# halt returns to U (and clears mstatus.MPRV); dcsr.prv 01 / 10 read as U;
# EBREAK in U enters debug mode with dcsr.ebreaku (cause 1, prv 0, dpc = the
# EBREAK) and traps to M without it (also with ebreakm alone); EBREAK in M
# with ebreaku alone traps to M.
# The mode after a dret is told by `csrr mscratch`: it traps in U only.
# Handler as in umode.S: ECALL with a7 = 0 (from U or M) returns to M at x22
# (TO_M), a7 = 93 goes to trap_vector; other traps: x29 count, x28 mcause,
# x27 mepc; exceptions skip the instruction.
# run.py: no-spike; needs-debug

#include "riscv_test.h"
#include "test_macros.h"
#include "dbg.h"

#define CLINT_MTIMECMP  0x02004000
#define DCSR_EBREAKU    (1 << 12)

#define MB(off, r)      lw r, off(x21)
#define MB_SET(off, v)  li x5, v; sw x5, off(x21)
#define MB_SETL(off, l) la x5, l; sw x5, off(x21)

# M -> U: MRET with MPP = U to the next instruction
#define TO_U \
  la t0, 1f; csrw mepc, t0; li t0, MSTATUS_MPP; csrc mstatus, t0; mret; 1:

# U or M -> M: service ECALL, continues at the next instruction in M-mode
#define TO_M \
  la x22, 1f; li a7, 0; ecall; j fail; 1:

# x9 = 1 if running in U (csrr mscratch traps), else 0; uses x10
#define MODE_U \
  mv x10, x29; csrr x5, mscratch; sub x9, x29, x10

# last debug entry: cause, prv
#define CHECK_ENTRY(cause, prv) \
  MB(MB_DCSR, x5); srli x6, x5, 6; andi x6, x6, 7; li x7, cause; \
  bne x6, x7, fail; andi x6, x5, 3; li x7, prv; bne x6, x7, fail

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x5, CLINT_MTIMECMP
  li x6, -1
  sw x6, 4(x5)                            # mtimecmp hi = max: no timer interrupt
  lw x6, 4(x5)
  la t0, handler
  csrw mtvec, t0
  la x20, irqgen
  la x21, dbg_mbox
  csrw mie, x0
  li x29, 0

  # ---- halt request in U: prv = 0, dret back to U ----------------------------
  li TESTNUM, 2
  TO_U
  DBG_HALT
  MODE_U
  TO_M
  li x7, 1
  bne x9, x7, fail                        # was in U after dret
  CHECK_ENTRY(3, 0)
  MB(MB_COUNT, x5)
  li x7, 1
  bne x5, x7, fail
  li x29, 0

  # ---- halt in U, the DM sets prv = M: dret returns to M --------------------
  li TESTNUM, 3
  MB_SET(MB_DCSR_WR, DCSR_PRV_M)
  TO_U
  DBG_HALT
  MODE_U
  bnez x9, fail                           # in M after dret
  CHECK_ENTRY(3, 0)
  TO_M

  # ---- halt in M with MPRV = 1, the DM sets prv = U: dret to U, MPRV = 0 -----
  li TESTNUM, 4
  li x5, MSTATUS_MPRV
  csrs mstatus, x5
  MB_SET(MB_DCSR_WR, 1)                   # prv = 01: reads as U
  DBG_HALT
  MODE_U
  TO_M
  li x7, 1
  bne x9, x7, fail
  CHECK_ENTRY(3, 3)
  csrr x5, mstatus
  li x7, MSTATUS_MPRV
  and x5, x5, x7
  bnez x5, fail
  # prv WARL: 01 / 10 read as 0 (the DM's write, read back on the next entry)
  MB_SET(MB_DCSR_WR, 2)
  DBG_HALT                                # in M; dret to U
  MB_SET(MB_DCSR_WR, DCSR_PRV_M)
  DBG_HALT                                # from U: prv 0 seen, dret to M
  CHECK_ENTRY(3, 0)
  MODE_U
  bnez x9, fail
  li x29, 0

  # ---- EBREAK in U with ebreaku: debug entry, cause 1, prv 0 -----------------
  li TESTNUM, 5
  MB_SET(MB_DCSR_WR, DCSR_EBREAKU | DCSR_PRV_M)
  DBG_HALT
  MB_SETL(MB_DPC_WR, ebrk_5 + 4)
  MB_SET(MB_DCSR_WR, 0)                   # back to U, ebreaku cleared
  MB(MB_COUNT, x8)
  TO_U
ebrk_5:
  ebreak
  MODE_U
  TO_M
  li x7, 1
  bne x9, x7, fail                        # the MODE_U trap only
  li x7, CAUSE_ILLEGAL_INSTRUCTION
  bne x28, x7, fail
  MB(MB_COUNT, x5)
  addi x8, x8, 1
  bne x5, x8, fail
  CHECK_ENTRY(1, 0)
  MB(MB_DPC, x5)
  la x6, ebrk_5
  bne x5, x6, fail
  li x29, 0

  # ---- EBREAK in U without ebreaku (ebreakm set): M trap -------------------
  li TESTNUM, 6
  MB_SET(MB_DCSR_WR, DCSR_EBREAKM | DCSR_PRV_M)
  DBG_HALT
  MB(MB_COUNT, x8)
  TO_U
  ebreak
  TO_M
  li x7, 1
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  MB(MB_COUNT, x5)
  bne x5, x8, fail                        # no debug entry
  li x29, 0

  # ---- EBREAK in M with ebreaku only: M trap --------------------------------
  li TESTNUM, 7
  MB_SET(MB_DCSR_WR, DCSR_EBREAKU | DCSR_PRV_M)
  DBG_HALT
  MB(MB_COUNT, x8)
  ebreak
  li x7, 1
  bne x29, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  MB(MB_COUNT, x5)
  bne x5, x8, fail
  MB_SET(MB_DCSR_WR, DCSR_PRV_M)
  DBG_HALT

  la t0, trap_vector                      # RVTEST_PASS / FAIL from M-mode
  csrw mtvec, t0
  TEST_PASSFAIL

  .pushsection .text, "ax"                # own section: 4-byte aligned for mtvec
  .balign 4
handler:
  csrr t5, mcause
  li t6, CAUSE_USER_ECALL
  beq t5, t6, 2f
  li t6, CAUSE_MACHINE_ECALL
  bne t5, t6, 1f
2:
  li t6, 93                               # RVTEST_PASS / FAIL
  beq a7, t6, trap_vector
  csrw mepc, x22                          # TO_M: back to M at x22
  li t6, MSTATUS_MPP
  csrs mstatus, t6
  mret
1:
  addi x29, x29, 1
  mv x28, t5
  csrr x27, mepc
  csrr t5, mepc                           # exception: skip the instruction
  addi t5, t5, 4
  csrw mepc, t5
  mret
  .popsection

  DBG_ROM

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  DBG_DATA
RVTEST_DATA_END
