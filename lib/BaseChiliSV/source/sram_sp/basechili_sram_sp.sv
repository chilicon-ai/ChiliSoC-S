// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_sram_sp
//
// Single-port synchronous SRAM, DEPTH words of WIDTH bits with byte (or
// BYTE_W-bit) write enables. Storage primitive: the behavioural model that
// synthesis maps to FPGA block RAM or flops, and the place an ASIC flow
// swaps in a technology macro with the same ports. Matches the mem_* port of
// basechili_ahb_sram.
//
//   req && we  : write wdata lanes with be set to mem[addr]
//   req && !we : read; rdata = mem[addr] the next cycle
//   otherwise  : rdata holds (also during writes: "no change" mode)
//
// The memory array (mem) and rdata have no reset, like an SRAM: their values
// are unknown until written. This and basechili_reg_array's flops are the
// library's two memories (basechili_sram_2p is the two-port variant); with
// it, the one exception to the single-dimension rule, so tools infer RAM.
//
// Timing    : rdata is registered, one cycle after a read request; a write
//             is visible to a read in the next cycle.
// Debug     : wrong read data -> mem[addr] and the be of the last write to
//             it; rdata changing without a read -> req / we.
// -----------------------------------------------------------------------------
module basechili_sram_sp #(
  parameter  int WIDTH  = 32,                  // word width in bits
  parameter  int DEPTH  = 1024,                // words
  parameter  int BYTE_W = 8,                   // bits per write-enable lane (WIDTH multiple)
  localparam int N_BE   = WIDTH / BYTE_W,      // write-enable lanes
  localparam int AW     = (DEPTH > 1) ? $clog2(DEPTH) : 1
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

  always_ff @(posedge clk) begin
    if (req && we) begin
      for (int l = 0; l < N_BE; l++)
        if (be[l]) mem[addr][l*BYTE_W +: BYTE_W] <= wdata[l*BYTE_W +: BYTE_W];
    end
    if (req && !we) rdata <= mem[addr];
  end

endmodule
