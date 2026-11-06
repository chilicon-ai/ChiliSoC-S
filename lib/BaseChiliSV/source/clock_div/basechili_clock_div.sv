// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_clock_div
//
// Integer clock divider with 50% duty cycle for even and odd divisors:
// clk_out has a period of div clk cycles. tick is a one-cycle pulse once per
// output period (the last clk cycle of it), the clock-enable form of the
// same rate; prefer tick inside the clk domain and use clk_out only where a
// real clock is needed (SPI SCLK, an external pin, a slow clock domain).
//
//   even_hi : first half of an even period (posedge flop)
//   odd_hi  : first ceil(div / 2) cycles of an odd period (posedge flop)
//   hi_neg  : odd_hi half a cycle later (negedge flop)
//   clk_out = even_hi | (odd_hi & hi_neg)   (odd: high for div / 2 cycles)
//
// Each term changes on one clock edge while the other is stable low, and
// even_hi and odd_hi are never high in the same period, so clk_out cannot
// glitch, also when the divisor's parity changes between periods.
//
// div is sampled at the end of each output period, so a new value starts
// with the next period. Values below 2 act as 2. After reset clk_out is high
// (the first half of a 2-cycle period), and the first period is always 2
// cycles long.
//
// Timing    : clk_out comes from flops on both clk edges through an AND-OR;
//             tick is combinational from the count.
// Invariants: cnt < div_q; tick == (cnt == div_q - 1); even_hi and odd_hi
//             are never both high.
// Debug     : wrong frequency -> div_q (u_div.q) and cnt (u_cnt.count);
//             wrong duty on odd divisors -> odd_hi and hi_neg (u_hi_neg.q).
// -----------------------------------------------------------------------------
module basechili_clock_div #(
  parameter int W = 8          // divisor bits (div up to 2**W - 1)
) (
  input  logic         clk,
  input  logic         rst_n,     // async, active-low
  input  logic [W-1:0] div,       // divisor, >= 2
  output logic         clk_out,   // clk / div, 50% duty
  output logic         tick       // last clk cycle of each clk_out period
);

  localparam logic [W-1:0] TWO = W'(2);

  logic         clk_n;      // inverted clk for the negedge flop
  logic [W-1:0] div_eff;    // div, at least 2
  logic [W-1:0] div_q;      // divisor of the current period
  logic [W-1:0] div_d;      // divisor of the next cycle's period
  logic [W-1:0] cnt;        // clk cycle within the period
  logic [W-1:0] cnt_d;      // next cnt
  logic [W-1:0] half_d;     // high cycles of the next cycle's period
  logic         hi_d;       // next cycle is in the first half of its period
  logic         even_hi_d;  // next even_hi
  logic         odd_hi_d;   // next odd_hi
  logic         even_hi;    // first half of an even period
  logic         odd_hi;     // first ceil(div / 2) cycles of an odd period
  logic         hi_neg;     // odd_hi half a cycle later (negedge)

  assign div_eff  = (div < TWO) ? TWO : div;
  assign tick     = cnt == div_q - 1'b1;
  assign div_d    = tick ? div_eff : div_q;
  assign half_d   = (div_d >> 1) + W'(div_d[0]);
  assign hi_d      = cnt_d < half_d;
  assign even_hi_d = hi_d && !div_d[0];
  assign odd_hi_d  = hi_d && div_d[0];

  basechili_updown_counter #(.WIDTH(W)) u_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (tick),
    .load_val ('0),
    .inc      (1'b1),
    .dec      (1'b0),
    .count    (cnt),
    .count_d  (cnt_d)
  );

  basechili_dff #(.WIDTH(W), .RESET_VAL(TWO)) u_div (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (div_d),
    .q     (div_q)
  );

  basechili_dff #(.WIDTH(1), .RESET_VAL(1'b1)) u_even_hi (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (even_hi_d),
    .q     (even_hi)
  );

  basechili_dff #(.WIDTH(1)) u_odd_hi (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (odd_hi_d),
    .q     (odd_hi)
  );

  assign clk_n = ~clk;

  basechili_dff #(.WIDTH(1)) u_hi_neg (
    .clk   (clk_n),
    .rst_n (rst_n),
    .d     (odd_hi),
    .q     (hi_neg)
  );

  assign clk_out = even_hi || (odd_hi && hi_neg);

endmodule
