// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// ext_irq.h: PLIC helpers for the peripheral tests (one test per program,
// so the definitions below appear once per binary).
//   ext_irq_on(src, prio)  enable PLIC source src (1 .. N_IRQ) at priority
//                          prio, and machine external interrupts
//   ext_irq_off(src)       disable it again
//   ext_irq_trap(mcause)   from a trap hook: for a machine external
//                          interrupt, claim, call the test's
//                          ext_irq(src) and complete; returns 1, else 0
#ifndef EXT_IRQ_H
#define EXT_IRQ_H

#include "runtime.h"
#include "chilimix_plic_regs.h"

#define PLIC(off) REG32(PLIC_BASE, off)

static void ext_irq(uint32_t src);     // the test's handler

static inline uint32_t plic_enable_offset(int src)
{
  return src < 32 ? CHILIMIX_PLIC_ENABLE0_OFFSET(0) : CHILIMIX_PLIC_ENABLE1_OFFSET(0);
}

static inline void ext_irq_on(int src, uint32_t prio)
{
  PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(src)) = prio;
  PLIC(plic_enable_offset(src)) |= 1u << (src & 31);
  PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = 0;
  __asm__ volatile("csrs mie, %0" :: "r"(0x800));  // MEIE
  __asm__ volatile("csrs mstatus, 8");             // MIE
}

static inline void ext_irq_off(int src)
{
  PLIC(plic_enable_offset(src)) &= ~(1u << (src & 31));
}

static inline int ext_irq_trap(uint32_t mcause)
{
  if (mcause != 0x8000000bu)
    return 0;
  uint32_t src = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
  ext_irq(src);
  PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;         // complete
  return 1;
}

#endif
