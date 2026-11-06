/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 Chilicon */
/* ChiliSoC-S :: boot ROM link script */
OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY { ROM (rx) : ORIGIN = 0x00010000, LENGTH = 4K }
SECTIONS { .text : { *(.text.init) *(.text .text.*) } > ROM }
