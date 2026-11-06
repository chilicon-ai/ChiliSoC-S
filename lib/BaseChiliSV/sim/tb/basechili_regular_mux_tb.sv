// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_regular_mux -- out = input sel, zero when sel >= N.
`include "tb_common.svh"
module basechili_regular_mux_tb #(
  parameter  int WIDTH = 1,
  parameter  int N     = 2,
  localparam int SEL_W = (N > 1) ? $clog2(N) : 1
);
  logic [N*WIDTH-1:0] in;
  logic [SEL_W-1:0]   sel;
  logic [WIDTH-1:0]   out, exp_o;

  basechili_regular_mux #(.WIDTH(WIDTH), .N(N)) dut (.in, .sel, .out);

  initial begin
    for (int t = 0; t < 5000; t++) begin
      for (int i = 0; i < N; i++) in[i*WIDTH +: WIDTH] = WIDTH'({$urandom, $urandom});
      if (t % 50 == 0) in = ~in;
      sel = SEL_W'($urandom);
      exp_o = (int'(sel) < N) ? in[int'(sel)*WIDTH +: WIDTH] : '0;
      #1 `CHECK(out == exp_o, $sformatf("sel=%0d out=%h expected %h", sel, out, exp_o))
    end
    tb_pass();
  end
endmodule
