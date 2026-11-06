// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// umode: ChillU-S U-mode on the SoC, and the bus privilege it shows (HPROT).
// PMP entry 0 gives U all memory (sw/tests/pmp.c tests the PMP). Each step
// writes its phase to socctl scratch[0]; the testbench counts the
// core's unprivileged fetches, data accesses and APB transfers per phase,
// and sim/run.py checks them:
//   phase 1  user code: loads / stores to SRAM1, UART0 output, a system
//            call (ECALL from U), M-mode CSR and MRET (illegal in U), the
//            cycle counter with mcounteren.CY clear (illegal) and set
//            -> user fetches, data accesses and APB transfers
//   phase 2  M-mode with mstatus.MPRV and MPP = U: loads / stores use U
//            -> user data accesses only, privileged fetches, no APB
//   phase 0, 3  M-mode only -> no user transfers
#include "user.h"

#define SYS_DOUBLE   0x2D            // a7 of the test system call: a0 *= 2

static volatile int n_ecall, n_illegal, n_other;
static volatile uint32_t last_cause, last_mpp;
static volatile uint32_t user_data[4];  // SRAM1 (.bss)

static uint32_t on_trap(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  last_cause = mcause;
  last_mpp = (mstatus() & MSTATUS_MPP) >> 11;
  uint32_t resume = user_exit_trap(mcause, frame); // ECALL from U: user code done
  if (resume)
    return resume;
  if (mcause == 8 && frame[11] == SYS_DOUBLE) {    // system call: a0 *= 2
    n_ecall++;
    frame[4] *= 2;
    return mepc + 4;
  }
  if (mcause == 2) {                               // illegal instruction: skip it (4 bytes)
    n_illegal++;
    return mepc + 4;
  }
  n_other++;
  return mepc + 4;
}

static uint32_t sys_double(uint32_t x)
{
  register uint32_t a0 __asm__("a0") = x;
  register uint32_t a7 __asm__("a7") = SYS_DOUBLE;
  __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "memory");
  return a0;
}

static volatile uint32_t u_double, u_mstatus_seen, u_cycle_ok;
static volatile int u_ill_csr, u_ill_mret, u_ill_cycle;

static void user_main(void)
{
  int ill;
  for (int i = 0; i < 4; i++)
    user_data[i] = 0x1000u * (i + 1);
  user_data[3] += user_data[0];
  con_printf("user: hello from U-mode\n");
  u_double = sys_double(21);

  ill = n_illegal;                                   // M-mode CSR: illegal in U
  uint32_t v = 0xdead;
  __asm__ volatile("csrr %0, mstatus" : "+r"(v));
  u_mstatus_seen = v;
  u_ill_csr = n_illegal - ill;

  ill = n_illegal;                                   // MRET: illegal in U
  __asm__ volatile(".option push\n .option norvc\n mret\n .option pop" ::: "memory");
  u_ill_mret = n_illegal - ill;

  ill = n_illegal;                                   // cycle with mcounteren.CY = 0: illegal
  uint32_t c = 0;
  __asm__ volatile("csrr %0, cycle" : "+r"(c));
  u_ill_cycle = n_illegal - ill;
}

static void user_cycle(void)
{
  uint32_t c0, c1;                                   // mcounteren.CY = 1: allowed
  __asm__ volatile("csrr %0, cycle" : "=r"(c0));
  __asm__ volatile("csrr %0, cycle" : "=r"(c1));
  u_cycle_ok = c1 != c0;
}

int main(void)
{
  trap_hook = on_trap;
  pmp_set(0, 0xffffffffu, PMP_NAPOT | PMP_R | PMP_W | PMP_X);   // U may use all memory (PMP tested by pmp.c)
  __asm__ volatile("csrw mcounteren, zero" ::: "memory");

  PHASE(1);
  enter_user(user_main);
  __asm__ volatile("csrw mcounteren, %0" : : "r"(1) : "memory");
  enter_user(user_cycle);
  __asm__ volatile("csrw mcounteren, zero" ::: "memory");
  uint32_t ill_seen = n_illegal;

  PHASE(2);                                          // MPRV: data accesses as U
  volatile uint32_t *p = &user_data[1];
  __asm__ volatile("csrc mstatus, %0" : : "r"(MSTATUS_MPP) : "memory");
  __asm__ volatile("csrs mstatus, %0" : : "r"(MSTATUS_MPRV) : "memory");
  uint32_t mprv_rd = *p;
  *p = mprv_rd + 1;
  __asm__ volatile("csrc mstatus, %0" : : "r"(MSTATUS_MPRV) : "memory");
  __asm__ volatile("csrs mstatus, %0" : : "r"(MSTATUS_MPP) : "memory");
  PHASE(3);

  con_printf("umode: double %u, illegal csr %d mret %d cycle %d, cycle ok %u, mprv read %x\n",
             (unsigned)u_double, u_ill_csr, u_ill_mret, u_ill_cycle, (unsigned)u_cycle_ok,
             (unsigned)mprv_rd);
  if (u_double != 42 || n_ecall != 1)
    return 1;
  if (u_ill_csr != 1 || u_mstatus_seen != 0xdead || u_ill_mret != 1 || u_ill_cycle != 1)
    return 2;
  if (!u_cycle_ok || ill_seen != 3 || n_other)
    return 3;
  if (user_data[0] != 0x1000 || user_data[3] != 0x5000 || mprv_rd != 0x2000 || user_data[1] != 0x2001)
    return 4;
  if (last_cause != 8 || last_mpp != 0)              // last trap: the user_cycle exit ECALL from U
    return 5;
  if (mstatus() & MSTATUS_MPRV)
    return 6;
  return 0;
}
