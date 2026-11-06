// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_sync -- q is d delayed by STAGES edges; reset value.
`include "tb_common.svh"
module basechili_sync_tb #(
  parameter int               WIDTH     = 1,
  parameter int               STAGES    = 2,
  parameter logic [WIDTH-1:0] RESET_VAL = '0
);
  `TB_CLOCK_RESET
  logic [WIDTH-1:0] d, q;
  logic [WIDTH-1:0] hist[$];

  basechili_sync #(.WIDTH(WIDTH), .STAGES(STAGES), .RESET_VAL(RESET_VAL)) dut (.clk, .rst_n, .d, .q);

  initial begin
    d = '0;
    @(posedge clk); #1 `CHECK(q == RESET_VAL, "reset value")
    tb_reset();
    for (int k = 0; k < STAGES; k++) hist.push_back(RESET_VAL);
    for (int t = 0; t < 3000; t++) begin
      `CHECK(q == hist[0], $sformatf("q=%h expected %h", q, hist[0]))
      d = WIDTH'($urandom);
      @(posedge clk); #1;
      void'(hist.pop_front()); hist.push_back(d);
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
