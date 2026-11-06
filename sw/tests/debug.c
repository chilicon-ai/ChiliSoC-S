// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// debug: the program side of the testbench's JTAG debugger session
// (sim/tb/chilisocs_tb.sv, +debugger). Mailbox: socctl scratch[1] (power-on
// domain, reached by the debugger's system bus access).
// First boot: publish the address of target() in scratch[0], run PWM 0, set
// scratch[1] = 1 and spin until the debugger writes 2, restarting a DMA
// copy (SRAM1 -> SRAM1) whenever it ends, so the core, the debugger's system
// bus access (a sweep of every region) and the DMA meet on the D bus.
// Meanwhile the debugger halts the hart, reads dcsr / dpc / sp with abstract commands,
// checks PWM 0 is frozen in debug mode, sets a trigger on target(), writes
// MAGIC to scratch[0] and 2 to scratch[1], and resumes. The call to target()
// hits the breakpoint; the debugger single-steps and resumes. Then scratch[0]
// must hold MAGIC; scratch[1] = 3 asks the debugger for ndmreset.
// Second boot: the reset cause is dbg, scratch[1] is still 3; the debugger
// writes 4 when it is done.
#include "runtime.h"
#include "chilimix_socctl_regs.h"
#include "chilimix_timer_pwm_regs.h"
#include "chilimix_uart_regs.h"
#include "chilimix_dma_regs.h"

#define SOCCTL(off) REG32(SOCCTL_BASE, off)
#define PWM0(off)   REG32(PWM_BASE(0), off)
#define MBOX        SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(1))
#define MAGIC       0xD0B60001u
#define DMA0(off)   REG32(DMA_CH_BASE(0), off)
#define N_BUF       512

static volatile uint32_t buf[2][N_BUF];         // DMA traffic while the debugger sweeps

static void dma_copy(void)
{
  DMA0(CHILIMIX_DMA_CONTROL_OFFSET) = CHILIMIX_DMA_CONTROL_W_CLAIM_MASK;
  DMA0(CHILIMIX_DMA_NEXT_CONFIG_OFFSET) = (2u << 28) | (2u << 24);   // word beats
  DMA0(CHILIMIX_DMA_NEXT_BYTES_OFFSET) = sizeof buf[0];
  DMA0(CHILIMIX_DMA_NEXT_DST_OFFSET) = (uint32_t)buf[1];
  DMA0(CHILIMIX_DMA_NEXT_SRC_OFFSET) = (uint32_t)buf[0];
  DMA0(CHILIMIX_DMA_CONTROL_OFFSET) = CHILIMIX_DMA_CONTROL_W_CLAIM_MASK | CHILIMIX_DMA_CONTROL_W_RUN_MASK;
}

static volatile int hits;

__attribute__((noinline)) int target(int x)
{
  hits++;
  return 3 * x + 1;
}

int (*volatile target_ptr)(int) = target;

int main(void)
{
  uint32_t cause = SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET);
  uint32_t mbox = MBOX;                            // the debugger may write 4 any time now
  con_printf("boot: reset cause %x, mailbox %u\n", cause, mbox);
  if (mbox == 3 || mbox == 4) {
    if (cause != CHILIMIX_SOCCTL_RST_CAUSE_DBG_MASK)
      return 1;
    for (int t = 0; t < 1000000 && MBOX != 4; t++)
      ;
    if (MBOX != 4)
      return 2;
    SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;
    SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = 0;
    MBOX = 0;
    return 0;
  }
  if (cause != CHILIMIX_SOCCTL_RST_CAUSE_POR_MASK)
    return 3;
  SOCCTL(CHILIMIX_SOCCTL_RST_CAUSE_OFFSET) = cause;
  PWM0(CHILIMIX_TIMER_PWM_CFG_OFFSET) = CHILIMIX_TIMER_PWM_CFG_ENALWAYS_MASK;
  SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) = (uint32_t)target;
  for (int i = 0; i < N_BUF; i++)
    buf[0][i] = 0x00c0ffeeu + (uint32_t)i;
  dma_copy();
  MBOX = 1;
  uint32_t spins = 0, copies = 1;
  while (MBOX != 2) {
    spins++;
    if (!(DMA0(CHILIMIX_DMA_CONTROL_OFFSET) & CHILIMIX_DMA_CONTROL_RUN_MASK)) {
      dma_copy();
      copies++;
    }
  }
  while (DMA0(CHILIMIX_DMA_CONTROL_OFFSET) & CHILIMIX_DMA_CONTROL_RUN_MASK)
    ;
  DMA0(CHILIMIX_DMA_CONTROL_OFFSET) = 0;
  for (int i = 0; i < N_BUF; i++)
    if (buf[1][i] != 0x00c0ffeeu + (uint32_t)i)
      return 6;
  int r = target_ptr(5);
  con_printf("spins %u, DMA copies %u, target %d, hits %d, scratch0 %08x\n", (unsigned)spins, (unsigned)copies, r, hits,
             (unsigned)SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)));
  if (r != 16 || hits != 1)
    return 4;
  if (SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0)) != MAGIC)
    return 5;
  con_puts("waiting for ndmreset\n");
  while (!(REG32(UART0_BASE, CHILIMIX_UART_LSR_OFFSET) & CHILIMIX_UART_LSR_TEMT_MASK))
    ;
  MBOX = 3;
  for (;;)
    ;
}
