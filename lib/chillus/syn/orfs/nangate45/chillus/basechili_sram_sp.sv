// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S ORFS :: basechili_sram_sp (Nangate45 macro version)
//
// Replaces lib/BaseChiliSV/source/sram_sp/basechili_sram_sp.sv in the ORFS
// file list only (config.mk): same module name, parameters and ports, so the
// core RTL is unchanged. Maps the instruction cache arrays (chillus_icache)
// to fakeram45 macros:
//   DEPTH  64, WIDTH <= 32      : one fakeram45_64x32 (unused bits tied 0)
//   DEPTH 128, WIDTH <= 32      : one fakeram45_128x32
//   DEPTH k*256, WIDTH == 32    : k fakeram45_256x32 banks (bank = high address bits)
// Any other shape keeps the behavioural array (flops). The macros only stand
// in for a real SRAM compiler's output: area and pin timing come from the
// platform's fakeram45 models.
//
// Timing    : rdata is registered (macro output), one cycle after a read,
//             through a bank mux selected by bank_q when there are banks.
// Invariants: at most one macro has ce_in high in a cycle.
// Debug     : wrong read data -> bank_q, the bank's ce_in / we_in / addr_in.
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
  localparam int MW = 32;                      // macro width

  logic [MW-1:0] wmask;                        // per-bit write mask from be (padded)
  logic [MW-1:0] wd;                           // write data (padded)

  for (genvar b = 0; b < MW; b++) begin : g_mask
    if (b < WIDTH) begin : g_used
      assign wmask[b] = be[b / BYTE_W];
      assign wd[b]    = wdata[b];
    end else begin : g_pad
      assign wmask[b] = 1'b0;
      assign wd[b]    = 1'b0;
    end
  end

  if (DEPTH == 64 && WIDTH <= MW) begin : g_64
    logic [MW-1:0] rd_out;                     // macro read data
    fakeram45_64x32 u_mem (
      .clk       (clk),
      .ce_in     (req),
      .we_in     (we),
      .addr_in   (addr),
      .wd_in     (wd),
      .w_mask_in (wmask),
      .rd_out    (rd_out)
    );
    assign rdata = rd_out[WIDTH-1:0];
  end else if (DEPTH == 128 && WIDTH <= MW) begin : g_128
    logic [MW-1:0] rd_out;                     // macro read data
    fakeram45_128x32 u_mem (
      .clk       (clk),
      .ce_in     (req),
      .we_in     (we),
      .addr_in   (addr),
      .wd_in     (wd),
      .w_mask_in (wmask),
      .rd_out    (rd_out)
    );
    assign rdata = rd_out[WIDTH-1:0];
  end else if (WIDTH == MW && DEPTH % 256 == 0) begin : g_256
    localparam int NB = DEPTH / 256;           // banks
    localparam int BW = (NB > 1) ? $clog2(NB) : 1;
    logic [BW-1:0]    bank;                    // addressed bank
    logic [BW-1:0]    bank_q;                  // bank of the last read
    logic             rd;                      // read this cycle (bank_q enable)
    logic [NB-1:0]    ce;                      // macro selects
    logic [NB*MW-1:0] rd_out;                  // every macro's read data
    logic             one;                     // bank_q reset (none: like the array)

    if (NB > 1) begin : g_bank
      assign bank = addr[AW-1:8];
    end else begin : g_one
      assign bank = '0;
    end
    assign rd  = req && !we;
    assign one = 1'b1;

    basechili_dffe #(.WIDTH(BW)) u_bank (
      .clk   (clk),
      .rst_n (one),
      .en    (rd),
      .d     (bank),
      .q     (bank_q)
    );

    for (genvar i = 0; i < NB; i++) begin : g_ram
      assign ce[i] = req && (bank == BW'(i));
      fakeram45_256x32 u_mem (
        .clk       (clk),
        .ce_in     (ce[i]),
        .we_in     (we),
        .addr_in   (addr[7:0]),
        .wd_in     (wd),
        .w_mask_in (wmask),
        .rd_out    (rd_out[i*MW +: MW])
      );
    end

    assign rdata = rd_out[bank_q*MW +: MW];
  end else begin : g_flops
    logic [WIDTH-1:0] mem [DEPTH];             // the memory array
    always_ff @(posedge clk) begin
      if (req && we) begin
        for (int l = 0; l < N_BE; l++)
          if (be[l]) mem[addr][l*BYTE_W +: BYTE_W] <= wdata[l*BYTE_W +: BYTE_W];
      end
      if (req && !we) rdata <= mem[addr];
    end
  end
endmodule
