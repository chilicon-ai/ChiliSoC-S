// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_dff_sclr -- clr > en, CLR_VAL vs RESET_VAL.
`include "tb_common.svh"
module basechili_dff_sclr_tb #(
  parameter int               WIDTH     = 1,
  parameter logic [WIDTH-1:0] RESET_VAL = '0,
  parameter logic [WIDTH-1:0] CLR_VAL   = RESET_VAL
);
  `TB_CLOCK_RESET
  logic             clr, en;
  logic [WIDTH-1:0] d, q, exp_q;

  basechili_dff_sclr #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL), .CLR_VAL(CLR_VAL)) dut (.clk, .rst_n, .clr, .en, .d, .q);

  initial begin
    d = '0; en = 1'b0; clr = 1'b0;
    @(posedge clk); #1 `CHECK(q == RESET_VAL, "reset value")
    tb_reset();
    exp_q = RESET_VAL;
    for (int t = 0; t < 3000; t++) begin
      `CHECK(q == exp_q, $sformatf("q=%h expected %h", q, exp_q))
      d = WIDTH'({$urandom, $urandom}); if (t % 50 == 0) d = ~d;
      en = $urandom; clr = ($urandom % 8) == 0;
      @(posedge clk); #1;
      if (clr) exp_q = CLR_VAL; else if (en) exp_q = d;
      @(negedge clk);
    end
    rst_n = 1'b0; #1 `CHECK(q == RESET_VAL, "async reset")
    tb_pass();
  end
endmodule
