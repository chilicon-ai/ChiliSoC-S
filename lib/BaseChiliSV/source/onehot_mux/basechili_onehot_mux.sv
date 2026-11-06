// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_onehot_mux
//
// N-to-1 multiplexer with a one-hot select (AND-OR structure). Combinational.
// Input i occupies in[i*WIDTH +: WIDTH].
// sel == 0 drives out to zero; a multi-hot sel ORs the selected inputs.
// -----------------------------------------------------------------------------
module basechili_onehot_mux #(
  parameter int WIDTH = 1,   // data width in bits
  parameter int N     = 2    // number of inputs
) (
  input  logic [N*WIDTH-1:0] in,
  input  logic [N-1:0]       sel,   // one-hot
  output logic [WIDTH-1:0]   out
);

  always_comb begin
    out = '0;
    for (int i = 0; i < N; i++) begin
      out |= in[i*WIDTH +: WIDTH] & {WIDTH{sel[i]}};
    end
  end

endmodule
