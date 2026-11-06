// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// sim/tb/softfloat_ref.c :: DPI-C reference of the IEEE FP testbenches
// (simulation only): Berkeley SoftFloat 3 with the RISCV specialization
// (tools/softfloat.py links it; sim/tb/softfloat_ref.svh imports these).
//
// fmt: 0 binary16, 1 binary32, 2 binary64; operands and results in the low
// bits of a 64-bit word. rm: 0 RNE, 1 RTZ, 2 RDN, 3 RUP, 4 RMM (SoftFloat's
// numbering). *flags: {NV, DZ, OF, UF, NX} (bit 4 .. 0, SoftFloat's).
// Tininess is detected after rounding. ityp: 0 int32, 1 uint32, 2 int64,
// 3 uint64 (32-bit results sign-extended to 64 bits).
#include <stdint.h>
#ifdef __cplusplus
extern "C" {   // Verilator compiles this file as C++; SoftFloat is C
#endif
#include "softfloat.h"

typedef union { float16_t h; float32_t s; float64_t d; } fp_u;

static fp_u mk(int fmt, uint64_t x) {
  fp_u u;
  if (fmt == 0) u.h.v = (uint16_t)x;
  else if (fmt == 1) u.s.v = (uint32_t)x;
  else u.d.v = x;
  return u;
}

static uint64_t bits(int fmt, fp_u u) {
  return fmt == 0 ? u.h.v : fmt == 1 ? u.s.v : u.d.v;
}

static void start(int rm) {
  softfloat_roundingMode = (uint_fast8_t)rm;
  softfloat_detectTininess = softfloat_tininess_afterRounding;
  softfloat_exceptionFlags = 0;
}

// op: 0 a * b + c, 1 a + b, 2 a - b, 3 a * b, 4 a / b, 5 sqrt(a)
uint64_t sf_arith(int fmt, int op, uint64_t a, uint64_t b, uint64_t c, int rm, int *flags) {
  fp_u x = mk(fmt, a), y = mk(fmt, b), z = mk(fmt, c), r;
  start(rm);
  switch (fmt) {
    case 0:
      r.h = op == 0 ? f16_mulAdd(x.h, y.h, z.h) : op == 1 ? f16_add(x.h, y.h) : op == 2 ? f16_sub(x.h, y.h) :
            op == 3 ? f16_mul(x.h, y.h) : op == 4 ? f16_div(x.h, y.h) : f16_sqrt(x.h);
      break;
    case 1:
      r.s = op == 0 ? f32_mulAdd(x.s, y.s, z.s) : op == 1 ? f32_add(x.s, y.s) : op == 2 ? f32_sub(x.s, y.s) :
            op == 3 ? f32_mul(x.s, y.s) : op == 4 ? f32_div(x.s, y.s) : f32_sqrt(x.s);
      break;
    default:
      r.d = op == 0 ? f64_mulAdd(x.d, y.d, z.d) : op == 1 ? f64_add(x.d, y.d) : op == 2 ? f64_sub(x.d, y.d) :
            op == 3 ? f64_mul(x.d, y.d) : op == 4 ? f64_div(x.d, y.d) : f64_sqrt(x.d);
      break;
  }
  *flags = softfloat_exceptionFlags;
  return bits(fmt, r);
}

// FP to integer (the RISC-V saturating results), exact = 1 (NX when rounded)
uint64_t sf_to_int(int fmt, int ityp, uint64_t a, int rm, int *flags) {
  fp_u x = mk(fmt, a);
  uint64_t r = 0;
  start(rm);
  switch (fmt * 4 + ityp) {
    case 0:  r = (uint64_t)(int64_t)f16_to_i32(x.h, rm, 1); break;
    case 1:  r = (uint64_t)(int64_t)(int32_t)f16_to_ui32(x.h, rm, 1); break;
    case 2:  r = (uint64_t)f16_to_i64(x.h, rm, 1); break;
    case 3:  r = f16_to_ui64(x.h, rm, 1); break;
    case 4:  r = (uint64_t)(int64_t)f32_to_i32(x.s, rm, 1); break;
    case 5:  r = (uint64_t)(int64_t)(int32_t)f32_to_ui32(x.s, rm, 1); break;
    case 6:  r = (uint64_t)f32_to_i64(x.s, rm, 1); break;
    case 7:  r = f32_to_ui64(x.s, rm, 1); break;
    case 8:  r = (uint64_t)(int64_t)f64_to_i32(x.d, rm, 1); break;
    case 9:  r = (uint64_t)(int64_t)(int32_t)f64_to_ui32(x.d, rm, 1); break;
    case 10: r = (uint64_t)f64_to_i64(x.d, rm, 1); break;
    default: r = f64_to_ui64(x.d, rm, 1); break;
  }
  *flags = softfloat_exceptionFlags;
  return r;
}

// integer to FP: a is the integer of type ityp in the low bits
uint64_t sf_from_int(int fmt, int ityp, uint64_t a, int rm, int *flags) {
  fp_u r;
  start(rm);
  switch (fmt * 4 + ityp) {
    case 0:  r.h = i32_to_f16((int32_t)a); break;
    case 1:  r.h = ui32_to_f16((uint32_t)a); break;
    case 2:  r.h = i64_to_f16((int64_t)a); break;
    case 3:  r.h = ui64_to_f16(a); break;
    case 4:  r.s = i32_to_f32((int32_t)a); break;
    case 5:  r.s = ui32_to_f32((uint32_t)a); break;
    case 6:  r.s = i64_to_f32((int64_t)a); break;
    case 7:  r.s = ui64_to_f32(a); break;
    case 8:  r.d = i32_to_f64((int32_t)a); break;
    case 9:  r.d = ui32_to_f64((uint32_t)a); break;
    case 10: r.d = i64_to_f64((int64_t)a); break;
    default: r.d = ui64_to_f64(a); break;
  }
  *flags = softfloat_exceptionFlags;
  return bits(fmt, r);
}

// FP to FP of another format (the same format: a unchanged, no flags)
uint64_t sf_cvt(int from, int to, uint64_t a, int rm, int *flags) {
  fp_u x = mk(from, a), r;
  start(rm);
  switch (from * 3 + to) {
    case 1: r.s = f16_to_f32(x.h); break;
    case 2: r.d = f16_to_f64(x.h); break;
    case 3: r.h = f32_to_f16(x.s); break;
    case 5: r.d = f32_to_f64(x.s); break;
    case 6: r.h = f64_to_f16(x.d); break;
    case 7: r.s = f64_to_f32(x.d); break;
    default: r = x; break;
  }
  *flags = softfloat_exceptionFlags;
  return bits(to, r);
}

#ifdef __cplusplus
}
#endif
