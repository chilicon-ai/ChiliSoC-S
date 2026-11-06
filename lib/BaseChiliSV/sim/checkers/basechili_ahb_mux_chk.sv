// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_mux_chk (bound into every basechili_ahb_mux)
//   - dsel is zero or one-hot (with a zero or one-hot sel)  (header Invariant)
//   - dsel changes only after a cycle with HREADY high       (header Invariant)
// -----------------------------------------------------------------------------
module basechili_ahb_mux_chk #(
  parameter int N = 2
) (
  input logic         clk,
  input logic         rst_n,
  input logic [N-1:0] dsel,
  input logic         HREADY
);

  assert property (@(posedge clk) disable iff (!rst_n) $onehot0(dsel))
    else $error("basechili_ahb_mux: dsel zero or one-hot violated: dsel=%b", dsel);

  assert property (@(posedge clk) disable iff (!rst_n) !$stable(dsel) |-> $past(HREADY))
    else $error("basechili_ahb_mux: dsel changed after a cycle with HREADY low: dsel=%b", dsel);

endmodule

bind basechili_ahb_mux basechili_ahb_mux_chk #(.N(N)) u_chk (
  .clk    (clk),
  .rst_n  (rst_n),
  .dsel   (dsel),
  .HREADY (HREADY)
);
