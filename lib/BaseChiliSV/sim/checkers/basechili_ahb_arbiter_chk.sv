// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_arbiter_chk (bound into every basechili_ahb_arbiter)
//   - a manager with a held transfer (pend) is in its data phase (mdp) with
//     HREADY_m low                                          (header Invariant)
//   - the bus never shows SEQ / BUSY while first            (header Invariant)
//   - ownership does not change inside a fixed-length burst: while
//     beats_left != 0 the owner is the manager of the last bus transfer
//     (downer)                                              (header Invariant)
//   - the owner changes only at an edge with the bus HREADY high (header)
// -----------------------------------------------------------------------------
module basechili_ahb_arbiter_chk #(
  parameter int N     = 2,
  parameter int IDX_W = 1
) (
  input logic             clk,
  input logic             rst_n,
  input logic [N-1:0]     pend,
  input logic [N-1:0]     mdp,
  input logic [N-1:0]     HREADY_m,
  input logic [1:0]       HTRANS,
  input logic             HREADY,
  input logic             first,
  input logic [3:0]       beats_left,
  input logic [IDX_W-1:0] owner,
  input logic [IDX_W-1:0] downer
);

  assert property (@(posedge clk) disable iff (!rst_n) (pend & ~(mdp & ~HREADY_m)) == '0)
    else $error("basechili_ahb_arbiter: pend without mdp / with HREADY_m high: pend=%b mdp=%b HREADY_m=%b",
                pend, mdp, HREADY_m);

  assert property (@(posedge clk) disable iff (!rst_n) first |-> !HTRANS[0])
    else $error("basechili_ahb_arbiter: SEQ / BUSY as the first transfer after an owner change: HTRANS=%b", HTRANS);

  assert property (@(posedge clk) disable iff (!rst_n) beats_left != '0 |-> owner == downer)
    else $error("basechili_ahb_arbiter: owner changed inside a fixed-length burst: owner=%0d downer=%0d beats_left=%0d",
                owner, downer, beats_left);

  assert property (@(posedge clk) disable iff (!rst_n) !HREADY |=> $stable(owner))
    else $error("basechili_ahb_arbiter: owner changed with HREADY low");

endmodule

bind basechili_ahb_arbiter basechili_ahb_arbiter_chk #(.N(N), .IDX_W(IDX_W)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .pend       (pend),
  .mdp        (mdp),
  .HREADY_m   (HREADY_m),
  .HTRANS     (HTRANS),
  .HREADY     (HREADY),
  .first      (first),
  .beats_left (beats_left),
  .owner      (owner),
  .downer     (downer)
);
