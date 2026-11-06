// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_decoder
//
// Binary to one-hot decoder. Combinational.
// An input value >= N drives out to zero (an unexpected all-zero out usually
// means an out-of-range in).
// -----------------------------------------------------------------------------
module basechili_decoder #(
  parameter  int N    = 4,                            // number of output bits
  localparam int IN_W = (N > 1) ? $clog2(N) : 1
) (
  input  logic [IN_W-1:0] in,
  output logic [N-1:0]    out   // one-hot
);

  always_comb begin
    out = '0;
    for (int i = 0; i < N; i++) begin
      out[i] = (in == unsigned'(IN_W'(i)));
    end
  end

endmodule
