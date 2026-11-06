// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// plic: GPIO edge interrupts through the PLIC (the testbench loops each
// driven GPIO output back to its input): three on PIN, then one on every
// pin, each claimed as its own source; then UART0 receive interrupts in
// 16550 loopback mode; last, a completion the PLIC must ignore: a source
// disabled between its claim and its completion stays claimed (the gateway
// forwards nothing more) until a completion arrives while it is enabled
// again (riscv-plic-spec, Interrupt Completion).
#include "runtime.h"
#include "chilimix_gpio_regs.h"
#include "chilimix_plic_regs.h"
#include "chilimix_uart_regs.h"

#define GPIO(off) REG32(GPIO_BASE, off)
#define PLIC(off) REG32(PLIC_BASE, off)
#define UART(off) REG32(UART0_BASE, off)
#define PIN 5
#define N_PINS 16                         // chilisocs_top N_GPIO (default)
#define MEIP (1u << 11)

static volatile int n_gpio, n_uart, n_bad, last_pin;
static volatile uint8_t rx[4];

static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (mcause != 0x8000000bu)              // machine external only
    exit(0x400 + (int)(mcause & 0xff));
  uint32_t src = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
  if (src >= IRQ_GPIO0 && src < IRQ_GPIO0 + N_PINS) {
    last_pin = (int)(src - IRQ_GPIO0);
    GPIO(CHILIMIX_GPIO_RISE_IP_OFFSET) = 1u << last_pin;   // w1c
    n_gpio++;
  } else if (src == IRQ_UART0) {
    while (UART(CHILIMIX_UART_LSR_OFFSET) & CHILIMIX_UART_LSR_DR_MASK)
      rx[n_uart++ & 3] = (uint8_t)UART(CHILIMIX_UART_RBR_OFFSET);
  } else {
    n_bad++;
  }
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;           // complete
  return mepc;
}

static void delay(void)                   // the GPIO synchronizer and the PLIC gateway
{
  for (int t = 0; t < 50; t++)
    __asm__ volatile("nop");
}

int main(void)
{
  trap_hook = hook;
  PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(IRQ_UART0)) = 1;
  for (int p = 0; p < N_PINS; p++)
    PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(IRQ_GPIO0 + p)) = p == PIN ? 2 : 1;
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = (((1u << N_PINS) - 1) << IRQ_GPIO0) | (1u << IRQ_UART0);
  PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = 0;
  __asm__ volatile("csrs mie, %0" :: "r"(0x800));  // MEIE
  __asm__ volatile("csrs mstatus, 8");

  // GPIO: rising edges on PIN
  GPIO(CHILIMIX_GPIO_INPUT_EN_OFFSET) = 1u << PIN;
  GPIO(CHILIMIX_GPIO_OUTPUT_EN_OFFSET) = 1u << PIN;
  GPIO(CHILIMIX_GPIO_RISE_IE_OFFSET) = 1u << PIN;
  for (int i = 0; i < 3; i++) {
    GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 1u << PIN;
    while (n_gpio == i)
      ;
    GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 0;
    for (int w = 0; w < 10; w++)
      __asm__ volatile("nop");
  }
  uint32_t level = GPIO(CHILIMIX_GPIO_INPUT_VAL_OFFSET);
  con_printf("gpio interrupts %d, input %x\n", n_gpio, level);
  if (n_gpio != 3 || n_bad || level & (1u << PIN))
    return 1;

  // every pin, one rising edge each: its own source
  GPIO(CHILIMIX_GPIO_INPUT_EN_OFFSET) = (1u << N_PINS) - 1;
  GPIO(CHILIMIX_GPIO_OUTPUT_EN_OFFSET) = (1u << N_PINS) - 1;
  GPIO(CHILIMIX_GPIO_RISE_IE_OFFSET) = (1u << N_PINS) - 1;
  for (int p = 0; p < N_PINS; p++) {
    int before = n_gpio;
    GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 1u << p;
    for (int t = 0; n_gpio == before && t < 1000; t++)
      ;
    GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 0;
    if (n_gpio != before + 1 || last_pin != p)
      return 10 + p;
  }
  GPIO(CHILIMIX_GPIO_RISE_IE_OFFSET) = 0;
  con_printf("gpio: every pin's source claimed (%d interrupts)\n", n_gpio);

  // UART0 loopback: wait until the console line is idle, loop, send, receive
  while (!(UART(CHILIMIX_UART_LSR_OFFSET) & CHILIMIX_UART_LSR_TEMT_MASK))
    ;
  UART(CHILIMIX_UART_MCR_OFFSET) = CHILIMIX_UART_MCR_LOOP_MASK;
  UART(CHILIMIX_UART_IER_OFFSET) = CHILIMIX_UART_IER_ERBFI_MASK;
  const char msg[4] = {'C', 'h', 'i', '!'};
  for (int i = 0; i < 4; i++)
    UART(CHILIMIX_UART_THR_OFFSET) = (uint8_t)msg[i];
  for (int t = 0; n_uart < 4 && t < 100000; t++)
    ;
  UART(CHILIMIX_UART_IER_OFFSET) = 0;
  UART(CHILIMIX_UART_MCR_OFFSET) = 0;
  con_printf("uart loopback %d bytes: %c%c%c%c\n", n_uart, rx[0], rx[1], rx[2], rx[3]);

  if (n_uart != 4 || memcmp((const void *)rx, msg, 4))
    return 2;

  // completion of a disabled source: ignored. PIN held high with its level
  // interrupt (high_ie) keeps the source asserted; interrupts are polled
  // (mstatus.MIE low, mip.MEIP)
  __asm__ volatile("csrc mstatus, 8");
  const uint32_t src = IRQ_GPIO0 + PIN, bit = 1u << src;
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = bit;
  GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 1u << PIN;
  GPIO(CHILIMIX_GPIO_HIGH_IE_OFFSET) = 1u << PIN;
  uint32_t mip;
  delay();
  __asm__ volatile("csrr %0, mip" : "=r"(mip));
  uint32_t got = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
  if (!(mip & MEIP) || got != src)
    return 3;
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = 0;          // disabled while claimed
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;         // ignored completion
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = bit;
  delay();
  __asm__ volatile("csrr %0, mip" : "=r"(mip));
  uint32_t pend = PLIC(CHILIMIX_PLIC_PENDING0_OFFSET) & bit;
  con_printf("plic: after an ignored completion pending %x, meip %d\n", (unsigned)pend, (int)!!(mip & MEIP));
  if (pend || (mip & MEIP))                        // still claimed: nothing forwarded
    return 4;
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;         // completion while enabled
  delay();
  __asm__ volatile("csrr %0, mip" : "=r"(mip));
  if (!(mip & MEIP) || PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) != src)
    return 5;                                      // the level was forwarded again
  GPIO(CHILIMIX_GPIO_HIGH_IE_OFFSET) = 0;
  GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 0;
  GPIO(CHILIMIX_GPIO_HIGH_IP_OFFSET) = 1u << PIN;  // w1c
  GPIO(CHILIMIX_GPIO_FALL_IP_OFFSET) = ~0u;        // the falling edges and low levels left
  GPIO(CHILIMIX_GPIO_LOW_IP_OFFSET) = ~0u;         // pending (no interrupt enabled)
  if (GPIO(CHILIMIX_GPIO_FALL_IP_OFFSET))          // no edge since: cleared
    return 7;
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = 0;
  return n_bad ? 6 : 0;
}
