/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
/* ChiliSoC-S :: link script for programs that run from the SPI0 flash (XIP)
 *
 * Code and read-only data in the flash (XIP window), executed in place
 * through SPI0's read lines and the instruction cache. Writable data keeps
 * its place (.sram0_data in SRAM0; data, bss and the stack in SRAM1) but is
 * loaded from the flash: crt0 copies .sram0_data and .data / .sdata from
 * their load addresses in the flash (the __*_load symbols) at start-up.
 * SRAM0 holds only .xip_entry at its base, the jump into the flash: the boot
 * ROM starts every program at SRAM0. sim/run.py --xip, fpga/build.py --xip.
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
  .xip_entry : {
    KEEP(*(.xip_entry))
  } > SRAM0

  .text : {
    *(.text.init)
    *(.text .text.*)
    *(.xip .xip.*)
  } > FLASH

  .rodata : ALIGN(4) {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  } > FLASH

  .sram0_data : ALIGN(4) {
    __sram0_data_start = .;
    *(.sram0_data)
    . = ALIGN(4);
    __sram0_data_end = .;
  } > SRAM0 AT> FLASH
  __sram0_data_load = LOADADDR(.sram0_data);

  .data : ALIGN(4) {
    __data_start = .;
    *(.data .data.*)
  } > SRAM1 AT> FLASH
  __data_load = LOADADDR(.data);

  .sdata : ALIGN(4) {
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
    . = ALIGN(4);
    __data_end = .;
  } > SRAM1 AT> FLASH

  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > SRAM1

  __stack_top = ORIGIN(SRAM1) + LENGTH(SRAM1);
}
