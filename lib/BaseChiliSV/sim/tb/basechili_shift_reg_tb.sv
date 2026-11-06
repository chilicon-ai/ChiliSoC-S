// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_shift_reg -- reference model for the configured
// direction: load wins over shift, shift_out is the output-end bit, reset
// value; random and long shift-only / load-only phases.
`include "tb_common.svh"
module basechili_shift_reg_tb #(
  parameter int               WIDTH     = 8,
  parameter bit               MSB_FIRST = 1'b0,
  parameter logic [WIDTH-1:0] RESET_VAL = '0
);
  `TB_CLOCK_RESET
  logic             load, shift, shift_in, shift_out;
  logic [WIDTH-1:0] load_val, q, exp_q;

  basechili_shift_reg #(.WIDTH(WIDTH), .MSB_FIRST(MSB_FIRST), .RESET_VAL(RESET_VAL)) dut (
    .clk, .rst_n, .load, .load_val, .shift, .shift_in, .q, .shift_out);

  function automatic logic [WIDTH-1:0] rnd();
    logic [WIDTH-1:0] v;
    for (int b = 0; b < WIDTH; b++) v[b] = 1'($urandom);
    return v;
  endfunction

  function automatic logic [WIDTH-1:0] shifted(logic [WIDTH-1:0] v, logic b);
    logic [WIDTH-1:0] r;
    if (WIDTH == 1) r = b;
    else if (MSB_FIRST) r = (v << 1) | WIDTH'(b);
    else r = (v >> 1) | (WIDTH'(b) << (WIDTH - 1));
    return r;
  endfunction

  initial begin
    load = 1'b0; shift = 1'b0; shift_in = 1'b0; load_val = '0;
    tb_reset();
    exp_q = RESET_VAL;
    for (int t = 0; t < 10000; t++) begin
      int ph;
      `CHECK(q == exp_q && shift_out == (MSB_FIRST ? exp_q[WIDTH-1] : exp_q[0]),
             $sformatf("q=%h shift_out=%b expected %h", q, shift_out, exp_q))
      ph = (t / 300) % 4;   // phases: random, shift-only, load-heavy, all-ones / zeros
      load     = (ph == 1) ? 1'b0 : (ph == 2) ? ($urandom % 4 != 0) : ($urandom % 8 == 0);
      shift    = (ph == 1) ? 1'b1 : 1'($urandom);
      shift_in = (ph == 3) ? ((t / 37) % 2 == 0) : 1'($urandom);
      load_val = (ph == 3) ? (((t / 50) % 2 == 0) ? '1 : '0) : rnd();
      if (t == 9000) begin   // async reset mid-run
        rst_n = 1'b0; #1;
        `CHECK(q == RESET_VAL, "reset value")
        exp_q = RESET_VAL;
        @(negedge clk); rst_n = 1'b1;
      end
      @(posedge clk); #1;
      if (load) exp_q = load_val;
      else if (shift) exp_q = shifted(exp_q, shift_in);
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
