// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_tag_compare -- random tag sets and valid bits; the
// lookup tag is usually copied from a way (hits), sometimes duplicated into
// a second way (multi-hit) or random (miss); hit_way, hit, hit_idx (OR of
// the hitting indices) and multi_hit against a model.
`include "tb_common.svh"
module basechili_tag_compare_tb #(
  parameter  int TAG_W = 20,
  parameter  int WAYS  = 4,
  localparam int IDX_W = (WAYS > 1) ? $clog2(WAYS) : 1
);
  logic [WAYS*TAG_W-1:0] tags;
  logic [WAYS-1:0]       valid, hit_way;
  logic [TAG_W-1:0]      tag;
  logic                  hit, multi_hit;
  logic [IDX_W-1:0]      hit_idx;

  basechili_tag_compare #(.TAG_W(TAG_W), .WAYS(WAYS)) dut (
    .tags, .valid, .tag, .hit_way, .hit, .hit_idx, .multi_hit);

  function automatic logic [TAG_W-1:0] rnd();
    logic [TAG_W-1:0] v;
    for (int b = 0; b < TAG_W; b++) v[b] = 1'($urandom);
    return v;
  endfunction

  initial begin
    for (int t = 0; t < 30000; t++) begin
      logic [WAYS-1:0]  exp_way;
      logic [IDX_W-1:0] exp_idx;
      int               w;
      for (int k = 0; k < WAYS; k++) tags[k*TAG_W +: TAG_W] = rnd();
      for (int k = 0; k < WAYS; k++) valid[k] = ($urandom % 4) != 0;
      w = $urandom % WAYS;
      case ($urandom % 4)
        0: tag = rnd();                                               // miss (usually)
        1: begin                                                      // duplicate
          tag = tags[w*TAG_W +: TAG_W];
          tags[(($urandom % WAYS))*TAG_W +: TAG_W] = tag;
        end
        default: tag = tags[w*TAG_W +: TAG_W];                        // hit unless invalid
      endcase
      #1;
      exp_idx = '0;
      for (int k = 0; k < WAYS; k++) begin
        exp_way[k] = valid[k] && (tags[k*TAG_W +: TAG_W] == tag);
        if (exp_way[k]) exp_idx |= IDX_W'(k);
      end
      `CHECK(hit_way == exp_way && hit == (|exp_way) && hit_idx == exp_idx &&
             multi_hit == ($countones(exp_way) > 1),
             $sformatf("hit_way=%b exp %b hit=%b idx=%0d exp %0d multi=%b", hit_way, exp_way, hit,
                       hit_idx, exp_idx, multi_hit))
    end
    tb_pass();
  end
endmodule
