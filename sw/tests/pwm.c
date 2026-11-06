// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// pwm: the chilimix_timer PWMs. PWM 0 runs a 100-cycle period (zerocmp on
// comparator 0) with comparators 1 / 2 at 25 / 75, routed to GPIO pins 1 / 2
// as IO function 1; the testbench loops each pin back to its input, so
// input_val shows about 75 % / 25 % high. Comparators 0 .. 2 of PWM 0 leave
// their (disabled) sources pending. Then every comparator of every PWM
// (sticky, the others parked at their maximum) raises its own PLIC source,
// taken as an external interrupt.
#include "runtime.h"
#include "chilimix_gpio_regs.h"
#include "chilimix_plic_regs.h"
#include "chilimix_timer_pwm_regs.h"

#define GPIO(off)   REG32(GPIO_BASE, off)
#define PLIC(off)   REG32(PLIC_BASE, off)
#define PWM(k, off) REG32(PWM_BASE(k), off)
#define SAMPLES 400

static volatile int n_irq, n_bad;
static volatile uint32_t last_src;

static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (mcause != 0x8000000bu) {
    n_bad++;
    return mepc;
  }
  uint32_t src = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
  uint32_t k = (src - IRQ_PWM0) / 4;
  if (src < IRQ_PWM0 || k >= N_PWM)
    n_bad++;
  else {
    PWM(k, CHILIMIX_TIMER_PWM_COUNT_OFFSET) = 0;   // no longer elapsed
    PWM(k, CHILIMIX_TIMER_PWM_CFG_OFFSET) = 0;     // stop, clear ip (byte 3 written)
  }
  last_src = src;
  n_irq++;
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;         // complete
  return mepc;
}

int main(void)
{
  // PWM 0: period 100 cycles, out1 high for s >= 25, out2 for s >= 75
  PWM(0, CHILIMIX_TIMER_PWM_CMP_OFFSET(0)) = 99;
  PWM(0, CHILIMIX_TIMER_PWM_CMP_OFFSET(1)) = 25;
  PWM(0, CHILIMIX_TIMER_PWM_CMP_OFFSET(2)) = 75;
  PWM(0, CHILIMIX_TIMER_PWM_CFG_OFFSET) = CHILIMIX_TIMER_PWM_CFG_ZEROCMP_MASK |
                                          CHILIMIX_TIMER_PWM_CFG_ENALWAYS_MASK;
  GPIO(CHILIMIX_GPIO_INPUT_EN_OFFSET) = 0x6;
  if (GPIO(CHILIMIX_GPIO_INPUT_VAL_OFFSET) & 0x6)  // not routed yet: pins idle
    return 1;
  GPIO(CHILIMIX_GPIO_IOF_SEL_OFFSET) = 0x6;
  GPIO(CHILIMIX_GPIO_IOF_EN_OFFSET) = 0x6;

  int hi1 = 0, hi2 = 0;
  for (int i = 0; i < SAMPLES; i++) {
    uint32_t v = GPIO(CHILIMIX_GPIO_INPUT_VAL_OFFSET);
    hi1 += (v >> 1) & 1;
    hi2 += (v >> 2) & 1;
  }
  uint32_t s = PWM(0, CHILIMIX_TIMER_PWM_S_OFFSET);
  con_printf("pwm0: pin1 high %d / %d, pin2 high %d / %d, s %u\n", hi1, SAMPLES, hi2, SAMPLES,
             (unsigned)s);
  if (hi1 < SAMPLES * 65 / 100 || hi1 > SAMPLES * 85 / 100)
    return 2;
  if (hi2 < SAMPLES * 15 / 100 || hi2 > SAMPLES * 35 / 100)
    return 3;
  if (s > 99)                                      // zerocmp keeps s below the period
    return 4;
  // comparators 0 .. 2 elapsed: their PLIC sources are pending (not enabled)
  uint32_t pend = PLIC(CHILIMIX_PLIC_PENDING0_OFFSET);
  if ((pend & (0x7u << IRQ_PWM0)) != (0x7u << IRQ_PWM0))
    return 10;
  PWM(0, CHILIMIX_TIMER_PWM_CFG_OFFSET) = 0;
  GPIO(CHILIMIX_GPIO_IOF_EN_OFFSET) = 0;

  // every comparator of each PWM: sticky interrupt on its own PLIC source
  trap_hook = hook;
  PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = 0;
  __asm__ volatile("csrs mie, %0" :: "r"(0x800));  // MEIE
  __asm__ volatile("csrs mstatus, 8");
  uint32_t all = 0;
  for (int k = 0; k < N_PWM; k++)
    for (int j = 0; j < 4; j++) {
      uint32_t src = IRQ_PWM0 + 4 * k + j;
      all |= 1u << src;
      PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(src)) = 1;
      PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = 1u << src;
      PWM(k, CHILIMIX_TIMER_PWM_COUNT_OFFSET) = 0;
      for (int c = 0; c < 4; c++)
        PWM(k, CHILIMIX_TIMER_PWM_CMP_OFFSET(c)) = c == j ? 50 + 20 * k : 0xffff;
      PWM(k, CHILIMIX_TIMER_PWM_CFG_OFFSET) = CHILIMIX_TIMER_PWM_CFG_STICKY_MASK |
                                              CHILIMIX_TIMER_PWM_CFG_ENALWAYS_MASK;
      int before = n_irq;
      for (int t = 0; t < 1000 && n_irq == before; t++)
        ;
      if (n_irq != before + 1 || last_src != src || n_bad) {
        con_printf("pwm%d: cmp%d interrupt source %u\n", k, j, (unsigned)last_src);
        return 5 + 4 * k + j;
      }
      PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = 0;
    }
  con_printf("pwm: every comparator's source claimed (%d interrupts)\n", n_irq);
  __asm__ volatile("csrc mstatus, 8");
  if (PLIC(CHILIMIX_PLIC_PENDING0_OFFSET) & all)   // every comparator completed
    return 30;
  return 0;
}
