// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// openocd: the program side of a real OpenOCD + GDB session over the JTAG
// pins (sim/run.py starts OpenOCD with sim/openocd/chilisocs.cfg and GDB with
// sim/openocd/session.py; the testbench bridges JTAG to OpenOCD through
// remote_bitbang). The SRAMs start empty: GDB halts the hart at reset, loads
// this program over the debug module and runs it. The program then spins
// until GDB sets go; GDB stops at a software breakpoint in main, a hardware
// breakpoint in add3, a watchpoint on result and a single step, changes
// variables, and detaches. The program checks what GDB changed.
#include "runtime.h"

volatile uint32_t go;              // set to 1 by GDB
volatile uint32_t poked;           // set to POKE by GDB at the add3 breakpoint
volatile uint32_t result;          // watched by GDB
volatile uint32_t calls;

#define POKE 0x600DF00Du

__attribute__((noinline)) uint32_t add3(uint32_t x)
{
  calls++;
  return x + 3;
}

int main(void)
{
  con_printf("openocd: loaded by the debugger, waiting for go\n");
  for (uint32_t t = 0; !go; t++)
    if (t == 50000000u)
      return 1;
  uint32_t r = add3(39);
  result = r;                      // the watchpoint fires here
  con_printf("openocd: add3 %u, calls %u, poked %x\n", (unsigned)r, (unsigned)calls, (unsigned)poked);
  if (r != 42 || calls != 1)
    return 2;
  if (poked != POKE)
    return 3;
  return 0;
}
