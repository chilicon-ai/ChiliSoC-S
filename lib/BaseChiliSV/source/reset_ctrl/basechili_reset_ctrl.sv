// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_reset_ctrl
//
// Reset sequencer for N reset domains of one clock (SoC control unit). When
// rst_n_async falls every domain enters reset at once (asynchronously).
// After it rises (synchronized by basechili_reset_sync), the domains leave
// reset one at a time in index order, STEP clk cycles apart: domain 0 first
// (e.g. the bus fabric), then 1 (peripherals), then 2 (the core), ...
// sw_rst[i] holds domain i in reset (software reset, synchronous); it leaves
// reset again the cycle after sw_rst[i] falls once its turn has come.
// test_en passes rst_n_async straight to every output (scan).
//
//   domain i released when  step >= i + 1  and  !sw_rst[i]
//
// Timing    : rst_n_out is registered (except in test mode): assertion is
//             asynchronous, release is synchronous to clk; domain i is
//             released STAGES + (i + 1) * STEP cycles after rst_n_async
//             rises.
// Invariants: rst_n_out[i] high implies rst_n_out[j] high for every j < i
//             unless sw_rst is in use; step never decreases while srst_n is
//             high.
// Debug     : a domain never leaves reset -> srst_n (u_sync), step
//             (u_step.count) and sw_rst; wrong order -> release_d.
// -----------------------------------------------------------------------------
module basechili_reset_ctrl #(
  parameter  int N      = 3,                            // reset domains
  parameter  int STEP   = 16,                           // clk cycles between releases, >= 1
  parameter  int STAGES = 2,                            // reset synchronizer flops, >= 2
  localparam int SW     = $clog2(N + 1),                // step bits (0 .. N)
  localparam int CW     = (STEP > 1) ? $clog2(STEP) : 1 // cycle count bits
) (
  input  logic         clk,
  input  logic         rst_n_async,     // power-on / external reset, async, active-low
  input  logic         test_en,         // scan: rst_n_out = rst_n_async
  input  logic [N-1:0] sw_rst,          // hold domain i in reset (synchronous)
  output logic [N-1:0] rst_n_out,       // domain resets, active-low
  output logic         done             // every domain has had its turn
);

  localparam logic [SW-1:0] LAST_STEP = SW'(N);          // every domain released
  localparam logic [CW-1:0] LAST_CYC  = CW'(STEP - 1);   // last cycle of a step

  logic          srst_n;      // synchronized reset: async assert, sync release
  logic [SW-1:0] step;        // domains whose turn has come
  logic [SW-1:0] step_d;      // next step
  logic [CW-1:0] cyc;         // cycles in the current step
  logic          cyc_clr;     // cyc restarts (step end, or done)
  logic          step_end;    // last cycle of a step
  logic          running;     // not every domain released yet
  logic [N-1:0]  release_d;   // domain i out of reset next cycle
  logic [N-1:0]  rel;         // registered release

  basechili_reset_sync #(.STAGES(STAGES)) u_sync (
    .clk         (clk),
    .rst_n_async (rst_n_async),
    .test_en     (test_en),
    .rst_n_sync  (srst_n)
  );

  assign running  = step != LAST_STEP;
  assign step_end = running && (cyc == LAST_CYC);
  assign cyc_clr  = !running || step_end;

  basechili_counter #(.WIDTH(CW)) u_cyc (
    .clk   (clk),
    .rst_n (srst_n),
    .clr   (cyc_clr),
    .en    (1'b1),
    .count (cyc)
  );

  basechili_updown_counter #(.WIDTH(SW)) u_step (
    .clk      (clk),
    .rst_n    (srst_n),
    .load     (1'b0),
    .load_val ('0),
    .inc      (step_end),
    .dec      (1'b0),
    .count    (step),
    .count_d  (step_d)
  );

  always_comb begin
    for (int i = 0; i < N; i++) release_d[i] = (step_d > unsigned'(SW'(i))) && !sw_rst[i];
  end

  basechili_dff #(.WIDTH(N)) u_rel (
    .clk   (clk),
    .rst_n (srst_n),
    .d     (release_d),
    .q     (rel)
  );

  assign rst_n_out = test_en ? {N{rst_n_async}} : rel;
  assign done      = !running;

endmodule
