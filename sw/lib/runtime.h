// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S sw :: runtime.h (C runtime for programs on chilisocs_top)
//
// Console on UART0 (8N1 at divisor UART_DIV, read back by the
// testbench), a small printf, the Zicntr counters, traps, and the
// freestanding memory functions GCC may call. The printf and memory
// functions follow ChillU-S's sim runtime (lib/chillus/sim/sw), so ChillU-S's
// CoreMark port builds against this file unchanged.
// -----------------------------------------------------------------------------
#ifndef CHILISOCS_RUNTIME_H
#define CHILISOCS_RUNTIME_H

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

#include "chilisocs.h"

#ifndef UART_DIV              // -DUART_DIV=27 on the Arty at 50 MHz: 115200 baud (fpga/README.md)
#define UART_DIV 1            // UART0 divisor: one bit = 16 * UART_DIV clk cycles
#endif

void uart_init(void);         // crt0.S calls it before main
// console: UART0
void con_putc(char c);
void con_puts(const char *s);
// printf subset: %c %s %d %i %u %x %X %p %%, flags '-' '0', width, 'l' / 'h'
int  con_vprintf(const char *fmt, va_list ap);
int  con_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

// Zicntr counters, 64 bits (high / low / high re-read)
uint64_t rd_cycle(void);
uint64_t rd_instret(void);

// end the program: prints "*** PASS" (code 0) or "*** FAIL <code>", waits
// until UART0 has sent it, then spins; the testbench stops on that line
void exit(int code) __attribute__((noreturn));

// trap_handler(mcause, mepc, frame) returns the mepc to resume at. Without a
// hook every trap ends the program with FAIL 0x400 + mcause (interrupts:
// 0x800 + cause). frame[0] is the trapped code's ra.
typedef uint32_t (*trap_hook_t)(uint32_t mcause, uint32_t mepc, uint32_t *frame);
extern trap_hook_t trap_hook;
uint32_t trap_handler(uint32_t mcause, uint32_t mepc, uint32_t *frame);

void *memset(void *d, int c, size_t n);
void *memcpy(void *d, const void *s, size_t n);
void *memmove(void *d, const void *s, size_t n);
int   memcmp(const void *a, const void *b, size_t n);
size_t strlen(const char *s);

#endif
