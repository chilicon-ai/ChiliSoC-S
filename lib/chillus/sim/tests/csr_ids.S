/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: the machine CSRs beyond the
# trap / counter set: misa, the hardware performance monitor CSRs and the
# PMP CSRs (zero entries: read 0, writes ignored), and CSRs that must trap
# (no Zihpm, the debug CSRs and dret outside debug mode, no custom
# CSRs at 0x7C0 / 0x7C1), and the M-mode CSRs of U-mode support: mcounteren, menvcfg[h]. The handler counts traps
# in x29 and skips the instruction. Every retired instruction is also
# compared with Spike by sim/run.py.
# Also: reads of the counters / time (values not compared by sim/run.py,
# never branched on except at the very end), mconfigptr, mstatush; writes of
# mcause / mtval / mie / mip read back (mip: writes ignored); writes of the
# read-only counter / ID CSRs and CSR addresses just outside the implemented
# HPM / PMP / ID ranges trap; every CSR op with and without its write;
# mcountinhibit.CY stops mcycle (checked last: the comparison ends there).
# The PMP entries (pmpcfg0, pmpaddr0..3) are checked by pmp.S; here only
# the read-zero PMP CSRs beyond them. mie is written with bits 15:0 only: Spike has no local
# interrupt bits 30:16 (irq_fast_nmi.S checks them).

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li x29, 0
  li x1, 0x5a5a5a5a

  # ---- misa: RV32 (MXL 1), I, M, C, U; read-only in ChillU-S. Only
  # value-preserving writes are tested: Spike lets a write clear C / M (WARL),
  # which then disables them.
  TEST_CASE( 2, x4, 0x40101104, csrr x4, misa)
  # writes that keep the value (the same on both): its own value, set a set
  # bit (I), clear a clear bit (A)
  TEST_CASE( 3, x4, 0x40101104, csrw misa, x4; li x5, 0x100; csrs misa, x5; csrci misa, 1; csrr x4, misa)

  # ---- hardware performance monitor: read 0, writes ignored -------------
  TEST_CASE( 5, x4, 0, csrw mhpmcounter3, x1;   csrr x4, mhpmcounter3)
  TEST_CASE( 6, x4, 0, csrw mhpmcounter31, x1;  csrr x4, mhpmcounter31)
  TEST_CASE( 7, x4, 0, csrw mhpmcounter3h, x1;  csrr x4, mhpmcounter3h)
  TEST_CASE( 8, x4, 0, csrw mhpmcounter31h, x1; csrr x4, mhpmcounter31h)
  TEST_CASE( 9, x4, 0, csrw mhpmevent3, x1;     csrr x4, mhpmevent3)
  TEST_CASE(10, x4, 0, csrw mhpmevent31, x1;    csrr x4, mhpmevent31)
  TEST_CASE(11, x4, 0, csrrs x4, mhpmevent17, x1; csrr x4, mhpmevent17)

  # ---- PMP CSRs beyond the 4 entries: read 0 --------------------------------
  TEST_CASE(12, x4, 0, csrw pmpaddr4, x1;  csrr x4, pmpaddr4)
  TEST_CASE(13, x4, 0, csrw pmpaddr15, x1; csrr x4, pmpaddr15)
  TEST_CASE(14, x4, 0, csrw pmpaddr63, x1; csrr x4, pmpaddr63)
  TEST_CASE(15, x4, 0, csrw pmpcfg1, x1;   csrr x4, pmpcfg1)
  TEST_CASE(16, x4, 0, csrw pmpcfg15, x1;  csrr x4, pmpcfg15)

  # ---- U-mode support: mcounteren CY / TM / IR (others 0), menvcfg[h] read 0
  TEST_CASE(50, x4, 7, li x5, -1; csrw mcounteren, x5; csrr x4, mcounteren)
  TEST_CASE(51, x4, 2, csrw mcounteren, 2;  csrr x4, mcounteren)
  TEST_CASE(52, x4, 0, csrw mcounteren, x0; csrr x4, mcounteren)
  TEST_CASE(53, x4, 0, csrw menvcfg, x1;    csrr x4, menvcfg)
  TEST_CASE(54, x4, 0, csrw menvcfgh, x1;   csrr x4, menvcfgh)

  # none of the above trapped
  li TESTNUM, 17
  bne x29, x0, fail

  # ---- must trap: rd unchanged ---------------------------------------------
  li TESTNUM, 18
  li x4, 0x77
  csrr x4, hpmcounter3             # no Zihpm
  csrr x4, hpmcounter31h
  csrr x4, dcsr                    # debug CSRs: only in debug mode
  csrr x4, dpc
  csrw dscratch0, x1
  csrrs x4, dscratch1, x0
  .word 0x7b200073                 # dret: only in debug mode
  csrr x4, 0x7c0                   # custom CSR, not implemented
  csrw 0x7c1, x1                   # custom CSR, not implemented
  li x7, 0x77
  bne x4, x7, fail
  li x7, 9
  bne x29, x7, fail

  # ---- read-only ID CSRs: legal to read, writes trap ---------------------
  li TESTNUM, 19
  csrr x4, mhartid
  bne x4, x0, fail
  csrr x5, mvendorid
  csrr x5, marchid
  csrr x5, mimpid
  csrw mhartid, x1                 # read-only: traps
  li x7, 10
  bne x29, x7, fail

  # ---- counters and time: read (values not compared), mconfigptr, mstatush --
  li TESTNUM, 20
  csrr x5, time
  csrr x5, timeh
  csrr x5, mcycle
  csrr x5, mcycleh
  csrr x5, cycle
  csrr x5, cycleh
  csrrs x5, time, x0               # no write: legal on a read-only CSR
  csrrci x5, timeh, 0
  li x5, 0
  TEST_CASE(21, x4, 0, csrr x4, mconfigptr)
  TEST_CASE(22, x4, 0, csrw mstatush, x1; csrr x4, mstatush)
  TEST_CASE(23, x4, 0, csrrs x4, mstatush, x0)

  # ---- mcause / mtval: written and read back ----------------------------------
  TEST_CASE(24, x4, 0x8000000b, li x5, 0x8000000b; csrw mcause, x5; csrr x4, mcause)
  TEST_CASE(25, x4, 0x00000005, csrwi mcause, 5; csrr x4, mcause)
  TEST_CASE(26, x4, 0x5a5a5a5a, csrw mtval, x1; csrr x4, mtval)
  TEST_CASE(27, x4, 0x5a5a5a5e, csrrsi x0, mtval, 4; csrr x4, mtval)
  TEST_CASE(28, x4, 0x00000000, csrrc x0, mtval, x1; csrrw x4, mtval, x0; csrr x4, mtval)

  # ---- mie: MEIE set, MTIE cleared (mstatus.MIE = 0: nothing is taken) --------
  TEST_CASE(29, x4, 0x088, li x5, 0x88; csrw mie, x5; csrr x4, mie)
  TEST_CASE(30, x4, 0x808, li x5, 0x800; csrs mie, x5; csrci mie, 0; li x5, 0x80; csrc mie, x5; csrr x4, mie)
  TEST_CASE(31, x4, 0x888, li x5, 0xffff; csrrw x0, mie, x5; csrr x4, mie)
  TEST_CASE(32, x4, 0x000, csrw mie, x0; csrr x4, mie)

  # ---- mip: read-only bits, writes ignored (Spike's mtimecmp resets to 0:
  # mtimecmp hi = all ones first, read back) --------------------------------
  li TESTNUM, 33
  li x6, 0x02004000
  li x5, -1
  sw x5, 4(x6)
  lw x5, 4(x6)
  csrw mip, x5
  csrr x4, mip
  bne x4, x0, fail
  TEST_CASE(34, x4, 0, csrrs x4, mip, x1; csrrc x0, mip, x1; csrrsi x4, mip, 8)

  # ---- CSR ops with and without their write (mscratch) ------------------------
  TEST_CASE(35, x4, 0x5a5a5a5a, csrrw x0, mscratch, x1; csrrs x4, mscratch, x0)
  TEST_CASE(36, x4, 0x5a5a5a5a, csrrc x4, mscratch, x0; csrrsi x5, mscratch, 0; csrrci x5, mscratch, 0)
  TEST_CASE(37, x4, 0x0000001f, csrrwi x0, mscratch, 0; csrrsi x5, mscratch, 31; csrr x4, mscratch)
  TEST_CASE(38, x4, 0x0000001a, csrrci x5, mscratch, 5; csrr x4, mscratch)
  TEST_CASE(39, x4, 0x0000001a, li x5, 0x0f; csrrc x4, mscratch, x5; csrrwi x5, mscratch, 3)
  TEST_CASE(40, x4, 0x00000003, csrrs x4, mscratch, x0)
  TEST_CASE(41, x4, 0x0000000b, li x5, 8; csrrs x0, mscratch, x5; csrr x4, mscratch)

  # ---- writes of read-only CSRs trap (rd unchanged, no write) ----------------
  li TESTNUM, 42
  li x29, 0
  li x4, 0x77
  csrw time, x1
  csrw timeh, x1
  csrw cycle, x1
  csrw cycleh, x1
  csrw instret, x1
  csrw instreth, x1
  csrrs x4, marchid, x1
  csrrci x4, mimpid, 1
  csrrwi x4, mconfigptr, 0         # csrrw writes even with uimm = 0
  csrrc x4, mvendorid, x1
  csrrsi x4, mhartid, 1
  li x7, 0x77
  bne x4, x7, fail
  li x7, 11
  bne x29, x7, fail

  # ---- addresses just outside the implemented ranges trap --------------------
  li TESTNUM, 43
  li x29, 0
  csrr x4, 0xb01                   # between mcycle and minstret
  csrr x4, 0xb20                   # past mhpmcounter31
  csrr x4, 0xb81                   # between mcycleh and minstreth
  csrr x4, 0xba0                   # past mhpmcounter31h
  csrr x4, 0x321                   # between mcountinhibit and mhpmevent3
  csrr x4, 0x322
  csrr x4, 0x39f                   # below pmpcfg0
  csrr x4, 0x3f0                   # past pmpaddr63
  csrw 0x3f0, x1
  csrr x4, 0xf10                   # below mvendorid
  csrr x4, 0xf16                   # past mconfigptr
  csrr x4, 0xc03                   # hpmcounter3: no Zihpm
  csrr x4, 0xc1f
  csrr x4, 0x302                   # medeleg: no S-mode
  csrr x4, 0x303                   # mideleg
  li x7, 0x77
  bne x4, x7, fail
  li x7, 15
  bne x29, x7, fail
  # and the implemented edges do not
  TEST_CASE(44, x4, 0, csrr x4, mhpmcounter3h; csrr x5, mhpmcounter31; csrr x5, mhpmevent3; csrr x5, mhpmevent31)
  TEST_CASE(45, x4, 0, csrw pmpaddr62, x1; csrr x4, pmpaddr62; csrr x5, pmpcfg14)
  li TESTNUM, 46
  li x7, 15
  bne x29, x7, fail

  # ---- mcountinhibit.CY stops mcycle (last: the trace comparison ends at the
  # branch on the cycle values) ---------------------------------------------
  li TESTNUM, 47
  csrwi mcountinhibit, 1
  csrr x5, mcycle
  nop
  csrr x6, mcycle
  csrr x10, mcycleh
  csrr x11, mcycleh
  csrwi mcountinhibit, 0
  csrr x4, mcountinhibit
  bne x4, x0, fail
  bne x5, x6, fail
  bne x10, x11, fail

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  addi x29, x29, 1
  csrr t5, mepc
  lhu t6, 0(t5)                    # skip the trapping instruction: 2 or 4 bytes (C)
  andi t6, t6, 3
  addi t5, t5, 2
  xori t6, t6, 3
  bnez t6, 1f
  addi t5, t5, 2
1:
  csrw mepc, t5
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
