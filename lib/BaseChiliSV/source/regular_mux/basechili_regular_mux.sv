// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_regular_mux
//
// N-to-1 multiplexer with a binary-encoded select. Combinational.
// Input i occupies in[i*WIDTH +: WIDTH].
// A select value >= N drives out to zero (an unexpected zero out usually
// means an out-of-range sel).
// -----------------------------------------------------------------------------
module basechili_regular_mux #(
  parameter  int WIDTH = 1,                           // data width in bits
  parameter  int N     = 2,                           // number of inputs
  localparam int SEL_W = (N > 1) ? $clog2(N) : 1
) (
  input  logic [N*WIDTH-1:0] in,
  input  logic [SEL_W-1:0]   sel,
  output logic [WIDTH-1:0]   out
);

  // Indexed select: synthesis builds a balanced mux tree (log2(N) levels)
  // instead of a priority chain over the inputs.
  assign out = (int'(sel) < N) ? in[int'(sel)*WIDTH +: WIDTH] : '0;

endmodule
