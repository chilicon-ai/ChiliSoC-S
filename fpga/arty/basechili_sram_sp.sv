// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S FPGA :: basechili_sram_sp (block RAM version with an initial image)
//
// Replaces lib/BaseChiliSV/source/sram_sp/basechili_sram_sp.sv in the FPGA
// file list only (fpga/build.py): the library module plus INIT_FILE, a
// $readmemh image (32-bit words, one per line) that Vivado puts in the block
// RAM's initial contents. The board top sets it for the boot ROM alone
// (defparam u_soc.u_rom.INIT_FILE, from fpga/build.py); every other memory
// keeps "" and starts at zero, as block RAM does.
//
// Timing    : rdata is registered, one cycle after a read request; a write
//             is visible to a read in the next cycle.
// Invariants: as the library version.
// Debug     : the ROM does not boot -> INIT_FILE in the Vivado log (a missing
//             file is a warning there, and the ROM reads zero).
// -----------------------------------------------------------------------------
module basechili_sram_sp #(
  parameter  int    WIDTH     = 32,            // word width in bits
  parameter  int    DEPTH     = 1024,          // words
  parameter  int    BYTE_W    = 8,             // bits per write-enable lane (WIDTH multiple)
  parameter  string INIT_FILE = "",            // $readmemh image, "" for none
  localparam int    N_BE      = WIDTH / BYTE_W,  // write-enable lanes
  localparam int    AW        = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input  logic             clk,
  input  logic             req,                // access this cycle
  input  logic             we,                 // write (else read)
  input  logic [AW-1:0]    addr,               // word address (< DEPTH)
  input  logic [WIDTH-1:0] wdata,
  input  logic [N_BE-1:0]  be,                 // write lane enables
  output logic [WIDTH-1:0] rdata               // read data, cycle after the read
);

  logic [WIDTH-1:0] mem [DEPTH];               // the memory array

  initial begin
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  always_ff @(posedge clk) begin
    if (req && we) begin
      for (int l = 0; l < N_BE; l++)
        if (be[l]) mem[addr][l*BYTE_W +: BYTE_W] <= wdata[l*BYTE_W +: BYTE_W];
    end
    if (req && !we) rdata <= mem[addr];
  end

endmodule
