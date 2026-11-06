// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// hello: boot from ROM, print over UART0, read the socctl ID and reset cause.
#include "runtime.h"
#include "chilimix_socctl_regs.h"

int main(void)
{
  uint32_t id = REG32(SOCCTL_BASE, CHILIMIX_SOCCTL_ID_OFFSET);
  uint32_t cause = REG32(SOCCTL_BASE, CHILIMIX_SOCCTL_RST_CAUSE_OFFSET);
  con_printf("Hello from ChiliSoC-S: id %08x, reset cause %x\n", id, cause);
  if (id != SOC_ID)
    return 1;
#ifdef FPGA
  // on the board the debugger's reset halt (dbg) and the reset button input
  // at configuration (ext) may add to power-on
  cause &= ~(CHILIMIX_SOCCTL_RST_CAUSE_DBG_MASK | CHILIMIX_SOCCTL_RST_CAUSE_EXT_MASK);
#endif
  if (cause != CHILIMIX_SOCCTL_RST_CAUSE_POR_MASK)
    return 2;
  return 0;
}
