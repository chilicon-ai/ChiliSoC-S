// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_max_tree -- winner and index against a linear-scan
// model (strictly greater wins, so the lowest index wins a tie): all invalid,
// all equal, single valid, maximum at each index, extreme values (signed
// negatives when SIGNED), then random with narrow and full value ranges.
`include "tb_common.svh"
module basechili_max_tree_tb #(
  parameter  int N      = 8,
  parameter  int W      = 8,
  parameter  bit SIGNED = 1'b0,
  localparam int IDX_W  = (N > 1) ? $clog2(N) : 1
);
  logic [N*W-1:0]   val;
  logic [N-1:0]     valid;
  logic             max_valid;
  logic [W-1:0]     max_val;
  logic [IDX_W-1:0] max_idx;

  basechili_max_tree #(.N(N), .W(W), .SIGNED(SIGNED)) dut (.val, .valid, .max_valid, .max_val, .max_idx);

  function automatic bit gt(logic [W-1:0] a, logic [W-1:0] b);
    return SIGNED ? ($signed(a) > $signed(b)) : (a > b);
  endfunction

  function automatic logic [W-1:0] rnd_val();
    return W'({$urandom, $urandom});
  endfunction

  localparam logic [W-1:0] VMAX = SIGNED ? {1'b0, {(W-1){1'b1}}} : '1;  // largest value
  localparam logic [W-1:0] VMIN = SIGNED ? {1'b1, {(W-1){1'b0}}} : '0;  // smallest value

  task automatic check_one();
    bit           ev = 1'b0;
    logic [W-1:0] mv = '0;
    int           mi = 0;
    #1;
    for (int i = 0; i < N; i++)
      if (valid[i] && (!ev || gt(val[i*W +: W], mv))) begin ev = 1'b1; mv = val[i*W +: W]; mi = i; end
    `CHECK(max_valid == ev, $sformatf("valid=%b max_valid=%b expected %b", valid, max_valid, ev))
    if (ev) `CHECK(max_val == mv && int'(max_idx) == mi,
                   $sformatf("val=%h valid=%b max_val=%h max_idx=%0d expected %h at %0d", val, valid, max_val, max_idx, mv, mi))
    #1;
  endtask

  initial begin
    logic [W-1:0] v;
    // all invalid, with random and extreme values
    valid = '0; val = '0;  check_one();
    valid = '0; val = '1;  check_one();
    for (int t = 0; t < 20; t++) begin
      valid = '0; for (int i = 0; i < N; i++) val[i*W +: W] = rnd_val(); check_one();
    end
    // all equal: index 0 wins; also with only a subset valid
    for (int t = 0; t < 40; t++) begin
      v = (t == 0) ? VMAX : (t == 1) ? VMIN : (t == 2) ? '0 : rnd_val();
      for (int i = 0; i < N; i++) val[i*W +: W] = v;
      valid = (t < 20) ? '1 : N'({$urandom, $urandom});
      check_one();
    end
    // single valid at each index, others hold larger values
    for (int i = 0; i < N; i++)
      for (int t = 0; t < 4; t++) begin
        for (int j = 0; j < N; j++) val[j*W +: W] = (t == 0) ? VMAX : rnd_val();
        val[i*W +: W] = (t == 1) ? VMIN : (t == 2) ? VMAX : rnd_val();
        valid = '0; valid[i] = 1'b1;
        check_one();
      end
    // maximum at each index, all others valid and smaller (or equal to it)
    for (int i = 0; i < N; i++)
      for (int t = 0; t < 8; t++) begin
        for (int j = 0; j < N; j++) val[j*W +: W] = (t == 0) ? VMIN : (t == 1) ? (VMAX - W'(1)) : rnd_val();
        for (int j = 0; j < N; j++) if (!gt(val[i*W +: W], val[j*W +: W]) && j != i && t >= 2) val[j*W +: W] = VMIN;
        val[i*W +: W] = (t < 2) ? VMAX : val[i*W +: W];
        if (t == 7) for (int j = i + 1; j < N; j++) val[j*W +: W] = val[i*W +: W];  // ties above i lose
        valid = '1;
        check_one();
      end
    // signed negatives: all valid values negative
    if (SIGNED)
      for (int t = 0; t < 500; t++) begin
        for (int i = 0; i < N; i++) val[i*W +: W] = {1'b1, W'(rnd_val()) >> 1};
        valid = N'({$urandom, $urandom}); if (t % 2 == 0) valid = '1;
        check_one();
      end
    // random: narrow value range (many ties) and full range
    for (int t = 0; t < 20000; t++) begin
      for (int i = 0; i < N; i++) val[i*W +: W] = (t % 2 == 0) ? W'($urandom % 3) - W'(SIGNED) : rnd_val();
      valid = N'({$urandom, $urandom});
      if (t % 4 == 1) valid = valid | N'({$urandom, $urandom});
      if (t % 4 == 3) valid = valid & N'({$urandom, $urandom});
      check_one();
    end
    tb_pass();
  end
endmodule
