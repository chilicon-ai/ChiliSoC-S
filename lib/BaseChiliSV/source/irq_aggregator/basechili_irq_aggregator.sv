// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_irq_aggregator
//
// N interrupt sources to one interrupt line, with per-source pending and
// enable (GPIO and peripheral interrupt blocks). A source sets its pending
// bit while its input is high (edge_sel 0, level) or on its rising edge
// (edge_sel 1); clr clears it (write-1-to-clear from a register bank). A set
// in the same cycle wins over the clear, so no event is lost, and a level
// source still high re-sets its bit.
//
//   pending_d = set | (pending & ~clr)      irq = |(pending & enable)
//
// Inputs must be synchronous to clk (basechili_sync for pins).
//
// Timing    : pending is registered, set the cycle after the source;
//             irq / active are combinational from pending and enable.
// Invariants: irq == ((pending & enable) != 0).
// Debug     : interrupt stuck -> pending (u_pending.q), clr and a level
//             source still high; missed edge -> u_edge.prev and edge_sel.
// -----------------------------------------------------------------------------
module basechili_irq_aggregator #(
  parameter int N = 8          // sources
) (
  input  logic         clk,
  input  logic         rst_n,       // async, active-low
  input  logic [N-1:0] src,         // interrupt sources, synchronous
  input  logic [N-1:0] edge_sel,    // 1: rising edge sets pending, 0: high level
  input  logic [N-1:0] enable,      // pending source i may raise irq
  input  logic [N-1:0] clr,         // clear pending bit i
  output logic [N-1:0] pending,     // sources that requested
  output logic [N-1:0] active,      // pending & enable
  output logic         irq          // some enabled source is pending
);

  logic [N-1:0] rise;        // src rising edge
  logic [N-1:0] set;         // pending bits set this cycle
  logic [N-1:0] pending_d;   // next pending

  basechili_edge_detect #(.WIDTH(N)) u_edge (
    .clk      (clk),
    .rst_n    (rst_n),
    .in       (src),
    .rise     (rise),
    .fall     (),
    .any_edge ()
  );

  assign set       = (edge_sel & rise) | (~edge_sel & src);
  assign pending_d = set | (pending & ~clr);

  basechili_dff #(.WIDTH(N)) u_pending (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pending_d),
    .q     (pending)
  );

  assign active = pending & enable;
  assign irq    = |active;

endmodule
