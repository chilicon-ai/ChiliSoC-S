/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: an interrupt preempts every instruction class.
# The interrupt (MSI via msip, or MTI via mtimecmp = 0) is made pending while
# mstatus.MIE = 0 (store, read back from the CLINT, fence), then one CSR
# instruction enables it and the interrupt is taken on the next instruction
# X: X must not execute (no rd write, no store, no jump, no CSR write), mepc
# = X, and X runs once after mret. X: load, store, taken / not-taken branch,
# jal, jalr, mul, div, csr, fence, fence.i, compressed (c.addi, c.lw,
# c.bnez), a 32-bit instruction at pc[1] = 1, and the enabling CSR write via
# mie instead of mstatus. Also "Y; csrsi mstatus.MIE; X" with Y = load /
# store / mul / div (an older Y at distance 2 when the interrupt is taken),
# and mret -> mret: an mret with MPIE = 0 returns to an mret whose MIE = MPIE
# = 1 enables a pending MSI, taken on that mret itself (mepc = it).
# Determinism (Spike vs RTL): Spike looks for interrupts only after a CSR
# instruction, an mret or a trap (and every few thousand instructions), so
# an interrupt is only ever enabled by one of those, never made pending by a
# store while enabled; mtime is never read. Spike's mtimecmp resets to 0, so
# mtimecmp hi = all ones comes first.
# The handler logs every trap: x29 count, x28 mcause, x27 mepc, x26 mstatus;
# it clears the source (msip = 0 / mtimecmp hi = max, read back), and when
# x24 != 0 resumes there instead of mepc (x24 then 0). Any exception fails.
# It uses only those registers and t5 / t6. x23 counts the expected traps.
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000
#define IRQ_MSI         0x80000003
#define IRQ_MTI         0x80000007

#define C16(...) .option push; .option rvc; __VA_ARGS__; .option pop

# make an interrupt pending (MIE = 0 here)
#define MSI_PEND  sw x22, 0(x20); lw x5, 0(x20); fence
#define MTI_PEND  sw x0, 4(x21); sw x0, 0(x21); lw x5, 0(x21); fence
#define MIE_ON    csrsi mstatus, MSTATUS_MIE
#define MIE_OFF   csrci mstatus, MSTATUS_MIE

# after the interrupt at lbl: one more trap, mepc = lbl, mcause = cause
#define CHECK_IRQ(lbl, cause) \
  addi x23, x23, 1; bne x29, x23, fail; \
  la x7, lbl; bne x27, x7, fail; \
  li x7, cause; bne x28, x7, fail; \
  MIE_OFF

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  li x20, CLINT_MSIP                      # x20: msip
  li x21, CLINT_MTIMECMP                  # x21: mtimecmp lo, hi at +4
  li x22, 1
  li x5, -1
  sw x5, 4(x21)                           # mtimecmp hi = max: no timer interrupt
  lw x5, 4(x21)
  la x8, buf                              # x8: data buffer
  li x23, 0
  li x24, 0
  li x5, MIP_MSIP | MIP_MTIP
  csrs mie, x5                            # MSIE, MTIE; MIE = 0
  li x9, 0x1234
  li x10, 7

  # ---- load ------------------------------------------------------------------
  li TESTNUM, 2
  sw x9, 0(x8)
  li x4, 0
  MSI_PEND
  MIE_ON
irq_2:
  lw x4, 0(x8)
  CHECK_IRQ(irq_2, IRQ_MSI)
  bne x4, x9, fail

  # ---- store: done once, after mret -------------------------------------------
  li TESTNUM, 3
  sw x0, 4(x8)
  MTI_PEND
  MIE_ON
irq_3:
  sw x9, 4(x8)
  CHECK_IRQ(irq_3, IRQ_MTI)
  lw x4, 4(x8)
  bne x4, x9, fail

  # ---- taken branch ------------------------------------------------------------
  li TESTNUM, 4
  li x4, 0
  MSI_PEND
  MIE_ON
irq_4:
  beq x9, x9, 1f
  li x4, 1                                # skipped
1:
  CHECK_IRQ(irq_4, IRQ_MSI)
  bnez x4, fail

  # ---- not-taken branch --------------------------------------------------------
  li TESTNUM, 5
  li x4, 0
  MTI_PEND
  MIE_ON
irq_5:
  bne x9, x9, fail
  addi x4, x4, 1
  CHECK_IRQ(irq_5, IRQ_MTI)
  li x7, 1
  bne x4, x7, fail

  # ---- jal ---------------------------------------------------------------------
  li TESTNUM, 6
  li x1, 0
  MSI_PEND
  MIE_ON
irq_6:
  jal x1, 1f
2:
  j fail
1:
  CHECK_IRQ(irq_6, IRQ_MSI)
  la x7, 2b
  bne x1, x7, fail

  # ---- jalr --------------------------------------------------------------------
  li TESTNUM, 7
  la x11, 1f
  li x1, 0
  MSI_PEND
  MIE_ON
irq_7:
  jalr x1, 0(x11)
2:
  j fail
1:
  CHECK_IRQ(irq_7, IRQ_MSI)
  la x7, 2b
  bne x1, x7, fail

  # ---- mul ---------------------------------------------------------------------
  li TESTNUM, 8
  li x4, 0
  MTI_PEND
  MIE_ON
irq_8:
  mul x4, x9, x10
  CHECK_IRQ(irq_8, IRQ_MTI)
  li x7, 0x1234 * 7
  bne x4, x7, fail

  # ---- div (its source register is also its destination) ------------------------
  li TESTNUM, 9
  li x4, 0x1234 * 7
  MSI_PEND
  MIE_ON
irq_9:
  div x4, x4, x10
  CHECK_IRQ(irq_9, IRQ_MSI)
  bne x4, x9, fail

  # ---- csr: the read-modify-write happens once -----------------------------------
  li TESTNUM, 10
  li x5, 0x55
  csrw mscratch, x5
  MSI_PEND
  MIE_ON
irq_10:
  csrrs x4, mscratch, x9
  CHECK_IRQ(irq_10, IRQ_MSI)
  li x7, 0x55
  bne x4, x7, fail
  csrr x4, mscratch
  li x7, 0x55 | 0x1234
  bne x4, x7, fail

  # ---- fence, fence.i ------------------------------------------------------------
  li TESTNUM, 11
  MTI_PEND
  MIE_ON
irq_11:
  fence
  CHECK_IRQ(irq_11, IRQ_MTI)

  li TESTNUM, 12
  MSI_PEND
  MIE_ON
irq_12:
  fence.i
  CHECK_IRQ(irq_12, IRQ_MSI)

  # ---- compressed: c.addi, c.lw, c.bnez ------------------------------------------
  li TESTNUM, 13
  li x12, 5
  MSI_PEND
  MIE_ON
irq_13:
  C16(c.addi x12, 1)
  C16(c.nop)
  CHECK_IRQ(irq_13, IRQ_MSI)
  li x7, 6
  bne x12, x7, fail

  li TESTNUM, 14
  li x13, 0
  MTI_PEND
  MIE_ON
irq_14:
  C16(c.lw x13, 0(x8))
  C16(c.nop)
  CHECK_IRQ(irq_14, IRQ_MTI)
  bne x13, x9, fail

  li TESTNUM, 15
  li x12, 0
  MSI_PEND
  MIE_ON
irq_15:
  C16(c.bnez x12, 1f)                     # not taken
  C16(c.addi x12, 1)
1:
  CHECK_IRQ(irq_15, IRQ_MSI)
  li x7, 1
  bne x12, x7, fail

  # ---- 32-bit instruction at pc[1] = 1 (after a CSR at pc[1] = 1) --------------------
  li TESTNUM, 16
  li x4, 1
  MSI_PEND
  C16(.balign 4)
  C16(c.nop)
  MIE_ON                                  # @2
irq_16:
  add x4, x4, x9                          # @2
  C16(c.nop)
  CHECK_IRQ(irq_16, IRQ_MSI)
  li x7, 0x1235
  bne x4, x7, fail

  li TESTNUM, 17                          # a 32-bit load at pc[1] = 1
  li x4, 0
  MTI_PEND
  C16(.balign 4)
  C16(c.nop)
  MIE_ON                                  # @2
irq_17:
  lw x4, 0(x8)                            # @2
  C16(c.nop)
  CHECK_IRQ(irq_17, IRQ_MTI)
  bne x4, x9, fail

  # ---- enabled through mie (MIE = 1, MSIE = 0) ---------------------------------------
  li TESTNUM, 18
  csrci mie, MIP_MSIP
  MSI_PEND
  MIE_ON                                  # MSIE = 0: not taken
  li x4, 0
  csrsi mie, MIP_MSIP
irq_18:
  sw x10, 8(x8)
  CHECK_IRQ(irq_18, IRQ_MSI)
  lw x4, 8(x8)
  bne x4, x10, fail

  # ---- older load / store / mul / div at distance 2 -----------------------------------
  li TESTNUM, 19
  MSI_PEND
  lw x4, 0(x8)
  MIE_ON
irq_19:
  addi x4, x4, 1
  CHECK_IRQ(irq_19, IRQ_MSI)
  li x7, 0x1235
  bne x4, x7, fail

  li TESTNUM, 20
  MTI_PEND
  sw x10, 12(x8)
  MIE_ON
irq_20:
  lw x4, 12(x8)                           # store -> load, split by the interrupt
  CHECK_IRQ(irq_20, IRQ_MTI)
  bne x4, x10, fail

  li TESTNUM, 21
  MSI_PEND
  mul x4, x9, x9
  MIE_ON
irq_21:
  add x4, x4, x10
  CHECK_IRQ(irq_21, IRQ_MSI)
  li x7, 0x1234 * 0x1234 + 7
  bne x4, x7, fail

  li TESTNUM, 22
  MTI_PEND
  divu x4, x9, x10
  MIE_ON
irq_22:
  mul x4, x4, x10
  CHECK_IRQ(irq_22, IRQ_MTI)
  li x7, (0x1234 / 7) * 7
  bne x4, x7, fail

  li TESTNUM, 23                          # div two before, then a div preempted
  li x4, 100
  MSI_PEND
  rem x5, x9, x10
  MIE_ON
irq_23:
  div x4, x4, x5
  CHECK_IRQ(irq_23, IRQ_MSI)
  li x7, 100 / (0x1234 % 7)
  bne x4, x7, fail

  # ---- both pending: MSI first, MTI on the same instruction after its mret ------------
  li TESTNUM, 24
  li x25, 0
  MSI_PEND
  MTI_PEND
  MIE_ON
irq_24:
  jal x1, 1f
1:
  addi x23, x23, 1                        # two traps, both at irq_24
  CHECK_IRQ(irq_24, IRQ_MTI)

  # ---- mret -> mret: the second one enables MSI and is preempted itself ----------------
  li TESTNUM, 25
  li x5, MSTATUS_MPIE
  csrc mstatus, x5                        # MPIE = 0, MIE = 0
  li x5, MSTATUS_MPP
  csrs mstatus, x5                        # MPP = M: the first mret stays in M
  MSI_PEND
  la x5, mret_a
  csrw mepc, x5
  la x24, 1f                              # the handler resumes at 1f
  mret                                    # -> mret_a; MIE = MPIE = 0, MPIE = 1, MPP = U
  j fail
  j fail
mret_a:
  mret                                    # -> mret_a in U-mode: MSI taken here
  j fail
1:
  CHECK_IRQ(mret_a, IRQ_MSI)
  bnez x24, fail

  li TESTNUM, 26
  li x7, 25                               # traps
  bne x29, x7, fail
  csrw mie, x0

  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mepc
  csrr x26, mstatus
  bgez x28, fail                          # no exceptions expected
  andi t6, x28, 15
  addi t6, t6, -3
  bnez t6, 1f
  li t5, CLINT_MSIP                       # MSI: msip = 0
  sw x0, 0(t5)
  lw t6, 0(t5)                            # read back: the clear is done
  j 2f
1:
  li t5, CLINT_MTIMECMP                   # MTI: mtimecmp hi = max
  li t6, -1
  sw t6, 4(t5)
  lw t6, 4(t5)
2:
  li t5, MSTATUS_MPP                      # return to M (test 25 traps from U)
  csrs mstatus, t5
  beqz x24, 3f                            # taken branch -> mret
  csrw mepc, x24
  li x24, 0
3:
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 8, 4, 0
RVTEST_DATA_END
