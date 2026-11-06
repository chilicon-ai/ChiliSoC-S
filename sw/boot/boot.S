/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
// ChiliSoC-S :: boot ROM (ROM_BASE): jump to the program in SRAM0.
//
// The testbench loads this image into the ROM and the program into SRAM0 /
// SRAM1. A later boot ROM will load the program itself (e.g. over UART).
//
// FPGA (the Arty build, fpga/build.py): flash boot. Unless the debugger reset
// the SoC (socctl RST_CAUSE.dbg set: it halts here and loads the program
// itself), a boot image at BOOT_IMAGE in the SPI0 flash window is copied to
// SRAM first. Image (fpga/build.py --program NAME writes NAME.boot.bin):
//   word 0  BOOT_MAGIC        word 1  segment count
//   per segment: address, byte length (a multiple of 4), the words
// No magic: the program in SRAM0 runs, as without FPGA.
  .section .text.init, "ax", @progbits
  .globl _start
_start:
  li    t0, 0x80000000              // SRAM0: the entry (word 0 of the ROM, sw/tests/bus.c reads it)
#ifdef FPGA
  li    t1, 0x10000000              // SOCCTL_BASE
  lw    t2, 0x4(t1)                 // CHILIMIX_SOCCTL_RST_CAUSE_OFFSET
  andi  t2, t2, 0x10                // CHILIMIX_SOCCTL_RST_CAUSE_DBG_MASK
  bnez  t2, 9f
  li    t1, 0x20000000              // XIP_BASE: a first read (the flash may miss the first
  lw    t2, 0(t1)                   //   CCLK edges after configuration, STARTUPE2)
  li    t1, BOOT_IMAGE
  lw    t2, 0(t1)
  li    t3, BOOT_MAGIC
  bne   t2, t3, 9f
  lw    t4, 4(t1)                   // segments
  addi  t1, t1, 8
1:
  beqz  t4, 9f
  lw    a0, 0(t1)                   // address
  lw    a1, 4(t1)                   // bytes
  addi  t1, t1, 8
2:
  beqz  a1, 3f
  lw    a2, 0(t1)
  sw    a2, 0(a0)
  addi  t1, t1, 4
  addi  a0, a0, 4
  addi  a1, a1, -4
  j     2b
3:
  addi  t4, t4, -1
  j     1b
9:
  fence.i                           // the copied code is fetched next
#endif
  jr    t0
