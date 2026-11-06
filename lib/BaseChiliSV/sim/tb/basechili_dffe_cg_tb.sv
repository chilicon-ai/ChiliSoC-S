// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_dffe_cg -- q loads d on enabled (or test_en) edges,
// holds otherwise, like basechili_dffe; d and en come from flops on clk, so
// they change at the same edge the gated flops sample (no race through gclk).
`include "tb_common.svh"
module basechili_dffe_cg_tb #(
  parameter int               WIDTH     = 1,
  parameter logic [WIDTH-1:0] RESET_VAL = '0,
  parameter bit               GATE      = 1'b1
);
  `TB_CLOCK_RESET
  logic             en_in, test_en_in;   // stimulus, driven after falling edges
  logic [WIDTH-1:0] d_in;
  logic             en, test_en;         // registered stimulus: changes at rising edges
  logic [WIDTH-1:0] d, q, exp_q;

  always_ff @(posedge clk) begin
    en      <= en_in;
    test_en <= test_en_in;
    d       <= d_in;
  end

  basechili_dffe_cg #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL), .GATE(GATE)) dut (
    .clk, .rst_n, .test_en, .en, .d, .q
  );

  // reference: the value of d at every edge where en || test_en was high
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)                       exp_q <= RESET_VAL;
    else if (en || (GATE && test_en)) exp_q <= d;
  end

  always @(negedge clk) if (rst_n) `CHECK(q == exp_q, $sformatf("q=%h expected %h", q, exp_q))

  initial begin
    d_in = '0; en_in = 1'b0; test_en_in = 1'b0;
    @(posedge clk); #1 `CHECK(q == RESET_VAL, "reset value")
    tb_reset();
    for (int t = 0; t < 4000; t++) begin
      d_in       = WIDTH'({$urandom, $urandom});
      if (t % 50 == 0) d_in = ~d_in;
      en_in      = (t < 2000) ? 1'($urandom) : (($urandom % 8) == 0);   // then long holds
      test_en_in = ($urandom % 16) == 0;
      @(negedge clk);
    end
    // reset while the clock is gated off
    en_in = 1'b0; test_en_in = 1'b0;
    repeat (2) @(negedge clk);
    rst_n = 1'b0; #1 `CHECK(q == RESET_VAL, "async reset while gated")
    tb_pass();
  end
endmodule
