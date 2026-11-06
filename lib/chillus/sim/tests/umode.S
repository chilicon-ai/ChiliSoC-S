/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: U-mode (riscv-privileged.pdf 1.12: M and U, no S).
# Covered: mstatus.MPP WARL (00 / 11), MRET to U (MPP = U after, MPRV
# cleared), U-mode loads / stores / branches / compressed code / FENCE.I,
# ECALL from U (mcause 8) and M (11), EBREAK from U, misaligned and faulting
# loads in U, CSR privilege in U (M CSRs illegal; cycle / time / instret[h]
# only with their mcounteren bit; writes of read-only counters illegal), MRET
# and WFI with mstatus.TW = 1 illegal in U, WFI in U with TW = 0 (sleeps until
# MTIP), interrupts taken in U with mstatus.MIE = 0 (and not in M), a pending
# interrupt taken on the first U-mode instruction after MRET, MPRV loads /
# stores in M (no PMP: they succeed; HPROT is checked by hprot.S).
# Every retired instruction is also compared with Spike by sim/run.py,
# including its privilege mode.
# The test installs its own trap handler (handler below) so that ECALL from U
# is a service call, not the end of the test: with a7 = 0 it returns to
# M-mode at x22 (TO_M); with a7 = 93 (RVTEST_PASS / FAIL) it goes to the
# environment's trap_vector. Other traps: x29 counts them, x28 = mcause, x27 =
# mepc, x26 = mtval, x25 = mstatus at the trap; exceptions skip the
# instruction (2 or 4 bytes) and return to the mode trapped from; interrupts
# clear their source (MSI: msip = 0, MTI: mtimecmp hi = max).
# Scratch registers used by the handler: t5, t6 (x30, x31); TO_M uses x22 and a7.

#include "riscv_test.h"
#include "test_macros.h"

#define CLINT_MSIP      0x02000000
#define CLINT_MTIMECMP  0x02004000
#define IRQ_MSI         0x80000003
#define IRQ_MTI         0x80000007
#define UNMAPPED        0x40000000

#define C16(...) .option push; .option rvc; __VA_ARGS__; .option pop

# M -> U: MRET with MPP = U to the next instruction
#define TO_U \
  la t0, 1f; csrw mepc, t0; li t0, MSTATUS_MPP; csrc mstatus, t0; mret; 1:

# U -> M: service ECALL, continues at the next instruction in M-mode
#define TO_M \
  la x22, 1f; li a7, 0; ecall; j fail; 1:

# last trap: x29 = n traps so far, mcause = cause
#define CHECK_TRAP(n, cause) \
  li x7, n; bne x29, x7, fail; li x7, cause; bne x28, x7, fail

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  la t0, handler
  csrw mtvec, t0
  li x29, 0
  la x8, buf

  # ---- mstatus.MPP WARL: 11 M, 00 U, 01 / 10 read as U ------------------------
  li TESTNUM, 2
  li x5, MSTATUS_MPP
  csrc mstatus, x5
  li x6, 0x800                            # MPP = 01
  csrs mstatus, x6
  csrr x4, mstatus
  and x4, x4, x5
  bnez x4, fail
  li x6, 0x1000                           # MPP = 10
  csrs mstatus, x6
  csrr x4, mstatus
  and x4, x4, x5
  bnez x4, fail
  csrs mstatus, x5                        # MPP = 11
  csrr x4, mstatus
  and x4, x4, x5
  bne x4, x5, fail
  # TW and MPRV are writable
  li x6, MSTATUS_TW | MSTATUS_MPRV
  csrs mstatus, x6
  csrr x4, mstatus
  and x4, x4, x6
  bne x4, x6, fail
  csrc mstatus, x6

  # ---- U-mode code: ALU, loads / stores, branches, compressed, FENCE.I -------
  li TESTNUM, 3
  li x1, 0x11223344
  TO_U
  sw x1, 0(x8)
  lw x2, 0(x8)
  addi x2, x2, 1
  sh x2, 4(x8)
  lbu x3, 5(x8)
  C16(c.addi x3, 3)
  beq x3, x0, 2f
  fence.i
  C16(c.j 2f)
  nop
2:
  TO_M
  csrr x4, mstatus                        # back in M: MPP = U (set by the ECALL trap)
  li x5, MSTATUS_MPP
  and x4, x4, x5
  bnez x4, fail
  li x7, 0x11223345
  bne x2, x7, fail
  li x7, 0x36
  bne x3, x7, fail
  bnez x29, fail                          # TO_U / TO_M: no counted trap

  # ---- ECALL from M is 11 (handled by the environment: test end), from U 8 ---
  # (TO_M above is the U one; the M one ends the test in RVTEST_PASS)

  # ---- EBREAK, misaligned load, access fault in U ----------------------------
  li TESTNUM, 4
  TO_U
  ebreak
  lw x4, 2(x8)                            # misaligned
  li x9, UNMAPPED
  lw x4, 0(x9)                            # access fault
  sw x4, 0(x9)
  TO_M
  CHECK_TRAP(4, CAUSE_STORE_ACCESS)
  bne x26, x9, fail                       # mtval = address
  li x5, MSTATUS_MPP                      # trapped from U: MPP = 00
  and x5, x25, x5
  bnez x5, fail

  # ---- CSR privilege in U: M CSRs, debug CSRs, read-only counters -------------
  li TESTNUM, 5
  li x29, 0
  li x4, 0x77
  TO_U
  csrr x4, mstatus
  csrr x4, mscratch
  csrw mscratch, x1
  csrr x4, misa
  csrr x4, mhartid
  csrr x4, mcycle
  csrr x4, dcsr
  csrr x4, hpmcounter3
  csrw cycle, x1                          # read-only
  csrr x4, 0x7a0                          # tselect
  TO_M
  CHECK_TRAP(10, CAUSE_ILLEGAL_INSTRUCTION)
  li x7, 0x77
  bne x4, x7, fail                        # rd unchanged
  csrr x5, mscratch                       # the U write had no effect
  bnez x5, fail

  # ---- counters in U: only with their mcounteren bit --------------------------
  li TESTNUM, 6
  li x29, 0
  csrw mcounteren, x0
  TO_U
  csrr x4, cycle
  csrr x4, time
  csrr x4, instret
  csrr x4, cycleh
  csrr x4, timeh
  csrr x4, instreth
  TO_M
  CHECK_TRAP(6, CAUSE_ILLEGAL_INSTRUCTION)

  li TESTNUM, 7
  li x29, 0
  csrwi mcounteren, 5                     # CY, IR
  TO_U
  csrr x4, cycle                          # values not compared (cycle counts)
  csrr x4, cycleh
  csrr x4, instreth
  csrr x10, instret
  csrr x4, time                           # TM = 0
  csrr x4, timeh
  TO_M
  CHECK_TRAP(2, CAUSE_ILLEGAL_INSTRUCTION)

  li TESTNUM, 8
  li x29, 0
  csrwi mcounteren, 2                     # TM
  TO_U
  csrr x4, time
  csrr x4, timeh
  csrr x4, cycle
  TO_M
  CHECK_TRAP(1, CAUSE_ILLEGAL_INSTRUCTION)
  csrw mcounteren, x0

  # ---- MRET in U and WFI with TW = 1 are illegal ------------------------------
  li TESTNUM, 9
  li x29, 0
  li x5, MSTATUS_TW
  csrs mstatus, x5
  TO_U
  mret
  wfi
  TO_M
  CHECK_TRAP(2, CAUSE_ILLEGAL_INSTRUCTION)
  li x5, MSTATUS_TW
  csrc mstatus, x5

  # ---- WFI in U with TW = 0: sleeps until MTIP, which is taken in U although
  # mstatus.MIE = 0 (mepc = the WFI + 4) ---------------------------------------
  li TESTNUM, 10
  li x29, 0
  li x21, CLINT_MTIMECMP
  li x23, -1
  sw x23, 4(x21)                          # mtimecmp hi = max: no timer interrupt
  lw x5, 4(x21)
  csrci mstatus, MSTATUS_MIE
  li x5, MIP_MTIP
  csrw mie, x5
  li x5, 0x8000
  sw x5, 0(x21)                           # mtimecmp = 0x8000, far above mtime
  sw x0, 4(x21)
  lw x5, 4(x21)
  TO_U
  wfi
irq_epc_10:
  TO_M
  CHECK_TRAP(1, IRQ_MTI)
  la x7, irq_epc_10
  bne x27, x7, fail
  li x5, MSTATUS_MIE                      # MIE was 0 at the trap
  and x5, x25, x5
  bnez x5, fail
  csrw mie, x0

  # ---- a pending MSI: not taken in M with MIE = 0, taken on the first U-mode
  # instruction after MRET -------------------------------------------------------
  li TESTNUM, 11
  li x29, 0
  li x5, MSTATUS_MPIE | MSTATUS_MIE
  csrc mstatus, x5                        # MIE = 0, and MRET keeps it 0
  li x5, MIP_MSIP
  csrw mie, x5
  li x20, CLINT_MSIP
  li x5, 1
  sw x5, 0(x20)                           # msip = 1
  lw x5, 0(x20)
  nop
  nop
  bnez x29, fail                          # M-mode, MIE = 0: not taken
  la t0, irq_epc_11
  csrw mepc, t0
  li t0, MSTATUS_MPP
  csrc mstatus, t0
  mret
irq_epc_11:
  addi x4, x0, 5
  TO_M
  CHECK_TRAP(1, IRQ_MSI)
  la x7, irq_epc_11
  bne x27, x7, fail
  li x7, 5
  bne x4, x7, fail
  csrw mie, x0

  # ---- MPRV: loads / stores in M with the U (or M) privilege ------------------
  li TESTNUM, 12
  li x29, 0
  li x5, MSTATUS_MPRV
  csrs mstatus, x5                        # MPP = U (from the last trap)
  li x1, 0x5555aaaa
  sw x1, 8(x8)
  lw x2, 8(x8)
  bne x2, x1, fail
  li x6, MSTATUS_MPP
  csrs mstatus, x6                        # MPP = M
  lh x2, 8(x8)
  li x7, -0x5556
  bne x2, x7, fail
  # MRET to M keeps MPRV, MRET to U clears it
  la t0, 2f
  csrw mepc, t0
  mret                                    # MPP = M: stays in M
2:
  csrr x4, mstatus
  and x4, x4, x5
  beqz x4, fail
  TO_U
  TO_M
  csrr x4, mstatus
  and x4, x4, x5
  bnez x4, fail
  bnez x29, fail

  la t0, trap_vector                      # RVTEST_PASS / FAIL from M-mode
  csrw mtvec, t0
  TEST_PASSFAIL

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
  csrr x26, mtval
  csrr x25, mstatus
  bgez t5, 3f
  li t6, CLINT_MSIP                       # interrupt: clear MSI and MTI
  sw x0, 0(t6)
  lw t6, 0(t6)
  li t6, CLINT_MTIMECMP
  sw x23, 4(t6)
  lw t6, 4(t6)
  mret
3:
  csrr t5, mepc                           # exception: skip the instruction
  lhu t6, 0(t5)
  andi t6, t6, 3
  addi t5, t5, 2
  xori t6, t6, 3                          # 0: 32-bit instruction
  bnez t6, 4f
  addi t5, t5, 2
4:
  csrw mepc, t5
  mret
  .popsection

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
  .align 4
buf: .fill 16, 4, 0
RVTEST_DATA_END
