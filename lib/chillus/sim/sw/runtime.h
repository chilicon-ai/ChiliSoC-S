// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S sim :: runtime.h (C runtime for chillus_tb and Spike, see crt0.S)
//
// Console output (chillus_tb +console), a small printf, the Zicntr counters
// and the freestanding memory functions GCC may call.
// -----------------------------------------------------------------------------
#ifndef CHILLUS_RUNTIME_H
#define CHILLUS_RUNTIME_H

#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

// console: one character per store
void con_putc(char c);
void con_puts(const char *s);
// printf subset: %c %s %d %i %u %x %X %p %%, flags '-' '0', width, 'l' / 'h'
int  con_vprintf(const char *fmt, va_list ap);
int  con_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

// Zicntr counters, 64 bits (high / low / high re-read for XLEN 32)
uint64_t rd_cycle(void);
uint64_t rd_instret(void);

// end the test: exit code 0 = PASS (crt0.S)
void exit(int code) __attribute__((noreturn));

void *memset(void *d, int c, size_t n);
void *memcpy(void *d, const void *s, size_t n);
void *memmove(void *d, const void *s, size_t n);
int   memcmp(const void *a, const void *b, size_t n);
size_t strlen(const char *s);

#endif
