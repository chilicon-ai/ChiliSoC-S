// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_dff -- q follows d one edge later; reset value.
`include "tb_common.svh"
module basechili_dff_tb #(
  parameter int               WIDTH     = 1,
  parameter logic [WIDTH-1:0] RESET_VAL = '0
);
  `TB_CLOCK_RESET
  logic [WIDTH-1:0] d, q, exp_q;

  basechili_dff #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) dut (.clk, .rst_n, .d, .q);

  initial begin
    d = '0;
    @(posedge clk); #1 `CHECK(q == RESET_VAL, "reset value")
    tb_reset();
    exp_q = RESET_VAL;
    for (int t = 0; t < 2000; t++) begin
      `CHECK(q == exp_q, $sformatf("q=%h expected %h", q, exp_q))
      d = WIDTH'({$urandom, $urandom});
      if (t % 50 == 0) d = ~d;
      @(posedge clk); #1;
      exp_q = d;
      @(negedge clk);
    end
    rst_n = 1'b0; #1 `CHECK(q == RESET_VAL, "async reset")
    tb_pass();
  end
endmodule
