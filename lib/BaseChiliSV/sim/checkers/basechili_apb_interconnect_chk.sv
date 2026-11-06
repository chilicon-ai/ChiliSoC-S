// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_apb_interconnect_chk (bound into every
// basechili_apb_interconnect)
//   - PSEL_s is zero or one-hot, and zero when PSEL is low  (header Invariants)
// The module has no clock: immediate assertions on every input change.
// -----------------------------------------------------------------------------
module basechili_apb_interconnect_chk #(
  parameter int N = 2
) (
  input logic         PSEL,
  input logic [N-1:0] PSEL_s
);

  always_comb begin
    assert ($onehot0(PSEL_s))
      else $error("basechili_apb_interconnect: PSEL_s zero or one-hot violated: PSEL_s=%b", PSEL_s);
    assert (PSEL || PSEL_s == '0)
      else $error("basechili_apb_interconnect: PSEL_s zero when PSEL low violated: PSEL_s=%b", PSEL_s);
  end

endmodule

bind basechili_apb_interconnect basechili_apb_interconnect_chk #(.N(N)) u_chk (
  .PSEL   (PSEL),
  .PSEL_s (PSEL_s)
);
