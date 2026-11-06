// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_priority_encoder
//
// Find-first-set: the lowest set bit of in (MSB_FIRST = 0) or the highest
// (MSB_FIRST = 1), as a one-hot vector and as a binary index. Combinational.
// Also a fixed-priority arbiter: in = requests, onehot = grant.
// in == 0 gives onehot = 0, idx = 0 and valid = 0.
// -----------------------------------------------------------------------------
module basechili_priority_encoder #(
  parameter  int N         = 8,                      // number of input bits
  parameter  bit MSB_FIRST = 1'b0,                   // 1: highest set bit wins
  localparam int IDX_W     = (N > 1) ? $clog2(N) : 1
) (
  input  logic [N-1:0]     in,
  output logic [N-1:0]     onehot,   // only the winning bit set
  output logic [IDX_W-1:0] idx,      // index of the winning bit
  output logic             valid     // any bit set
);

  logic [N-1:0] found;   // found[i]: a higher-priority bit than i is set

  always_comb begin
    found = '0;
    if (MSB_FIRST) begin
      for (int i = N - 2; i >= 0; i--) found[i] = found[i+1] || in[i+1];
    end else begin
      for (int i = 1; i < N; i++) found[i] = found[i-1] || in[i-1];
    end
  end

  assign onehot = in & ~found;
  assign valid  = |in;

  basechili_encoder #(.N(N)) u_enc (
    .in    (onehot),
    .out   (idx),
    .valid ()
  );

endmodule
