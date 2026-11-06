// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_max_tree
//
// Maximum of N valid values with its index, as a balanced tree of
// comparators (ceil(log2 N) levels instead of a chain of N - 1). Invalid
// inputs never win; on equal values the lower index wins. Used for
// highest-priority selection, e.g. the pending interrupt with the highest
// priority.
//
// The tree has LEVELS + 1 levels: level LEVELS (g_lvl[LEVELS]) is the N
// inputs, level l has ceil(N / 2**(LEVELS - l)) nodes, node j taking nodes
// 2j and 2j + 1 of level l + 1, and level 0 is the result. A node whose
// right child does not exist (N not a power of two) passes its left child
// on. Node j of level l is at nv[j], nval[j*W +: W] and, below the leaves,
// nidx[j*RW +: RW]: the winner's index inside the node's subtree of
// 2**RW inputs (RW = LEVELS - l), built from the take_r choices on the way
// down, so no level stores constant indices.
//
// Timing    : combinational, ceil(log2 N) compare-and-select levels.
// Invariants: max_valid == (valid != 0); when max_valid, valid[max_idx] is
//             set and no valid input is greater than max_val.
// Debug     : wrong winner -> walk the tree from g_lvl[0] down (nv, nval,
//             g_cmp.nidx, g_node[j].g_two.take_r).
// -----------------------------------------------------------------------------
module basechili_max_tree #(
  parameter  int N      = 8,                            // inputs
  parameter  int W      = 8,                            // value width
  parameter  bit SIGNED = 1'b0,                         // values are two's complement
  localparam int IDX_W  = (N > 1) ? $clog2(N) : 1,
  localparam int LEVELS = (N > 1) ? $clog2(N) : 0       // compare levels
) (
  input  logic [N*W-1:0]   val,         // value i at val[i*W +: W]
  input  logic [N-1:0]     valid,       // value i takes part
  output logic             max_valid,   // some value is valid
  output logic [W-1:0]     max_val,     // the largest valid value
  output logic [IDX_W-1:0] max_idx      // its index (lowest on a tie)
);

  // ---- levels: g_lvl[LEVELS] holds the inputs, g_lvl[0] the result ------------------
  // One set of vectors per level (not one heap vector) so simulators see no
  // false combinational loop.
  for (genvar l = LEVELS; l >= 0; l--) begin : g_lvl
    localparam int NN = (N + (1 << (LEVELS - l)) - 1) >> (LEVELS - l);   // nodes on this level
    localparam int RW = (l < LEVELS) ? LEVELS - l : 1;                    // index bits below this level
    logic [NN-1:0]   nv;     // node valid
    logic [NN*W-1:0] nval;   // node value

    if (l == LEVELS) begin : g_leaf
      assign nv   = valid;
      assign nval = val;
    end else begin : g_cmp
      localparam int CN = (N + (1 << (LEVELS - l - 1)) - 1) >> (LEVELS - l - 1);   // nodes on level l + 1
      logic [NN*RW-1:0] nidx;   // winner index inside each node's subtree

      for (genvar j = 0; j < NN; j++) begin : g_node
        logic [W-1:0] lv;     // left (lower-index) child value
        logic         lvld;   // left child valid
        logic [RW-1:0] idx;   // winner index inside this subtree

        assign lv   = g_lvl[l+1].nval[(2*j)*W +: W];
        assign lvld = g_lvl[l+1].nv[2*j];

        if (2 * j + 1 < CN) begin : g_two
          logic [W-1:0] rv;       // right child value
          logic         rvld;     // right child valid
          logic         r_gt;     // right value greater than left
          logic         take_r;   // the right child wins

          assign rv     = g_lvl[l+1].nval[(2*j+1)*W +: W];
          assign rvld   = g_lvl[l+1].nv[2*j+1];
          assign r_gt   = SIGNED ? ($signed(rv) > $signed(lv)) : (rv > lv);
          assign take_r = rvld && (!lvld || r_gt);

          if (RW == 1) begin : g_bit
            assign idx = take_r;
          end else begin : g_sub
            assign idx = {take_r, take_r ? g_lvl[l+1].g_cmp.nidx[(2*j+1)*(RW-1) +: RW-1]
                                         : g_lvl[l+1].g_cmp.nidx[(2*j)*(RW-1) +: RW-1]};
          end

          assign nv[j]          = lvld || rvld;
          assign nval[j*W +: W] = take_r ? rv : lv;
        end else begin : g_one
          // no right child: pass the left one on (its subtree is the lower half)
          if (RW == 1) begin : g_bit
            assign idx = 1'b0;
          end else begin : g_sub
            assign idx = {1'b0, g_lvl[l+1].g_cmp.nidx[(2*j)*(RW-1) +: RW-1]};
          end

          assign nv[j]          = lvld;
          assign nval[j*W +: W] = lv;
        end

        assign nidx[j*RW +: RW] = idx;
      end
    end
  end

  assign max_valid = g_lvl[0].nv[0];
  assign max_val   = g_lvl[0].nval;

  if (LEVELS == 0) begin : g_single
    assign max_idx = '0;
  end else begin : g_tree
    assign max_idx = g_lvl[0].g_cmp.nidx;
  end

endmodule
