// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_counter -- clr > en, wraps at 2**WIDTH.
`include "tb_common.svh"
module basechili_counter_tb #(
  parameter int WIDTH = 8
);
  `TB_CLOCK_RESET
  logic             clr, en;
  logic [WIDTH-1:0] count, exp_c;

  basechili_counter #(.WIDTH(WIDTH)) dut (.clk, .rst_n, .clr, .en, .count);

  initial begin
    clr = 1'b0; en = 1'b0;
    tb_reset();
    exp_c = '0;
    for (int t = 0; t < 5000; t++) begin
      `CHECK(count == exp_c, $sformatf("count=%0d expected %0d", count, exp_c))
      clr = ($urandom % 64) == 0; en = ($urandom % 8) != 0;
      @(posedge clk); #1;
      if (clr) exp_c = '0; else if (en) exp_c = exp_c + 1'b1;
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
