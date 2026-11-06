// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_edge_detect -- rise / fall / any_edge against the
// previous input value.
`include "tb_common.svh"
module basechili_edge_detect_tb #(
  parameter int               WIDTH     = 1,
  parameter logic [WIDTH-1:0] RESET_VAL = '0
);
  `TB_CLOCK_RESET
  logic [WIDTH-1:0] in, rise, fall, any_edge, prev;

  basechili_edge_detect #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) dut (.clk, .rst_n, .in, .rise, .fall, .any_edge);

  initial begin
    in = RESET_VAL;
    tb_reset();
    prev = RESET_VAL;
    for (int t = 0; t < 3000; t++) begin
      in = WIDTH'($urandom); #1;
      `CHECK(rise == (in & ~prev) && fall == (~in & prev) && any_edge == (in ^ prev),
             $sformatf("in=%b prev=%b rise=%b fall=%b any=%b", in, prev, rise, fall, any_edge))
      @(posedge clk); #1 prev = in;
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
