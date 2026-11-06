// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// spi: SPI0 and its flash window (XIP) against the testbench's SPI NOR
// flash model. Steps:
//   1  XIP with the reset instruction (0x03 read, single): a table in the
//      flash (.xip) reads back, and a function in the flash runs (fetches
//      through the I layer, its loads through the D layer)
//   2  a store to the window faults (store access fault, mtval = address)
//   3  FIFO frames with the flash interface off (fctrl.en 0): JEDEC ID
//      (0x9F) and status (0x05) under csmode HOLD
//   4  XIP with the 0x0B fast read, 0x3B dual and 0x6B quad output reads
//      at sckdiv 0 (writing ffmt empties the read cache)
//   5  the TX watermark interrupt through the PLIC (source IRQ_SPI0)
#include "ext_irq.h"
#include "chilimix_spi_regs.h"

#define SPI(off) REG32(SPI0_BASE, off)
#define N_TAB 64
#define E(i)  (0x9E3779B1u * (i) + 0x7F4A7C15u)
#define E4(i) E(i), E(i + 1), E(i + 2), E(i + 3)
#define E16(i) E4(i), E4(i + 4), E4(i + 8), E4(i + 12)

__attribute__((section(".xip.rodata"))) const uint32_t xip_tab[N_TAB] = {
  E16(0), E16(16), E16(32), E16(48)
};

// runs from the flash: a checksum of a table
__attribute__((section(".xip.text"), noinline, noclone)) uint32_t xip_sum(const volatile uint32_t *p, int n)
{
  uint32_t s = 0;
  for (int i = 0; i < n; i++)
    s = s * 31u + p[i];
  return s;
}

static uint32_t ref_sum(void)
{
  uint32_t s = 0;
  for (uint32_t i = 0; i < N_TAB; i++)
    s = s * 31u + E(i);
  return s;
}

static volatile int n_spi_irq, n_bad_irq, n_store_fault;
static volatile uint32_t fault_tval;

static void ext_irq(uint32_t src)
{
  if (src == IRQ_SPI0) {
    SPI(CHILIMIX_SPI_IE_OFFSET) = 0;               // a level: mask it
    n_spi_irq++;
  } else {
    n_bad_irq++;
  }
}

static uint32_t on_trap(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (ext_irq_trap(mcause))
    return mepc;
  if (mcause == 7) {
    __asm__ volatile("csrr %0, mtval" : "=r"(fault_tval));
    n_store_fault++;
    return mepc + 4;                               // sw4: 4 bytes
  }
  exit(0x400 + (int)(mcause & 0xff));
}

static inline void sw4(uint32_t a, uint32_t v)
{
  __asm__ volatile(".option push\n .option norvc\n sw %0, 0(%1)\n .option pop"
                   : : "r"(v), "r"(a) : "memory");
}

// the table and the flash function, against their values
static int xip_check(void)
{
  for (int i = 0; i < N_TAB; i++)
    if (((const volatile uint32_t *)xip_tab)[i] != E((uint32_t)i))
      return 0;
  return xip_sum(xip_tab, N_TAB) == ref_sum();
}

// one FIFO frame (8 bits, single): send tx, return the received byte
static uint32_t frame(uint32_t tx)
{
  SPI(CHILIMIX_SPI_TXDATA_OFFSET) = tx;
  uint32_t r;
  do r = SPI(CHILIMIX_SPI_RXDATA_OFFSET); while (r & CHILIMIX_SPI_RXDATA_EMPTY_MASK);
  return r & 0xff;
}

#define FFMT(cmd, pad, dproto) (0x1u | (3u << 1) | ((pad) << 4) | ((dproto) << 12) | ((uint32_t)(cmd) << 16))

int main(void)
{
  trap_hook = on_trap;
  uint32_t ffmt0 = SPI(CHILIMIX_SPI_FFMT_OFFSET), div0 = SPI(CHILIMIX_SPI_SCKDIV_OFFSET);
  con_printf("spi: fctrl %x ffmt %x sckdiv %x, xip_sum at %p\n", (unsigned)SPI(CHILIMIX_SPI_FCTRL_OFFSET),
             (unsigned)ffmt0, (unsigned)div0, (void *)xip_sum);
  if (SPI(CHILIMIX_SPI_FCTRL_OFFSET) != 1 || ffmt0 != FFMT(0x03, 0, 0))
    return 1;
  if (((uint32_t)xip_sum & 0xe0000000u) != XIP_BASE || ((uint32_t)xip_tab & 0xe0000000u) != XIP_BASE)
    return 2;

  // 1: reset instruction
  if (!xip_check())
    return 3;

  // 2: the window is read-only
  sw4((uint32_t)&xip_tab[3], 0);
  if (n_store_fault != 1 || fault_tval != (uint32_t)&xip_tab[3] || xip_tab[3] != E(3u))
    return 4;

  // 3: FIFO frames: JEDEC ID and status, cs held across the frames
  SPI(CHILIMIX_SPI_FCTRL_OFFSET) = 0;
  SPI(CHILIMIX_SPI_CSMODE_OFFSET) = 2;             // HOLD
  uint32_t id[4];
  for (int i = 0; i < 4; i++)
    id[i] = frame(i ? 0 : 0x9f);
  SPI(CHILIMIX_SPI_CSMODE_OFFSET) = 0;             // AUTO: ends the hold
  SPI(CHILIMIX_SPI_CSMODE_OFFSET) = 2;
  frame(0x05);
  uint32_t st = frame(0);
  SPI(CHILIMIX_SPI_CSMODE_OFFSET) = 0;
  SPI(CHILIMIX_SPI_FCTRL_OFFSET) = 1;
  con_printf("spi: jedec id %x %x %x, status %x\n", (unsigned)id[1], (unsigned)id[2], (unsigned)id[3], (unsigned)st);
#ifdef FPGA
  if (id[1] != 0x01 || id[2] != 0x20 || id[3] != 0x18 || st != 0)   // the Arty's S25FL128S
#else
  if (id[1] != 0xef || id[2] != 0x40 || id[3] != 0x18 || st != 0)   // the testbench's model
#endif
    return 5;

  // 4: faster instructions
  static const uint32_t fmts[3] = {FFMT(0x0b, 8, 0), FFMT(0x3b, 8, 1), FFMT(0x6b, 8, 2)};
  SPI(CHILIMIX_SPI_SCKDIV_OFFSET) = 0;
  for (int f = 0; f < 3; f++) {
    SPI(CHILIMIX_SPI_FFMT_OFFSET) = fmts[f];
    uint64_t c0 = rd_cycle();
    int ok = xip_check();
    con_printf("spi: ffmt %x %s, %u cycles\n", (unsigned)fmts[f], ok ? "ok" : "BAD", (unsigned)(rd_cycle() - c0));
    if (!ok)
      return 6 + f;
  }
  SPI(CHILIMIX_SPI_FFMT_OFFSET) = ffmt0;
  SPI(CHILIMIX_SPI_SCKDIV_OFFSET) = div0;

  // 5: TX watermark (TX FIFO count 0 < txmark 1) through the PLIC
  ext_irq_on(IRQ_SPI0, 1);
  SPI(CHILIMIX_SPI_TXMARK_OFFSET) = 1;
  SPI(CHILIMIX_SPI_IE_OFFSET) = CHILIMIX_SPI_IE_TXWM_MASK;
  for (int t = 0; n_spi_irq == 0 && t < 1000; t++)
    ;
  ext_irq_off(IRQ_SPI0);
  con_printf("spi: %d watermark interrupts\n", n_spi_irq);
  if (n_spi_irq != 1 || n_bad_irq)
    return 9;
  return 0;
}
