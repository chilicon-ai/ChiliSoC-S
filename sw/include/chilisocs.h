// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
/* ChiliSoC-S :: chilisocs.h -- memory map for software (source/pkg/chilisocs_pkg.sv)
 *
 * Bases of the SoC regions and the PLIC sources; register offsets and
 * fields come from the ChiliMix headers (lib/ChiliMix/sw/include). The
 * values must match chilisocs_pkg: tools/check.py compares them.
 */
#ifndef CHILISOCS_H
#define CHILISOCS_H

#include <stdint.h>

#define DM_BASE     0x00000000u   /* debug module memory (debugger use only) */
#define ROM_BASE    0x00010000u
#define CLINT_BASE  0x02000000u
#define DMA_BASE    0x03000000u   /* channel i at + 0x1000 * i */
#define PLIC_BASE   0x0C000000u
#define SOCCTL_BASE 0x10000000u
#define GPIO_BASE   0x10012000u
#define UART0_BASE  0x10013000u
#define SPI0_BASE   0x10014000u
#define TIMER_BASE  0x10015000u   /* PWM k at + 0x100 * k, watchdog at + 0x400 */
#define I2C0_BASE   0x10016000u
#define XIP_BASE    0x20000000u   /* SPI0 flash window (read-only, 512 MiB) */
#define SRAM0_BASE  0x80000000u
#define SRAM1_BASE  0x80010000u

#define IRQ_UART0 1           /* PLIC source of UART0 */
#define IRQ_GPIO0 2           /* PLIC source of GPIO pin 0; pin i is IRQ_GPIO0 + i */
#define IRQ_PWM0  18          /* PWM k comparator j is IRQ_PWM0 + 4 * k + j */
#define IRQ_WDOG  30          /* watchdog */
#define IRQ_SPI0  31          /* SPI0 watermarks */
#define IRQ_I2C0  32          /* I2C0 */
#define IRQ_DMA0  33          /* DMA channel i done is IRQ_DMA0 + 2 * i, error + 1 */
#define N_IRQ     63          /* PLIC sources */

#define N_DMA_CH  2           /* DMA channels */
#define DMA_CH_BASE(i) (DMA_BASE + 0x1000u * (i))

#define N_PWM     3           /* PWM devices; PWM k comparator j drives GPIO pin 4k + j (IOF1) */
#define PWM_BASE(k) (TIMER_BASE + 0x100u * (k))
#define WDOG_BASE   (TIMER_BASE + 0x400u)

#define SOC_ID 0x5C050700u    /* chilisocs_top SOC_ID default */

/* 32-bit register at base + offset */
#define REG32(base, off) (*(volatile uint32_t *)((base) + (off)))

#endif
