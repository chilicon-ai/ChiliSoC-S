// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// pmp: ChillU-S PMP (4 entries) on the SoC memory map. Entries:
//   0  GPIO   4 KiB NAPOT, no permission (locked in phase 3)
//   1  UART0  4 KiB NAPOT, R W
//   2  SRAM0 64 KiB NAPOT, R X (code, read-only data)
//   3  SRAM1 64 KiB NAPOT, R W (data, stack)
// Anything else (socctl, CLINT, ...) matches no entry: denied to U, allowed
// to M. Each step writes its phase to socctl scratch[0]; the testbench
// counts the core's unprivileged transfers per phase (sim/run.py checks them):
//   phase 1  user code: UART0 output and SRAM1 work; a store to SRAM0, a
//            fetch from SRAM1 and a load from the CLINT fault
//            -> user fetches, data accesses and APB transfers
//   phase 2  user code that only touches socctl and GPIO: every access
//            faults -> user fetches, but no user data access or APB transfer
//            (a denied access never reaches the bus)
//   phase 3  M-mode: GPIO is readable while entry 0 is unlocked; a load
//            under MPRV (MPP = U) from socctl faults; after locking entry
//            0, M-mode faults on GPIO too and entry 0 ignores writes
//            -> no user transfers
#include "user.h"

#define N_LOG 16
static volatile uint32_t log_cause[N_LOG], log_tval[N_LOG];
static volatile int n_log;
static volatile uint32_t sram1_code[2];          // a "function" in SRAM1 (not executable)
static volatile uint32_t user_buf[4];

#define SCRATCH1 (SOCCTL_BASE + CHILIMIX_SOCCTL_SCRATCH_OFFSET(1))

static uint32_t on_trap(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  uint32_t resume = user_exit_trap(mcause, frame);
  if (resume)
    return resume;
  uint32_t tval;
  __asm__ volatile("csrr %0, mtval" : "=r"(tval));
  if (n_log < N_LOG) {
    log_cause[n_log] = mcause;
    log_tval[n_log] = tval;
    n_log++;
  }
  if (mcause == 1)                               // fetch fault: back to the caller (jalr set ra)
    return frame[0];
  if (mcause == 5 || mcause == 7)                // load / store fault: skip it (4 bytes, norvc)
    return mepc + 4;
  exit(0x400 + (int)mcause);
}

// 4-byte loads / stores, so a faulting one is skipped with mepc + 4
static inline uint32_t lw4(uint32_t a)
{
  uint32_t v = 0;
  __asm__ volatile(".option push\n .option norvc\n lw %0, 0(%1)\n .option pop"
                   : "+r"(v) : "r"(a) : "memory");
  return v;
}

static inline void sw4(uint32_t a, uint32_t v)
{
  __asm__ volatile(".option push\n .option norvc\n sw %0, 0(%1)\n .option pop"
                   : : "r"(v), "r"(a) : "memory");
}

static volatile uint32_t u_code_word, u_buf_ok;

__attribute__((aligned(4))) static void user_main(void)   // aligned: its first word is loaded and stored
{
  con_printf("user: UART0 is R W for U\n");
  for (int i = 0; i < 4; i++)
    user_buf[i] = 0x100u * i + 7;
  u_buf_ok = user_buf[3] == 0x307;
  u_code_word = lw4((uint32_t)user_main);          // SRAM0 is R for U
  sw4((uint32_t)user_main, 0);                     // ... but not W: store fault
  ((void (*)(void))sram1_code)();                  // SRAM1 is not X: fetch fault
  lw4(CLINT_BASE);                                 // no entry: load fault
}

// only socctl and GPIO accesses (no stack, no other data): all denied
void user_denied(void);
__asm__(
  "  .text\n"
  "  .option push\n"
  "  .option norvc\n"
  "user_denied:\n"
  "  li    t0, 0x10000020\n"           // socctl scratch[1]
  "  lw    t1, 0(t0)\n"
  "  sw    t1, 0(t0)\n"
  "  li    t0, 0x10012000\n"           // GPIO
  "  lw    t1, 0(t0)\n"
  "  sw    t1, 0(t0)\n"
  "  ret\n"
  "  .option pop\n");

static int expect(int i, uint32_t cause, uint32_t tval)
{
  return i < n_log && log_cause[i] == cause && log_tval[i] == tval;
}

int main(void)
{
  trap_hook = on_trap;
  sram1_code[0] = 0x00008067u;                     // ret (it never runs)
  pmp_set(0, NAPOT(GPIO_BASE, 0x1000), PMP_NAPOT);
  pmp_set(1, NAPOT(UART0_BASE, 0x1000), PMP_NAPOT | PMP_R | PMP_W);
  pmp_set(2, NAPOT(SRAM0_BASE, 0x10000), PMP_NAPOT | PMP_R | PMP_X);
  pmp_set(3, NAPOT(SRAM1_BASE, 0x10000), PMP_NAPOT | PMP_R | PMP_W);
  if (pmpcfg0() != 0x1b1d1b18u)
    return 1;

  PHASE(1);
  enter_user(user_main);
  int n1 = n_log;
  PHASE(2);
  enter_user(user_denied);
  int n2 = n_log;
  PHASE(3);

  uint32_t gpio = lw4(GPIO_BASE);                  // M, entry 0 unlocked: allowed
  int n3a = n_log;
  __asm__ volatile("csrc mstatus, %0" : : "r"(MSTATUS_MPP) : "memory");
  __asm__ volatile("csrs mstatus, %0" : : "r"(MSTATUS_MPRV) : "memory");
  lw4(SCRATCH1);                                   // MPRV, MPP = U: socctl denied
  __asm__ volatile("csrc mstatus, %0" : : "r"(MSTATUS_MPRV) : "memory");
  __asm__ volatile("csrs mstatus, %0" : : "r"(MSTATUS_MPP) : "memory");
  pmp_set(0, NAPOT(GPIO_BASE, 0x1000), PMP_NAPOT | PMP_L);
  lw4(GPIO_BASE);                                  // locked: M denied too
  pmp_set(0, 0xffffffffu, PMP_NAPOT | PMP_R | PMP_W | PMP_X | PMP_L);   // ignored
  uint32_t cfg = pmpcfg0();
  int n3 = n_log;
  PHASE(4);

  con_printf("pmp: %d faults (phase 1 %d, 2 %d, 3 %d), code word %x, gpio %x, pmpcfg0 %x\n",
             n_log, n1, n2 - n1, n3 - n2, (unsigned)u_code_word, (unsigned)gpio, (unsigned)cfg);
  for (int i = 0; i < n_log; i++)
    con_printf("  fault %d: mcause %u mtval %x\n", i, (unsigned)log_cause[i], (unsigned)log_tval[i]);
  if (!u_buf_ok || u_code_word != *(volatile uint32_t *)user_main)
    return 2;
  if (n1 != 3 || !expect(0, 7, (uint32_t)user_main) || !expect(1, 1, (uint32_t)sram1_code)
      || !expect(2, 5, CLINT_BASE))
    return 3;
  if (n2 - n1 != 4 || !expect(3, 5, SCRATCH1) || !expect(4, 7, SCRATCH1)
      || !expect(5, 5, GPIO_BASE) || !expect(6, 7, GPIO_BASE))
    return 4;
  if (n3a != n2 || n3 - n2 != 2 || !expect(7, 5, SCRATCH1) || !expect(8, 5, GPIO_BASE))
    return 5;
  if ((cfg & 0xff) != (PMP_NAPOT | PMP_L) || (cfg >> 8) != 0x1b1d1bu)
    return 6;
  return 0;
}
