// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_latch_array
//
// Latch-based memory: DEPTH entries of WIDTH bits, one synchronous write port
// and N_RD combinational read ports; the same interface and timing as
// basechili_reg_array at a fraction of the area. A documented exception to
// the no-latch rule: the latches are storage only.
// Read port r uses raddr[r*AW +: AW] and drives rdata[r*WIDTH +: WIDTH].
// A read address >= DEPTH returns zero; a write address >= DEPTH is dropped.
//
// Write: at the rising clk edge where we is high, wdata is captured in a
// clock-gated register (u_wdata, basechili_dffe_cg) and the clock gate of
// entry waddr (g_entry[waddr].u_cg) opens its latches for that clk high
// phase; they close on the falling edge with the register's stable value.
// One WIDTH-bit register replaces DEPTH*WIDTH flops.
//
// Timing: rdata follows raddr combinationally. A write is visible on rdata
//         after the next rising edge (as basechili_reg_array), settling
//         shortly after it through the open latch.
// Reset : entries are not reset (undefined until written).
// Debug : entry i is mem[i*WIDTH +: WIDTH] (latch g_entry[i].u_entry). A
//         missed write -> wen[i] before the edge, then g_entry[i].gclk high
//         after it; a wrong value -> wdata_q.
// -----------------------------------------------------------------------------
module basechili_latch_array #(
  parameter  int WIDTH = 32,                          // entry width in bits
  parameter  int DEPTH = 4,                           // number of entries
  parameter  int N_RD  = 1,                           // number of read ports
  localparam int AW    = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input  logic                  clk,
  input  logic                  rst_n,     // async, active-low (write-data flop only)
  input  logic                  test_en,   // scan / test: open every clock gate
  input  logic                  we,
  input  logic [AW-1:0]         waddr,
  input  logic [WIDTH-1:0]      wdata,
  input  logic [N_RD*AW-1:0]    raddr,
  output logic [N_RD*WIDTH-1:0] rdata
);

  logic [DEPTH-1:0]       wsel;      // one-hot write address
  logic [DEPTH-1:0]       wen;       // per-entry write enable, before the edge
  logic [WIDTH-1:0]       wdata_q;   // write data, held through the write's clk high phase
  logic [DEPTH*WIDTH-1:0] mem;       // entry i at mem[i*WIDTH +: WIDTH]

  basechili_decoder #(.N(DEPTH)) u_wdec (
    .in  (waddr),
    .out (wsel)
  );

  assign wen = wsel & {DEPTH{we}};

  basechili_dffe_cg #(.WIDTH(WIDTH)) u_wdata (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (test_en),
    .en      (we),
    .d       (wdata),
    .q       (wdata_q)
  );

  for (genvar i = 0; i < DEPTH; i++) begin : g_entry
    logic gclk;   // entry clock: one high phase after a write edge

    basechili_clock_gate u_cg (
      .clk     (clk),
      .en      (wen[i]),
      .test_en (test_en),
      .gclk    (gclk)
    );

    basechili_latch #(.WIDTH(WIDTH)) u_entry (
      .en (gclk),
      .d  (wdata_q),
      .q  (mem[i*WIDTH +: WIDTH])
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
