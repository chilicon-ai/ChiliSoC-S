// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_decoder
//
// Address decoder: one HSEL per subordinate region. Region i matches when
// (addr & MASK[i]) == BASE[i]; regions should not overlap. When none
// matches, sel_default is high (connect it to basechili_ahb_default_sub).
// Also usable as the PSEL decoder of an APB bus.
//
// Region i occupies BASE[i*ADDR_W +: ADDR_W] and MASK[i*ADDR_W +: ADDR_W].
// Example (ADDR_W = 32): a 64 KiB region at 0x1000_0000 has
// BASE 32'h1000_0000, MASK 32'hFFFF_0000.
//
// Timing    : combinational from addr.
// Invariants: sel is zero or one-hot (non-overlapping regions);
//             sel_default == (sel == 0).
// Debug     : wrong subordinate selected -> compare addr & MASK[i] with
//             BASE[i] for the region that should match.
// -----------------------------------------------------------------------------
module basechili_ahb_decoder #(
  parameter int                  ADDR_W = 32,     // address width
  parameter int                  N      = 2,      // number of regions
  parameter logic [N*ADDR_W-1:0] BASE   = '0,     // region base addresses
  parameter logic [N*ADDR_W-1:0] MASK   = '0      // region address masks
) (
  input  logic [ADDR_W-1:0] addr,
  output logic [N-1:0]      sel,           // region i matches
  output logic              sel_default    // no region matches
);

  always_comb begin
    for (int i = 0; i < N; i++)
      sel[i] = (addr & MASK[i*ADDR_W +: ADDR_W]) == BASE[i*ADDR_W +: ADDR_W];
  end

  assign sel_default = !(|sel);

endmodule
