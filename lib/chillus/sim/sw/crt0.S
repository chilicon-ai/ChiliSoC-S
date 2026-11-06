/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
// -----------------------------------------------------------------------------
// ChillU-S sim :: crt0 (C runtime start-up for chillus_tb and Spike)
//
//   _start : gp, sp, mtvec; zero minstret / mcycle (Spike's boot ROM has
//            already retired a few instructions, the RTL has not, so both
//            count from here); clear .bss; main(); exit with its return value.
//   exit   : tohost = (code << 1) | 1, i.e. 1 = PASS, else FAIL <code>
//            (riscv-tests convention, read by chillus_tb and Spike's HTIF).
//   trap   : any trap is unexpected: exit with code 0x400 + mcause.
//
// .tohost holds tohost / fromhost (Spike HTIF) and console: a store of a byte
// to console prints it (chillus_tb +console; for Spike it is plain memory).
// -----------------------------------------------------------------------------
  .section .text.init, "ax", @progbits
  .globl _start
_start:
  .option push
  .option norelax
  la    gp, __global_pointer$
  .option pop
  la    sp, __stack_top
  la    t0, trap_entry
  csrw  mtvec, t0

  csrw  minstret, zero
  csrw  minstreth, zero
  csrw  mcycle, zero
  csrw  mcycleh, zero

  la    t0, __bss_start
  la    t1, __bss_end
1:
  bgeu  t0, t1, 2f
  sw    zero, 0(t0)
  addi  t0, t0, 4
  j     1b
2:
  call  main

  .globl exit
exit:
  slli  a0, a0, 1
  ori   a0, a0, 1
  la    t0, tohost
  sw    a0, 0(t0)
3:
  j     3b

  .align 2
trap_entry:
  csrr  a0, mcause
  addi  a0, a0, 0x400
  j     exit

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost:
  .dword 0
  .align 6
  .globl fromhost
fromhost:
  .dword 0
  .align 6
  .globl console
console:
  .word 0
