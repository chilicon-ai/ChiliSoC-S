/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: load / store access faults (bus error) in the
# pipeline. 0x4000_0000 is unmapped (testbench and Spike): loads (lb / lh /
# lw / lbu / lhu) trap with mcause 5 and stores (sb / sh / c.sw) with
# mcause 7, mtval = the access address. Checked: rd unchanged (also when used
# at once), a store has no effect (x9 aliases the data buffer in the low 20
# bits), older instructions (load, store, M) complete, the younger
# instruction runs once, back-to-back faults, a fault address forwarded from
# a load, a faulting 32-bit load at 2 mod 4, a compressed faulting store
# (mepc + 2), and misaligned accesses to the unmapped address: Spike reports
# the misaligned exception (mcause 4 / 6, mtval = address), not the fault.
# The handler counts traps in x29, records mcause in x28 and mtval in x27 and
# skips the trapping instruction (2 or 4 bytes: it loads the instruction's
# low halfword from mepc). Instructions using x5 / x6 are never compressed.
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

# last trap: mcause = cause, mtval = base + off
#define CHECK_FAULT(cause, base, off) \
  li x7, cause; bne x28, x7, fail; addi x7, base, off; bne x27, x7, fail

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la x8, buf                              # x8: data buffer
  li x6, 0x40000000                       # x6: unmapped base
  sub x9, x8, x6                          # x9: unmapped, = buf in the low 20 bits
  li x1, 0x11223344
  li x5, 0x55                             # x5: faulting loads' rd, stays 0x55
  li x10, 0x66

  # ---- lw after an older load; the younger instruction uses rd, runs once ----
  li TESTNUM, 2
  sw x1, 0(x8)
  lw x11, 0(x8)                           # older load
  lw x5, 0(x6)                            # fault
  add x12, x12, x5                        # x12 = 0 + old x5, once
  CHECK_FAULT(CAUSE_LOAD_ACCESS, x6, 0)
  bne x11, x1, fail
  li x7, 0x55
  bne x12, x7, fail

  # ---- sb after an older store; no effect at the aliasing address -----------
  li TESTNUM, 3
  sw x1, 4(x8)                            # older store
  sb x5, 4(x9)                            # fault
  CHECK_FAULT(CAUSE_STORE_ACCESS, x9, 4)
  lw x11, 4(x8)
  bne x11, x1, fail

  # ---- lh right after an M instruction ------------------------------------
  li TESTNUM, 4
  li x12, 6
  li x13, 7
  mul x14, x12, x13
  lh x5, 6(x6)                            # fault
  CHECK_FAULT(CAUSE_LOAD_ACCESS, x6, 6)
  li x7, 42
  bne x14, x7, fail

  # ---- back to back: lb, sh (aliasing), lbu with its address from a load ----
  li TESTNUM, 5
  sw x6, 8(x8)
  lw x15, 8(x8)                           # x15 = x6, forwarded into the lbu
  lb x5, 3(x6)                            # fault
  sh x1, 2(x9)                            # fault
  lbu x5, 1(x15)                          # fault
  CHECK_FAULT(CAUSE_LOAD_ACCESS, x6, 1)

  # ---- faulting 32-bit lhu at 2 mod 4, compressed faulting c.sw ---------------
  li TESTNUM, 6
  .balign 4
  c.nop
  lhu x5, 10(x6)                          # @2: fault
  CHECK_FAULT(CAUSE_LOAD_ACCESS, x6, 10)
  c.sw x10, 8(x9)                         # fault, aliases buf + 8: mepc + 2
  CHECK_FAULT(CAUSE_STORE_ACCESS, x9, 8)

  # ---- misaligned to the unmapped address: misaligned exception ----------------
  li TESTNUM, 7
  lw x5, 2(x6)
  CHECK_FAULT(CAUSE_MISALIGNED_LOAD, x6, 2)
  sw x1, 2(x9)                            # aliases buf + 2
  CHECK_FAULT(CAUSE_MISALIGNED_STORE, x9, 2)

  # ---- rd and memory unchanged, trap count -----------------------------------
  li TESTNUM, 8
  li x7, 0x55
  bne x5, x7, fail
  lw x11, 0(x8)                           # sh 2(x9), sw 2(x9) alias this word
  bne x11, x1, fail
  lw x11, 8(x8)                           # c.sw 8(x9) aliases this word
  bne x11, x6, fail
  li x7, 10                               # traps so far
  bne x29, x7, fail

  TEST_PASSFAIL

  .balign 4
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr x28, mcause
  csrr x27, mtval
  csrr t5, mepc
  lhu t6, 0(t5)                           # low half of the trapping instruction
  andi t6, t6, 3
  addi t5, t5, 2
  xori t6, t6, 3                          # 0: 32-bit instruction
  bnez t6, 1f
  addi t5, t5, 2
1:
  csrw mepc, t5
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 16, 4, 0
RVTEST_DATA_END
