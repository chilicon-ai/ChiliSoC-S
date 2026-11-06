// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_handshake_sync_chk (bound into every basechili_handshake_sync)
//   - !src_accept -> the word in flight (dst_data) holds     (header Invariant)
// -----------------------------------------------------------------------------
module basechili_handshake_sync_chk #(
  parameter int WIDTH = 32
) (
  input logic             src_clk,
  input logic             src_rst_n,
  input logic             src_accept,
  input logic [WIDTH-1:0] dst_data
);

  assert property (@(posedge src_clk) disable iff (!src_rst_n) !src_accept |=> $stable(dst_data))
    else $error("basechili_handshake_sync: word in flight changed: dst_data=%h", dst_data);

endmodule

bind basechili_handshake_sync basechili_handshake_sync_chk #(.WIDTH(WIDTH)) u_chk (
  .src_clk    (src_clk),
  .src_rst_n  (src_rst_n),
  .src_accept (src_accept),
  .dst_data   (dst_data)
);
