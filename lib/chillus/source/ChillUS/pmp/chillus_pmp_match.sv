// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_pmp_match
//
// One PMP entry against one 4-byte grain (riscv-privileged.pdf 3.7.1.1,
// G = 0): does entry pmpaddr = pa with mode A cover the word address a
// (address bits [XLEN-1:2])? pmpaddr holds address bits [XLEN+1:2], so a is
// compared zero-extended.
//   OFF   never
//   TOR   lo <= a < pa (lo: the previous entry's pmpaddr, 0 for entry 0)
//   NA4   a == pa
//   NAPOT a == pa outside napot_ign (= pa ^ (pa + 1): the trailing ones and
//         the bit above them)
//
// Timing   : combinational.
// Debug    : wrong match -> mode, a_x against pa / lo, napot_ign.
// -----------------------------------------------------------------------------
module chillus_pmp_match #(
  parameter int XLEN = 32                        // register and address width
) (
  input  logic [1:0]      mode,                  // A: 0 OFF, 1 TOR, 2 NA4, 3 NAPOT
  input  logic [XLEN-3:0] a,                     // word address checked
  input  logic [XLEN-1:0] pa,                    // pmpaddr of the entry
  input  logic [XLEN-1:0] lo,                    // TOR base (previous pmpaddr, or 0)
  input  logic [XLEN-1:0] napot_ign,             // NAPOT: bits of pa that are ignored
  output logic            match                  // the entry covers a
);

  logic [XLEN-1:0] a_x;             // a zero-extended to pmpaddr's width

  assign a_x = {2'b00, a};

  always_comb begin
    case (mode)
      2'd1:    match = (a_x >= lo) && (a_x < pa);
      2'd2:    match = (a_x == pa);
      2'd3:    match = ((a_x ^ pa) & ~napot_ign) == '0;
      default: match = 1'b0;
    endcase
  end

endmodule
