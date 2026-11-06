/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
/* riscv-tests debug suite programs on ChiliSoC-S (from riscv-tests
 * debug/targets/RISC-V/spike32.lds, BSD-3-Clause). */
OUTPUT_ARCH( "riscv" )

SECTIONS
{
  /* The first 8 KiB of SRAM0 are the OpenOCD work area (chilisocs.cfg);
   * programs follow it.  */
  . = 0x80002000;
  .text :
  {
    *(.text.entry)
    *(.text)
    *(.text.*)
  }

  /* data segment */
  .rodata : { *(.rodata .rodata.*) }

  .data : { *(.data .data.*) }

  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2)
    *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  }

  /* bss segment */
  __bss_start = .;
  .sbss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  }
  .bss : { *(.bss .bss.*) }
  __bss_end = .;

  __malloc_start = .;
  . = . + 512;

  /* End of uninitalized data segement */
  _end = .;
}
