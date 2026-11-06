// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S :: chilisocs_pkg
//
// The SoC memory map and interrupt numbers (SiFive FE310 layout where one
// exists). Region i of the AHB / APB decoders matches (addr & *_MASK) ==
// *_BASE; a memory smaller than its region repeats inside it. Software sees
// the same values in sw/include/chilisocs.h (tools/check.py compares them).
//
//   region   base          size     bus
//   DM       0x0000_0000    4 KiB   AHB, I and D (chilimix_debug memory)
//   ROM      0x0001_0000   64 KiB   AHB, I and D (boot ROM, read-only)
//   CLINT    0x0200_0000   64 KiB   APB (chilimix_aclint)
//   DMA      0x0300_0000   16 KiB   APB (chilimix_dma, channel i at + 0x1000 * i)
//   PLIC     0x0C00_0000    4 MiB   APB (chilimix_plic)
//   SOCCTL   0x1000_0000    4 KiB   APB (chilimix_socctl)
//   GPIO     0x1001_2000    4 KiB   APB (chilimix_gpio)
//   UART0    0x1001_3000    4 KiB   APB (chilimix_uart, ns16550a)
//   SPI0     0x1001_4000    4 KiB   APB (chilimix_spi registers)
//   TIMER    0x1001_5000    4 KiB   APB (chilimix_timer: PWM k at + 0x100 * k,
//                                   watchdog at + 0x400)
//   I2C0     0x1001_6000    4 KiB   APB (chilimix_i2c)
//   XIP      0x2000_0000  512 MiB   AHB, I and D (SPI0 flash window, read-only)
//   SRAM0    0x8000_0000   64 KiB   AHB, I and D (code)
//   SRAM1    0x8001_0000   64 KiB   AHB, D only (data, stack)
//
// The debug module's ROM (halt entry 0x800, exception entry 0x808) and
// data sit in DM; the debugger's system bus access reaches everything the
// D bus reaches, and so does the DMA engine (a third manager of the D
// bus). Every other address gets an AHB ERROR (fetch / load / store access fault);
// inside the APB windows (0x0200_0000 + 64 KiB, 0x0300_0000 + 64 KiB,
// 0x0C00_0000 + 4 MiB, 0x1000_0000 + 1 MiB) an
// address no peripheral claims gets PSLVERR, the same fault.
// -----------------------------------------------------------------------------
package chilisocs_pkg;

  // AHB regions
  localparam logic [31:0] DM_BASE     = 32'h0000_0000;   // debug module: ROM at + 0x800
  localparam logic [31:0] DM_MASK     = 32'hFFFF_F000;
  localparam logic [31:0] ROM_BASE    = 32'h0001_0000;
  localparam logic [31:0] ROM_MASK    = 32'hFFFF_0000;
  localparam logic [31:0] SRAM0_BASE  = 32'h8000_0000;
  localparam logic [31:0] SRAM0_MASK  = 32'hFFFF_0000;
  localparam logic [31:0] SRAM1_BASE  = 32'h8001_0000;
  localparam logic [31:0] SRAM1_MASK  = 32'hFFFF_0000;
  localparam logic [31:0] XIP_BASE    = 32'h2000_0000;   // SPI0 flash, read-only
  localparam logic [31:0] XIP_MASK    = 32'hE000_0000;
  // AHB windows of the APB bridge
  localparam logic [31:0] APBW0_BASE  = 32'h0200_0000;   // CLINT
  localparam logic [31:0] APBW0_MASK  = 32'hFFFF_0000;
  localparam logic [31:0] APBW1_BASE  = 32'h0C00_0000;   // PLIC
  localparam logic [31:0] APBW1_MASK  = 32'hFFC0_0000;
  localparam logic [31:0] APBW2_BASE  = 32'h1000_0000;   // peripherals
  localparam logic [31:0] APBW2_MASK  = 32'hFFF0_0000;
  localparam logic [31:0] APBW3_BASE  = 32'h0300_0000;   // DMA
  localparam logic [31:0] APBW3_MASK  = 32'hFFFF_0000;
  localparam int          N_APBW      = 4;

  // APB regions
  localparam logic [31:0] CLINT_BASE  = 32'h0200_0000;
  localparam logic [31:0] CLINT_MASK  = 32'hFFFF_0000;
  localparam logic [31:0] PLIC_BASE   = 32'h0C00_0000;
  localparam logic [31:0] PLIC_MASK   = 32'hFFC0_0000;
  localparam logic [31:0] SOCCTL_BASE = 32'h1000_0000;
  localparam logic [31:0] SOCCTL_MASK = 32'hFFFF_F000;
  localparam logic [31:0] GPIO_BASE   = 32'h1001_2000;
  localparam logic [31:0] GPIO_MASK   = 32'hFFFF_F000;
  localparam logic [31:0] UART0_BASE  = 32'h1001_3000;
  localparam logic [31:0] UART0_MASK  = 32'hFFFF_F000;
  localparam logic [31:0] TIMER_BASE  = 32'h1001_5000;
  localparam logic [31:0] TIMER_MASK  = 32'hFFFF_F000;
  localparam logic [31:0] SPI0_BASE   = 32'h1001_4000;
  localparam logic [31:0] SPI0_MASK   = 32'hFFFF_F000;
  localparam logic [31:0] I2C0_BASE   = 32'h1001_6000;
  localparam logic [31:0] I2C0_MASK   = 32'hFFFF_F000;
  localparam logic [31:0] DMA_BASE    = 32'h0300_0000;
  localparam logic [31:0] DMA_MASK    = 32'hFFFF_C000;

  // PLIC sources (1 .. N_IRQ): UART0, one per GPIO pin (at most 16), one per
  // PWM comparator (PWM k comparator j at IRQ_PWM0 + 4 * k + j), the
  // watchdog, SPI0, I2C0, two per DMA channel (channel i done at
  // IRQ_DMA0 + 2 * i, error at IRQ_DMA0 + 2 * i + 1, the FU540 order)
  localparam int IRQ_UART0 = 1;
  localparam int IRQ_GPIO0 = 2;
  localparam int IRQ_PWM0  = 18;
  localparam int IRQ_WDOG  = 30;
  localparam int IRQ_SPI0  = 31;
  localparam int IRQ_I2C0  = 32;
  localparam int IRQ_DMA0  = 33;
  localparam int N_IRQ     = 63;   // chilimix_plic sources

  // chilimix_dma channels
  localparam int N_DMA_CH = 2;

  // chilimix_timer PWM devices (4 comparators each, outputs on GPIO IOF1)
  localparam int N_PWM = 3;

  // reset domains of chilimix_socctl, released in this order
  localparam int DOM_BUS = 0;   // fabric, memories, peripherals
  localparam int DOM_CPU = 1;   // ChillU-S
  localparam int N_DOM   = 2;

  // JTAG IDCODE of the debug TAP (bit 0 = 1; version 0, part 0x5C05, no
  // JEDEC manufacturer yet)
  localparam logic [31:0] JTAG_IDCODE = 32'h05C0_5001;

endpackage
