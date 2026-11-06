// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_fifo
//
// Synchronous FIFO with valid/accept stream ports (see
// doc/valid_accept_handshake.md): DEPTH entries, any DEPTH >= 1, plus count
// and a synchronous flush (priority over both ports). Built on
// basechili_peek_fifo with a one-entry window.
//
//   in_accept = !full        out_valid = !empty        out_data = head
//
// Timing: in_accept / out_valid / count come from registers (no path from
//         one side to the other); out_data is the head entry, read
//         combinationally from storage. A word pushed at an edge can leave
//         at the next edge (one cycle through an empty FIFO); no bypass.
// Debug : see basechili_peek_fifo (u_q.count, u_q.wr_ptr / u_q.rd_ptr).
// -----------------------------------------------------------------------------
module basechili_fifo #(
  parameter  int WIDTH = 32,                          // entry width in bits
  parameter  int DEPTH = 4,                           // number of entries
  localparam int CNT_W = $clog2(DEPTH + 1)
) (
  input  logic             clk,
  input  logic             rst_n,       // async, active-low
  input  logic             flush,       // sync empty
  input  logic             in_valid,
  output logic             in_accept,
  input  logic [WIDTH-1:0] in_data,
  output logic             out_valid,
  input  logic             out_accept,
  output logic [WIDTH-1:0] out_data,
  output logic [CNT_W-1:0] count        // number of valid entries
);

  logic in_fire;    // push
  logic out_fire;   // pop
  logic full;
  logic empty;

  assign in_accept = !full;
  assign out_valid = !empty;
  assign in_fire   = in_valid && in_accept;
  assign out_fire  = out_valid && out_accept;

  basechili_peek_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH), .PEEK(1)) u_q (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (1'b0),
    .flush   (flush),
    .push    (in_fire),
    .wdata   (in_data),
    .pop     (out_fire),
    .rdata   (out_data),
    .count   (count),
    .full    (full),
    .empty   (empty)
  );

endmodule
