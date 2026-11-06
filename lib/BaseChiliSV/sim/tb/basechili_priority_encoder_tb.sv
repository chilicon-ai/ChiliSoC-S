// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_priority_encoder -- lowest / highest set bit against
// a model; exhaustive for N <= 12.
`include "tb_common.svh"
module basechili_priority_encoder_tb #(
  parameter  int N         = 8,
  parameter  bit MSB_FIRST = 1'b0,
  localparam int IDX_W     = (N > 1) ? $clog2(N) : 1
);
  logic [N-1:0]     in, onehot;
  logic [IDX_W-1:0] idx;
  logic             valid;

  basechili_priority_encoder #(.N(N), .MSB_FIRST(MSB_FIRST)) dut (.in, .onehot, .idx, .valid);

  task automatic check_one(logic [N-1:0] v);
    int w = -1;
    in = v;
    for (int i = 0; i < N; i++) if (v[i] && (w < 0 || MSB_FIRST)) w = i;
    #1;
    if (w < 0) `CHECK(!valid && onehot == '0 && idx == '0, $sformatf("in=%b zero", v))
    else `CHECK(valid && onehot == N'(1) << w && int'(idx) == w, $sformatf("in=%b idx=%0d expected %0d", v, idx, w))
  endtask

  initial begin
    if (N <= 12) for (int v = 0; v < 2**N; v++) check_one(N'(v));
    else for (int t = 0; t < 20000; t++) check_one((t % 2) ? N'({$urandom, $urandom}) >> ($urandom % N) : N'({$urandom, $urandom}));
    tb_pass();
  end
endmodule
