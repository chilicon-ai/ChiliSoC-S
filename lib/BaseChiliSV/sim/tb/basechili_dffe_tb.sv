// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_dffe -- q loads d on enabled edges, holds otherwise.
`include "tb_common.svh"
module basechili_dffe_tb #(
  parameter int               WIDTH     = 1,
  parameter logic [WIDTH-1:0] RESET_VAL = '0
);
  `TB_CLOCK_RESET
  logic             en;
  logic [WIDTH-1:0] d, q, exp_q;

  basechili_dffe #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) dut (.clk, .rst_n, .en, .d, .q);

  initial begin
    d = '0; en = 1'b0;
    @(posedge clk); #1 `CHECK(q == RESET_VAL, "reset value")
    tb_reset();
    exp_q = RESET_VAL;
    for (int t = 0; t < 2000; t++) begin
      `CHECK(q == exp_q, $sformatf("q=%h expected %h", q, exp_q))
      d  = WIDTH'({$urandom, $urandom});
      if (t % 50 == 0) d = ~d;
      en = $urandom;
      @(posedge clk); #1;
      if (en) exp_q = d;
      @(negedge clk);
    end
    rst_n = 1'b0; #1 `CHECK(q == RESET_VAL, "async reset")
    tb_pass();
  end
endmodule
