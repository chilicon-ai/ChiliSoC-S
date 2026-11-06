// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_pkg
//
// AMBA 5 AHB encodings shared by AHB modules.
// -----------------------------------------------------------------------------
package basechili_ahb_pkg;

  // HTRANS
  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_BUSY   = 2'b01;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
  localparam logic [1:0] HTRANS_SEQ    = 2'b11;

  // HBURST
  localparam logic [2:0] HBURST_SINGLE = 3'b000;
  localparam logic [2:0] HBURST_INCR   = 3'b001;
  localparam logic [2:0] HBURST_WRAP4  = 3'b010;
  localparam logic [2:0] HBURST_INCR4  = 3'b011;
  localparam logic [2:0] HBURST_WRAP8  = 3'b100;
  localparam logic [2:0] HBURST_INCR8  = 3'b101;
  localparam logic [2:0] HBURST_WRAP16 = 3'b110;
  localparam logic [2:0] HBURST_INCR16 = 3'b111;

  // HRESP
  localparam logic HRESP_OKAY  = 1'b0;
  localparam logic HRESP_ERROR = 1'b1;

  // HPROT (default: non-cacheable, non-bufferable, privileged, data access)
  localparam logic [3:0] HPROT_DEFAULT = 4'b0011;

endpackage
