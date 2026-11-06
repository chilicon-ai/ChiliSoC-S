/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: RV32C compressed instructions in the pipeline.
# Every RV32C instruction class: c.li / c.lui / c.addi / c.addi16sp /
# c.addi4spn, c.lw / c.sw / c.lwsp / c.swsp, c.slli / c.srli / c.srai /
# c.andi, c.mv / c.add / c.sub / c.xor / c.or / c.and, c.beqz / c.bnez (taken
# and not taken), c.j, c.jal and c.jalr (link = pc + 2), c.jr, c.ebreak.
# Forwarding between compressed and 32-bit instructions (ALU, load-use,
# address, branch, jalr). 32-bit instructions at addresses = 2 mod 4 (they
# straddle a fetch word), jumps / branches to such targets, a jalr to an odd
# address (bit 0 cleared), compressed and mixed loops, illegal compressed
# instructions (mtval = the 16 instruction bits only, also when the next
# halfword is nonzero) and an illegal 32-bit instruction at 2 mod 4 (mtval =
# all 32 bits).
# Layout: compressed instructions are written as c.* mnemonics, instructions
# that must stay 32-bit are wrapped in N32() (.option norvc); .option norelax
# keeps the alignment fixed. "@2" marks a 32-bit instruction or target at an
# address = 2 mod 4 (checked with objdump).
# The handler counts traps in x29, records mcause in x28 and mtval in x27 and
# skips the trapping instruction (2 or 4 bytes: it loads the instruction's
# low halfword from mepc).
# Every retired instruction is also compared with Spike by sim/run.py.

#include "riscv_test.h"
#include "test_macros.h"

#define N32(...) .option push; .option norvc; __VA_ARGS__; .option pop

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN

  la sp, buf                              # sp: buffer base (c.lwsp / c.swsp)
  c.mv s0, sp                             # s0: buffer base (c.lw / c.sw)

  # ---- constants and immediates ----------------------------------------------
  TEST_CASE( 2, a0, 0xffffeff9, c.li a0, -5; c.lui a1, 0x1f; c.add a0, a1; c.lui a1, 0xfffe0; c.add a0, a1; c.addi a0, -2)

  # c.addi16sp (largest +/- immediates), result used at once
  li TESTNUM, 3
  c.addi16sp sp, 496
  c.mv a2, sp
  N32(addi a1, s0, 496)
  bne a2, a1, fail
  c.addi16sp sp, -512
  N32(addi a1, s0, -16)
  bne sp, a1, fail
  c.addi16sp sp, 16                       # sp = buf again

  # c.addi4spn (largest immediate) against the 32-bit addi
  li TESTNUM, 4
  c.addi4spn a0, sp, 1020
  N32(addi a1, sp, 1020)
  bne a0, a1, fail

  # ---- loads and stores --------------------------------------------------------
  # c.sw / c.lw, compressed load -> 32-bit consumer (load-use)
  li TESTNUM, 5
  li a1, 0x12345678
  c.sw a1, 4(s0)
  c.lw a2, 4(s0)
  N32(addi a3, a2, 1)
  li x7, 0x12345679
  bne a3, x7, fail
  TEST_CASE( 6, a4, 0x12345678, c.swsp a1, 252(sp); c.lwsp a4, 252(sp))
  # 32-bit load -> compressed consumer, then compressed -> 32-bit store data
  TEST_CASE( 7, a3, 0x2468acf0, N32(lw a2, 4(s0)); c.add a2, a2; N32(sw a2, 8(s0)); c.lw a3, 8(s0))
  # store address from a compressed ALU result at distance 1
  TEST_CASE( 8, a4, 0x12345678, c.mv a5, s0; c.addi a5, 12; c.sw a1, 0(a5); N32(lw a4, 12(s0)))
  # c.lwsp -> c.swsp data, c.lw with the largest offset
  TEST_CASE( 9, a5, 0x2468acf0, c.lwsp a3, 8(sp); c.swsp a3, 124(sp); c.lw a5, 124(s0))

  # ---- shifts and logic ------------------------------------------------------
  TEST_CASE(10, a0, 0x0000002c, c.li a0, 15; c.slli a0, 28; c.srli a0, 26; c.andi a0, -20)
  TEST_CASE(11, a0, 0xfffffff8, N32(lui a0, 0x80000); c.srai a0, 28)

  # ---- register-register -----------------------------------------------------
  TEST_CASE(12, a0, 7,          c.li a0, 5; c.li a1, 7; c.mv x20, a0; c.add x20, a1; c.sub a0, a1; c.xor a0, a1; c.or a0, a1; c.li a1, -5; c.and a0, a1; c.add a0, x20)

  # ---- forwarding alternating 32-bit and compressed, distance 1 and 2 ----------
  TEST_CASE(13, a0, 212,        N32(addi a0, x0, 100); c.addi a0, 1; N32(slli a0, a0, 1); c.srli a0, 1; N32(add a0, a0, a0); c.li a1, 9; N32(addi a2, x0, 1); N32(add a1, a1, a2); c.add a0, a1)

  # ---- c.beqz / c.bnez taken and not taken (operand from distance 1) ---------
  li TESTNUM, 14
  c.li a0, 0
  c.bnez a0, 2f                           # not taken
  c.beqz a0, 1f                           # taken
2:
  j fail
1:
  c.li a0, 3
  c.beqz a0, 2b                           # not taken (backward)
  c.bnez a0, 3f                           # taken
  j fail
3:

  # ---- c.j, c.jal (link pc + 2), c.jr, c.jalr (link pc + 2) ------------------
  li TESTNUM, 15
  c.j 1f
  j fail
1:
  c.jal 1f
2:
  j fail
1:
  la a1, 2b
  bne ra, a1, fail

  la a1, 1f
  c.mv a3, a1
  c.jr a3                                 # target forwarded at distance 1
  j fail
1:
  la a1, 1f
  c.jalr a1
2:
  j fail
1:
  la a2, 2b
  bne ra, a2, fail

  # ---- 32-bit instructions at 2 mod 4 -----------------------------------------
  li TESTNUM, 16
  .balign 4
  c.li a0, 1
  N32(addi a0, a0, 2)                     # @2
  N32(slli a0, a0, 4)                     # @2
  c.addi a0, 1                            # @2
  N32(addi a1, a0, 0)                     # @0
  li x7, 0x31
  bne a1, x7, fail

  # loads / stores / branch / jal at 2 mod 4, targets at 2 mod 4
  li TESTNUM, 17
  .balign 4
  c.nop
  N32(lw a2, 4(s0))                       # @2
  N32(sw a2, 16(s0))                      # @2
  N32(lw a3, 16(s0))                      # @2
  N32(beq a2, a3, 1f)                     # @2, taken, target @2
  N32(j fail)                             # @2
1:
  N32(jal ra, 2f)                         # @2, target @2
3:
  N32(j fail)                             # @2
2:
  N32(auipc a1, 0)                        # @2
  N32(addi a1, a1, -4)                    # a1 = 3b
  bne ra, a1, fail

  # jump from 0 mod 4 to a 2 mod 4 target, then back to 0 mod 4
  li TESTNUM, 18
  .balign 4
  N32(jal x0, 1f)                         # @0, target @2
  c.nop
1:
  c.j 2f                                  # @2, target @0
  N32(j fail)                             # @0
2:

  # ---- loops ---------------------------------------------------------------
  # compressed loop
  li TESTNUM, 19
  c.li a0, 3
  c.li a1, 0
1:
  c.add a1, a0
  c.addi a0, -1
  c.bnez a0, 1b
  li x7, 6
  bne a1, x7, fail

  # mixed loop: start @2, 32-bit backward branch @2
  li TESTNUM, 20
  .balign 4
  c.li a0, 3
  c.li a1, 0
  c.nop
1:
  N32(add a1, a1, a0)                     # @2
  c.addi a0, -1                           # @2
  c.nop                                   # @0
  N32(bne a0, x0, 1b)                     # @2
  li x7, 6
  bne a1, x7, fail

  # ---- jalr to an odd address: bit 0 cleared, lands on a 2 mod 4 target --------
  li TESTNUM, 21
  la a1, 1f
  N32(jalr ra, 1(a1))                     # target 1f + 1 -> 1f
2:
  j fail
  .balign 4
  c.nop
1:
  la a2, 2b                               # @2
  bne ra, a2, fail
  la a1, 1f
  N32(addi a2, a1, 4)
  N32(jalr x0, -3(a2))                    # 1f + 1 -> 1f, base forwarded
  j fail
  .balign 4
  c.nop
1:
  c.nop                                   # @2

  # ---- c.ebreak (mtval = pc), handler resumes 2 bytes on ---------------------
  li TESTNUM, 22
  c.li a0, 1
  .balign 4
  c.nop
1:
  c.ebreak                                # @2
  c.addi a0, 1                            # runs once, after the handler
  li x7, 2
  bne a0, x7, fail
  li x7, CAUSE_BREAKPOINT
  bne x28, x7, fail
  la x7, 1b
  bne x27, x7, fail

  # ---- illegal compressed instructions: mcause 2, mtval = the 16 bits --------
  li TESTNUM, 23
  .half 0x0000                            # all-zero: illegal
  li x7, CAUSE_ILLEGAL_INSTRUCTION
  bne x28, x7, fail
  bne x27, x0, fail
  .balign 4
  c.nop
  .half 0x4002                            # @2: c.lwsp x0 (reserved), next half nonzero
  c.li a0, 1
  li x7, 0x4002
  bne x27, x7, fail
  # illegal 32-bit instruction at 2 mod 4: mtval = all 32 bits
  .balign 4
  c.nop
  N32(csrr a0, 0x7ff)                     # @2, no such CSR
  li x7, 0x7ff02573
  bne x27, x7, fail
  li x7, 4                                # traps so far
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
buf: .fill 64, 4, 0
RVTEST_DATA_END
