// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_reset_sync
//
// Reset synchronizer: asserts rst_n_sync asynchronously as soon as
// rst_n_async falls, and releases it synchronously, STAGES rising clk edges
// after rst_n_async rises (a basechili_sync chain that resets to 0 and
// shifts in 1). test_en bypasses the chain (rst_n_sync = rst_n_async) so
// scan test controls the reset directly.
//
// Timing: rst_n_sync falls with rst_n_async (no clock needed); it rises on
//         the STAGES-th rising edge after rst_n_async rises.
// Debug : reset never released -> clk running? u_chain.chain shows the
//         ones shifting in.
// -----------------------------------------------------------------------------
module basechili_reset_sync #(
  parameter int STAGES = 2   // flops in the release chain, >= 2
) (
  input  logic clk,
  input  logic rst_n_async,   // asynchronous reset in, active-low
  input  logic test_en,       // scan / test: pass rst_n_async through
  output logic rst_n_sync     // assert async, deassert synchronous to clk
);

  logic released;   // the chain output: 1 STAGES edges after rst_n_async rises

  basechili_sync #(.WIDTH(1), .STAGES(STAGES)) u_chain (
    .clk   (clk),
    .rst_n (rst_n_async),
    .d     (1'b1),
    .q     (released)
  );

  assign rst_n_sync = test_en ? rst_n_async : released;

endmodule
