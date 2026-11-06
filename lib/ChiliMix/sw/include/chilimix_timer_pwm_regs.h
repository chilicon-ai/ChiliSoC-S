/* GENERATED FILE - DO NOT EDIT
 * Source: source/timer/regs/timer_pwm.json
 *
 * ChiliMix timer_pwm: PWM / timer with four 16-bit comparators in the SiFive PWM layout: a 31-bit counter, a power-of-2 scaled view pwms and per-comparator interrupts and outputs registers.
 * Layout compatible with sifive,pwm0.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_TIMER_PWM_REGS_H
#define CHILIMIX_TIMER_PWM_REGS_H

#include <stdint.h>

#define CHILIMIX_TIMER_PWM_SPAN 0x40u

/* cfg: pwmcfg: configuration and interrupt pending bits */
#define CHILIMIX_TIMER_PWM_CFG_OFFSET 0x0u
#define CHILIMIX_TIMER_PWM_CFG_RESET 0x0u
#define CHILIMIX_TIMER_PWM_CFG_SCALE_SHIFT 0
#define CHILIMIX_TIMER_PWM_CFG_SCALE_MASK 0xfu  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_STICKY_SHIFT 8
#define CHILIMIX_TIMER_PWM_CFG_STICKY_MASK 0x100u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_ZEROCMP_SHIFT 9
#define CHILIMIX_TIMER_PWM_CFG_ZEROCMP_MASK 0x200u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_DEGLITCH_SHIFT 10
#define CHILIMIX_TIMER_PWM_CFG_DEGLITCH_MASK 0x400u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_ENALWAYS_SHIFT 12
#define CHILIMIX_TIMER_PWM_CFG_ENALWAYS_MASK 0x1000u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_ONESHOT_SHIFT 13
#define CHILIMIX_TIMER_PWM_CFG_ONESHOT_MASK 0x2000u  /* ro */
#define CHILIMIX_TIMER_PWM_CFG_CENTER_SHIFT 16
#define CHILIMIX_TIMER_PWM_CFG_CENTER_MASK 0xf0000u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_INVERT_SHIFT 20
#define CHILIMIX_TIMER_PWM_CFG_INVERT_MASK 0xf00000u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_GANG_SHIFT 24
#define CHILIMIX_TIMER_PWM_CFG_GANG_MASK 0xf000000u  /* rw */
#define CHILIMIX_TIMER_PWM_CFG_IP_SHIFT 28
#define CHILIMIX_TIMER_PWM_CFG_IP_MASK 0xf0000000u  /* ro */

/* count: pwmcount: the counter (writable: a write loads the strobed bytes) */
#define CHILIMIX_TIMER_PWM_COUNT_OFFSET 0x8u
#define CHILIMIX_TIMER_PWM_COUNT_RESET 0x0u
#define CHILIMIX_TIMER_PWM_COUNT_VALUE_SHIFT 0
#define CHILIMIX_TIMER_PWM_COUNT_VALUE_MASK 0x7fffffffu  /* ro */

/* s: pwms: scaled counter, pwmcount bits pwmscale + 15 .. pwmscale */
#define CHILIMIX_TIMER_PWM_S_OFFSET 0x10u
#define CHILIMIX_TIMER_PWM_S_RESET 0x0u
#define CHILIMIX_TIMER_PWM_S_VALUE_SHIFT 0
#define CHILIMIX_TIMER_PWM_S_VALUE_MASK 0xffffu  /* ro */

/* cmp: pwmcmpX: comparator X */
#define CHILIMIX_TIMER_PWM_CMP_COUNT 4
#define CHILIMIX_TIMER_PWM_CMP_OFFSET(i) (0x20u + (i) * 0x4u)
#define CHILIMIX_TIMER_PWM_CMP_RESET 0xffffu
#define CHILIMIX_TIMER_PWM_CMP_VALUE_SHIFT 0
#define CHILIMIX_TIMER_PWM_CMP_VALUE_MASK 0xffffu  /* rw */

#endif /* CHILIMIX_TIMER_PWM_REGS_H */
