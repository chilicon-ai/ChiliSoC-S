// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// sysrst: software system reset through socctl, then the external reset
// pin. First boot (power-on): clear the cause, leave a mark in scratch[0]
// (power-on domain, survives), write the sysrst key. Second boot: the cause
// is sw and the mark is there; leave MARK2 and ask the testbench for an
// external reset (EXT_RST_REQ to scratch[1]: ext_rst_n low for 20 cycles).
// Third boot: the cause is ext.
#include "runtime.h"
#include "chilimix_socctl_regs.h"
#include "chilimix_uart_regs.h"

#define SOCCTL(off) REG32(SOCCTL_BASE, off)
#define MARK 0xC0FFEE01u
#define MARK2 0xC0FFEE02u
#define KEY  0x52535421u   // 'RST!'
#define EXT_RST_REQ 0xE7E70001u  // sim/tb/chilisocs_tb.sv

static void drain(void)
{
  while (!(REG32(UART0_BASE, CHILIMIX_UART_LSR_OFFSET) & CHILIMIX_UART_LSR_TEMT_MASK))
    ;
}

int main(void)
{
  uint32_t cause = SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET);
  uint32_t mark = SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0));
  con_printf("boot: reset cause %x, scratch %08x\n", cause, mark);
  if (mark == MARK2) {
    if (cause != CHILIMIX_SOCCTL_RST_CAUSE_EXT_MASK)
      return 3;
    SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;
    SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = 0;
    SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(1)) = 0;
    return 0;
  }
  if (mark != MARK) {
    if (cause != CHILIMIX_SOCCTL_RST_CAUSE_POR_MASK)
      return 1;
    SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;      // w1c
    SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = MARK;
    SOCCTL(CHILIMIX_SOCCTL_SYSRST_OFFSET) = 0x12345678u;  // wrong key: nothing
    con_puts("system reset\n");
    drain();
    SOCCTL(CHILIMIX_SOCCTL_SYSRST_OFFSET) = KEY;
    for (;;)
      ;
  }
  if (cause != CHILIMIX_SOCCTL_RST_CAUSE_SW_MASK)
    return 2;
  SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;
  SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = MARK2;
  con_puts("external reset\n");
  drain();
  SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(1)) = EXT_RST_REQ;
  for (;;)
    ;
}
