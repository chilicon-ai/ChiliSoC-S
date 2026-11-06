// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// regs: every ChiliMix register of the SoC through the core, the AHB fabric
// and the APB bridge, from the register maps (table sw/tests/regs_map.h,).
//   1. reset: the rw bits of every register hold the map's reset value
//      (before any write of this test)
//   2. write: patterns written to the rw bits read back; byte and halfword writes change only their lanes, and
//      byte and halfword reads return their lanes; the value is restored
//   3. holes: a word with no register reads 0 and ignores writes; past a
//      block's last register and outside every block, loads and stores fault
//   4. touch: every other readable word reads without a fault (value not
//      checked); the registers the write test leaves out get their own value
//      written back
#include "runtime.h"
#include "regs_map.h"

#define N_REGS  (sizeof sweep_regs / sizeof sweep_regs[0])
#define N_HOLES (sizeof sweep_holes / sizeof sweep_holes[0])
#define N_TOUCH (sizeof sweep_touch / sizeof sweep_touch[0])

static volatile uint32_t last_cause, n_traps;

// accesses are single 4-byte instructions (norvc), so mepc + 4 resumes
static uint32_t hook(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  last_cause = mcause;
  n_traps++;
  return mepc + 4;
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

static int fails;

static void fail(const char *name, const char *what, uint32_t got, uint32_t exp)
{
  con_printf("%-24s %-12s got %08x expected %08x\n", name, what, (unsigned)got, (unsigned)exp);
  fails++;
}

static void check(const sweep_reg_t *r, const char *what, uint32_t exp)
{
  uint32_t got = load(r->addr) & r->write_m;
  if (got != (exp & r->write_m))
    fail(r->name, what, got, exp & r->write_m);
}

static const uint32_t patterns[] = {0xffffffffu, 0x00000000u, 0xa5a5a5a5u, 0x5a5a5a5au};

static void sweep_write(const sweep_reg_t *r)
{
  uint32_t orig = load(r->addr);
  uint32_t keep = orig & ~r->write_m;          // bits outside the test keep their value
  for (unsigned p = 0; p < sizeof patterns / sizeof patterns[0]; p++) {
    store(r->addr, keep | (patterns[p] & r->write_m));
    check(r, "pattern", patterns[p]);
  }
  for (int b = 0; b < 4; b++) {                // byte lanes
    store(r->addr, keep);
    *(volatile uint8_t *)(r->addr + b) = 0xff;
    check(r, "byte write", 0xffu << (8 * b));
    store(r->addr, keep | (0xa5c3e187u & r->write_m));
    uint32_t got = *(volatile uint8_t *)(r->addr + b) & (r->write_m >> (8 * b)) & 0xff;
    uint32_t exp = (0xa5c3e187u & r->write_m) >> (8 * b) & 0xff;
    if (got != exp)
      fail(r->name, "byte read", got, exp);
  }
  for (int h = 0; h < 4; h += 2) {             // halfword lanes
    store(r->addr, keep);
    *(volatile uint16_t *)(r->addr + h) = 0xffff;
    check(r, "half write", 0xffffu << (8 * h));
    store(r->addr, keep | (0x96f01e3cu & r->write_m));
    uint32_t got = *(volatile uint16_t *)(r->addr + h) & (r->write_m >> (8 * h)) & 0xffff;
    uint32_t exp = (0x96f01e3cu & r->write_m) >> (8 * h) & 0xffff;
    if (got != exp)
      fail(r->name, "half read", got, exp);
  }
  store(r->addr, orig);
  uint32_t now = load(r->addr) & r->write_m;
  if (now != (orig & r->write_m))
    fail(r->name, "restore", now, orig & r->write_m);
}

static void sweep_hole(const sweep_hole_t *h)
{
  n_traps = 0;
  last_cause = ~0u;
  if (h->kind == HOLE_ZERO) {
    store(h->addr, 0xffffffffu);
    uint32_t v = load(h->addr);
    if (n_traps)
      fail(h->name, "trapped", last_cause, 0);
    else if (v)
      fail(h->name, "not zero", v, 0);
    return;
  }
  load(h->addr);
  if (n_traps != 1 || last_cause != 5)
    fail(h->name, "load fault", n_traps ? last_cause : ~0u, 5);
  n_traps = 0;
  last_cause = ~0u;
  store(h->addr, 0);
  if (n_traps != 1 || last_cause != 7)
    fail(h->name, "store fault", n_traps ? last_cause : ~0u, 7);
}

int main(void)
{
  trap_hook = hook;
  unsigned n_reset = 0, n_write = 0;
  for (unsigned i = 0; i < N_REGS; i++) {
    const sweep_reg_t *r = &sweep_regs[i];
    if (!r->reset_m)
      continue;
    uint32_t got = load(r->addr) & r->reset_m;
    if (got != r->reset)
      fail(r->name, "reset", got, r->reset);
    n_reset++;
  }
  int reset_fails = fails;
  for (unsigned i = 0; i < N_REGS; i++)
    if (sweep_regs[i].write_m) {
      sweep_write(&sweep_regs[i]);
      n_write++;
    }
  int write_fails = fails - reset_fails;
  for (unsigned i = 0; i < N_HOLES; i++)
    sweep_hole(&sweep_holes[i]);
  int hole_fails = fails - reset_fails - write_fails;
  for (unsigned i = 0; i < N_TOUCH; i++) {
    const sweep_touch_t *t = &sweep_touch[i];
    n_traps = 0;
    uint32_t v = load(t->addr);
    if (t->rewrite)
      store(t->addr, v);
    if (n_traps)
      fail(t->name, "touch trap", last_cause, 0);
  }
  con_printf("reset %u registers (%d wrong), write %u (%d wrong), holes %u (%d wrong), touch %u (%d wrong)\n",
             n_reset, reset_fails, n_write, write_fails, (unsigned)N_HOLES, hole_fails, (unsigned)N_TOUCH,
             fails - reset_fails - write_fails - hole_fails);
  return fails ? 1 : 0;
}
