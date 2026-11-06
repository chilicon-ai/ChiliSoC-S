// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_decoder -- exhaustive: one-hot of in, zero when in >= N.
`include "tb_common.svh"
module basechili_decoder_tb #(
  parameter  int N    = 4,
  localparam int IN_W = (N > 1) ? $clog2(N) : 1
);
  logic [IN_W-1:0] in;
  logic [N-1:0]    out, exp_o;

  basechili_decoder #(.N(N)) dut (.in, .out);

  initial begin
    for (int r = 0; r < 4; r++)
      for (int v = 0; v < 2**IN_W; v++) begin
        in = IN_W'(v);
        exp_o = (v < N) ? N'(1) << v : '0;
        #1 `CHECK(out == exp_o, $sformatf("in=%0d out=%b", in, out))
      end
    tb_pass();
  end
endmodule
