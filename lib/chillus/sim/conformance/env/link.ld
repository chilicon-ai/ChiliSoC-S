/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
/* ChillU-S architectural tests: 4 MiB RAM at 0x8000_0000 (chillus_tb
   MEM_WORDS = act_lib.MEM_WORDS, Sail and Spike configured to match; some
   tests, e.g. I/jal-01, need more than the default 1 MiB);
   rvtest_entry_point at the reset pc. */
OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 4M
}

SECTIONS
{
  .text.init : { *(.text.init) } > RAM
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) } > RAM
  . = ALIGN(0x1000);
  .text : { *(.text) } > RAM
  . = ALIGN(0x1000);
  .data : { *(.data) } > RAM
  .data.string : { *(.data.string) } > RAM
  .bss : { *(.bss) } > RAM
  _end = .;
}
