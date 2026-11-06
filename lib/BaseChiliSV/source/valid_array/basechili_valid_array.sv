// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_valid_array
//
// N per-entry valid bits (cache lines, TLB entries, buffer slots) with an
// indexed set port, an indexed clear port and a bulk flush:
//   flush            : every bit cleared (highest priority)
//   set_en, set_idx  : bit set_idx set
//   clr_en, clr_idx  : bit clr_idx cleared (set wins on the same index)
// An index >= N is ignored. Allocation helpers: full / empty, and free_idx,
// the lowest invalid entry (meaningful when !full).
//
// Timing: set / clr / flush change valid at the next rising edge; full,
//         empty and free_idx follow valid combinationally.
// Reset : all bits invalid.
// Debug : entry stuck valid -> clr_idx vs. a set_en to the same index in
//         the same cycle; u_valid.q holds the bits.
// -----------------------------------------------------------------------------
module basechili_valid_array #(
  parameter  int N    = 8,                         // number of entries
  localparam int IDX_W = (N > 1) ? $clog2(N) : 1
) (
  input  logic             clk,
  input  logic             rst_n,      // async, active-low
  input  logic             flush,      // clear every bit
  input  logic             set_en,
  input  logic [IDX_W-1:0] set_idx,
  input  logic             clr_en,
  input  logic [IDX_W-1:0] clr_idx,
  output logic [N-1:0]     valid,
  output logic             full,       // every entry valid
  output logic             empty,      // no entry valid
  output logic [IDX_W-1:0] free_idx    // lowest invalid entry
);

  logic [N-1:0] set_dec;   // one-hot set_idx
  logic [N-1:0] clr_dec;   // one-hot clr_idx
  logic [N-1:0] valid_d;   // next valid bits (flush is the flop's clr)
  logic [N-1:0] free;      // invalid entries

  basechili_decoder #(.N(N)) u_set_dec (
    .in  (set_idx),
    .out (set_dec)
  );

  basechili_decoder #(.N(N)) u_clr_dec (
    .in  (clr_idx),
    .out (clr_dec)
  );

  assign valid_d = (valid & ~(clr_dec & {N{clr_en}})) | (set_dec & {N{set_en}});

  basechili_dff_sclr #(.WIDTH(N)) u_valid (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (flush),
    .en    (1'b1),
    .d     (valid_d),
    .q     (valid)
  );

  assign free = ~valid;

  basechili_priority_encoder #(.N(N)) u_free (
    .in     (free),
    .onehot (),
    .idx    (free_idx),
    .valid  ()
  );

  assign full  = &valid;
  assign empty = ~|valid;

endmodule
