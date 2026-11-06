// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S sim :: runtime.c (see runtime.h)
// -----------------------------------------------------------------------------
#include "runtime.h"

extern volatile uint32_t console;   // crt0.S, .tohost section

// GCC's loop-idiom pass would turn these loops back into calls to themselves.
#define NO_LIBCALL __attribute__((optimize("no-tree-loop-distribute-patterns")))

// -----------------------------------------------------------------------------
// console
// -----------------------------------------------------------------------------
void con_putc(char c)
{
  console = (uint8_t)c;
}

void con_puts(const char *s)
{
  while (*s)
    con_putc(*s++);
}

// pad, then the digits / string; returns characters written
static int emit(const char *s, int len, int width, int left, char pad)
{
  int n = 0;
  if (!left)
    for (; width > len; width--, n++)
      con_putc(pad);
  for (int i = 0; i < len; i++, n++)
    con_putc(s[i]);
  if (left)
    for (; width > len; width--, n++)
      con_putc(' ');
  return n;
}

int con_vprintf(const char *fmt, va_list ap)
{
  int n = 0;
  for (; *fmt; fmt++) {
    if (*fmt != '%') {
      con_putc(*fmt);
      n++;
      continue;
    }
    fmt++;
    int left = 0;
    char pad = ' ';
    for (;; fmt++) {
      if (*fmt == '-')      left = 1;
      else if (*fmt == '0') pad = '0';
      else                  break;
    }
    int width = 0;
    while (*fmt >= '0' && *fmt <= '9')
      width = width * 10 + (*fmt++ - '0');
    while (*fmt == 'l' || *fmt == 'h')   // long and int are both 32 bits
      fmt++;

    char buf[12];                        // 32-bit value: at most 10 digits and a sign
    char *p = buf + sizeof(buf);
    unsigned long v;
    unsigned base = 10;
    int neg = 0;
    const char *digits = "0123456789abcdef";
    switch (*fmt) {
    case 'c':
      buf[0] = (char)va_arg(ap, int);
      n += emit(buf, 1, width, left, ' ');
      continue;
    case 's': {
      const char *s = va_arg(ap, const char *);
      n += emit(s, (int)strlen(s), width, left, ' ');
      continue;
    }
    case 'd':
    case 'i': {
      long d = va_arg(ap, long);
      neg = d < 0;
      v = neg ? -(unsigned long)d : (unsigned long)d;
      break;
    }
    case 'u':
      v = va_arg(ap, unsigned long);
      break;
    case 'X':
      digits = "0123456789ABCDEF";
      /* fall through */
    case 'x':
    case 'p':
      v = (*fmt == 'p') ? (unsigned long)va_arg(ap, void *) : va_arg(ap, unsigned long);
      base = 16;
      break;
    case '%':
      con_putc('%');
      n++;
      continue;
    default:                             // unknown conversion: print it as is
      con_putc('%');
      n++;
      if (!*fmt)
        return n;
      con_putc(*fmt);
      n++;
      continue;
    }
    do {
      *--p = digits[v % base];
      v /= base;
    } while (v);
    if (neg && pad == '0') {             // sign before the zero padding
      con_putc('-');
      n++;
      width--;
    } else if (neg) {
      *--p = '-';
    }
    n += emit(p, (int)(buf + sizeof(buf) - p), width, left, pad);
  }
  return n;
}

int con_printf(const char *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  int n = con_vprintf(fmt, ap);
  va_end(ap);
  return n;
}

// -----------------------------------------------------------------------------
// counters
// -----------------------------------------------------------------------------
uint64_t rd_cycle(void)
{
  uint32_t hi, lo, hi2;
  do {
    __asm__ volatile("csrr %0, cycleh" : "=r"(hi));
    __asm__ volatile("csrr %0, cycle"  : "=r"(lo));
    __asm__ volatile("csrr %0, cycleh" : "=r"(hi2));
  } while (hi != hi2);
  return ((uint64_t)hi << 32) | lo;
}

uint64_t rd_instret(void)
{
  uint32_t hi, lo, hi2;
  do {
    __asm__ volatile("csrr %0, instreth" : "=r"(hi));
    __asm__ volatile("csrr %0, instret"  : "=r"(lo));
    __asm__ volatile("csrr %0, instreth" : "=r"(hi2));
  } while (hi != hi2);
  return ((uint64_t)hi << 32) | lo;
}

// -----------------------------------------------------------------------------
// memory functions
// -----------------------------------------------------------------------------
NO_LIBCALL void *memset(void *d, int c, size_t n)
{
  uint8_t *p = d;
  while (n--)
    *p++ = (uint8_t)c;
  return d;
}

NO_LIBCALL void *memcpy(void *d, const void *s, size_t n)
{
  uint8_t *p = d;
  const uint8_t *q = s;
  while (n--)
    *p++ = *q++;
  return d;
}

NO_LIBCALL void *memmove(void *d, const void *s, size_t n)
{
  uint8_t *p = d;
  const uint8_t *q = s;
  if (p < q) {
    while (n--)
      *p++ = *q++;
  } else {
    while (n--)
      p[n] = q[n];
  }
  return d;
}

int memcmp(const void *a, const void *b, size_t n)
{
  const uint8_t *p = a, *q = b;
  for (; n; n--, p++, q++)
    if (*p != *q)
      return *p - *q;
  return 0;
}

size_t strlen(const char *s)
{
  size_t n = 0;
  while (s[n])
    n++;
  return n;
}
