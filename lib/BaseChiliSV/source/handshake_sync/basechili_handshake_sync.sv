// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_handshake_sync
//
// Bus clock-domain crossing for slow-changing data (configuration, status,
// counters snapshots), two-phase (toggle) req / ack, valid/accept on both
// sides (doc/valid_accept_handshake.md).
//   source: src_fire captures src_data in u_data and flips req (u_req);
//           src_accept is low until the ack for that word comes back.
//   dest  : the synchronized req differs from ack -> dst_valid with
//           dst_data = the captured word (held stable in the source domain);
//           dst_fire flips ack (u_ack), which is synchronized back.
// Only the req and ack levels cross (STAGES flops each); the data bus
// crosses unsynchronized: it changes together with req and stays stable
// until the ack for it is back in the source domain.
//
// Timing    : dst_valid rises STAGES dst_clk edges after src_fire; src_accept
//             returns STAGES src_clk edges after dst_fire. One word per
//             round trip (about 2 * STAGES cycles of each clock).
// Invariants: !src_accept -> u_data.q stable (the word in flight).
// Constraint: the dst_data path is a multicycle / max-delay CDC path in STA
//             (it must settle within STAGES - 1 dst_clk periods).
// Reset     : both domains reset to req = ack = 0 (idle); assert both
//             resets together.
// Debug     : src_accept stuck low -> u_ack.q vs. u_req.q through the two
//             synchronizers (u_req_sync.q, u_ack_sync.q); dst_valid stuck
//             -> dst_accept.
// -----------------------------------------------------------------------------
module basechili_handshake_sync #(
  parameter int WIDTH  = 32,   // data width in bits
  parameter int STAGES = 2     // synchronizer flops per direction, >= 2
) (
  input  logic             src_clk,
  input  logic             src_rst_n,    // async, active-low (source domain)
  input  logic             src_valid,
  output logic             src_accept,   // idle: no word in flight
  input  logic [WIDTH-1:0] src_data,
  input  logic             dst_clk,
  input  logic             dst_rst_n,    // async, active-low (destination domain)
  output logic             dst_valid,
  input  logic             dst_accept,
  output logic [WIDTH-1:0] dst_data
);

  logic src_fire;   // word captured this src_clk cycle
  logic req;        // request level, flips on src_fire (src domain)
  logic req_d;      // next request level
  logic ack_s;      // ack synchronized to src_clk
  logic dst_fire;   // word taken this dst_clk cycle
  logic ack;        // acknowledge level, flips on dst_fire (dst domain)
  logic ack_d;      // next acknowledge level
  logic req_s;      // req synchronized to dst_clk

  // ---- source domain ----
  assign src_accept = (req == ack_s);
  assign src_fire   = src_valid && src_accept;
  assign req_d      = req ^ src_fire;

  basechili_dff u_req (
    .clk   (src_clk),
    .rst_n (src_rst_n),
    .d     (req_d),
    .q     (req)
  );

  basechili_dffe #(.WIDTH(WIDTH)) u_data (
    .clk   (src_clk),
    .rst_n (src_rst_n),
    .en    (src_fire),
    .d     (src_data),
    .q     (dst_data)
  );

  basechili_sync #(.STAGES(STAGES)) u_ack_sync (
    .clk   (src_clk),
    .rst_n (src_rst_n),
    .d     (ack),
    .q     (ack_s)
  );

  // ---- destination domain ----
  basechili_sync #(.STAGES(STAGES)) u_req_sync (
    .clk   (dst_clk),
    .rst_n (dst_rst_n),
    .d     (req),
    .q     (req_s)
  );

  assign dst_valid = (req_s != ack);
  assign dst_fire  = dst_valid && dst_accept;
  assign ack_d     = ack ^ dst_fire;

  basechili_dff u_ack (
    .clk   (dst_clk),
    .rst_n (dst_rst_n),
    .d     (ack_d),
    .q     (ack)
  );

endmodule
