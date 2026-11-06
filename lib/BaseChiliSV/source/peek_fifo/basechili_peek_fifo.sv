// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_peek_fifo
//
// Circular-buffer FIFO with an explicit occupancy count, synchronous flush
// and a PEEK-entry read window. rdata[i*WIDTH +: WIDTH] is the i-th oldest
// entry (0 = head); it is meaningful only when count > i. pop removes the
// head entry. flush empties the FIFO and has priority over push and pop.
//
// Timing    : rdata follows the head combinationally. push / pop / flush
//             change count and rdata the cycle after (no push-to-read bypass).
// Invariants: count <= DEPTH; wr_ptr == (rd_ptr + count) mod DEPTH.
// Debug     : count > DEPTH or a corrupted head entry means the user pushed
//             while full (without a pop) or popped while empty; neither is
//             checked in RTL. Entry k of the storage is u_mem.mem[k*WIDTH +:
//             WIDTH]; the head is entry rd_ptr.
// -----------------------------------------------------------------------------
module basechili_peek_fifo #(
  parameter  int WIDTH = 32,                          // entry width in bits
  parameter  int DEPTH = 4,                           // number of entries
  parameter  int PEEK  = 2,                           // entries visible at the head
  parameter  bit CLOCK_GATE = 1'b0,                   // 1: clock-gated entries (basechili_reg_array)
  localparam int AW    = (DEPTH > 1) ? $clog2(DEPTH) : 1,
  localparam int CNT_W = $clog2(DEPTH + 1)
) (
  input  logic                  clk,
  input  logic                  rst_n,   // async, active-low
  input  logic                  test_en, // scan / test: open the entry clock gates (CLOCK_GATE)
  input  logic                  flush,   // sync empty
  input  logic                  push,
  input  logic [WIDTH-1:0]      wdata,
  input  logic                  pop,
  output logic [PEEK*WIDTH-1:0] rdata,
  output logic [CNT_W-1:0]      count,   // number of valid entries
  output logic                  full,
  output logic                  empty
);

  logic [AW-1:0]      wr_ptr;   // storage entry written by the next push (tail)
  logic [AW-1:0]      rd_ptr;   // storage entry holding the head
  logic [PEEK*AW-1:0] raddr;    // window entry i reads (rd_ptr + i) mod DEPTH
  logic [AW:0]        rsum;     // rd_ptr + i before wrap

  basechili_mod_counter #(.MOD(DEPTH)) u_wr_ptr (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (flush),
    .en    (push),
    .count (wr_ptr)
  );

  basechili_mod_counter #(.MOD(DEPTH)) u_rd_ptr (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (flush),
    .en    (pop),
    .count (rd_ptr)
  );

  // Occupancy is tracked explicitly, so rd_ptr == wr_ptr is never ambiguous.
  basechili_updown_counter #(.WIDTH(CNT_W)) u_count (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (flush),
    .load_val ('0),
    .inc      (push),
    .dec      (pop),
    .count    (count),
    .count_d  ()
  );

  always_comb begin
    rsum  = '0;
    raddr = '0;
    for (int i = 0; i < PEEK; i++) begin
      rsum = {1'b0, rd_ptr} + unsigned'((AW+1)'(i));
      if (rsum >= unsigned'((AW+1)'(DEPTH))) rsum = rsum - unsigned'((AW+1)'(DEPTH));
      raddr[i*AW +: AW] = rsum[AW-1:0];
    end
  end

  basechili_reg_array #(.WIDTH(WIDTH), .DEPTH(DEPTH), .N_RD(PEEK), .CLOCK_GATE(CLOCK_GATE)) u_mem (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (test_en),
    .we      (push),
    .waddr   (wr_ptr),
    .wdata   (wdata),
    .raddr   (raddr),
    .rdata   (rdata)
  );

  assign full  = (count == unsigned'(CNT_W'(DEPTH)));
  assign empty = (count == '0);

endmodule
