// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_wide_counter_chk (bound into every basechili_wide_counter)
//   - lo_ones == (low part of count is all ones)            (header Invariant)
// -----------------------------------------------------------------------------
module basechili_wide_counter_chk #(
  parameter int WIDTH = 64,
  parameter int LO_W  = 32
) (
  input logic             clk,
  input logic             rst_n,
  input logic             lo_ones,
  input logic [WIDTH-1:0] count
);

  assert property (@(posedge clk) disable iff (!rst_n)
                   lo_ones == (count[LO_W-1:0] == {LO_W{1'b1}}))
    else $error("basechili_wide_counter: lo_ones disagrees with the low part");

endmodule

bind basechili_wide_counter basechili_wide_counter_chk #(.WIDTH(WIDTH), .LO_W(LO_W)) u_chk (
  .clk     (clk),
  .rst_n   (rst_n),
  .lo_ones (lo_ones),
  .count   (count)
);
