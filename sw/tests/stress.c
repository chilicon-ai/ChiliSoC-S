// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// stress: seeded random stress (SEED: sim/run.py --seed). ROUNDS rounds,
// each a random mix of the following, all running at once:
//   - DMA copies on both channels (random length and alignment) SRAM0 ->
//     SRAM1 and SRAM1 -> SRAM0; done interrupts through the PLIC; the
//     destination is checked byte for byte, guard bytes included
//   - interrupt storms: ACLINT timer deadlines a few ticks apart (re-armed
//     from the handler), msip (from main, U-mode syscalls and other
//     handlers), GPIO rise edges (pins looped back by the testbench)
//   - nested traps: handlers re-enable MIE (the PLIC threshold raised to
//     the claimed priority) up to MAX_DEPTH; the GPIO handler sets msip
//     (a nested software interrupt), whose handler raises exceptions
//     (ECALL, misaligned load / store) one level deeper still
//   - U/M switches: a kernel of byte / halfword / word loads and stores runs
//     in U-mode with syscalls (ECALL) and an illegal CSR access, and again
//     in M-mode on another buffer: results and buffers must match
//   - WFI (MIE low) with a timer deadline armed: the deadline wakes it
// The testbench's debugger (+sba_stress) meanwhile writes, reads and checks
// its own buffer (DBG_BUF) over the system bus and halts / resumes the hart.
// Mailbox socctl scratch[1]: the program writes 1 (running), then 3 (done);
// the debugger leaves its final pattern in DBG_BUF and writes 4.
#include "ext_irq.h"
#include "user.h"
#include "chilimix_aclint_regs.h"
#include "chilimix_dma_regs.h"
#include "chilimix_gpio_regs.h"

#ifndef SEED
#define SEED 1
#endif
#define ROUNDS    24
#define STEPS     10             // random actions per round
#define MAX_DEPTH 4              // interrupt nesting
#define N_PIN     4              // GPIO pins 0 .. N_PIN-1 toggled
#define DBUF      1024           // DMA buffers (bytes)
#define KWORDS    256            // kernel buffers (words)
#define K_OPS     96             // kernel operations per run
#define LIMIT     400000         // wait loop bound
#define DBG_BUF   (SRAM1_BASE + 0xA000u)   // the debugger's 64 words (above .bss, below the stack)
#define DBG_WORDS 64
#define DBG_FINAL(i) (0xD1B00000u ^ (0x9E3779B9u * (uint32_t)(i)))

#define CLINT(off) REG32(CLINT_BASE, off)
#define GPIO(off)  REG32(GPIO_BASE, off)
#define DMA(ch, off) REG32(DMA_CH_BASE(ch), off)
#define CTL(ch)    DMA(ch, CHILIMIX_DMA_CONTROL_OFFSET)
#define MBOX       SOCCTL(CHILIMIX_SOCCTL_SCRATCH_OFFSET(1))
#define SYS_MSIP   0x51
#define SYS_ADD    0x52

extern char __bss_end[];

// ---- random numbers: one stream for main, one for the handlers
static uint32_t rnd_s = 0x2545F491u ^ (SEED * 0x9E3779B9u);
static uint32_t hrnd_s = 0x6C8E9CF5u ^ (SEED * 0x85EBCA6Bu);

static uint32_t xs(uint32_t x)
{
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return x;
}
static uint32_t rnd(void) { return rnd_s = xs(rnd_s); }
static uint32_t hrnd(void) { return hrnd_s = xs(hrnd_s); }

// counters shared between main and handlers: changed with MIE low
static inline void inc(volatile uint32_t *c)
{
  uint32_t m;
  __asm__ volatile("csrrci %0, mstatus, 8" : "=r"(m) :: "memory");
  (*c)++;
  __asm__ volatile("csrs mstatus, %0" :: "r"(m & 8u) : "memory");
}

static volatile uint32_t depth, max_depth, n_nested;       // interrupt nesting
static volatile uint32_t n_tmr, n_msip, n_ext, n_spurious;  // interrupts taken
static volatile uint32_t tmr_left;                          // timer deadlines still to arm
static volatile uint8_t  pend[N_PIN];                       // GPIO edge issued, not handled
static volatile uint32_t n_edge[N_PIN], n_gpio[N_PIN];
static volatile uint32_t dma_busy[N_DMA_CH], n_dma_start, n_dma_done;
static volatile uint32_t req_ecall, n_ecall;                // M-mode ECALLs
static volatile uint32_t req_misal, n_misal, bad_tval;      // misaligned loads / stores
static volatile uint32_t u_sys, n_sys, u_ill, n_ill, u_bad; // U-mode syscalls, illegal CSR reads
static volatile uint32_t n_wfi;

// ---- timer
static void set_mtimecmp(uint64_t t)
{
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = 0xffffffffu;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_LO_OFFSET(0)) = (uint32_t)t;
  CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) = (uint32_t)(t >> 32);
}

static uint64_t mtime(void)
{
  uint32_t hi, lo;
  do {
    hi = CLINT(CHILIMIX_ACLINT_MTIME_HI_OFFSET);
    lo = CLINT(CHILIMIX_ACLINT_MTIME_LO_OFFSET);
  } while (hi != CLINT(CHILIMIX_ACLINT_MTIME_HI_OFFSET));
  return ((uint64_t)hi << 32) | lo;
}

static int tmr_armed(void) { return CLINT(CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(0)) != 0xffffffffu; }

// ---- exceptions raised on purpose (4-byte instructions: mepc + 4 resumes)
static volatile uint8_t misal_buf[16];

static void m_ecall(void)
{
  __asm__ volatile(".option push\n .option norvc\n ecall\n .option pop" ::: "memory");
}

static void misal(uint32_t r)
{
  uint32_t a = (uint32_t)&misal_buf[1 + (r & 3) * 2], v = r;   // odd address
  if (r & 4)
    __asm__ volatile(".option push\n .option norvc\n lw %0, 0(%1)\n .option pop" : "=&r"(v) : "r"(a) : "memory");
  else
    __asm__ volatile(".option push\n .option norvc\n sh %0, 0(%1)\n .option pop" :: "r"(v), "r"(a) : "memory");
}

static uint32_t sys_call(uint32_t n, uint32_t a, uint32_t b)
{
  register uint32_t a0 __asm__("a0") = a;
  register uint32_t a1 __asm__("a1") = b;
  register uint32_t a7 __asm__("a7") = n;
  __asm__ volatile("ecall" : "+r"(a0) : "r"(a1), "r"(a7) : "memory");
  return a0;
}

// ---- interrupt handlers (run with MIE high below MAX_DEPTH)
static void ext_irq(uint32_t src)
{
  int pin = (int)src - IRQ_GPIO0;
  int k = (int)src - IRQ_DMA0;
  if (pin >= 0 && pin < N_PIN) {
    GPIO(CHILIMIX_GPIO_RISE_IP_OFFSET) = 1u << pin;   // w1c
    n_gpio[pin]++;
    pend[pin] = 0;
    if (depth < MAX_DEPTH - 1)
      CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 1;         // a nested software interrupt
  } else if (k >= 0 && k < 2 * N_DMA_CH && !(k & 1)) {
    CTL(k / 2) = CHILIMIX_DMA_CONTROL_W_CLAIM_MASK;   // done 0: clears the level
    inc(&n_dma_done);
    dma_busy[k / 2] = 0;
  } else {
    exit(0x300 + (int)src);                            // DMA error or an unexpected source
  }
}

static uint32_t on_irq(uint32_t mcause, uint32_t mepc)
{
  uint32_t ms = mstatus(), thr = 0, src = 0;           // MPP / MPIE of this trap
  uint32_t d = ++depth;
  if (d > max_depth)
    max_depth = d;
  if (d > 1)
    n_nested++;
  switch (mcause & 0xff) {
  case 3:
    CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 0;
    n_msip++;
    break;
  case 7:
    n_tmr++;
    if (tmr_left) {
      tmr_left--;
      set_mtimecmp(mtime() + 1 + (hrnd() & 7));        // may be due before MIE is back on
    } else {
      set_mtimecmp(~0ull);
    }
    break;
  case 11:
    src = PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0));
    thr = PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0));
    if (src)
      PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = PLIC(CHILIMIX_PLIC_PRIORITY_OFFSET(src));
    else
      n_spurious++;
    break;
  default:
    exit(0x800 + (int)(mcause & 0xff));
  }
  if (d < MAX_DEPTH)
    __asm__ volatile("csrs mstatus, 8" ::: "memory");
  if (src)
    ext_irq(src);
  else if ((mcause & 0xff) == 3 && d >= 2 && d < MAX_DEPTH) {
    inc(&req_ecall);                                   // exceptions inside a nested handler
    m_ecall();
    uint32_t r = hrnd();
    inc(&req_misal);
    misal(r);
  }
  for (uint32_t i = hrnd() & 15; i; i--)               // stay a while: more nesting
    __asm__ volatile("nop");
  __asm__ volatile("csrc mstatus, 8" ::: "memory");
  if (src) {
    PLIC(CHILIMIX_PLIC_CLAIM_OFFSET(0)) = src;           // complete
    PLIC(CHILIMIX_PLIC_THRESHOLD_OFFSET(0)) = thr;
  }
  depth--;
  __asm__ volatile("csrc mstatus, %0" :: "r"(MSTATUS_MPP | 0x80u) : "memory");
  __asm__ volatile("csrs mstatus, %0" :: "r"(ms & (MSTATUS_MPP | 0x80u)) : "memory");
  return mepc;
}

static uint32_t on_trap(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  uint32_t tval, r;
  if (mcause >> 31)
    return on_irq(mcause, mepc);
  switch (mcause) {
  case 2:                                              // illegal instruction (U-mode CSR read)
    n_ill++;
    return mepc + 4;
  case 4:
  case 6:                                              // misaligned load / store
    __asm__ volatile("csrr %0, mtval" : "=r"(tval));
    if (!(tval & 1) || tval < (uint32_t)misal_buf || tval >= (uint32_t)misal_buf + sizeof misal_buf)
      bad_tval++;
    n_misal++;
    return mepc + 4;
  case 8:                                              // ECALL from U
    if ((r = user_exit_trap(mcause, frame)))
      return r;
    n_sys++;
    if (frame[11] == SYS_MSIP)
      CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 1;          // taken right after mret
    else if (frame[11] == SYS_ADD)
      frame[4] = frame[4] + frame[5];
    else
      exit(0x500 + (int)(frame[11] & 0xff));
    return mepc + 4;
  case 11:                                             // ECALL from M
    n_ecall++;
    return mepc + 4;
  default:
    exit(0x400 + (int)mcause);
  }
}

// ---- the kernel: in U-mode with syscalls, and in M-mode as the reference
static volatile uint32_t ubuf[KWORDS];
__attribute__((section(".sram0_data"))) static volatile uint32_t mbuf[KWORDS];
static volatile uint32_t u_x, u_acc;

static uint32_t __attribute__((noinline)) kernel(uint32_t x, volatile uint32_t *buf, int sys)
{
  volatile uint8_t *b8 = (volatile uint8_t *)buf;
  volatile uint16_t *b16 = (volatile uint16_t *)buf;
  uint32_t acc = 0;
  for (int i = 0; i < K_OPS; i++) {
    x = xs(x);
    uint32_t k = x & (4 * KWORDS - 1);
    switch ((x >> 12) & 3) {
    case 0:  b8[k] = (uint8_t)(x >> 16); break;
    case 1:  b16[k >> 1] = (uint16_t)(x >> 8); break;
    case 2:  buf[k >> 2] = x; break;
    default: acc += b8[k] + b16[(k >> 1) ^ 1] + buf[(k >> 2) ^ 7]; break;
    }
    acc = ((acc << 1) | (acc >> 31)) ^ x;
    if (sys) {
      uint32_t s = (x >> 20) & 15;
      if (s == 0) {
        u_sys++;
        sys_call(SYS_MSIP, 0, 0);
      } else if (s == 1) {
        u_sys++;
        if (sys_call(SYS_ADD, x, acc) != x + acc)
          u_bad++;
      } else if (s == 2) {
        u_ill++;
        __asm__ volatile("csrr t0, mstatus" ::: "t0", "memory");   // illegal in U-mode
      }
    }
  }
  return acc;
}

static void user_fn(void)
{
  u_acc = kernel(u_x, ubuf, 1);
}

// ---- DMA: channel 0 SRAM0 -> SRAM1, channel 1 SRAM1 -> SRAM0
__attribute__((section(".sram0_data"))) static volatile uint8_t s0_src[DBUF], s0_dst[DBUF];
static volatile uint8_t s1_src[DBUF], s1_dst[DBUF];
static uint32_t x_len[N_DMA_CH], x_so[N_DMA_CH], x_do[N_DMA_CH];
#define CLAIM CHILIMIX_DMA_CONTROL_W_CLAIM_MASK

static volatile uint8_t *dma_src(int ch) { return ch ? s1_src : s0_src; }
static volatile uint8_t *dma_dst(int ch) { return ch ? s0_dst : s1_dst; }

static void dma_start(int ch)
{
  volatile uint32_t *s = (volatile uint32_t *)dma_src(ch), *d = (volatile uint32_t *)dma_dst(ch);
  for (int i = 0; i < DBUF / 4; i++) {
    s[i] = rnd();
    d[i] = 0xEEEEEEEEu;
  }
  x_len[ch] = 1 + rnd() % (DBUF - 256);
  x_so[ch] = rnd() & 255;
  x_do[ch] = rnd() & 255;
  dma_busy[ch] = 1;
  inc(&n_dma_start);
  CTL(ch) = CLAIM;
  DMA(ch, CHILIMIX_DMA_NEXT_CONFIG_OFFSET) = (2u << 28) | (2u << 24);
  DMA(ch, CHILIMIX_DMA_NEXT_BYTES_OFFSET) = x_len[ch];
  DMA(ch, CHILIMIX_DMA_NEXT_DST_OFFSET) = (uint32_t)&dma_dst(ch)[x_do[ch]];
  DMA(ch, CHILIMIX_DMA_NEXT_SRC_OFFSET) = (uint32_t)&dma_src(ch)[x_so[ch]];
  CTL(ch) = CLAIM | CHILIMIX_DMA_CONTROL_W_RUN_MASK | CHILIMIX_DMA_CONTROL_W_DONE_IE_MASK
            | CHILIMIX_DMA_CONTROL_W_ERROR_IE_MASK;
}

static int dma_check(int ch)
{
  volatile uint8_t *s = dma_src(ch), *d = dma_dst(ch);
  for (uint32_t i = 0; i < DBUF; i++) {
    uint8_t want = (i >= x_do[ch] && i < x_do[ch] + x_len[ch]) ? s[x_so[ch] + i - x_do[ch]] : 0xEE;
    if (d[i] != want)
      return 0;
  }
  return 1;
}

// ---- main
static void gpio_edge(int p)
{
  if (pend[p])
    return;
  pend[p] = 1;
  n_edge[p]++;
  GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 1u << p;
  GPIO(CHILIMIX_GPIO_OUTPUT_VAL_OFFSET) = 0;
}

static void arm_timer(void)
{
  if (tmr_armed())
    return;
  tmr_left = 1 + (rnd() & 7);
  set_mtimecmp(mtime() + 2 + (rnd() & 15));
}

static int round_done(void)
{
  if (tmr_armed() || dma_busy[0] || dma_busy[1])
    return 0;
  for (int p = 0; p < N_PIN; p++)
    if (pend[p])
      return 0;
  return 1;
}

int main(void)
{
  trap_hook = on_trap;
  if ((uint32_t)__bss_end > DBG_BUF)
    return 1;
  MBOX = 1;
  PHASE(1);                                            // the testbench counts U-mode transfers
  pmp_set(0, 0xffffffffu, PMP_NAPOT | PMP_R | PMP_W | PMP_X);
  set_mtimecmp(~0ull);
  GPIO(CHILIMIX_GPIO_INPUT_EN_OFFSET) = (1u << N_PIN) - 1;
  GPIO(CHILIMIX_GPIO_OUTPUT_EN_OFFSET) = (1u << N_PIN) - 1;
  GPIO(CHILIMIX_GPIO_RISE_IE_OFFSET) = (1u << N_PIN) - 1;
  for (int p = 0; p < N_PIN; p++)
    ext_irq_on(IRQ_GPIO0 + p, 1 + (rnd() % 3));
  for (int i = 0; i < 2 * N_DMA_CH; i++)
    ext_irq_on(IRQ_DMA0 + i, 1 + (rnd() % 3));
  __asm__ volatile("csrs mie, %0" :: "r"(0x888));      // MEIE, MTIE, MSIE (MIE set by ext_irq_on)

  for (int r = 0; r < ROUNDS; r++) {
    for (int ch = 0; ch < N_DMA_CH; ch++)
      if (rnd() & 3)
        dma_start(ch);
    for (int s = 0; s < STEPS; s++) {
      uint32_t a = rnd();
      switch (a & 7) {
      case 0: gpio_edge((int)((a >> 3) % N_PIN)); break;
      case 1: CLINT(CHILIMIX_ACLINT_MSIP_OFFSET(0)) = 1; break;
      case 2: inc(&req_ecall); m_ecall(); break;
      case 3: inc(&req_misal); misal(a >> 3); break;
      case 4:
        __asm__ volatile("csrc mstatus, 8" ::: "memory");
        arm_timer();                                   // with MIE low: still armed at the WFI
        if (tmr_armed()) {                             // a deadline is due: WFI wakes
          n_wfi++;
          __asm__ volatile("wfi");
        }
        __asm__ volatile("csrs mstatus, 8" ::: "memory");
        break;
      case 5: arm_timer(); break;
      default: {                                       // the kernel in U-mode, then in M-mode
        uint32_t x = rnd() | 1;
        u_x = x;
        enter_user(user_fn);
        if (kernel(x, mbuf, 0) != u_acc)
          return 10;
        for (int i = 0; i < KWORDS; i++)
          if (ubuf[i] != mbuf[i])
            return 11;
        break;
      }
      }
    }
    int t = 0;
    while (!round_done() && t < LIMIT)
      t++;
    if (t == LIMIT) {
      con_printf("stress: round %d stuck: timer %d dma %d %d pend %d%d%d%d\n", r, tmr_armed(), dma_busy[0],
                 dma_busy[1], pend[0], pend[1], pend[2], pend[3]);
      return 20;
    }
    for (int ch = 0; ch < N_DMA_CH; ch++)
      if (x_len[ch] && !dma_check(ch)) {
        con_printf("stress: round %d DMA channel %d copy wrong (%d bytes, %d -> %d)\n", r, ch,
                   (int)x_len[ch], (int)x_so[ch], (int)x_do[ch]);
        return 21;
      }
    x_len[0] = x_len[1] = 0;
  }
  __asm__ volatile("csrc mstatus, 8" ::: "memory");
  PHASE(0);

  uint32_t edges = 0, gpio = 0;
  for (int p = 0; p < N_PIN; p++) {
    edges += n_edge[p];
    gpio += n_gpio[p];
    if (n_edge[p] != n_gpio[p])
      return 30 + p;
  }
  con_printf("stress: seed %u, %d rounds: timer %u, msip %u, ext %u (gpio %u, dma %u of %u), nested %u "
             "(depth %u), spurious %u\n", (unsigned)SEED, ROUNDS, (unsigned)n_tmr, (unsigned)n_msip,
             (unsigned)(gpio + n_dma_done), (unsigned)gpio, (unsigned)n_dma_done, (unsigned)n_dma_start,
             (unsigned)n_nested, (unsigned)max_depth, (unsigned)n_spurious);
  con_printf("stress: ecall %u/%u, misaligned %u/%u, syscalls %u/%u, illegal %u/%u, wfi %u\n",
             (unsigned)n_ecall, (unsigned)req_ecall, (unsigned)n_misal, (unsigned)req_misal, (unsigned)n_sys,
             (unsigned)u_sys, (unsigned)n_ill, (unsigned)u_ill, (unsigned)n_wfi);
  if (n_ecall != req_ecall || n_misal != req_misal || bad_tval || n_sys != u_sys || n_ill != u_ill || u_bad)
    return 40;
  if (n_dma_done != n_dma_start || !n_nested || max_depth < 3 || !n_tmr || !n_msip || !gpio || !n_wfi)
    return 41;

  // the debugger's session ends: its final pattern must be in DBG_BUF
  MBOX = 3;
  int t = 0;
  while (MBOX != 4 && t < LIMIT)
    t++;
  if (MBOX != 4)
    return 50;
  for (int i = 0; i < DBG_WORDS; i++)
    if (REG32(DBG_BUF, 4 * i) != DBG_FINAL(i))
      return 51;
  con_printf("stress: debugger buffer ok\n");
  return 0;
}
