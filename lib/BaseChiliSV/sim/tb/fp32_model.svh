// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim/tb/fp32_model.svh :: binary32 reference model for the basechili_fp32_*
// testbenches (simulation only), written from the profile and algorithm
// texts in the RTL headers, independent of the RTL:
//   m_add / m_mul    binary64 (real) arithmetic, then one rounding to binary32
//                    (exact for a product, and correctly rounded for a sum
//                    since 53 >= 2 * 24 + 2); DAZ, FTZ, canonical NaN
//   m_from_int / m_to_int   integer conversions with integer arithmetic
//   m_exp / m_log / m_rsqrt / m_recip   the fixed algorithms step by step,
//                    their constants and tables computed here from $ln,
//                    $sqrt and ** in binary64
//   m_rand           random binary32 patterns biased to edge cases
// -----------------------------------------------------------------------------
`ifndef BASECHILI_FP32_MODEL_SVH
`define BASECHILI_FP32_MODEL_SVH

localparam logic [31:0] M_CNAN = 32'h7fc00000;
localparam logic [31:0] M_PINF = 32'h7f800000;

function automatic logic [31:0] m_daz(logic [31:0] a);
  return a[30:23] == 8'd0 ? {a[31], 31'd0} : a;
endfunction

function automatic logic m_is_nan(logic [31:0] a);
  return a[30:23] == 8'hff && a[22:0] != 23'd0;
endfunction

function automatic logic [31:0] m_neg(logic [31:0] a);
  return {~a[31], a[30:0]};
endfunction

// binary32 (after DAZ) as a real
function automatic real m_real(logic [31:0] a);
  logic [31:0] b;
  logic [10:0] e;
  b = m_daz(a);
  if (b[30:0] == 31'd0) return $bitstoreal({b[31], 63'd0});
  e = b[30:23] == 8'hff ? 11'h7ff : 11'(int'(b[30:23]) - 127 + 1023);
  return $bitstoreal({b[31], e, b[22:0], 29'd0});
endfunction

// a real to binary32: nearest even at 24 bits, then overflow to inf and FTZ below 2**-126
function automatic logic [31:0] m_round(real r);
  logic [63:0] d;
  int          e;
  logic [24:0] m;
  d = $realtobits(r);
  if (d[62:52] == 11'h7ff) return d[51:0] != 52'd0 ? M_CNAN : {d[63], 8'hff, 23'd0};
  if (d[62:52] == 11'd0) return {d[63], 31'd0};
  e = int'(d[62:52]) - 1023;
  m = {2'b01, d[51:29]};
  if (d[28] && (d[27:0] != 28'd0 || m[0])) m = m + 25'd1;
  if (m[24]) begin
    m = m >> 1;
    e = e + 1;
  end
  if (e > 127) return {d[63], 8'hff, 23'd0};
  if (e < -126) return {d[63], 31'd0};
  return {d[63], 8'(e + 127), m[22:0]};
endfunction

function automatic logic [31:0] m_add(logic [31:0] a, logic [31:0] b);
  return m_round(m_real(a) + m_real(b));
endfunction

function automatic logic [31:0] m_mul(logic [31:0] a, logic [31:0] b);
  return m_round(m_real(a) * m_real(b));
endfunction

// y * 2**k, exact unless it overflows or flushes
function automatic logic [31:0] m_scale(logic [31:0] y, int k);
  return m_round(m_real(y) * (2.0 ** k));
endfunction

// signed integer (sign-extended to 64 bits) to binary32, nearest even
function automatic logic [31:0] m_from_int(longint v);
  logic [63:0] mag;
  logic [63:0] q;
  logic [63:0] rem;
  int          nb;
  int          sh;
  int          e;
  if (v == 0) return 32'd0;
  mag = v < 0 ? 64'(-v) : 64'(v);
  nb = 0;
  for (int i = 0; i < 64; i++) if (mag[i]) nb = i + 1;
  e = nb - 1;
  if (nb <= 24) begin
    q = mag << (24 - nb);
  end else begin
    sh  = nb - 24;
    q   = mag >> sh;
    rem = mag & ((64'd1 << sh) - 64'd1);
    if (rem > (64'd1 << (sh - 1)) || (rem == (64'd1 << (sh - 1)) && q[0])) q = q + 64'd1;
    if (q[24]) begin
      q = q >> 1;
      e = e + 1;
    end
  end
  return {v < 0, 8'(e + 127), q[22:0]};
endfunction

// binary32 to int<w>: nearest even, saturate, NaN to 0
function automatic longint m_to_int(logic [31:0] a, int w);
  real    x;
  real    fl;
  real    r;
  real    hi;
  if (m_is_nan(a)) return 0;
  x  = m_real(a);
  hi = 2.0 ** (w - 1);
  if (x >= hi) return (longint'(1) <<< (w - 1)) - 1;
  if (x <= -hi) return -(longint'(1) <<< (w - 1));
  fl = $floor(x);
  r  = fl;
  if (x - fl > 0.5 || (x - fl == 0.5 && fl - 2.0 * $floor(fl / 2.0) == 1.0)) r = fl + 1.0;
  if (r >= hi) return (longint'(1) <<< (w - 1)) - 1;
  return longint'(r);
endfunction

// ---- function constants and tables ----
function automatic logic [31:0] m_rn(real v);
  return m_round(v);
endfunction

// v truncated to its leading nb significant bits
function automatic logic [31:0] m_trunc(real v, int nb);
  logic [63:0] d;
  d = $realtobits(v);
  d = d & ~((64'd1 << (53 - nb)) - 64'd1);
  return m_round($bitstoreal(d));
endfunction

function automatic real m_ln2();
  return $ln(2.0);
endfunction

function automatic logic [31:0] m_exp_t(int j);
  return m_rn(2.0 ** (real'(j) / 64.0));
endfunction

function automatic logic [31:0] m_log_r(int k);
  return m_rn(128.0 / real'(k));
endfunction

function automatic logic [31:0] m_log_l(int k);
  if (k == 128 || k == 256) return 32'd0;
  return m_rn($ln(real'(k) / (k < 182 ? 128.0 : 256.0)));
endfunction

function automatic logic [31:0] m_rsqrt_t(int odd, int i);
  return m_rn(1.0 / $sqrt((1.0 + real'(2 * i + 1) / 128.0) * (odd != 0 ? 2.0 : 1.0)));
endfunction

function automatic logic [31:0] m_recip_t(int i);
  return m_rn(1.0 / (1.0 + real'(2 * i + 1) / 128.0));
endfunction

// ---- the functions ----
function automatic logic [31:0] m_exp(logic [31:0] a);
  logic [31:0] x, c_inv, c_hi, c_lo, c3, t, nf, r, q, p, tj;
  longint      n;
  x = m_daz(a);
  if (m_is_nan(x)) return M_CNAN;
  if (m_real(x) > 89.0) return M_PINF;
  if (m_real(x) < -104.0) return 32'd0;
  c_inv = m_rn(64.0 / m_ln2());
  c_hi  = m_trunc(m_ln2() / 64.0, 10);
  c_lo  = m_rn(m_ln2() / 64.0 - m_real(c_hi));
  c3    = m_rn(1.0 / 6.0);
  t  = m_mul(x, c_inv);
  n  = m_to_int(t, 32);
  nf = m_from_int(n);
  r  = m_add(x, m_neg(m_mul(nf, c_hi)));
  r  = m_add(r, m_neg(m_mul(nf, c_lo)));
  q  = m_add(m_mul(r, c3), 32'h3f000000);
  q  = m_mul(m_mul(q, r), r);
  p  = m_add(q, r);
  tj = m_exp_t(int'(n & 63));
  return m_scale(m_add(tj, m_mul(tj, p)), int'(n >>> 6));
endfunction

function automatic logic [31:0] m_log(logic [31:0] a);
  logic [31:0] x, m, c, d, r, q, y, ef, ln2_hi, ln2_lo, c3;
  int          e, k, mant;
  x = m_daz(a);
  if (m_is_nan(x) || (x[31] && x[30:0] != 31'd0)) return M_CNAN;
  if (x[30:0] == 31'd0) return 32'hff800000;
  if (x == M_PINF) return M_PINF;
  ln2_hi = m_trunc(m_ln2(), 16);
  ln2_lo = m_rn(m_ln2() - m_real(ln2_hi));
  c3     = m_rn(1.0 / 3.0);
  e    = int'(x[30:23]) - 127;
  mant = int'(x[22:0]);
  m    = {9'h07f, x[22:0]};
  k    = 128 + ((mant + (1 << 15)) >> 16);
  c    = m_rn(real'(k) / 128.0);
  d    = m_add(m, m_neg(c));
  r    = m_mul(d, m_log_r(k));
  q    = m_add(m_mul(r, c3), 32'hbf000000);
  q    = m_mul(m_mul(q, r), r);
  y    = m_add(m_log_l(k), m_add(q, r));
  ef   = m_from_int(longint'(e + (k >= 182 ? 1 : 0)));
  return m_add(m_mul(ef, ln2_hi), m_add(y, m_mul(ef, ln2_lo)));
endfunction

function automatic logic [31:0] m_rsqrt(logic [31:0] a);
  logic [31:0] x, m, h, y;
  int          e, odd;
  x = m_daz(a);
  if (m_is_nan(x) || (x[31] && x[30:0] != 31'd0)) return M_CNAN;
  if (x[30:0] == 31'd0) return {x[31], 8'hff, 23'd0};
  if (x == M_PINF) return 32'd0;
  e   = int'(x[30:23]) - 127;
  odd = e & 1;
  m   = {9'h07f, x[22:0]};
  h   = m_scale(m, odd - 1);
  y   = m_rsqrt_t(odd, int'(x[22:17]));
  for (int i = 0; i < 2; i++)
    y = m_mul(y, m_add(32'h3fc00000, m_neg(m_mul(m_mul(y, y), h))));
  return m_scale(y, -((e - odd) / 2));
endfunction

function automatic logic [31:0] m_recip(logic [31:0] a);
  logic [31:0] x, m, y;
  int          e;
  x = m_daz(a);
  if (m_is_nan(x)) return M_CNAN;
  if (x[30:0] == 31'd0) return {x[31], 8'hff, 23'd0};
  if (x[30:0] == M_PINF[30:0]) return {x[31], 31'd0};
  e = int'(x[30:23]) - 127;
  m = {9'h07f, x[22:0]};
  y = m_recip_t(int'(x[22:17]));
  for (int i = 0; i < 2; i++)
    y = m_mul(y, m_add(32'h40000000, m_neg(m_mul(m, y))));
  y = m_scale(y, -e);
  return {x[31] ^ y[31], y[30:0]};
endfunction

// ulp distance of two finite binary32 values of the same sign
function automatic int m_ulps(logic [31:0] a, logic [31:0] b);
  return a[30:0] > b[30:0] ? int'(a[30:0] - b[30:0]) : int'(b[30:0] - a[30:0]);
endfunction

// ---- stimulus ----
function automatic logic [31:0] m_special();
  case ($urandom % 10)
    0: return 32'd0;
    1: return 32'h80000000;
    2: return M_PINF;
    3: return 32'hff800000;
    4: return {1'($urandom), 8'hff, 23'($urandom | 1)};               // NaN
    5: return {1'($urandom), 8'h00, 23'($urandom)};                   // subnormal
    6: return {1'($urandom), 8'h01, 23'($urandom)};                   // smallest normals
    7: return {1'($urandom), 8'hfe, 23'($urandom)};                   // largest normals
    8: return {1'($urandom), 8'h7f, 23'h7fffff};
    default: return {1'($urandom), 8'h7f, 23'd0};
  endcase
endfunction

// a random binary32: specials, any exponent, or an exponent within win of centre
function automatic logic [31:0] m_rand(int centre, int win);
  logic [22:0] f;
  int          e;
  case ($urandom % 4)
    0: f = 23'($urandom);
    1: f = 23'($urandom) | 23'h7ffff0;
    2: f = 23'($urandom) & 23'h00000f;
    default: f = 23'($urandom) & ~(23'h1 << ($urandom % 23));
  endcase
  case ($urandom % 8)
    0: return m_special();
    1: e = 1 + int'($urandom % 254);
    default: e = centre - win + int'($urandom % (2 * win + 1));
  endcase
  if (e < 1) e = 1;
  if (e > 254) e = 254;
  return {1'($urandom), 8'(e), f};
endfunction

`endif
