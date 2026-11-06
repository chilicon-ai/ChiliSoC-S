// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// wdog: the chilimix_timer watchdog (SiFive AON layout), counting mtime
// ticks. First boot (power-on): writes without the key are ignored; with
// rsten clear, an elapsed count raises PLIC source IRQ_WDOG; with coreawake
// it does not count while the core sleeps in WFI (sim/run.py requires the
// sleep); with rsten set, feeding keeps the system alive for several
// periods, then the starved watchdog bites. Second boot: the reset cause is
// req (the watchdog's socctl rst_req), the mark in scratch[0] survived and
// the watchdog is back at its reset state.
#include "runtime.h"
#include "chilimix_aclint_regs.h"
#include "chilimix_plic_regs.h"
#include "chilimix_socctl_regs.h"
#include "chilimix_timer_wdog_regs.h"
#include "chilimix_uart_regs.h"

#define CLINT(off)  REG32(CLINT_BASE, off)
#define PLIC(off)   REG32(PLIC_BASE, off)
#define SOCCTL(off) REG32(SOCCTL_BASE, off)
#define WDOG(off)   REG32(WDOG_BASE, off)
#define KEY   0x0051F15Eu
#define FOOD  0x0D09F00Du
#define MARK  0xB17E0001u

#define CFG_ENALWAYS  CHILIMIX_TIMER_WDOG_CFG_ENALWAYS_MASK
#define CFG_COREAWAKE CHILIMIX_TIMER_WDOG_CFG_COREAWAKE_MASK
#define CFG_RSTEN     CHILIMIX_TIMER_WDOG_CFG_RSTEN_MASK
#define CFG_IP0       CHILIMIX_TIMER_WDOG_CFG_IP0_MASK

static volatile int n_wdog, n_bad;
static volatile uint32_t irq_mtime;

static uint32_t mtime_lo(void)
{
  return CLINT(CHILIMIX_ACLINT_MTIME_LO_OFFSET);
}

static void set_mtimecmp(uint64_t t)
{
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = 0xffffffffu;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_LO_OFFSET(0)) = (uint32_t)t;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = (uint32_t)(t >> 32);
}

static void wdog_wr(uint32_t off, uint32_t v)       // unlock, then write
{
  WDOG(CHILIMIX_TIMER_WDOG_KEY_OFFSET) = KEY;
  WDOG(off) = v;
}

static void wdog_feed(void)
{
  wdog_wr(CHILIMIX_TIMER_WDOG_FEED_OFFSET, FOOD);
}

// stop and restart from 0 with compare value cmp and configuration cfg
static void wdog_start(uint32_t cmp, uint32_t cfg)
{
  wdog_wr(CHILIMIX_TIMER_WDOG_CFG_OFFSET, 0);
  wdog_wr(CHILIMIX_TIMER_WDOG_COUNT_OFFSET, 0);
  wdog_wr(CHILIMIX_TIMER_WDOG_CMP0_OFFSET, cmp);
  wdog_wr(CHILIMIX_TIMER_WDOG_CFG_OFFSET, cfg);
}

static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (mcause != 0x8000000bu) {
    n_bad++;
    return mepc;
  }
  uint32_t src = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
  if (src == IRQ_WDOG && (WDOG(CHILIMIX_TIMER_WDOG_CFG_OFFSET) & CFG_IP0)) {
    irq_mtime = mtime_lo();
    wdog_wr(CHILIMIX_TIMER_WDOG_COUNT_OFFSET, 0);  // no longer elapsed
    wdog_wr(CHILIMIX_TIMER_WDOG_CFG_OFFSET, 0);    // stop, clear ip0
    n_wdog++;
  } else {
    n_bad++;
  }
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;         // complete
  return mepc;
}

static int first_boot(uint32_t cause)
{
  if (cause != CHILIMIX_SOCCTL_RST_CAUSE_POR_MASK)
    return 1;
  SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;  // w1c

  // locked: a write without the key does nothing
  WDOG(CHILIMIX_TIMER_WDOG_CFG_OFFSET) = CFG_ENALWAYS;
  WDOG(CHILIMIX_TIMER_WDOG_KEY_OFFSET) = KEY;
  WDOG(CHILIMIX_TIMER_WDOG_FEED_OFFSET) = 0;       // not the food: locks again
  WDOG(CHILIMIX_TIMER_WDOG_CMP0_OFFSET) = 7;
  if (WDOG(CHILIMIX_TIMER_WDOG_CFG_OFFSET) || WDOG(CHILIMIX_TIMER_WDOG_CMP0_OFFSET) == 7 ||
      WDOG(CHILIMIX_TIMER_WDOG_COUNT_OFFSET))
    return 2;

  // interrupt through the PLIC after cmp0 ticks
  trap_hook = hook;
  PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(IRQ_WDOG)) = 1;
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = 1u << IRQ_WDOG;
  PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = 0;
  __asm__ volatile("csrs mie, %0" :: "r"(0x800));  // MEIE
  __asm__ volatile("csrs mstatus, 8");
  uint32_t t0 = mtime_lo();
  wdog_start(40, CFG_ENALWAYS);
  for (int t = 0; t < 2000 && !n_wdog; t++)
    ;
  __asm__ volatile("csrc mstatus, 8");
  con_printf("wdog irq: %d after %u ticks\n", n_wdog, (unsigned)(irq_mtime - t0));
  if (n_wdog != 1 || n_bad || irq_mtime - t0 < 40)
    return 3;
  if (WDOG(CHILIMIX_TIMER_WDOG_CFG_OFFSET) & CFG_IP0)
    return 4;

  // coreawake: no counting while the core sleeps
  __asm__ volatile("csrs mie, %0" :: "r"(0x80));   // MTIE (wakes WFI, MIE stays low)
  set_mtimecmp(~0ull);
  wdog_start(0xffff, CFG_COREAWAKE);
  t0 = mtime_lo();
  set_mtimecmp(t0 + 200);
  __asm__ volatile("wfi");
  uint32_t dt = mtime_lo() - t0, cnt = WDOG(CHILIMIX_TIMER_WDOG_COUNT_OFFSET);
  set_mtimecmp(~0ull);
  __asm__ volatile("csrc mie, %0" :: "r"(0x80));
  con_printf("wdog coreawake: %u ticks while %u passed\n", (unsigned)cnt, (unsigned)dt);
  if (dt < 200 || cnt == 0 || cnt + 100 > dt)
    return 5;

  // reset enabled: fed for several periods, then starved
  con_puts("feeding, then starving the watchdog\n");
  while (!(REG32(UART0_BASE, CHILIMIX_UART_LSR_OFFSET) & CHILIMIX_UART_LSR_TEMT_MASK))
    ;
  wdog_start(100, CFG_RSTEN | CFG_ENALWAYS);
  for (int i = 0; i < 6; i++) {
    while (WDOG(CHILIMIX_TIMER_WDOG_S_OFFSET) < 60)
      ;
    wdog_feed();
    if (WDOG(CHILIMIX_TIMER_WDOG_S_OFFSET) >= 60)
      return 6;
  }
  SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = MARK;
  for (;;)                                         // no bite: the run times out
    ;
}

int main(void)
{
  uint32_t cause = SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET);
  uint32_t mark = SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0));
  con_printf("boot: reset cause %x, scratch %08x\n", cause, mark);
  if (mark != MARK)
    return first_boot(cause);
  if (cause != CHILIMIX_SOCCTL_RST_CAUSE_REQ_MASK)
    return 8;
  if (WDOG(CHILIMIX_TIMER_WDOG_CFG_OFFSET) || WDOG(CHILIMIX_TIMER_WDOG_COUNT_OFFSET))
    return 9;                                      // the watchdog was reset too
  SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;
  SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = 0;
  return 0;
}
