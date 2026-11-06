/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S test: the privilege of every bus access (imss_priv / dmss_priv,
# HPROT[1] with --param AHB=1). The testbench makes 4 KiB at 0x80080000
# privileged (+priv_region): an access to it with priv = 0 gets a bus error.
# Covered: M-mode fetch / load / store to the region succeed; with
# mstatus.MPRV = 1 loads and stores use MPP (U: load / store access fault
# with mtval = the address, other memory still works; M: succeed) while
# fetches stay M; U-mode loads, stores and fetches of the region fault
# (mcause 5, 7, 1). With --param AHB=1 the testbench also checks the HPROT
# format of every transfer (opcode / data, privileged, not bufferable /
# cacheable). Spike has no such region, so this test checks itself.
# Handler as in umode.S: ECALL from U with a7 = 0 returns to M at x22 (TO_M),
# a7 = 93 or ECALL from M goes to trap_vector; other traps: x29 count, x28
# mcause, x27 mepc, x26 mtval; exceptions skip the instruction, an
# instruction access fault returns to ra.
# run.py: no-spike; plusarg +priv_region=80080000

#include "riscv_test.h"
#include "test_macros.h"

#define REGION   0x80080000
#define RET_INSN 0x00008067

  .option norelax

# M -> U: MRET with MPP = U to the next instruction
#define TO_U \
  la t0, 1f; csrw mepc, t0; li t0, MSTATUS_MPP; csrc mstatus, t0; mret; 1:

# U -> M: service ECALL, continues at the next instruction in M-mode
#define TO_M \
  la x22, 1f; li a7, 0; ecall; j fail; 1:

# last trap: x29 = n traps so far, mcause = cause, mtval = addr in x9
#define CHECK_TRAP(n, cause) \
  li x7, n; bne x29, x7, fail; li x7, cause; bne x28, x7, fail; \
  bne x26, x9, fail

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  la t0, handler
  csrw mtvec, t0
  li x29, 0
  li x9, REGION
  la x8, buf

  # ---- M-mode: store, load and fetch the region ------------------------------
  li TESTNUM, 2
  li x11, RET_INSN
  sw x11, 0(x9)
  li x11, 0x13579bdf
  sw x11, 4(x9)
  fence.i
  lw x2, 0(x9)
  li x7, RET_INSN
  bne x2, x7, fail
  jalr ra, x9                             # fetch from the region: ret
  bnez x29, fail

  # ---- MPRV = 1, MPP = U: loads / stores are U, fetches stay M ---------------
  li TESTNUM, 3
  li x5, MSTATUS_MPP
  csrc mstatus, x5
  li x5, MSTATUS_MPRV
  csrs mstatus, x5
  li x2, 0x77
  lw x2, 4(x9)                            # faults: x2 unchanged
  addi x9, x9, 4
  CHECK_TRAP(1, CAUSE_LOAD_ACCESS)
  li x7, 0x77
  bne x2, x7, fail
  sh x11, 2(x9)                            # faults
  addi x9, x9, 2
  CHECK_TRAP(2, CAUSE_STORE_ACCESS)
  li x9, REGION
  sw x11, 0(x8)                            # other memory: fine
  lw x3, 0(x8)
  bne x3, x11, fail
  jalr ra, x9                             # fetch: M
  li x7, 2
  bne x29, x7, fail
  csrr x4, mstatus                        # still MPRV = 1, MPP = U
  li x5, MSTATUS_MPRV | MSTATUS_MPP
  and x4, x4, x5
  li x7, MSTATUS_MPRV
  bne x4, x7, fail

  # ---- MPRV = 1, MPP = M: loads / stores are M -------------------------------
  li TESTNUM, 4
  li x5, MSTATUS_MPP
  csrs mstatus, x5
  lw x2, 4(x9)
  bne x2, x11, fail
  sb x0, 4(x9)
  lbu x2, 5(x9)
  li x7, 0x9b
  bne x2, x7, fail
  li x7, 2
  bne x29, x7, fail
  li x5, MSTATUS_MPRV
  csrc mstatus, x5

  # ---- U-mode: load, store and fetch of the region fault ---------------------
  li TESTNUM, 5
  li x29, 0
  li x2, 0x55
  TO_U
  lw x2, 0(x9)
  sw x2, 0(x9)
  jalr ra, x9                             # fetch fault: back at ra
  lw x3, 0(x8)                            # other memory: fine
  TO_M
  li x7, 0x55
  bne x2, x7, fail
  bne x3, x11, fail
  CHECK_TRAP(3, CAUSE_FETCH_ACCESS)
  bne x27, x9, fail                       # mepc = the region
  li x7, RET_INSN                         # the U store did not write
  lw x2, 0(x9)
  bne x2, x7, fail

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
  li t6, CAUSE_FETCH_ACCESS
  bne t5, t6, 3f
  csrw mepc, ra                           # fetch fault: return to ra
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
buf: .fill 4, 4, 0
RVTEST_DATA_END
