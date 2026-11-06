// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// ChillU-S debug tests: a minimal Debug Module ROM for the testbench.
//
// DBG_ROM places the code at the testbench's DM_HALT_ADDR (section .dbg_rom,
// linked at chillus_tb DM_ROM by sim/run.py; DM_EXCEPTION_ADDR = + 8). It
// works off a mailbox in RAM (dbg_mbox, DBG_DATA), like riscv-dbg's ROM
// works off DM memory, but every command is a field the M-mode test code
// sets before it raises the halt request:
//
//   on each entry (halt request, step, EBREAK with ebreakm):
//     save x1 / x29 / x30 / x31 in the mailbox (dscratch1 for a moment)
//     clear irqgen bits DBG_REQ / DBG_WAKE (debug_req falls) and wait for it
//     MB_COUNT += 1; MB_DPC = dpc; MB_DCSR = dcsr; MB_LOG[count % 32] = dpc
//     MB_HOOK != 0: call it (jalr x1) in debug mode; it may use x29 / x30
//       (x31 = mailbox, not to be changed) and MB_USER0 / 1
//     MB_STEPS != 0: decrement; at 0 clear dcsr.step
//     MB_DCSR_WR != 0: write dcsr (one-shot); MB_DPC_WR != 0: write dpc
//     restore the registers, dret
//   EBREAK in debug mode (from a hook): MB_EBREAK += 1, MB_USER0 = dpc,
//     MB_USER1 = dcsr, continue after the hook (MB_INROM tells it apart
//     from a new entry)
//   exception in debug mode (from a hook): MB_EXC += 1, continue after it
//
// The test needs the word `irqgen` (chillus_tb interrupt generator).

#define DBG_REQ     (1 << 29)      // irqgen: debug_req level
#define DBG_WAKE    (1 << 30)      // irqgen: debug_req once asleep (held)

// DCSR_STEP / DCSR_EBREAKM: riscv-tests encoding.h
#define DCSR_PRV_M      3
#define DCSR_STOPCOUNT  (1 << 10)
#define DCSR_NMIP       (1 << 3)

#define MB_COUNT    0
#define MB_DPC      4
#define MB_DCSR     8
#define MB_DCSR_WR  12
#define MB_DPC_WR   16
#define MB_HOOK     20
#define MB_EXC      24
#define MB_EBREAK   28
#define MB_INROM    32
#define MB_X1       36
#define MB_X29      40
#define MB_X30      44
#define MB_X31      48
#define MB_STEPS    52
#define MB_USER0    56
#define MB_USER1    60
#define MB_LOG      64
#define MB_SIZE     (64 + 32 * 4)

// irqgen |= bits (x20 = &irqgen), uses x5 / x6
#define DBG_GEN_OR(bits)  lw x5, 0(x20); li x6, bits; or x5, x5, x6; sw x5, 0(x20); lw x5, 0(x20); fence

// halt request: raise debug_req and spin until the DM code ran once
// (x21 = &dbg_mbox), uses x5 / x6 / x7
#define DBG_HALT \
  lw x7, MB_COUNT(x21); \
  DBG_GEN_OR(DBG_REQ); \
  1: lw x5, MB_COUNT(x21); beq x5, x7, 1b

#define DBG_ROM \
  .pushsection .dbg_rom, "ax"; \
  .option push; \
  .option norvc; \
  .global dm_rom; \
dm_rom: \
  j dm_halt;                      /* DM_HALT_ADDR */ \
  j dm_halt;                      /* + 4: riscv-dbg resume address (unused) */ \
  j dm_exc;                       /* DM_EXCEPTION_ADDR = + 8 */ \
dm_halt: \
  csrw dscratch1, x30; \
51: auipc x30, %pcrel_hi(dbg_mbox + MB_INROM); \
  lw x30, %pcrel_lo(51b)(x30); \
  bnez x30, dm_reenter; \
52: auipc x30, %pcrel_hi(dbg_mbox); \
  addi x30, x30, %pcrel_lo(52b); \
  sw x31, MB_X31(x30); \
  mv x31, x30; \
  csrr x30, dscratch1; \
  sw x30, MB_X30(x31); \
  sw x29, MB_X29(x31); \
  sw x1, MB_X1(x31); \
  li x30, 1; \
  sw x30, MB_INROM(x31); \
  la x29, irqgen; \
  lw x30, 0(x29); \
  li x1, ~(DBG_REQ | DBG_WAKE); \
  and x30, x30, x1; \
  sw x30, 0(x29); \
  lw x30, 0(x29); \
  fence; \
  lw x29, MB_COUNT(x31); \
  csrr x30, dpc; \
  sw x30, MB_DPC(x31); \
  andi x1, x29, 31; \
  slli x1, x1, 2; \
  add x1, x1, x31; \
  sw x30, MB_LOG(x1); \
  addi x29, x29, 1; \
  sw x29, MB_COUNT(x31); \
  csrr x30, dcsr; \
  sw x30, MB_DCSR(x31); \
  lw x30, MB_HOOK(x31); \
  beqz x30, dm_hook_ret; \
  jalr x1, 0(x30); \
dm_hook_ret: \
  lw x30, MB_STEPS(x31); \
  beqz x30, 53f; \
  addi x30, x30, -1; \
  sw x30, MB_STEPS(x31); \
  bnez x30, 53f; \
  csrci dcsr, DCSR_STEP; \
53: lw x30, MB_DCSR_WR(x31); \
  beqz x30, 54f; \
  csrw dcsr, x30; \
  sw zero, MB_DCSR_WR(x31); \
54: lw x30, MB_DPC_WR(x31); \
  beqz x30, 55f; \
  csrw dpc, x30; \
  sw zero, MB_DPC_WR(x31); \
55: sw zero, MB_INROM(x31); \
  lw x1, MB_X1(x31); \
  lw x29, MB_X29(x31); \
  lw x30, MB_X30(x31); \
  lw x31, MB_X31(x31); \
  dret; \
dm_reenter:                       /* EBREAK in debug mode (x31 = mailbox) */ \
  lw x30, MB_EBREAK(x31); \
  addi x30, x30, 1; \
  sw x30, MB_EBREAK(x31); \
  csrr x30, dpc; \
  sw x30, MB_USER0(x31); \
  csrr x30, dcsr; \
  sw x30, MB_USER1(x31); \
  j dm_hook_ret; \
dm_exc:                           /* exception in debug mode (x31 = mailbox) */ \
  lw x30, MB_EXC(x31); \
  addi x30, x30, 1; \
  sw x30, MB_EXC(x31); \
  j dm_hook_ret; \
  .option pop; \
  .popsection

#define DBG_DATA \
  .balign 4; \
  .global dbg_mbox; \
dbg_mbox: .space MB_SIZE; \
  .global irqgen; \
irqgen: .word 0
