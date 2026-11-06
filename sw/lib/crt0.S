/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
// -----------------------------------------------------------------------------
// ChiliSoC-S sw :: crt0 (C runtime start-up, entered from the boot ROM)
//
//   _start : gp, sp, mtvec; zero mcycle / minstret; copy .sram0_data and
//            .data / .sdata from their load addresses (in the flash under
//            link_xip.ld; none under link.ld); clear .bss; UART0 init;
//            main(); exit with its return value (runtime.c).
//   .xip_entry (link_xip.ld only: kept at the base of SRAM0, where the boot
//            ROM starts programs): a jump to _start in the flash.
//   trap   : saves the caller-saved registers and calls trap_handler(mcause,
//            mepc, frame) (runtime.c; a test may install a hook; frame[0] is
//            the saved ra), then mret to the mepc it returns.
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

  la    t0, __sram0_data_load
  la    t1, __sram0_data_start
  la    t2, __sram0_data_end
  call  copy_words
  la    t0, __data_load
  la    t1, __data_start
  la    t2, __data_end
  call  copy_words

  la    t0, __bss_start
  la    t1, __bss_end
1:
  bgeu  t0, t1, 2f
  sw    zero, 0(t0)
  addi  t0, t0, 4
  j     1b
2:
  call  uart_init
  call  main
  tail  exit

// words from t0 to [t1, t2); nothing when t0 = t1 (loaded in place)
copy_words:
  beq   t0, t1, 2f
1:
  bgeu  t1, t2, 2f
  lw    t3, 0(t0)
  sw    t3, 0(t1)
  addi  t0, t0, 4
  addi  t1, t1, 4
  j     1b
2:
  ret

  .section .xip_entry, "ax", @progbits
xip_entry:
  lui   t0, %hi(_start)
  addi  t0, t0, %lo(_start)
  jr    t0

  .text
  .align 2
trap_entry:
  addi  sp, sp, -64
  sw    ra,  0(sp)
  sw    t0,  4(sp)
  sw    t1,  8(sp)
  sw    t2, 12(sp)
  sw    a0, 16(sp)
  sw    a1, 20(sp)
  sw    a2, 24(sp)
  sw    a3, 28(sp)
  sw    a4, 32(sp)
  sw    a5, 36(sp)
  sw    a6, 40(sp)
  sw    a7, 44(sp)
  sw    t3, 48(sp)
  sw    t4, 52(sp)
  sw    t5, 56(sp)
  sw    t6, 60(sp)
  csrr  a0, mcause
  csrr  a1, mepc
  mv    a2, sp
  call  trap_handler
  csrw  mepc, a0
  lw    ra,  0(sp)
  lw    t0,  4(sp)
  lw    t1,  8(sp)
  lw    t2, 12(sp)
  lw    a0, 16(sp)
  lw    a1, 20(sp)
  lw    a2, 24(sp)
  lw    a3, 28(sp)
  lw    a4, 32(sp)
  lw    a5, 36(sp)
  lw    a6, 40(sp)
  lw    a7, 44(sp)
  lw    t3, 48(sp)
  lw    t4, 52(sp)
  lw    t5, 56(sp)
  lw    t6, 60(sp)
  addi  sp, sp, 64
  mret
