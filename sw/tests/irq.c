// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// irq: Vectored mtvec with the SoC's three interrupt sources. Each cause
// jumps to its own entry (BASE + 4 * code): machine software (ACLINT msip),
// timer (ACLINT mtimecmp) and external (PLIC, a GPIO edge); an exception
// (ECALL) still goes to BASE. Then all three are made pending together with
// mstatus.MIE low and taken in the privileged spec's order: external,
// software, timer.
#include "runtime.h"
#include "chilimix_aclint_regs.h"
#include "chilimix_gpio_regs.h"
#include "chilimix_plic_regs.h"

#define CLINT(off) REG32(CLINT_BASE, off)
#define GPIO(off)  REG32(GPIO_BASE, off)
#define PLIC(off)  REG32(PLIC_BASE, off)
#define PIN 3

static volatile int n_soft, n_timer, n_ext, n_ecall, n_bad;
static volatile uint32_t order[8];
static volatile int n_order;

// the vector table: 4-byte jumps (no RVC), entry i at BASE + 4 * i
__asm__(
  "  .section .text.vec, \"ax\", @progbits\n"
  "  .balign 256\n"
  "  .option push\n"
  "  .option norvc\n"
  "vec_table:\n"
  "  j     isr_exc\n"            // 0: exceptions
  "  j     isr_bad\n"            // 1
  "  j     isr_bad\n"            // 2
  "  j     isr_soft\n"           // 3: machine software
  "  j     isr_bad\n"            // 4
  "  j     isr_bad\n"            // 5
  "  j     isr_bad\n"            // 6
  "  j     isr_timer\n"          // 7: machine timer
  "  j     isr_bad\n"            // 8
  "  j     isr_bad\n"            // 9
  "  j     isr_bad\n"            // 10
  "  j     isr_ext\n"            // 11: machine external
  "  .option pop\n"
  "  .text\n");
extern char vec_table[];

static void set_mtimecmp(uint64_t t)
{
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = 0xffffffffu;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_LO_OFFSET(0)) = (uint32_t)t;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = (uint32_t)(t >> 32);
}

static uint32_t mcause(void)
{
  uint32_t c;
  __asm__ volatile("csrr %0, mcause" : "=r"(c));
  return c;
}

static void log_cause(uint32_t c)
{
  if (n_order < 8)
    order[n_order] = c;
  n_order++;
}

__attribute__((interrupt("machine"), used)) void isr_soft(void)
{
  if (mcause() != 0x80000003u)
    n_bad++;
  log_cause(3);
  n_soft++;
  CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 0;
}

__attribute__((interrupt("machine"), used)) void isr_timer(void)
{
  if (mcause() != 0x80000007u)
    n_bad++;
  log_cause(7);
  n_timer++;
  set_mtimecmp(~0ull);
}

__attribute__((interrupt("machine"), used)) void isr_ext(void)
{
  if (mcause() != 0x8000000bu)
    n_bad++;
  log_cause(11);
  uint32_t src = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
  if (src == IRQ_GPIO0 + PIN) {
    GPIO(CHILIMIX_GPIO_RISE_IP_OFFSET) = 1u << PIN;   // w1c
    n_ext++;
  } else {
    n_bad++;
  }
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;           // complete
}

__attribute__((interrupt("machine"), used)) void isr_exc(void)
{
  uint32_t epc;
  if (mcause() != 11u)                               // ECALL from M-mode only
    exit(0x400 + (int)mcause());
  n_ecall++;
  __asm__ volatile("csrr %0, mepc" : "=r"(epc));
  __asm__ volatile("csrw mepc, %0" :: "r"(epc + 4));
}

__attribute__((interrupt("machine"), used)) void isr_bad(void)
{
  exit(0x800 + (int)(mcause() & 0xff));
}

static void gpio_edge(void)
{
  GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 1u << PIN;
  GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 0;
}

int main(void)
{
  uint32_t tvec = (uint32_t)vec_table | 1u, rd;
  __asm__ volatile("csrw mtvec, %0" :: "r"(tvec));
  __asm__ volatile("csrr %0, mtvec" : "=r"(rd));
  if (rd != tvec)
    return 1;                                        // Vectored mode not kept

  set_mtimecmp(~0ull);
  PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(IRQ_GPIO0 + PIN)) = 1;
  PLIC(CHILIMIX_PLIC_ENABLE0_OFFSET(0)) = 1u << (IRQ_GPIO0 + PIN);
  PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = 0;
  GPIO(CHILIMIX_GPIO_INPUT_EN_OFFSET) = 1u << PIN;
  GPIO(CHILIMIX_GPIO_OUTPUT_EN_OFFSET) = 1u << PIN;
  GPIO(CHILIMIX_GPIO_RISE_IE_OFFSET) = 1u << PIN;
  __asm__ volatile("csrs mie, %0" :: "r"(0x888));    // MEIE, MTIE, MSIE

  // one at a time, each to its own vector
  __asm__ volatile("csrs mstatus, 8");
  CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 1;
  while (n_soft == 0)
    ;
  set_mtimecmp(0);
  while (n_timer == 0)
    ;
  gpio_edge();
  while (n_ext == 0)
    ;
  __asm__ volatile("ecall");
  con_printf("vectored: software %d, timer %d, external %d, ecall %d\n", n_soft, n_timer, n_ext, n_ecall);
  if (n_soft != 1 || n_timer != 1 || n_ext != 1 || n_ecall != 1 || n_bad)
    return 2;

  // all three pending at once: taken external, software, timer
  __asm__ volatile("csrc mstatus, 8");
  n_order = 0;
  CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 1;
  set_mtimecmp(0);
  gpio_edge();
  uint32_t mip;
  for (int t = 0; t < 1000; t++) {
    __asm__ volatile("csrr %0, mip" : "=r"(mip));
    if ((mip & 0x888) == 0x888)
      break;
  }
  __asm__ volatile("csrs mstatus, 8");
  while (n_order < 3)
    ;
  __asm__ volatile("csrc mstatus, 8");
  con_printf("pending 0x%x, order %u %u %u\n", (unsigned)(mip & 0x888),
             (unsigned)order[0], (unsigned)order[1], (unsigned)order[2]);
  if ((mip & 0x888) != 0x888 || n_order != 3 || n_bad)
    return 3;
  if (order[0] != 11 || order[1] != 3 || order[2] != 7)
    return 4;
  return 0;
}
