// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_onehot_check
//
// One-hot checks on an N-bit vector, combinational:
//   zero    : no bit set
//   onehot  : exactly one bit set
//   onehot0 : at most one bit set (one-hot or zero)
//   multi   : two or more bits set
// Built as a balanced binary tree of (any, multi) pairs, so the depth is
// log2(N) gates instead of the add chain a bit count (popcount > 1) gives.
// Tree nodes are heap-indexed: node k has children 2k+1 and 2k+2; nodes
// 0 .. N-2 are internal and node N-1+i is input bit i.
//
// Timing: all outputs are combinational from in.
// Debug : multi high unexpectedly -> any_t / mul_t of the root's children
//         (nodes 1 and 2) say which half holds the extra bit.
// -----------------------------------------------------------------------------
module basechili_onehot_check #(
  parameter  int N    = 8,                     // number of input bits
  localparam int NI_W = (N > 1) ? N - 1 : 1    // internal-node vector width
) (
  input  logic [N-1:0] in,
  output logic         zero,      // no bit set
  output logic         onehot,    // exactly one bit set
  output logic         onehot0,   // at most one bit set
  output logic         multi      // two or more bits set
);

  logic [NI_W-1:0] any_t;   // internal node k: some bit set below it
  logic [NI_W-1:0] mul_t;   // internal node k: two or more bits set below it
  logic            any_r;   // root: some bit set
  logic            mul_r;   // root: two or more bits set

  // (any, multi) of heap node c: an input bit for a leaf, else the node pair
  function automatic logic [1:0] node(int c, logic [N-1:0] v, logic [NI_W-1:0] a, logic [NI_W-1:0] m);
    if (c >= N - 1) return {1'b0, v[c - (N - 1)]};
    return {m[c], a[c]};
  endfunction

  if (N > 1) begin : g_tree
    always_comb begin
      logic [1:0] l, r;   // (multi, any) of the left / right child
      any_t = '0;
      mul_t = '0;
      for (int k = N - 2; k >= 0; k--) begin
        l        = node(2 * k + 1, in, any_t, mul_t);
        r        = node(2 * k + 2, in, any_t, mul_t);
        any_t[k] = l[0] | r[0];
        mul_t[k] = l[1] | r[1] | (l[0] & r[0]);
      end
    end
    assign any_r = any_t[0];
    assign mul_r = mul_t[0];
  end else begin : g_one
    assign any_t = in;
    assign mul_t = '0;
    assign any_r = in[0];
    assign mul_r = 1'b0;
  end

  assign zero    = !any_r;
  assign multi   = mul_r;
  assign onehot  = any_r && !mul_r;
  assign onehot0 = !mul_r;

endmodule
