// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_reset_sync -- assert is immediate (mid-cycle, no
// clock edge), release comes on the STAGES-th rising edge; test_en bypass.
`include "tb_common.svh"
module basechili_reset_sync_tb #(
  parameter int STAGES = 2
);
  logic clk = 1'b0;
  logic rst_n_async, test_en, rst_n_sync;

  always #5 clk = ~clk;
  basechili_reset_sync #(.STAGES(STAGES)) dut (.clk, .rst_n_async, .test_en, .rst_n_sync);

  initial begin
    test_en = 1'b0; rst_n_async = 1'b0;
    repeat (3) @(posedge clk);
    for (int t = 0; t < 300; t++) begin
      // release at a random point of the low clock phase (clear of the edge)
      @(negedge clk); #($urandom % 4) rst_n_async = 1'b1;
      for (int k = 1; k <= STAGES; k++) begin
        `CHECK(!rst_n_sync, $sformatf("released before edge %0d", k))
        @(posedge clk); #1;
      end
      `CHECK(rst_n_sync, "released on the STAGES-th edge")
      repeat ($urandom % 5) @(posedge clk);
      // assert at a random point: immediate, without a clock edge
      #($urandom % 4 + 1) rst_n_async = 1'b0;
      #1 `CHECK(!rst_n_sync, "asserts asynchronously")
      repeat ($urandom % 3) @(posedge clk);
    end
    test_en = 1'b1;
    for (int t = 0; t < 20; t++) begin
      rst_n_async = $urandom; #1 `CHECK(rst_n_sync == rst_n_async, "test_en bypass")
    end
    // back to functional mode: the chain holds reset while rst_n_async is low
    rst_n_async = 1'b0; #1 test_en = 1'b0;
    #1 `CHECK(!rst_n_sync, "test_en off, reset held")
    tb_pass();
  end
endmodule
