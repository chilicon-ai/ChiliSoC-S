/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
/* ChiliSoC-S :: link script for programs (sw/lib runtime)
 *
 * Code and read-only data in SRAM0 (I and D buses), data, bss and the stack
 * in SRAM1 (D bus only). The testbench loads both images, so there is no
 * copy from a load address. .sram0_data: writable data placed in SRAM0
 * (e.g. code written by the D bus and then executed). .xip: code and
 * read-only data in the SPI0 flash (XIP window), loaded into the
 * testbench's flash model. The __*_load symbols equal the start symbols
 * (nothing to copy; crt0's copy loops are for sw/lib/link_xip.ld).
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  SRAM0 (rwx) : ORIGIN = 0x80000000, LENGTH = 64K
  SRAM1 (rw)  : ORIGIN = 0x80010000, LENGTH = 64K
  FLASH (rx)  : ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text .text.*)
  } > SRAM0

  .rodata : ALIGN(4) {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  } > SRAM0

  .sram0_data : ALIGN(4) {
    __sram0_data_start = .;
    *(.sram0_data)
    . = ALIGN(4);
    __sram0_data_end = .;
  } > SRAM0
  __sram0_data_load = LOADADDR(.sram0_data);

  .xip : ALIGN(4) {
    *(.xip .xip.*)
  } > FLASH

  .data : ALIGN(4) {
    __data_start = .;
    *(.data .data.*)
  } > SRAM1
  __data_load = LOADADDR(.data);

  .sdata : ALIGN(4) {
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
    . = ALIGN(4);
    __data_end = .;
  } > SRAM1

  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > SRAM1

  /DISCARD/ : { *(.xip_entry) }   /* link_xip.ld's jump into the flash */

  __stack_top = ORIGIN(SRAM1) + LENGTH(SRAM1);
}
