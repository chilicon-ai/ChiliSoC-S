// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_wide_counter -- exact count model: inc adds one,
// load[w] replaces word w and wins over inc (no increment that cycle).
// Loads put the low part at or just below all ones (and the high part at
// all ones) so low and full wraps happen often; random word masks give
// high-only, low-only and partial loads.
`include "tb_common.svh"
module basechili_wide_counter_tb #(
  parameter  int WIDTH  = 64,
  parameter  int LO_W   = 32,
  parameter  int WORD_W = 32,
  localparam int N_WORD = WIDTH / WORD_W
);
  `TB_CLOCK_RESET
  logic              inc;
  logic [N_WORD-1:0] load;
  logic [WIDTH-1:0]  load_val, count, exp_c;
  int                lo_wraps, hi_wraps;   // wraps seen (stimulus sanity)

  basechili_wide_counter #(.WIDTH(WIDTH), .LO_W(LO_W), .WORD_W(WORD_W)) dut (
    .clk, .rst_n, .inc, .load, .load_val, .count);

  function automatic logic [WIDTH-1:0] rnd();
    logic [WIDTH-1:0] v;
    for (int b = 0; b < WIDTH; b++) v[b] = 1'($urandom);
    return v;
  endfunction

  // load value: random, or low part all ones minus 0..3, high part random / all ones
  function automatic logic [WIDTH-1:0] pick();
    logic [WIDTH-1:0] v;
    logic [LO_W-1:0]  lo;
    int               k;
    v = rnd();
    case ($urandom % 6)
      0, 1: ;
      default: begin
        k  = $urandom % 4;
        lo = '1;
        lo = lo - LO_W'(k);
        v[LO_W-1:0] = lo;
        if ($urandom % 3 == 0) v[WIDTH-1:LO_W] = '1;
      end
    endcase
    return v;
  endfunction

  initial begin
    inc = 1'b0; load = '0; load_val = '0;
    lo_wraps = 0; hi_wraps = 0;
    tb_reset();
    exp_c = '0;
    for (int t = 0; t < 20000; t++) begin
      `CHECK(count == exp_c, $sformatf("count=%h expected %h", count, exp_c))
      inc      = ((t / 1000) % 4 == 3) ? 1'($urandom) : ($urandom % 8 != 0);
      load     = ($urandom % 6 == 0) ? N_WORD'($urandom) : '0;
      if (t < 40) load = (t % 8 == 0) ? '1 : '0;   // early full loads near the wrap
      load_val = pick();
      if (t == 15000) begin   // async reset mid-run
        rst_n = 1'b0; #1;
        `CHECK(count == '0, "reset value")
        exp_c = '0;
        @(negedge clk); rst_n = 1'b1;
      end
      @(posedge clk); #1;
      if (|load) begin
        for (int b = 0; b < WIDTH; b++) if (load[b / WORD_W]) exp_c[b] = load_val[b];
      end else if (inc) begin
        if (&exp_c[LO_W-1:0]) lo_wraps++;
        if (&exp_c) hi_wraps++;
        exp_c = exp_c + 1'b1;
      end
      @(negedge clk);
    end
    `CHECK(lo_wraps > 100 && hi_wraps > 10, $sformatf("too few wraps: %0d low, %0d full", lo_wraps, hi_wraps))
    tb_pass();
  end
endmodule
