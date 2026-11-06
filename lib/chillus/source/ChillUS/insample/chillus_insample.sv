// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_insample
//
// Input sample registers for the core's sideband inputs: interrupts,
// debug_req and fetch_enable go into one flop each before any logic (0 logic levels, pipeline
// spec), so the platform drives a flop and the core's long interrupt / sleep
// cones start at a register.
//
// clk is the core's ungated clock: the interrupts and debug_req wake the core
// from WFI sleep (chillus_trap irq_wake, chillus_ctrl wake / clk_en), so their
// samples keep updating while the sleep clock gate (chillus_core u_cg) stops
// the rest of the core. These are the only flops on the free clock.
//
// Timing
//   Every output is registered: an input change shows on the outputs one
//   clock edge later (one cycle of interrupt / wake latency).
//
// Invariants
//   Each output equals its input one clock edge earlier; all 0 after reset.
// -----------------------------------------------------------------------------
module chillus_insample #(
  parameter int NF = 15                      // number of fast interrupts (irq_fast)
) (
  input  logic          clk,                 // ungated core clock
  input  logic          rst_n,               // async, active-low
  // from the platform
  input  logic          irq_software,
  input  logic          irq_timer,
  input  logic          irq_external,
  input  logic [NF-1:0] irq_fast,
  input  logic          irq_nmi,
  input  logic          debug_req,
  input  logic          fetch_enable,
  // sampled, to the core
  output logic          irq_software_q,
  output logic          irq_timer_q,
  output logic          irq_external_q,
  output logic [NF-1:0] irq_fast_q,
  output logic          irq_nmi_q,
  output logic          debug_req_q,
  output logic          fetch_enable_q
);

  localparam int W = NF + 6;

  logic [W-1:0] in_d;   // all inputs, one vector
  logic [W-1:0] in_q;   // their samples

  assign in_d = {irq_software, irq_timer, irq_external, irq_fast, irq_nmi,
                 debug_req, fetch_enable};

  basechili_dff #(.WIDTH(W)) u_in (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (in_d),
    .q     (in_q)
  );

  assign {irq_software_q, irq_timer_q, irq_external_q, irq_fast_q, irq_nmi_q,
          debug_req_q, fetch_enable_q} = in_q;

endmodule
