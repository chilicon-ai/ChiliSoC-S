// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_encoder
//
// One-hot to binary encoder (OR structure, no priority). Combinational.
// valid is high when any input bit is set.
// A multi-hot input yields the bitwise OR of the set indices (a garbage out
// with valid high usually means in was not one-hot).
// -----------------------------------------------------------------------------
module basechili_encoder #(
  parameter  int N     = 4,                           // number of input bits
  localparam int OUT_W = (N > 1) ? $clog2(N) : 1
) (
  input  logic [N-1:0]     in,    // one-hot
  output logic [OUT_W-1:0] out,
  output logic             valid
);

  always_comb begin
    out = '0;
    for (int i = 0; i < N; i++) begin
      if (in[i]) out |= unsigned'(OUT_W'(i));
    end
  end

  assign valid = |in;

endmodule
