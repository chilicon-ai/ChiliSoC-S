// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S FPGA :: lint models of the Xilinx 7-series primitives
//
// Port-compatible stand-ins for the UNISIM primitives fpga/arty instantiates
// (only the ports and parameters used there), so fpga/build.py --lint can
// elaborate chilisocs_arty with slang. Never synthesized: Vivado uses its own
// UNISIM library. Behaviour is the simplest one that drives every output;
// the configuration parameters are declared for the board top and not used.
// -----------------------------------------------------------------------------
`pragma diagnostic push
`pragma diagnostic ignore="-Wunused-parameter"

module MMCME2_BASE #(
  parameter real CLKIN1_PERIOD    = 0.0,
  parameter real CLKFBOUT_MULT_F  = 5.0,
  parameter int  DIVCLK_DIVIDE    = 1,
  parameter real CLKOUT0_DIVIDE_F = 1.0
) (
  input  logic CLKIN1,
  input  logic CLKFBIN,
  input  logic RST,
  input  logic PWRDWN,
  output logic CLKFBOUT,
  output logic CLKFBOUTB,
  output logic CLKOUT0,
  output logic CLKOUT0B,
  output logic CLKOUT1,
  output logic CLKOUT1B,
  output logic CLKOUT2,
  output logic CLKOUT2B,
  output logic CLKOUT3,
  output logic CLKOUT3B,
  output logic CLKOUT4,
  output logic CLKOUT5,
  output logic CLKOUT6,
  output logic LOCKED
);
  assign CLKFBOUT  = CLKIN1;
  assign CLKFBOUTB = !CLKIN1;
  assign CLKOUT0   = CLKIN1;
  assign CLKOUT0B  = !CLKIN1;
  assign CLKOUT1   = CLKIN1;
  assign CLKOUT1B  = !CLKIN1;
  assign CLKOUT2   = CLKIN1;
  assign CLKOUT2B  = !CLKIN1;
  assign CLKOUT3   = CLKIN1;
  assign CLKOUT3B  = !CLKIN1;
  assign CLKOUT4   = CLKIN1;
  assign CLKOUT5   = CLKIN1;
  assign CLKOUT6   = CLKIN1;
  assign LOCKED    = !RST && !PWRDWN && CLKFBIN == CLKFBIN;
endmodule

module BUFG (input logic I, output logic O);
  assign O = I;
endmodule

module BUFGCE (input logic I, input logic CE, output logic O);
  assign O = I && CE;
endmodule

module OBUFT (input logic I, input logic T, output wire O);
  assign O = T ? 1'bz : I;
endmodule

module IOBUF (input logic I, input logic T, output logic O, inout wire IO);
  assign IO = T ? 1'bz : I;
  assign O  = IO;
endmodule

module STARTUPE2 #(
  parameter string PROG_USR      = "FALSE",
  parameter real   SIM_CCLK_FREQ = 0.0
) (
  output logic CFGCLK,
  output logic CFGMCLK,
  output logic EOS,
  output logic PREQ,
  input  logic CLK,
  input  logic GSR,
  input  logic GTS,
  input  logic KEYCLEARB,
  input  logic PACK,
  input  logic USRCCLKO,
  input  logic USRCCLKTS,
  input  logic USRDONEO,
  input  logic USRDONETS
);
  assign CFGCLK  = USRCCLKO && !USRCCLKTS;
  assign CFGMCLK = CLK;
  assign EOS     = !GSR && !GTS && KEYCLEARB;
  assign PREQ    = PACK && USRDONEO && USRDONETS;
endmodule

`pragma diagnostic pop
