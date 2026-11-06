// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// dma: the DMA engine (a third manager of the D bus, sf-pdma layout) with
// the core running alongside:
//   1  channel 0 copies 256 bytes SRAM1 -> SRAM1 while channel 1 copies a
//      256-byte table from the SPI0 flash (XIP) -> SRAM0; both done
//      interrupts arrive through the PLIC (IRQ_DMA0 + 2 * i) while the core
//      keeps loading and storing in SRAM1
//   2  a 13-byte copy between odd addresses (1, 2 and 4-byte beats); the
//      bytes around the destination stay
//   3  a word to a peripheral: socctl scratch[1] over the APB bridge
//   4  a read from an address no subordinate claims: error interrupt
//      (IRQ_DMA0 + 2 * 1 + 1), control.error set; then the same on channel 0
//   5  the core sleeps (WFI, mstatus.MIE low) while a copy runs: its done
//      interrupt (machine external) wakes it
//   6  the core sleeps while the DMA writes the ACLINT msip register from a
//      word in the flash (XIP, an uncached line: slow): the software
//      interrupt wakes it
//   7  one word from each other region (debug module, ROM and every APB
//      subordinate) to SRAM1; the ROM word matches the core's load
//   8  a copy from the ROM runs while the core jumps into the boot ROM, so
//      fetches and DMA reads meet at the ROM; the boot ROM restarts the
//      program, which finds its mark in socctl scratch[0] (N_ROM times),
//      then checks the copy
#include "ext_irq.h"
#include "chilimix_aclint_regs.h"
#include "chilimix_dma_regs.h"
#include "chilimix_socctl_regs.h"

#define DMA(ch, off) REG32(DMA_CH_BASE(ch), off)
#define CTL(ch)      DMA(ch, CHILIMIX_DMA_CONTROL_OFFSET)
#define CLAIM   CHILIMIX_DMA_CONTROL_W_CLAIM_MASK
#define RUN     CHILIMIX_DMA_CONTROL_W_RUN_MASK
#define DONE_IE CHILIMIX_DMA_CONTROL_W_DONE_IE_MASK
#define ERR_IE  CHILIMIX_DMA_CONTROL_W_ERROR_IE_MASK
#define N_TAB 64
#define E(i)  (0x9E3779B1u * (i) + 0x7F4A7C15u)
#define E4(i) E(i), E(i + 1), E(i + 2), E(i + 3)
#define E16(i) E4(i), E4(i + 4), E4(i + 8), E4(i + 12)

__attribute__((section(".xip.rodata"))) const uint32_t xip_tab[N_TAB] = {
  E16(0), E16(16), E16(32), E16(48)
};

// a flash word alone in its cache line (phase 6): odd, so it sets msip
__attribute__((section(".xip.rodata"), aligned(256))) const uint32_t xip_msip = 0x5eed0001u;

static volatile uint32_t src[N_TAB], dst[N_TAB], work[N_TAB];
#define MARK      SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(0))
#define ROM_MARK  0xB0070000u                      // + restarts so far (phase 8)
#define N_ROM     3
#define ROM_COPY  (SRAM1_BASE + 0x8000u)           // above .data / .bss (crt0 clears .bss), below the stack
#define ROM_BYTES 1024u
__attribute__((section(".sram0_data"))) static volatile uint32_t dst0[N_TAB];
static volatile uint8_t odd_src[24], odd_dst[24];
static volatile uint32_t one_word;
static volatile int n_done[N_DMA_CH], n_err[N_DMA_CH], n_bad_irq;
static volatile uint32_t irq_ctl[N_DMA_CH];       // control at the last interrupt

static void ext_irq(uint32_t src_id)
{
  int k = (int)src_id - IRQ_DMA0;
  if (k >= 0 && k < 2 * N_DMA_CH) {
    int ch = k / 2;
    irq_ctl[ch] = CTL(ch);
    if (k & 1) n_err[ch]++; else n_done[ch]++;
    CTL(ch) = CLAIM;                               // done / error 0: clears the level
  } else {
    n_bad_irq++;
  }
}

static uint32_t on_trap(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (ext_irq_trap(mcause))
    return mepc;
  exit(0x400 + (int)(mcause & 0xff));
}

static void start(int ch, uint32_t from, uint32_t to, uint32_t bytes)
{
  CTL(ch) = CLAIM;
  DMA(ch, CHILIMIX_DMA_NEXT_CONFIG_OFFSET) = (2u << 28) | (2u << 24);   // rsize, wsize: words
  DMA(ch, CHILIMIX_DMA_NEXT_BYTES_OFFSET) = bytes;
  DMA(ch, CHILIMIX_DMA_NEXT_DST_OFFSET) = to;
  DMA(ch, CHILIMIX_DMA_NEXT_SRC_OFFSET) = from;
  CTL(ch) = CLAIM | RUN | DONE_IE | ERR_IE;
}

static int wait_irq(volatile int *cnt, int n)
{
  for (int t = 0; *cnt < n && t < 100000; t++)
    ;
  return *cnt == n;
}

#define SOCCTL(off) REG32(SOCCTL_BASE, off)

// phase 8: start the ROM copy (no interrupt: crt0 runs before trap_hook is
// set) and jump into the boot ROM, which jumps to the program's start
static void rom_restart(uint32_t n)
{
  MARK = ROM_MARK + n;
  __asm__ volatile("csrc mstatus, 8");
  CTL(0) = CLAIM;
  DMA(0, CHILIMIX_DMA_NEXT_CONFIG_OFFSET) = (2u << 28) | (2u << 24);
  DMA(0, CHILIMIX_DMA_NEXT_BYTES_OFFSET) = ROM_BYTES;
  DMA(0, CHILIMIX_DMA_NEXT_DST_OFFSET) = ROM_COPY;
  DMA(0, CHILIMIX_DMA_NEXT_SRC_OFFSET) = ROM_BASE;
  CTL(0) = CLAIM | RUN;
  ((void (*)(void))ROM_BASE)();
}

static int rom_phase(uint32_t n)
{
  while (CTL(0) & CHILIMIX_DMA_CONTROL_RUN_MASK)
    ;
  CTL(0) = 0;
  for (uint32_t a = 0; a < ROM_BYTES; a += 4)
    if (REG32(ROM_COPY, a) != REG32(ROM_BASE, a))
      return 30;
  if (n < N_ROM)
    rom_restart(n + 1);
  MARK = 0;
  con_printf("dma: ROM copies during %d boot ROM restarts ok\n", N_ROM);
  return 0;
}

int main(void)
{
  trap_hook = on_trap;
  if ((MARK & 0xffff0000u) == ROM_MARK)
    return rom_phase(MARK & 0xffffu);
  for (int i = 0; i < 2 * N_DMA_CH; i++)
    ext_irq_on(IRQ_DMA0 + i, 1);
  for (int i = 0; i < N_TAB; i++) {
    src[i] = 0xa5000000u + 0x10101u * (uint32_t)i;
    dst[i] = 0;
    dst0[i] = 0;
  }

  // 1: two channels, the core busy in SRAM1 meanwhile
  start(0, (uint32_t)src, (uint32_t)dst, sizeof src);
  start(1, (uint32_t)xip_tab, (uint32_t)dst0, sizeof xip_tab);
  uint32_t acc = 0;
  for (int r = 0; r < 8; r++)
    for (int i = 0; i < N_TAB; i++) {
      work[i] = work[i] * 3u + (uint32_t)i;
      acc += work[i];
    }
  int ok = wait_irq(&n_done[0], 1) && wait_irq(&n_done[1], 1);
  int bad = 0;
  for (int i = 0; i < N_TAB; i++)
    bad += (dst[i] != src[i]) + (dst0[i] != E((uint32_t)i));
  con_printf("dma: two channels done %d %d, %d wrong words (core acc %x)\n", n_done[0], n_done[1], bad,
             (unsigned)acc);
  if (!ok || bad)
    return 1;

  // 2: odd addresses and length
  for (int i = 0; i < 24; i++) {
    odd_src[i] = (uint8_t)(0x30 + i);
    odd_dst[i] = 0xee;
  }
  start(0, (uint32_t)&odd_src[1], (uint32_t)&odd_dst[3], 13);
  if (!wait_irq(&n_done[0], 2))
    return 2;
  for (int i = 0; i < 24; i++)
    if (odd_dst[i] != ((i >= 3 && i < 16) ? (uint8_t)(0x30 + i - 2) : 0xee))
      return 3;

  // 3: to a peripheral register
  one_word = 0x600dd00du;
  start(0, (uint32_t)&one_word, SOCCTL_BASE + CHILIMIX_SOCCTL_SCRATCH_OFFSET(1), 4);
  if (!wait_irq(&n_done[0], 3) || REG32(SOCCTL_BASE, CHILIMIX_SOCCTL_SCRATCH_OFFSET(1)) != 0x600dd00du)
    return 4;

  // 4: bus error
  start(1, 0x40000000u, (uint32_t)dst, 8);
  if (!wait_irq(&n_err[1], 1))
    return 5;
  uint32_t ctl = irq_ctl[1];
  CTL(1) = 0;                                      // release the channel
  start(0, 0x40000000u, (uint32_t)dst, 8);
  if (!wait_irq(&n_err[0], 1) || !(irq_ctl[0] & CHILIMIX_DMA_CONTROL_ERROR_MASK))
    return 7;
  con_printf("dma: odd copy, peripheral write and bus errors ok (done %d %d, errors %d %d)\n", n_done[0],
             n_done[1], n_err[0], n_err[1]);
  if (n_err[0] != 1 || n_done[1] != 1 || n_bad_irq || !(ctl & CHILIMIX_DMA_CONTROL_ERROR_MASK)
      || (ctl & (CHILIMIX_DMA_CONTROL_RUN_MASK | CHILIMIX_DMA_CONTROL_DONE_MASK)))
    return 6;

  // 5: asleep until the done interrupt (MIE low: WFI resumes, then the trap)
  __asm__ volatile("csrc mstatus, 8");
  start(0, (uint32_t)src, (uint32_t)dst, sizeof src);
  __asm__ volatile("wfi");
  __asm__ volatile("csrs mstatus, 8");
  if (!wait_irq(&n_done[0], 4))
    return 8;

  // 6: asleep until the DMA sets msip
  __asm__ volatile("csrc mstatus, 8");
  __asm__ volatile("csrs mie, %0" :: "r"(0x8));    // MSIE
  start(0, (uint32_t)&xip_msip, CLINT_BASE + CHILIMIX_ACLINT_MSIP_OFFSET(0), 4);
  __asm__ volatile("wfi");
  uint32_t mip;
  __asm__ volatile("csrr %0, mip" : "=r"(mip));
  REG32(CLINT_BASE, CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 0;
  __asm__ volatile("csrc mie, %0" :: "r"(0x8));
  __asm__ volatile("csrs mstatus, 8");
  if (!(mip & 0x8) || !wait_irq(&n_done[0], 5))
    return 9;

  // 7: every other region
  static const uint32_t from[] = {
    DM_BASE, ROM_BASE, CLINT_BASE + CHILIMIX_ACLINT_MTIME_LO_OFFSET, PLIC_BASE + 4, SOCCTL_BASE,
    GPIO_BASE, UART0_BASE + 0x1c, PWM_BASE(0) + 8, SPI0_BASE, I2C0_BASE, DMA_CH_BASE(1) + 8,
  };
  for (unsigned i = 0; i < sizeof from / sizeof from[0]; i++) {
    dst[i] = 0xdeadbeefu;
    start(0, from[i], (uint32_t)&dst[i], 4);
    if (!wait_irq(&n_done[0], 6 + (int)i))
      return 20 + (int)i;
  }
  CTL(0) = 0;
  con_printf("dma: woken by done and by msip; every region read (rom %08x)\n", (unsigned)dst[1]);
  if (dst[1] != REG32(ROM_BASE, 0) || n_err[0] != 1 || n_err[1] != 1 || n_bad_irq)
    return 10;

  // 8: through the boot ROM, with the DMA reading the ROM
  rom_restart(1);
  return 11;
}
