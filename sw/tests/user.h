// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// user.h: U-mode helpers shared by the umode and pmp tests (one test per
// program, so the definitions below appear once per binary).
//   PHASE(n)       mark a test step in socctl scratch[0]; the testbench counts
//                  the core's unprivileged transfers per phase
//   enter_user(fn) run fn in U-mode (interrupts may be on: MIE is masked while
//                  mepc is set and comes back after user_exit); fn returns to user_exit, whose ECALL
//                  (a7 = SYS_EXIT) the test's trap hook hands to
//                  user_exit_trap, which resumes M-mode after enter_user
//   pmp_set(i, pmpaddr, cfg), NAPOT(base, size)   PMP entry i
#ifndef USER_H
#define USER_H

#include "runtime.h"
#include "chilimix_socctl_regs.h"

#define SOCCTL(off)  REG32(SOCCTL_BASE, off)
#define PHASE(n)     (SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = (n))

#define SYS_EXIT     0x5E            // a7 of the ECALL that ends user code
#define MSTATUS_MPP  0x1800u
#define MSTATUS_MPRV 0x20000u

#define PMP_R      0x01u
#define PMP_W      0x02u
#define PMP_X      0x04u
#define PMP_NAPOT  0x18u
#define PMP_L      0x80u
#define NAPOT(base, size) (((base) | ((size) / 2 - 1)) >> 2)   // size: a power of two >= 8

uint32_t saved_ra;
void enter_user(void (*fn)(void));
extern char m_resume[];
__asm__(
  "  .text\n"
  "  .globl enter_user\n"
  "  .option push\n"
  "  .option norvc\n"
  "enter_user:\n"
  "  csrrci t1, mstatus, 8\n"       // MIE low while mepc / MPP are set: an interrupt here would replace mepc
  "  andi  t1, t1, 8\n"
  "  slli  t1, t1, 4\n"              // the old MIE as MPIE: back in M-mode after user_exit, MIE is restored
  "  li    t2, 0x80\n"
  "  csrc  mstatus, t2\n"
  "  csrs  mstatus, t1\n"
  "  la    t0, saved_ra\n"
  "  sw    ra, 0(t0)\n"
  "  csrw  mepc, a0\n"
  "  li    t0, 0x1800\n"
  "  csrc  mstatus, t0\n"          // MPP = U
  "  la    ra, user_exit\n"
  "  mret\n"
  "user_exit:\n"
  "  li    a7, 0x5E\n"
  "  ecall\n"
  "  .globl m_resume\n"
  "m_resume:\n"
  "  la    t0, saved_ra\n"
  "  lw    ra, 0(t0)\n"
  "  ret\n"
  "  .option pop\n");

static inline uint32_t mstatus(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, mstatus" : "=r"(v));
  return v;
}

// the mepc to resume at for the user_exit ECALL, 0 for any other trap
static inline uint32_t user_exit_trap(uint32_t mcause, const uint32_t *frame)
{
  if (mcause != 8 || frame[11] != SYS_EXIT)
    return 0;
  __asm__ volatile("csrs mstatus, %0" : : "r"(MSTATUS_MPP) : "memory");   // back to M
  return (uint32_t)m_resume;
}

// PMP entry i (0..3): pmpaddr i, then its pmpcfg0 byte
static inline void pmp_set(int i, uint32_t addr, uint32_t cfg)
{
  switch (i) {
  case 0: __asm__ volatile("csrw pmpaddr0, %0" : : "r"(addr) : "memory"); break;
  case 1: __asm__ volatile("csrw pmpaddr1, %0" : : "r"(addr) : "memory"); break;
  case 2: __asm__ volatile("csrw pmpaddr2, %0" : : "r"(addr) : "memory"); break;
  default: __asm__ volatile("csrw pmpaddr3, %0" : : "r"(addr) : "memory"); break;
  }
  uint32_t mask = 0xffu << (8 * i);
  __asm__ volatile("csrc pmpcfg0, %0" : : "r"(mask) : "memory");
  __asm__ volatile("csrs pmpcfg0, %0" : : "r"(cfg << (8 * i)) : "memory");
}

static inline uint32_t pmpcfg0(void)
{
  uint32_t v;
  __asm__ volatile("csrr %0, pmpcfg0" : "=r"(v));
  return v;
}

#endif
