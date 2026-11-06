// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S sim :: fakeram45_256x32 / 128x32 / 64x32 (gate-level simulation models)
//
// Behaviour of the small Nangate45 fakeram45 macros that the ORFS flow puts in
// for the ChillU-S instruction cache arrays (ICACHE_KB; see
// syn/orfs/nangate45/chilisocs/basechili_sram_sp.sv), matching
// basechili_sram_sp: a write updates the bits set in w_mask_in, a read gives
// rd_out the next cycle, rd_out holds otherwise. No preload: the cache sweeps
// its tags invalid after reset.
// -----------------------------------------------------------------------------
module fakeram45_256x32 (
  input  logic        clk,
  input  logic        ce_in,
  input  logic        we_in,
  input  logic [7:0]  addr_in,
  input  logic [31:0] wd_in,
  input  logic [31:0] w_mask_in,
  output logic [31:0] rd_out
);
  logic [31:0] mem [256];

  always_ff @(posedge clk)
    if (ce_in) begin
      if (we_in) mem[addr_in] <= (wd_in & w_mask_in) | (mem[addr_in] & ~w_mask_in);
      else       rd_out <= mem[addr_in];
    end
endmodule

module fakeram45_128x32 (
  input  logic        clk,
  input  logic        ce_in,
  input  logic        we_in,
  input  logic [6:0]  addr_in,
  input  logic [31:0] wd_in,
  input  logic [31:0] w_mask_in,
  output logic [31:0] rd_out
);
  logic [31:0] mem [128];

  always_ff @(posedge clk)
    if (ce_in) begin
      if (we_in) mem[addr_in] <= (wd_in & w_mask_in) | (mem[addr_in] & ~w_mask_in);
      else       rd_out <= mem[addr_in];
    end
endmodule

module fakeram45_64x32 (
  input  logic        clk,
  input  logic        ce_in,
  input  logic        we_in,
  input  logic [5:0]  addr_in,
  input  logic [31:0] wd_in,
  input  logic [31:0] w_mask_in,
  output logic [31:0] rd_out
);
  logic [31:0] mem [64];

  always_ff @(posedge clk)
    if (ce_in) begin
      if (we_in) mem[addr_in] <= (wd_in & w_mask_in) | (mem[addr_in] & ~w_mask_in);
      else       rd_out <= mem[addr_in];
    end
endmodule
