// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_onehot_mux -- out = OR of the selected inputs.
`include "tb_common.svh"
module basechili_onehot_mux_tb #(
  parameter int WIDTH = 1,
  parameter int N     = 2
);
  logic [N*WIDTH-1:0] in;
  logic [N-1:0]       sel;
  logic [WIDTH-1:0]   out, exp_o;

  basechili_onehot_mux #(.WIDTH(WIDTH), .N(N)) dut (.in, .sel, .out);

  initial begin
    for (int t = 0; t < 5000; t++) begin
      for (int i = 0; i < N; i++) in[i*WIDTH +: WIDTH] = WIDTH'({$urandom, $urandom});
      if (t % 50 == 0) in = ~in;
      sel = (t % 4 == 0) ? N'($urandom) : N'(1) << ($urandom % N);
      exp_o = '0;
      for (int i = 0; i < N; i++) if (sel[i]) exp_o |= in[i*WIDTH +: WIDTH];
      #1 `CHECK(out == exp_o, $sformatf("sel=%b out=%h expected %h", sel, out, exp_o))
    end
    tb_pass();
  end
endmodule
