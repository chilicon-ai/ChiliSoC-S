// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S ORFS :: basechili_sram_sp (Nangate45 macro version)
//
// Replaces lib/BaseChiliSV/source/sram_sp/basechili_sram_sp.sv in the ORFS
// file list only (config.mk): same module name, parameters and ports, so the
// SoC RTL is unchanged. A 32-bit memory whose depth is a multiple of 1024 is
// built from fakeram45_1024x32 macros (one bank per 1024 words, bank = the
// address bits above the low 10); the ChillU-S instruction cache's arrays
// (ICACHE_KB) map as in chillus' own ORFS flow: 64 words of up to 32 bits to
// fakeram45_64x32, multiples of 256 words of 32 bits to fakeram45_256x32 banks; any other shape
// keeps the behavioural array (flops). The macros only stand in for a real SRAM compiler's output:
// their area and pin timing come from the platform's fakeram45 models.
//
//   req && we  : write the lanes with be set in the addressed bank
//   req && !we : read the addressed bank; rdata = mem[addr] the next cycle
//   otherwise  : rdata holds (every bank holds rd_out, bank_q holds)
//
// Timing    : rdata is registered (macro output), one cycle after a read
//             request, through a bank mux selected by bank_q.
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
  localparam int  MD    = 1024;                // words per macro
  localparam int  MW    = 32;                  // macro width
  localparam bit  MACRO = (WIDTH == MW) && (DEPTH % MD == 0);
  localparam int  NB    = MACRO ? DEPTH / MD : 1;   // banks
  localparam int  BW    = (NB > 1) ? $clog2(NB) : 1;

  logic [MW-1:0] wmask_s;                      // small macros: per-bit write mask (padded)
  logic [MW-1:0] wd_s;                         // small macros: write data (padded)
  for (genvar b = 0; b < MW; b++) begin : g_pad
    if (b < WIDTH) begin : g_used
      assign wmask_s[b] = be[b / BYTE_W];
      assign wd_s[b]    = wdata[b];
    end else begin : g_zero
      assign wmask_s[b] = 1'b0;
      assign wd_s[b]    = 1'b0;
    end
  end

  if (MACRO) begin : g_macro
    logic [BW-1:0]    bank;                    // addressed bank
    logic [BW-1:0]    bank_q;                  // bank of the last read
    logic             rd;                      // read this cycle (bank_q enable)
    logic [MW-1:0]    wmask;                   // per-bit write mask from be
    logic [NB-1:0]    ce;                      // macro selects
    logic [NB*MW-1:0] rd_out;                  // every macro's read data
    logic             one;                     // bank_q reset (none: like the array)

    if (NB > 1) begin : g_bank
      assign bank = addr[AW-1:10];
    end else begin : g_one
      assign bank = '0;
    end
    assign rd  = req && !we;
    assign one = 1'b1;
    for (genvar b = 0; b < MW; b++) begin : g_mask
      assign wmask[b] = be[b / BYTE_W];
    end

    basechili_dffe #(.WIDTH(BW)) u_bank (
      .clk   (clk),
      .rst_n (one),
      .en    (rd),
      .d     (bank),
      .q     (bank_q)
    );

    for (genvar i = 0; i < NB; i++) begin : g_ram
      assign ce[i] = req && (bank == BW'(i));
      fakeram45_1024x32 u_mem (
        .clk       (clk),
        .ce_in     (ce[i]),
        .we_in     (we),
        .addr_in   (addr[9:0]),
        .wd_in     (wdata),
        .w_mask_in (wmask),
        .rd_out    (rd_out[i*MW +: MW])
      );
    end

    assign rdata = rd_out[bank_q*MW +: MW];
  end else if (DEPTH == 64 && WIDTH <= MW) begin : g_64
    logic [MW-1:0] rd_out;                     // macro read data
    fakeram45_64x32 u_mem (
      .clk       (clk),
      .ce_in     (req),
      .we_in     (we),
      .addr_in   (addr),
      .wd_in     (wd_s),
      .w_mask_in (wmask_s),
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
      .wd_in     (wd_s),
      .w_mask_in (wmask_s),
      .rd_out    (rd_out)
    );
    assign rdata = rd_out[WIDTH-1:0];
  end else if (WIDTH == MW && DEPTH % 256 == 0) begin : g_256
    localparam int NS  = DEPTH / 256;          // 256-word banks
    localparam int SBW = (NS > 1) ? $clog2(NS) : 1;
    logic [SBW-1:0]   sbank;                   // addressed bank
    logic [SBW-1:0]   sbank_q;                 // bank of the last read
    logic             rd;                      // read this cycle (sbank_q enable)
    logic [NS-1:0]    ce;                      // macro selects
    logic [NS*MW-1:0] rd_out;                  // every macro's read data
    logic             one;                     // sbank_q reset (none: like the array)

    if (NS > 1) begin : g_bank
      assign sbank = addr[AW-1:8];
    end else begin : g_one
      assign sbank = '0;
    end
    assign rd  = req && !we;
    assign one = 1'b1;

    basechili_dffe #(.WIDTH(SBW)) u_bank (
      .clk   (clk),
      .rst_n (one),
      .en    (rd),
      .d     (sbank),
      .q     (sbank_q)
    );

    for (genvar i = 0; i < NS; i++) begin : g_ram
      assign ce[i] = req && (sbank == SBW'(i));
      fakeram45_256x32 u_mem (
        .clk       (clk),
        .ce_in     (ce[i]),
        .we_in     (we),
        .addr_in   (addr[7:0]),
        .wd_in     (wd_s),
        .w_mask_in (wmask_s),
        .rd_out    (rd_out[i*MW +: MW])
      );
    end

    assign rdata = rd_out[sbank_q*MW +: MW];
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
