// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_dff
//
// D flip-flop with asynchronous active-low reset (falling edge of rst_n).
// Storage primitive: one of the few modules allowed to contain always_ff.
//
// Timing: q takes d on every rising clk edge (one cycle of delay).
// Reset : q = RESET_VAL as soon as rst_n falls, and while rst_n is low.
// -----------------------------------------------------------------------------
module basechili_dff #(
  parameter int               WIDTH     = 1,    // data width in bits
  parameter logic [WIDTH-1:0] RESET_VAL = '0    // value loaded on reset
) (
  input  logic             clk,
  input  logic             rst_n,   // async, active-low
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= RESET_VAL;
    else        q <= d;
  end

endmodule
