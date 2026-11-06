// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_thermo_encoder -- every input code (including the
// saturating ones above N) against out[i] = (in > i), LSB or MSB first,
// in order and then in random order.
`include "tb_common.svh"
module basechili_thermo_encoder_tb #(
  parameter  int N         = 8,
  parameter  bit MSB_FIRST = 1'b0,
  localparam int IN_W      = $clog2(N + 1)
);
  logic [IN_W-1:0] in;
  logic [N-1:0]    out;

  basechili_thermo_encoder #(.N(N), .MSB_FIRST(MSB_FIRST)) dut (.in, .out);

  task automatic check(int v);
    logic [N-1:0] exp;
    in = IN_W'(v);
    #1;
    for (int i = 0; i < N; i++) begin
      if (MSB_FIRST) exp[N - 1 - i] = (v > i);
      else           exp[i]         = (v > i);
    end
    `CHECK(out == exp, $sformatf("in=%0d out=%b expected %b", v, out, exp))
  endtask

  initial begin
    for (int v = 0; v < (1 << IN_W); v++) check(v);
    for (int v = (1 << IN_W) - 1; v >= 0; v--) check(v);
    for (int t = 0; t < 5000; t++) check($urandom % (1 << IN_W));
    tb_pass();
  end
endmodule
