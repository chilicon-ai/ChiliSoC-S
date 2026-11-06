// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_rr_arbiter -- grant is the first requester after the
// last served one (model); a waiting grant is stable; with every requester
// on, grants rotate.
`include "tb_common.svh"
module basechili_rr_arbiter_tb #(
  parameter  int N     = 4,
  localparam int IDX_W = (N > 1) ? $clog2(N) : 1
);
  `TB_CLOCK_RESET
  logic [N-1:0]     req, gnt;
  logic [IDX_W-1:0] gnt_idx;
  logic             gnt_accept, gnt_valid;
  int               last;   // last served index, -1 after reset

  basechili_rr_arbiter #(.N(N)) dut (.clk, .rst_n, .req, .gnt_accept, .gnt, .gnt_idx, .gnt_valid);

  function automatic int model(logic [N-1:0] r);
    for (int k = 1; k <= N; k++) begin
      int i = (last + k) % N;
      if (last < 0) i = k - 1;
      if (r[i]) return i;
    end
    return -1;
  endfunction

  initial begin
    req = '0; gnt_accept = 1'b0;
    tb_reset();
    last = -1;
    for (int t = 0; t < 20000; t++) begin
      int w;
      req = (t % 2000 < 200) ? '1 : N'($urandom);
      gnt_accept = (t % 2000 < 200) ? 1'b1 : 1'($urandom);
      #1 w = model(req);
      if (w < 0) `CHECK(!gnt_valid && gnt == '0, "no grant without requests")
      else `CHECK(gnt_valid && gnt == N'(1) << w && int'(gnt_idx) == w, $sformatf("req=%b gnt=%b expected %0d", req, gnt, w))
      @(posedge clk); #1;
      if (gnt_accept && w >= 0) last = w;
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
