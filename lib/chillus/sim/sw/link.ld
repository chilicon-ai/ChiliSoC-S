/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
/* ChillU-S sim :: link script for C programs (sim/sw runtime)
 *
 * One RAM region at 0x80000000 (chillus_tb memory: 1 MiB; Spike: 2 GiB), code
 * and data in place (no copy), stack at the top of the 1 MiB.
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 1M
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text .text.*)
  } > RAM

  .rodata : ALIGN(4) {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  } > RAM

  .data : ALIGN(4) {
    *(.data .data.*)
  } > RAM

  .sdata : ALIGN(4) {
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
  } > RAM

  .tohost : ALIGN(64) {
    *(.tohost)
  } > RAM

  .bss (NOLOAD) : ALIGN(4) {
    __bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > RAM

  __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
