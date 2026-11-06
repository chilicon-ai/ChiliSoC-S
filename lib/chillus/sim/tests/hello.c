// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// ChillU-S sim :: hello.c
//
// Smoke test of the C flow (sim/sw: crt0, console, printf, memory functions)
// and of the Zicntr counters: back-to-back instret reads differ by exactly
// one, cycle advances. Exit code = failed check (0 = PASS).
#include "runtime.h"

static int check(int ok, int code, const char *what)
{
  if (!ok)
    con_printf("FAIL %d: %s\n", code, what);
  return ok ? 0 : code;
}

int main(void)
{
  int err = 0;
  char buf[16], cpy[16];

  con_puts("Hello from ChillU-S\n");
  con_printf("dec %d %i %u, hex 0x%08x %X, chr %c, str [%-6s] [%6s], pad [%05d] [%-4d]\n",
             -42, 7, 4000000000u, 0xbeefu, 0xcafeu, 'Z', "ab", "cd", -12, 3);

  memset(buf, 'x', sizeof(buf));
  memcpy(cpy, buf, sizeof(buf));
  memmove(cpy + 1, cpy, 8);
  err = err ? err : check(memcmp(buf, cpy, sizeof(buf)) == 0, 2, "memset / memcpy / memmove");
  err = err ? err : check(strlen("chillus") == 7, 3, "strlen");

  uint32_t i0, i1;
  __asm__ volatile("csrr %0, instret\n\tcsrr %1, instret" : "=r"(i0), "=r"(i1));
  err = err ? err : check(i1 - i0 == 1, 4, "back-to-back instret reads differ by 1");

  uint64_t n = rd_instret();
  con_printf("instret %lu\n", (unsigned long)n);

  // last: cycle values differ from Spike (CPI 1), so nothing after this is
  // compared against its trace
  uint64_t c0 = rd_cycle();
  uint64_t c1 = rd_cycle();
  err = err ? err : check(c1 > c0, 5, "cycle advances");

  con_printf("%s\n", err ? "FAILED" : "PASSED");
  return err;
}
