// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_thermo_encoder
//
// Binary to thermometer code: out has its lowest `in` bits set,
//   out[i] = (in > i),  e.g. N = 8, in = 3 -> out = 8'b0000_0111.
// in = 0 gives all zeros, in >= N saturates to all ones. Used for masks of
// the first k entries, byte enables from a byte count, and fill levels.
// With MSB_FIRST = 1 the code fills from the top instead (out[N-1-i] =
// (in > i)), e.g. a mask of the k highest bits.
//
// Timing: combinational.
// -----------------------------------------------------------------------------
module basechili_thermo_encoder #(
  parameter  int N         = 8,                 // number of output bits
  parameter  bit MSB_FIRST = 1'b0,              // 1: fill from bit N-1 down
  localparam int IN_W      = $clog2(N + 1)      // codes 0 .. N
) (
  input  logic [IN_W-1:0] in,    // number of bits to set (> N saturates)
  output logic [N-1:0]    out
);

  logic [N-1:0] fill;   // thermometer code, LSB first

  always_comb begin
    for (int i = 0; i < N; i++) begin
      fill[i] = (in > unsigned'(IN_W'(i)));
    end
  end

  if (MSB_FIRST) begin : g_msb
    always_comb begin
      for (int i = 0; i < N; i++) out[N - 1 - i] = fill[i];
    end
  end else begin : g_lsb
    assign out = fill;
  end

endmodule
