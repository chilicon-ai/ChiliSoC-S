// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_valid_array -- random set / clear / flush (indices
// may be >= N, set and clear may name the same entry) against a bit model;
// fill phases reach full; valid, full, empty and free_idx (lowest invalid
// entry) checked every cycle.
`include "tb_common.svh"
module basechili_valid_array_tb #(
  parameter  int N     = 8,
  localparam int IDX_W = (N > 1) ? $clog2(N) : 1
);
  `TB_CLOCK_RESET
  logic             flush, set_en, clr_en, full, empty;
  logic [IDX_W-1:0] set_idx, clr_idx, free_idx;
  logic [N-1:0]     valid, model;

  basechili_valid_array #(.N(N)) dut (.clk, .rst_n, .flush, .set_en, .set_idx, .clr_en, .clr_idx,
                                      .valid, .full, .empty, .free_idx);

  task automatic check();
    int lo;
    lo = 0;
    while (lo < N - 1 && model[lo]) lo++;
    `CHECK(valid == model && full == (&model) && empty == (model == '0),
           $sformatf("valid=%b model=%b full=%b empty=%b", valid, model, full, empty))
    if (!(&model)) `CHECK(int'(free_idx) == lo, $sformatf("free_idx=%0d expected %0d (valid=%b)", free_idx, lo, model))
  endtask

  initial begin
    flush = 1'b0; set_en = 1'b0; clr_en = 1'b0; set_idx = '0; clr_idx = '0;
    model = '0;
    tb_reset();
    for (int t = 0; t < 30000; t++) begin
      bit filling;
      filling = (t % 1000) < 400;
      set_en  = filling ? ($urandom % 4 != 0) : ($urandom % 3 == 0);
      clr_en  = filling ? ($urandom % 8 == 0) : ($urandom % 2 == 0);
      set_idx = IDX_W'($urandom);
      clr_idx = ($urandom % 4 == 0) ? set_idx : IDX_W'($urandom);
      flush   = ($urandom % 200) == 0;
      #1 check();
      @(posedge clk); #1;
      if (flush) model = '0;
      else begin
        if (clr_en && int'(clr_idx) < N) model[clr_idx] = 1'b0;
        if (set_en && int'(set_idx) < N) model[set_idx] = 1'b1;
      end
      check();
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
