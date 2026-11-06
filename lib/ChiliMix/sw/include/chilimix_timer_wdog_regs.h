/* GENERATED FILE - DO NOT EDIT
 * Source: source/timer/regs/timer_wdog.json
 *
 * ChiliMix timer_wdog: Watchdog in the SiFive AON watchdog layout: a key-unlocked 31-bit counter with a power-of-2 scale, one 16-bit comparator, an interrupt and a reset request registers.
 * Layout compatible with sifive,wdt.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_TIMER_WDOG_REGS_H
#define CHILIMIX_TIMER_WDOG_REGS_H

#include <stdint.h>

#define CHILIMIX_TIMER_WDOG_SPAN 0x40u

/* cfg: wdogcfg: configuration and interrupt pending (writes need the key) */
#define CHILIMIX_TIMER_WDOG_CFG_OFFSET 0x0u
#define CHILIMIX_TIMER_WDOG_CFG_RESET 0x0u
#define CHILIMIX_TIMER_WDOG_CFG_SCALE_SHIFT 0
#define CHILIMIX_TIMER_WDOG_CFG_SCALE_MASK 0xfu  /* ro */
#define CHILIMIX_TIMER_WDOG_CFG_RSTEN_SHIFT 8
#define CHILIMIX_TIMER_WDOG_CFG_RSTEN_MASK 0x100u  /* ro */
#define CHILIMIX_TIMER_WDOG_CFG_ZEROCMP_SHIFT 9
#define CHILIMIX_TIMER_WDOG_CFG_ZEROCMP_MASK 0x200u  /* ro */
#define CHILIMIX_TIMER_WDOG_CFG_ENALWAYS_SHIFT 12
#define CHILIMIX_TIMER_WDOG_CFG_ENALWAYS_MASK 0x1000u  /* ro */
#define CHILIMIX_TIMER_WDOG_CFG_COREAWAKE_SHIFT 13
#define CHILIMIX_TIMER_WDOG_CFG_COREAWAKE_MASK 0x2000u  /* ro */
#define CHILIMIX_TIMER_WDOG_CFG_IP0_SHIFT 28
#define CHILIMIX_TIMER_WDOG_CFG_IP0_MASK 0x10000000u  /* ro */

/* count: wdogcount: the counter (writes need the key and load the strobed bytes) */
#define CHILIMIX_TIMER_WDOG_COUNT_OFFSET 0x8u
#define CHILIMIX_TIMER_WDOG_COUNT_RESET 0x0u
#define CHILIMIX_TIMER_WDOG_COUNT_VALUE_SHIFT 0
#define CHILIMIX_TIMER_WDOG_COUNT_VALUE_MASK 0x7fffffffu  /* ro */

/* s: wdogs: scaled counter, wdogcount bits wdogscale + 15 .. wdogscale */
#define CHILIMIX_TIMER_WDOG_S_OFFSET 0x10u
#define CHILIMIX_TIMER_WDOG_S_RESET 0x0u
#define CHILIMIX_TIMER_WDOG_S_VALUE_SHIFT 0
#define CHILIMIX_TIMER_WDOG_S_VALUE_MASK 0xffffu  /* ro */

/* feed: wdogfeed: writing 0x0D09F00D (with the key) restarts the counter */
#define CHILIMIX_TIMER_WDOG_FEED_OFFSET 0x18u
#define CHILIMIX_TIMER_WDOG_FEED_RESET 0x0u
#define CHILIMIX_TIMER_WDOG_FEED_VALUE_SHIFT 0
#define CHILIMIX_TIMER_WDOG_FEED_VALUE_MASK 0xffffffffu  /* wo */

/* key: wdogkey: writing 0x0051F15E unlocks the next write; any other write locks again */
#define CHILIMIX_TIMER_WDOG_KEY_OFFSET 0x1cu
#define CHILIMIX_TIMER_WDOG_KEY_RESET 0x0u
#define CHILIMIX_TIMER_WDOG_KEY_UNLOCKED_SHIFT 0
#define CHILIMIX_TIMER_WDOG_KEY_UNLOCKED_MASK 0x1u  /* ro */

/* cmp0: wdogcmp0: comparator (writes need the key) */
#define CHILIMIX_TIMER_WDOG_CMP0_OFFSET 0x20u
#define CHILIMIX_TIMER_WDOG_CMP0_RESET 0x0u
#define CHILIMIX_TIMER_WDOG_CMP0_VALUE_SHIFT 0
#define CHILIMIX_TIMER_WDOG_CMP0_VALUE_MASK 0xffffu  /* ro */

#endif /* CHILIMIX_TIMER_WDOG_REGS_H */
