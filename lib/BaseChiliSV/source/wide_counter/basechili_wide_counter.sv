// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_wide_counter
//
// Wide up counter (e.g. the 64-bit RISC-V mtime / cycle counter) split into
// a LO_W-bit low part and a high part so no carry ripples through all WIDTH
// bits in one cycle. The high part increments when the low part wraps, using
// a registered "low part is all ones" flag (lo_ones) computed one cycle ahead
// from a compare with all-ones minus one, so count is exact every cycle and
// the longest path is about one LO_W-bit (or WIDTH - LO_W-bit) increment.
//
// Software writes: load[w] loads word w (WORD_W bits) from load_val; any load
// wins over inc for that cycle (no increment while loading), the other
// words keep their value.
//
// Timing    : count is registered; an inc or load shows the cycle after.
// Invariants: lo_ones == (count[LO_W-1:0] == all ones).
// Debug     : high part off by one -> lo_ones (u_lo_ones.q) against the low
//             part; wrong value after a write -> load and load_val.
// -----------------------------------------------------------------------------
module basechili_wide_counter #(
  parameter  int WIDTH  = 64,                 // counter bits
  parameter  int LO_W   = 32,                 // low part bits, 1 .. WIDTH - 1
  parameter  int WORD_W = 32,                 // load granularity (divides WIDTH)
  localparam int N_WORD = WIDTH / WORD_W,     // loadable words
  localparam int HI_W   = WIDTH - LO_W        // high part bits
) (
  input  logic              clk,
  input  logic              rst_n,            // async, active-low
  input  logic              inc,              // count up by one
  input  logic [N_WORD-1:0] load,             // load word w from load_val
  input  logic [WIDTH-1:0]  load_val,
  output logic [WIDTH-1:0]  count
);

  localparam logic [LO_W-1:0] LO_MAX  = '1;              // low part all ones
  localparam logic [LO_W-1:0] LO_MAX1 = LO_MAX - 1'b1;   // ... minus one

  logic [WIDTH-1:0] mask;       // bits loaded this cycle
  logic             any_load;   // some word is loaded
  logic [WIDTH-1:0] loaded;     // count with the loaded words replaced
  logic [LO_W-1:0]  lo;         // low part
  logic [HI_W-1:0]  hi;         // high part
  logic [LO_W-1:0]  lo_d;       // next low part
  logic [HI_W-1:0]  hi_d;       // next high part
  logic             lo_ones;    // lo is all ones (registered, exact)
  logic             lo_ones_d;  // next lo_ones
  logic             cnt_en;     // count changes

  always_comb begin
    for (int b = 0; b < WIDTH; b++) mask[b] = load[b / WORD_W];
  end

  assign any_load = |load;
  assign loaded   = (count & ~mask) | (load_val & mask);

  always_comb begin
    if (any_load) begin
      lo_d      = loaded[LO_W-1:0];
      hi_d      = loaded[WIDTH-1:LO_W];
      lo_ones_d = loaded[LO_W-1:0] == LO_MAX;
    end else begin
      lo_d      = lo + 1'b1;
      hi_d      = lo_ones ? hi + 1'b1 : hi;
      lo_ones_d = lo == LO_MAX1;
    end
  end

  assign cnt_en = inc || any_load;

  basechili_dffe #(.WIDTH(LO_W)) u_lo (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cnt_en),
    .d     (lo_d),
    .q     (lo)
  );

  basechili_dffe #(.WIDTH(HI_W)) u_hi (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cnt_en),
    .d     (hi_d),
    .q     (hi)
  );

  basechili_dffe #(.WIDTH(1)) u_lo_ones (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cnt_en),
    .d     (lo_ones_d),
    .q     (lo_ones)
  );

  assign count = {hi, lo};

endmodule
