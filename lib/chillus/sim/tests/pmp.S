/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
# ChillU-S sequence test: PMP with 4 entries, grain 4 bytes (chillus_pmp,
# riscv-privileged.pdf 3.7). Compared with Spike (--pmpregions=4) per
# retired instruction, including mcause / mtval of every fault.
# run.py: needs-pmp
# Covered: pmpaddr0..3 read / write, pmpcfg0 bits [6:5] read 0; NA4 R-only
# word (U store faults 7, byte store too, load works; M not restricted);
# priority (entry 0 NA4 without permissions over entry 1 NAPOT RW); TOR
# (pmpaddr[i-1] <= a < pmpaddr[i], an empty range matches nothing);
# instruction fetch: U jump into a NAPOT block without X faults (mcause 1,
# mepc = mtval = target), M fetch is not restricted, X allows it; a 32-bit
# instruction whose second half is in a non-executable word (mtval = pc + 2);
# no matching entry: U denied, M allowed; MPRV (M loads with MPP = U are
# checked as U); lock: a locked entry restricts M (store fault 7), its cfg
# and pmpaddr ignore writes, a locked TOR entry also locks the pmpaddr below.
# Entry 3 is a 1 MiB NAPOT RWX region over the RAM (the fallback for U
# code and data); entries 0..2 are the ones under test.
# Handler as in umode.S: ECALL from U with a7 = 0 returns to M at x22
# (TO_M), a7 = 93 or ECALL from M goes to trap_vector; other traps: x29
# count, x28 mcause, x27 mepc, x26 mtval; exceptions skip the instruction,
# an instruction access fault returns to ra.

#include "riscv_test.h"
#include "test_macros.h"

#define RAM_NAPOT   ((0x80000000 >> 2) | ((0x100000 >> 3) - 1))   // 1 MiB at 0x8000_0000
#define A_TOR       0x08
#define A_NA4       0x10
#define A_NAPOT     0x18
#define P_R         0x01
#define P_W         0x02
#define P_X         0x04
#define P_L         0x80

# M -> U: MRET with MPP = U to the next instruction
#define TO_U \
  la t0, 1f; csrw mepc, t0; li t0, MSTATUS_MPP; csrc mstatus, t0; mret; 1:

# U -> M: service ECALL, continues at the next instruction in M-mode
#define TO_M \
  la x22, 1f; li a7, 0; ecall; j fail; 1:

# last trap: x29 = n traps so far, mcause = cause, mtval = x9
#define CHECK_TRAP(n, cause) \
  li x7, n; bne x29, x7, fail; li x7, cause; bne x28, x7, fail; bne x26, x9, fail

# pmpcfg0 = cfg (entries 0..3, byte i = entry i)
#define SET_CFG(cfg) li t0, cfg; csrw pmpcfg0, t0

# pmpaddr<n> = word address of label + off
#define SET_ADDR(n, label, off) la t0, label + off; srli t0, t0, 2; csrw pmpaddr##n, t0

  .option norelax

RVTEST_RV32M
RVTEST_CODE_BEGIN
  .option norvc

  la t0, handler
  csrw mtvec, t0
  li x29, 0
  la x8, pbuf
  li x20, 0x11111111
  sw x20, 0(x8)
  sw x20, 4(x8)
  sw x20, 8(x8)
  sw x20, 12(x8)

  # ---- CSRs: pmpaddr read / write, pmpcfg0 bits [6:5] read 0 ---------------
  li TESTNUM, 2
  SET_CFG(0)
  li x5, -1
  csrw pmpaddr1, x5
  csrr x4, pmpaddr1
  bne x4, x5, fail
  li x5, 0x12345678
  csrw pmpaddr2, x5
  csrr x4, pmpaddr2
  bne x4, x5, fail
  li x5, 0x1f
  csrw pmpaddr3, x5
  csrr x4, pmpaddr3
  bne x4, x5, fail
  li x5, 0x7f007f00                       # bytes 1 and 3: bits [6:5] set
  csrw pmpcfg0, x5
  csrr x4, pmpcfg0
  li x7, 0x1f001f00
  bne x4, x7, fail
  SET_CFG(0)

  # entry 3: RAM, RWX (U code and data)
  li t0, RAM_NAPOT
  csrw pmpaddr3, t0
  SET_CFG((A_NAPOT | P_R | P_W | P_X) << 24)
  li x29, 0

  # ---- U-mode through entry 3; no match outside it: U denied, M allowed ---
  li TESTNUM, 3
  TO_U
  lw x4, 0(x8)
  sw x4, 4(x8)
  li x9, 0x80100000                       # past the 1 MiB RAM: no entry matches
  lw x4, 0(x9)
  TO_M
  CHECK_TRAP(1, CAUSE_LOAD_ACCESS)
  li x29, 0

  # ---- NA4 R-only word: U loads it, U stores fault, M is not restricted -----
  li TESTNUM, 4
  SET_ADDR(0, pbuf, 0)
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | (A_NA4 | P_R))
  TO_U
  lw x4, 0(x8)
  sw x4, 0(x8)                            # fault
  sb x4, 1(x8)                            # fault
  lw x5, 4(x8)                            # next word: entry 3
  sw x5, 4(x8)
  TO_M
  addi x9, x8, 1
  CHECK_TRAP(2, CAUSE_STORE_ACCESS)
  sw x20, 0(x8)                           # M: allowed (entry not locked)
  li x29, 0

  # ---- priority: entry 0 NA4 without permissions over entry 1 NAPOT RW ------
  li TESTNUM, 5
  SET_ADDR(1, pbuf, 0)                    # NAPOT 16 bytes: pmpaddr | 1
  csrr t0, pmpaddr1
  ori t0, t0, 1
  csrw pmpaddr1, t0
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | ((A_NAPOT | P_R | P_W) << 8) | A_NA4)
  TO_U
  lw x4, 0(x8)                            # fault (entry 0)
  lw x5, 4(x8)                            # entry 1
  sw x5, 8(x8)
  TO_M
  mv x9, x8
  CHECK_TRAP(1, CAUSE_LOAD_ACCESS)
  li x29, 0

  # ---- TOR: pbuf <= a < pbuf + 8 without permissions; empty range ---------
  li TESTNUM, 6
  SET_ADDR(0, pbuf, 0)
  SET_ADDR(1, pbuf, 8)
  SET_ADDR(2, pbuf, 8)                    # entry 2: TOR from pbuf + 8 to pbuf + 8: empty
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | (A_TOR << 16) | (A_TOR << 8))
  TO_U
  lw x4, 4(x8)                            # fault
  lw x4, 8(x8)                            # entry 3 (entry 2 is empty)
  lw x4, -4(x8)                           # entry 3
  sw x4, 0(x8)                            # fault
  TO_M
  mv x9, x8
  CHECK_TRAP(2, CAUSE_STORE_ACCESS)
  li x29, 0

  # ---- fetch: NAPOT block without X ------------------------------------------
  li TESTNUM, 7
  SET_ADDR(0, xbuf, 0)                    # NAPOT 16 bytes
  csrr t0, pmpaddr0
  ori t0, t0, 1
  csrw pmpaddr0, t0
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | (A_NAPOT | P_R))
  la x9, xbuf
  jalr ra, x9                             # M: allowed
  bnez x29, fail
  TO_U
  jalr ra, x9                             # fault: back at ra
  lw x4, 0(x9)                            # R: allowed
  TO_M
  CHECK_TRAP(1, CAUSE_FETCH_ACCESS)
  bne x27, x9, fail                       # mepc = the target
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | (A_NAPOT | P_R | P_X))
  TO_U
  jalr ra, x9                             # X: allowed
  TO_M
  li x7, 1
  bne x29, x7, fail
  li x29, 0

  # ---- fetch: 32-bit instruction whose second half is not executable -------
  li TESTNUM, 8
  SET_ADDR(0, ybuf, 4)                    # NA4 on the word after ybuf: no X
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | (A_NA4 | P_R))
  la x11, ybuf
  TO_U
  jalr ra, x11                            # c.nop runs, the 32-bit ret faults
  TO_M
  la x9, ybuf + 4                         # mtval: its second half
  CHECK_TRAP(1, CAUSE_FETCH_ACCESS)
  la x7, ybuf + 2
  bne x27, x7, fail                       # mepc: the instruction
  li x29, 0

  # ---- MPRV: M loads with MPP = U are checked as U ---------------------------
  li TESTNUM, 9
  SET_ADDR(0, pbuf, 0)
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | A_NA4)
  li x5, MSTATUS_MPP
  csrc mstatus, x5
  li x5, MSTATUS_MPRV
  csrs mstatus, x5
  lw x4, 0(x8)                            # fault (as U)
  lw x4, 4(x8)                            # entry 3
  li x5, MSTATUS_MPP
  csrs mstatus, x5
  lw x4, 0(x8)                            # MPP = M: allowed
  li x5, MSTATUS_MPRV
  csrc mstatus, x5
  mv x9, x8
  CHECK_TRAP(1, CAUSE_LOAD_ACCESS)
  li x29, 0

  # ---- lock: restricts M; cfg / pmpaddr writes ignored; TOR locks the base --
  li TESTNUM, 10
  SET_ADDR(0, pbuf, 0)                    # entry 1: locked TOR, empty (pbuf .. pbuf)
  SET_ADDR(1, pbuf, 0)
  SET_ADDR(2, pbuf, 12)                   # entry 2: locked NA4, R only
  SET_CFG(((A_NAPOT | P_R | P_W | P_X) << 24) | ((P_L | A_NA4 | P_R) << 16) | ((P_L | A_TOR) << 8))
  lw x4, 12(x8)                           # M: R allowed
  sw x4, 12(x8)                           # M: fault (locked, no W)
  addi x9, x8, 12
  CHECK_TRAP(1, CAUSE_STORE_ACCESS)
  sw x4, 8(x8)                            # entry 3
  li t0, -1
  csrw pmpaddr2, t0                       # ignored (entry 2 locked)
  csrw pmpaddr1, t0                       # ignored (entry 1 locked)
  csrw pmpaddr0, t0                       # ignored (entry 1: locked TOR)
  SET_CFG(0)                              # bytes 1 and 2 ignored
  csrr x4, pmpcfg0
  li x7, ((P_L | A_NA4 | P_R) << 16) | ((P_L | A_TOR) << 8)
  bne x4, x7, fail
  la x7, pbuf
  srli x7, x7, 2
  csrr x4, pmpaddr0
  bne x4, x7, fail
  li x7, RAM_NAPOT                        # entry 3 unlocked: written
  csrw pmpaddr3, x7
  SET_CFG((A_NAPOT | P_R | P_W | P_X) << 24)
  li x29, 0

  la t0, trap_vector                      # RVTEST_PASS / FAIL from M-mode
  csrw mtvec, t0
  TEST_PASSFAIL

  # instruction blocks for the fetch tests
  .balign 16
xbuf:
  ret
  ret
  ret
  ret
  .balign 16
ybuf:
  .option push
  .option rvc
  c.nop
  .option pop
  jalr x0, 0(ra)                          # 32-bit, at ybuf + 2 .. + 5
  .balign 16

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
  .balign 16
  .word 0x22222222                        # pbuf - 4 (pbuf - 16 .. - 1: padding)
  .balign 16
pbuf: .fill 4, 4, 0
  .fill 4, 4, 0
RVTEST_DATA_END
