// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// wfi: WFI sleep (chillus core_sleep). First with mstatus.MIE low: the
// ACLINT timer wakes the core, which resumes after the WFI without a trap
// (riscv-privileged 3.3.3). Then with MIE high: the same wake takes the
// timer interrupt. The core clock is gated while asleep, so mcycle counts
// only the cycles around the sleep. sim/run.py also requires the testbench
// to have seen core_sleep high.
#include "runtime.h"
#include "chilimix_aclint_regs.h"
#include "chilimix_socctl_regs.h"

#define CLINT(off) REG32(CLINT_BASE, off)
#define DELAY 200                 // mtime ticks to sleep

static volatile int n_timer, n_other;

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
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = 0xffffffffu;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_LO_OFFSET(0)) = (uint32_t)t;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = (uint32_t)(t >> 32);
}

static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (mcause == 0x80000007u) {
    n_timer++;
    set_mtimecmp(~0ull);
  } else {
    n_other++;
  }
  return mepc;
}

int main(void)
{
  trap_hook = hook;
  REG32(SOCCTL_BASE, CHILIMIX_SOCCTL_CLKDIV_OFFSET(0)) = 2;   // mtime at clk / 2
  set_mtimecmp(~0ull);
  __asm__ volatile("csrs mie, %0" :: "r"(0x80));              // MTIE only

  // MIE low: wake, no trap
  uint64_t t0 = mtime();
  set_mtimecmp(t0 + DELAY);
  uint64_t c0 = rd_cycle();
  __asm__ volatile("wfi");
  uint64_t dc = rd_cycle() - c0;
  uint64_t t1 = mtime();
  uint32_t mip;
  __asm__ volatile("csrr %0, mip" : "=r"(mip));
  con_printf("wfi (MIE 0): %u cycles, mtime +%u, mip 0x%x, traps %d\n", (unsigned)dc,
             (unsigned)(t1 - t0), (unsigned)mip, n_timer + n_other);
  if (t1 < t0 + DELAY || !(mip & 0x80) || n_timer || n_other)
    return 1;
  if (dc >= DELAY)                // mcycle stops while the core clock is gated:
    return 2;                     // about 2 * DELAY clk cycles passed, few counted

  // MIE high: wake and take the interrupt
  set_mtimecmp(mtime() + DELAY);
  __asm__ volatile("csrs mstatus, 8");
  __asm__ volatile("wfi");
  for (int i = 0; i < 20 && !n_timer; i++)
    ;
  __asm__ volatile("csrc mstatus, 8");
  con_printf("wfi (MIE 1): timer interrupts %d\n", n_timer);
  if (n_timer != 1 || n_other)
    return 3;
  return 0;
}
