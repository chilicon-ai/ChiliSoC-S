// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_mod_counter -- counts 0 .. MOD-1 and wraps.
`include "tb_common.svh"
module basechili_mod_counter_tb #(
  parameter  int MOD   = 4,
  localparam int WIDTH = (MOD > 1) ? $clog2(MOD) : 1
);
  `TB_CLOCK_RESET
  logic             clr, en;
  logic [WIDTH-1:0] count;
  int               exp_c;

  basechili_mod_counter #(.MOD(MOD)) dut (.clk, .rst_n, .clr, .en, .count);

  initial begin
    clr = 1'b0; en = 1'b0;
    tb_reset();
    exp_c = 0;
    for (int t = 0; t < 5000; t++) begin
      `CHECK(int'(count) == exp_c, $sformatf("count=%0d expected %0d", count, exp_c))
      clr = ($urandom % 64) == 0; en = ($urandom % 8) != 0;
      @(posedge clk); #1;
      if (clr) exp_c = 0; else if (en) exp_c = (exp_c + 1) % MOD;
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
