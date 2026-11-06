// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_encoder -- one-hot to index; multi-hot ORs indices.
`include "tb_common.svh"
module basechili_encoder_tb #(
  parameter  int N     = 4,
  localparam int OUT_W = (N > 1) ? $clog2(N) : 1
);
  logic [N-1:0]     in;
  logic [OUT_W-1:0] out, exp_o;
  logic             valid;

  basechili_encoder #(.N(N)) dut (.in, .out, .valid);

  initial begin
    for (int t = 0; t < 3000; t++) begin
      in = (t % 3 == 0) ? N'($urandom) : (t % 3 == 1) ? N'(1) << ($urandom % N) : '0;
      if (t % 100 == 0) in = '1;
      exp_o = '0;
      for (int i = 0; i < N; i++) if (in[i]) exp_o |= OUT_W'(i);
      #1 `CHECK(out == exp_o && valid == (in != '0), $sformatf("in=%b out=%0d", in, out))
    end
    tb_pass();
  end
endmodule
