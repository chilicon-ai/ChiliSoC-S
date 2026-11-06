// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_edge_detect
//
// Per-bit rising / falling / any edge detector on a synchronous input (feed
// an asynchronous signal through basechili_sync first).
//
//   rise = in & ~prev    fall = ~in & prev    any_edge = in ^ prev
//
// Timing: the outputs are combinational from in and the registered previous
//         value (u_prev): high in the first cycle in shows its new value.
// Reset : prev = RESET_VAL, so an input equal to it gives no edge after reset.
// -----------------------------------------------------------------------------
module basechili_edge_detect #(
  parameter int               WIDTH     = 1,    // number of independent bits
  parameter logic [WIDTH-1:0] RESET_VAL = '0    // previous value assumed at reset
) (
  input  logic             clk,
  input  logic             rst_n,     // async, active-low
  input  logic [WIDTH-1:0] in,        // synchronous to clk
  output logic [WIDTH-1:0] rise,      // 0 -> 1 this cycle
  output logic [WIDTH-1:0] fall,      // 1 -> 0 this cycle
  output logic [WIDTH-1:0] any_edge   // any change this cycle
);

  logic [WIDTH-1:0] prev;   // in, one cycle ago

  basechili_dff #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) u_prev (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (in),
    .q     (prev)
  );

  assign rise     = in & ~prev;
  assign fall     = ~in & prev;
  assign any_edge = in ^ prev;

endmodule
