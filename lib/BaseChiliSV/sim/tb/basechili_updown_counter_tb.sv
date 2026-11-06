// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_updown_counter -- load > inc/dec, both hold, wraps.
`include "tb_common.svh"
module basechili_updown_counter_tb #(
  parameter int               WIDTH     = 8,
  parameter logic [WIDTH-1:0] RESET_VAL = '0
);
  `TB_CLOCK_RESET
  logic             load, inc, dec;
  logic [WIDTH-1:0] load_val, count, count_d, exp_c;

  basechili_updown_counter #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) dut (.clk, .rst_n, .load, .load_val, .inc, .dec, .count, .count_d);

  initial begin
    load = 1'b0; inc = 1'b0; dec = 1'b0; load_val = '0;
    tb_reset();
    exp_c = RESET_VAL;
    for (int t = 0; t < 5000; t++) begin
      `CHECK(count == exp_c, $sformatf("count=%0d expected %0d", count, exp_c))
      load = ($urandom % 32) == 0; inc = $urandom; dec = $urandom;
      load_val = WIDTH'({$urandom, $urandom});
      if (t % 97 == 0) load_val = '1;
      #1;
      if (load) exp_c = load_val;
      else if (inc && !dec) exp_c = exp_c + 1'b1;
      else if (dec && !inc) exp_c = exp_c - 1'b1;
      `CHECK(count_d == exp_c, $sformatf("count_d=%0d expected %0d", count_d, exp_c))
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
