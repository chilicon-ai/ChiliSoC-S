// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_dffe_cg
//
// Register with enable, built from a clock gate and plain flops instead of an
// enable flop: the WIDTH flops of basechili_dff are clocked by a
// basechili_clock_gate whose enable is en, so q holds by not being clocked
// rather than through a feedback mux on every bit. Same function as
// basechili_dffe; cheaper when WIDTH is a few bits or more and the target
// library has no enable flop (one gate replaces WIDTH 2-input muxes), and the
// held bits draw no clock power.
// GATE = 0 builds a basechili_dffe instead (FPGA or a flow without clock
// gating); test_en is then unused.
//
// Timing: q takes d on a rising clk edge where en (or test_en) is high;
//         otherwise q holds. en must settle before the rising edge at the
//         clock gate, which sits ahead of the flops in the clock tree: the
//         gate's latch closes on that edge.
// Reset : q = RESET_VAL as soon as rst_n falls, and while rst_n is low
//         (asynchronous, also while the clock is gated). The gate is open
//         while rst_n is low, so a simulation that starts with rst_n already
//         low (no falling edge) still resets the flops at the first edge.
// Debug : q does not load -> u_cg.en_l at the rising edge (GATE = 1), it
//         must have been high while clk was low.
// -----------------------------------------------------------------------------
module basechili_dffe_cg #(
  parameter int               WIDTH     = 1,    // data width in bits
  parameter logic [WIDTH-1:0] RESET_VAL = '0,   // value loaded on reset
  parameter bit               GATE      = 1'b1  // 1: clock gate + flops, 0: enable flops
) (
  input  logic             clk,
  input  logic             rst_n,     // async, active-low
  input  logic             test_en,   // scan / test: clock always on (GATE = 1)
  input  logic             en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);

  if (GATE) begin : g_gate
    logic cg_en;  // en, or reset: the flops see clock edges while rst_n is low
    logic gclk;   // clk, one high phase per edge where cg_en (or test_en) is high

    assign cg_en = en || !rst_n;

    basechili_clock_gate u_cg (
      .clk     (clk),
      .en      (cg_en),
      .test_en (test_en),
      .gclk    (gclk)
    );

    basechili_dff #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) u_q (
      .clk   (gclk),
      .rst_n (rst_n),
      .d     (d),
      .q     (q)
    );
  end else begin : g_mux
    basechili_dffe #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL)) u_q (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (en),
      .d     (d),
      .q     (q)
    );
  end

endmodule
