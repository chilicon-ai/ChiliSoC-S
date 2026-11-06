// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S FPGA :: basechili_clock_gate (Xilinx 7-series BUFGCE version)
//
// Replaces lib/BaseChiliSV/source/clock_gate/basechili_clock_gate.sv in the
// FPGA file list only (fpga/build.py): same module name and ports, so the
// SoC RTL is unchanged. The library's latch + AND gate does not belong in an
// FPGA's fabric; a BUFGCE gates the clock on the global clock network,
// glitch-free (CE is sampled on the falling edge of I). With RF_LATCH = 0 the
// one user in the SoC is ChillU-S's sleep gate (chillus_core u_cg), so this
// costs one BUFG.
//
// Timing    : en (or test_en) high in the cycle before a rising clk edge
//             gives that gclk pulse, as the library version. gclk is a second
//             global clock behind clk's BUFG; Vivado times the paths between
//             them with that skew.
// Invariants: gclk is clk or low; it never glitches.
// Debug     : missing gclk pulse -> ce at the falling clk edge before it.
// -----------------------------------------------------------------------------
module basechili_clock_gate (
  input  logic clk,
  input  logic en,        // enable for the next clk high phase
  input  logic test_en,   // scan / test override: clock always on
  output logic gclk       // gated clock
);

  logic ce;   // BUFGCE clock enable: en || test_en

  assign ce = en || test_en;

  BUFGCE u_bufgce (.I(clk), .CE(ce), .O(gclk));

endmodule
