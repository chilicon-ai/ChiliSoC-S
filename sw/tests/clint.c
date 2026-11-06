// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// clint: ACLINT timer and software interrupts (mtime runs at clk / clkdiv[0]).
#include "runtime.h"
#include "chilimix_aclint_regs.h"
#include "chilimix_socctl_regs.h"

#define CLINT(off) REG32(CLINT_BASE, off)

static volatile int n_timer, n_soft;

static uint64_t mtime(void)
{
  uint32_t hi, lo;
  do {
    hi = CLINT(CHILIMIX_ACLINT_MTIME_HI_OFFSET);
    lo = CLINT(CHILIMIX_ACLINT_MTIME_LO_OFFSET);
  } while (hi != CLINT(CHILIMIX_ACLINT_MTIME_HI_OFFSET));
  return ((uint64_t)hi << 32) | lo;
}

static void set_mtimecmp(uint64_t t)
{
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = 0xffffffffu;   // no spurious match on the way
  CLINT(CHILIMIX_ACLINT_MTIMECMP_LO_OFFSET(0)) = (uint32_t)t;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = (uint32_t)(t >> 32);
}

static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (mcause == 0x80000007u) {            // machine timer
    n_timer++;
    set_mtimecmp(~0ull);
  } else if (mcause == 0x80000003u) {     // machine software
    n_soft++;
    CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 0;
  } else {
    exit(0x400 + (int)mcause);
  }
  return mepc;
}

int main(void)
{
  trap_hook = hook;
  // mtime at clk / 4
  REG32(SOCCTL_BASE, CHILIMIX_SOCCTL_CLKDIV_OFFSET(0)) = 4;
  uint64_t t0 = mtime();
  uint64_t c0 = rd_cycle();
  while (mtime() < t0 + 100)
    ;
  uint64_t dc = rd_cycle() - c0;
  con_printf("mtime +100 in %u cycles\n", (unsigned)dc);
  if (dc < 380 || dc > 480)
    return 1;

  set_mtimecmp(~0ull);
  __asm__ volatile("csrs mie, %0" :: "r"(0x88));   // MTIE, MSIE
  __asm__ volatile("csrs mstatus, 8");            // MIE
  for (int i = 0; i < 3; i++) {
    set_mtimecmp(mtime() + 20);
    while (n_timer == i)
      __asm__ volatile("wfi");
  }
  for (int i = 0; i < 3; i++) {
    CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 1;
    while (n_soft == i)
      ;
  }
  con_printf("timer interrupts %d, software interrupts %d\n", n_timer, n_soft);
  return (n_timer == 3 && n_soft == 3) ? 0 : 2;
}
