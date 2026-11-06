// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// xip: code running from the SPI0 flash (XIP) through ChillU-S's instruction
// cache (ICACHE_KB, a top parameter; run.py passes it as -DICACHE_KB). A
// function in the flash, larger than SPI0's own four 16-byte read lines,
// runs cold (first call), warm (second call) and again after FENCE.I:
//   ICACHE_KB > 0: the warm call is at least 4x faster than the cold one
//                  (every fetch hits), and FENCE.I makes the next call
//                  cold again (it empties the cache)
//   ICACHE_KB = 0: every call fetches from the flash (warm about = cold)
// Every call's result is checked against the same arithmetic in SRAM.
#include "runtime.h"

#define N_DAT 16

static volatile uint32_t dat[N_DAT];

// one mixing step: about ten instructions, kept apart by the volatile reads
#define MIX(k) s = (s ^ dat[(k) & (N_DAT - 1)]) * 0x9E3779B1u + ((s >> 7) | (uint32_t)(k));

#define MIX8(k) MIX(k) MIX((k) + 1) MIX((k) + 2) MIX((k) + 3) \
                MIX((k) + 4) MIX((k) + 5) MIX((k) + 6) MIX((k) + 7)

// runs from the flash: 32 straight-line steps (several hundred bytes of code)
__attribute__((section(".xip.text"), noinline, noclone)) uint32_t xip_mix(uint32_t s)
{
  MIX8(0) MIX8(8) MIX8(16) MIX8(24)
  return s;
}

// the same in SRAM: the reference
__attribute__((noinline, noclone)) static uint32_t ref_mix(uint32_t s)
{
  MIX8(0) MIX8(8) MIX8(16) MIX8(24)
  return s;
}

static int bad;

// one timed call of the flash function, its result checked
static uint32_t timed(uint32_t seed)
{
  uint32_t t0 = (uint32_t)rd_cycle();
  uint32_t r  = xip_mix(seed);
  uint32_t t  = (uint32_t)rd_cycle() - t0;
  if (r != ref_mix(seed))
    bad++;
  return t;
}

int main(void)
{
  for (int i = 0; i < N_DAT; i++)
    dat[i] = 0x01234567u * (uint32_t)(i + 1);

  uint32_t cold  = timed(1);
  uint32_t warm  = timed(2);
  __asm__ volatile("fence.i" ::: "memory");
  uint32_t fence = timed(3);
  uint32_t warm2 = timed(4);
  con_printf("xip: ICACHE_KB %d, xip_mix at %p, cycles cold %u warm %u after fence.i %u warm %u\n",
             ICACHE_KB, (void *)xip_mix, (unsigned)cold, (unsigned)warm, (unsigned)fence, (unsigned)warm2);
  if (((uint32_t)xip_mix & 0xe0000000u) != XIP_BASE)
    return 1;
  if (bad)
    return 2;
#if ICACHE_KB > 0
  if (warm * 4 > cold || warm2 * 4 > fence)
    return 3;                                   // warm calls must hit
  if (fence * 2 < cold)
    return 4;                                   // FENCE.I must empty the cache
#else
  if (warm * 2 < cold)
    return 5;                                   // no cache: no speedup
#endif
  return 0;
}
