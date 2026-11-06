// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// bus: access faults from the AHB default subordinates, the ROM (read-only)
// and an unclaimed APB address; ROM reads over the D bus; code written to
// SRAM0 over the D bus and then fetched; concurrent fetch / data traffic on
// SRAM0 (read-only data lives there).
#include "runtime.h"

static volatile uint32_t last_cause, n_traps;

// accesses are single 4-byte instructions (norvc), so mepc + 4 resumes;
// a fetch fault returns to the caller (saved ra)
static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  last_cause = mcause;
  n_traps++;
  return mcause == 1 ? frame[0] : mepc + 4;
}

static uint32_t load(uint32_t addr)
{
  uint32_t v;
  __asm__ volatile(".option push\n.option norvc\nlw %0, 0(%1)\n.option pop" : "=r"(v) : "r"(addr) : "memory");
  return v;
}

static void store(uint32_t addr, uint32_t v)
{
  __asm__ volatile(".option push\n.option norvc\nsw %0, 0(%1)\n.option pop" :: "r"(v), "r"(addr) : "memory");
}

static int expect_fault(const char *what, uint32_t cause, int code)
{
  int ok = n_traps == 1 && last_cause == cause;
  con_printf("%-28s cause %u %s\n", what, (unsigned)last_cause, ok ? "ok" : "WRONG");
  n_traps = 0;
  last_cause = ~0u;
  return ok ? 0 : code;
}

// code buffer in SRAM0: li a0, 42 ; ret
__attribute__((section(".sram0_data"), aligned(4))) static uint32_t code[2];

static const uint32_t table[64] = {
  0x9e3779b9, 0x7f4a7c15, 0xf39cc060, 0x5ced1d4b, 0x1b873593, 0xcc9e2d51, 0x85ebca6b, 0xc2b2ae35,
};

int main(void)
{
  int err = 0;
  trap_hook = hook;
  last_cause = ~0u;

  load(0x40000000u);
  err = err ?: expect_fault("load from no region", 5, 1);
  store(0x40000000u, 1);
  err = err ?: expect_fault("store to no region", 7, 2);
  load(0x10030000u);
  err = err ?: expect_fault("load from no APB peripheral", 5, 3);
  store(ROM_BASE, 1);
  err = err ?: expect_fault("store to the ROM", 7, 4);
  ((void (*)(void))0x40000000u)();
  err = err ?: expect_fault("fetch from no region", 1, 5);
  ((void (*)(void))(SRAM1_BASE + 0x100))();
  err = err ?: expect_fault("fetch from SRAM1 (D only)", 1, 6);

  uint32_t w = load(ROM_BASE);                 // boot ROM: lui t0, 0x80000
  con_printf("ROM word 0 %08x\n", w);
  if (w != 0x800002b7u)
    err = err ?: 7;

  code[0] = 0x02a00513u;                       // li a0, 42
  code[1] = 0x00008067u;                       // ret
  __asm__ volatile("fence.i" ::: "memory");
  int r = ((int (*)(void))code)();
  con_printf("code written to SRAM0 returns %d\n", r);
  if (r != 42)
    err = err ?: 8;

  uint32_t sum = 0;                            // fetch and load SRAM0 together
  for (int k = 0; k < 64; k++)
    for (int i = 0; i < 8; i++)
      sum = (sum << 5 | sum >> 27) ^ table[(i + k) & 63];
  con_printf("rodata checksum %08x\n", sum);
  if (sum != 0x024fd598u)
    err = err ?: 9;
  return err;
}
