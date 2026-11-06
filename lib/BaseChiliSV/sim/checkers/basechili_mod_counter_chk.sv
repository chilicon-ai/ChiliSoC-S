// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_mod_counter_chk (bound into every basechili_mod_counter)
//   - count < MOD                            (header Invariant)
// -----------------------------------------------------------------------------
module basechili_mod_counter_chk #(
  parameter int MOD   = 4,
  parameter int WIDTH = 2
) (
  input logic             clk,
  input logic             rst_n,
  input logic [WIDTH-1:0] count
);

  assert property (@(posedge clk) disable iff (!rst_n) 32'(count) < MOD)
    else $error("basechili_mod_counter: count < MOD violated: count=%0d MOD=%0d", count, MOD);

endmodule

bind basechili_mod_counter basechili_mod_counter_chk #(.MOD(MOD), .WIDTH(WIDTH)) u_chk (
  .clk   (clk),
  .rst_n (rst_n),
  .count (count)
);
