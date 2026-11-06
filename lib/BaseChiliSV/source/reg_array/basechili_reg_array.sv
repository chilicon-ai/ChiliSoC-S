// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_reg_array
//
// Flop-based memory: DEPTH entries of WIDTH bits, N_WR synchronous write
// ports and N_RD combinational read ports. Entry i resets to
// RESET_VAL[i*WIDTH +: WIDTH] (default all zero).
// Write port p uses we[p], waddr[p*AW +: AW], wdata[p*WIDTH +: WIDTH]; read
// port r uses raddr[r*AW +: AW] and drives rdata[r*WIDTH +: WIDTH].
// A read address >= DEPTH returns zero; a write address >= DEPTH is dropped.
// Two ports writing one entry in the same cycle: the highest-numbered port
// wins.
//
// Timing: rdata follows raddr combinationally. A write is visible on rdata
//         the cycle after we (no write-to-read bypass).
// CLOCK_GATE = 1 stores each entry in a basechili_dffe_cg (one clock gate per
// entry instead of a feedback mux per bit); test_en opens the gates.
//
// Debug : entry i is mem[i*WIDTH +: WIDTH] (register g_entry[i].u_entry);
//         whsel[i*N_WR +: N_WR] are the ports that write it this cycle.
// -----------------------------------------------------------------------------
module basechili_reg_array #(
  parameter  int WIDTH = 32,                          // entry width in bits
  parameter  int DEPTH = 4,                           // number of entries
  parameter  int N_RD  = 1,                           // number of read ports
  parameter  int N_WR  = 1,                           // number of write ports
  parameter  bit CLOCK_GATE = 1'b0,                   // 1: entries are clock-gated registers (basechili_dffe_cg)
  parameter  logic [DEPTH*WIDTH-1:0] RESET_VAL = '0,  // reset value, entry i at [i*WIDTH +: WIDTH]
  localparam int AW    = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input  logic                  clk,
  input  logic                  rst_n,   // async, active-low
  input  logic                  test_en, // scan / test: open the entry clock gates (CLOCK_GATE)
  input  logic [N_WR-1:0]       we,
  input  logic [N_WR*AW-1:0]    waddr,
  input  logic [N_WR*WIDTH-1:0] wdata,
  input  logic [N_RD*AW-1:0]    raddr,
  output logic [N_RD*WIDTH-1:0] rdata
);

  logic [N_WR*DEPTH-1:0]  wsel;   // port p's one-hot write address at [p*DEPTH +: DEPTH]
  logic [DEPTH*N_WR-1:0]  whsel;  // entry i written by port p: whsel[i*N_WR + p]
  logic [DEPTH-1:0]       wen;    // per-entry write enable
  logic [DEPTH*WIDTH-1:0] wd;     // per-entry write data (highest writing port)
  logic [DEPTH*WIDTH-1:0] mem;    // entry i at mem[i*WIDTH +: WIDTH]

  for (genvar p = 0; p < N_WR; p++) begin : g_wdec
    basechili_decoder #(.N(DEPTH)) u_wdec (
      .in  (waddr[p*AW +: AW]),
      .out (wsel[p*DEPTH +: DEPTH])
    );
  end

  always_comb begin
    for (int i = 0; i < DEPTH; i++) begin
      wd[i*WIDTH +: WIDTH] = wdata[0 +: WIDTH];
      for (int p = 0; p < N_WR; p++) begin
        whsel[i*N_WR + p] = wsel[p*DEPTH + i] & we[p];
        if (whsel[i*N_WR + p]) wd[i*WIDTH +: WIDTH] = wdata[p*WIDTH +: WIDTH];
      end
      wen[i] = |whsel[i*N_WR +: N_WR];
    end
  end

  for (genvar i = 0; i < DEPTH; i++) begin : g_entry
    basechili_dffe_cg #(.WIDTH(WIDTH), .RESET_VAL(RESET_VAL[i*WIDTH +: WIDTH]), .GATE(CLOCK_GATE)) u_entry (
      .clk     (clk),
      .rst_n   (rst_n),
      .test_en (test_en),
      .en      (wen[i]),
      .d       (wd[i*WIDTH +: WIDTH]),
      .q       (mem[i*WIDTH +: WIDTH])
    );
  end

  for (genvar r = 0; r < N_RD; r++) begin : g_rd
    basechili_regular_mux #(.WIDTH(WIDTH), .N(DEPTH)) u_rmux (
      .in  (mem),
      .sel (raddr[r*AW +: AW]),
      .out (rdata[r*WIDTH +: WIDTH])
    );
  end

endmodule
