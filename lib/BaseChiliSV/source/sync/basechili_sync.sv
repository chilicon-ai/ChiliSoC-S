// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_sync
//
// Multi-flop synchronizer: brings an asynchronous level signal into the clk
// domain through a chain of STAGES flops (u_stg[0] samples d). Each bit is
// synchronized on its own, so a multi-bit d is only safe when at most one
// bit changes at a time (e.g. a Gray-coded pointer).
//
// Timing: q follows a stable d after STAGES rising edges (STAGES-1 plus the
//         metastability window of the first flop).
// Reset : every stage = RESET_VAL while rst_n is low.
// Debug : g_stg[0].u_stg.q is the metastable flop; never use it directly.
// -----------------------------------------------------------------------------
module basechili_sync #(
  parameter int               WIDTH     = 1,    // number of independent bits
  parameter int               STAGES    = 2,    // flops in the chain, >= 2
  parameter logic [WIDTH-1:0] RESET_VAL = '0    // value of every stage on reset
) (
  input  logic             clk,
  input  logic             rst_n,   // async, active-low
  input  logic [WIDTH-1:0] d,       // asynchronous input
  output logic [WIDTH-1:0] q        // synchronized to clk
);

  logic [(STAGES+1)*WIDTH-1:0] chain;   // stage k input at chain[k*WIDTH +: WIDTH]

  assign chain[0 +: WIDTH] = d;

  for (genvar k = 0; k < STAGES; k++) begin : g_stg
    basechili_dff #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) u_stg (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (chain[k*WIDTH +: WIDTH]),
      .q     (chain[(k+1)*WIDTH +: WIDTH])
    );
  end

  assign q = chain[STAGES*WIDTH +: WIDTH];

endmodule
