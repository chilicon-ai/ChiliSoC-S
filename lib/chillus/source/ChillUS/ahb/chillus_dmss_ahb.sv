// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_dmss_ahb
//
// Data port (LSU, req / gnt, then rvalid with rdata / err, one
// access outstanding) to an AHB-Lite manager, zero added latency:
//
//   address phase : a request is HTRANS = NONSEQ with HWRITE = mss_we and
//                   HADDR / HSIZE from the word address and the byte enables
//                   (below), HPROT = data access, privileged when mss_priv
//                   (M-mode, or MPRV), not bufferable / cacheable;
//                   mss_gnt = HREADY (the address phase completes).
//   data phase    : the cycle(s) after; HWDATA comes from u_wdata (the store
//                   data registered when the write was granted); pending
//                   (u_pending) marks an access in its data phase and
//                   mss_rvalid = pending && HREADY, with HRDATA and
//                   mss_err = HRESP (the second cycle of an ERROR response).
//
//   mss_be    HSIZE   HADDR[1:0]      mss_be    HSIZE   HADDR[1:0]
//   0001      byte    00              0011      half    00
//   0010      byte    01              1100      half    10
//   0100      byte    10              1111      word    00
//   1000      byte    11
//
// The store data is replicated into every byte lane by the LSU, so HWDATA
// has the bytes HSIZE / HADDR select. The LSU presents a new request only
// with nothing outstanding or in the cycle of the outstanding access's
// rvalid, so HTRANS depends combinationally on HREADY / HRESP (through the
// core): the subordinates and the interconnect must not derive HREADY from
// the current address phase.
//
// Timing    : HADDR / HTRANS / HWRITE / HSIZE / HPROT combinational from mss_*;
//             HWDATA registered; mss_gnt, mss_rvalid / mss_rdata / mss_err
//             combinational from HREADY / HRESP / HRDATA and pending.
// Invariants: mss_rvalid only when pending; a granted request (mss_req &&
//             HREADY) sets pending for the next cycle. HWDATA changes only at
//             an edge that grants a write.
// Debug     : store lost / wrong -> u_wdata.q vs the LSU store data at the
//             granting edge (wdata_en); load wrong -> HRDATA in the cycle of
//             mss_rvalid; hang -> HREADY, pending.
// -----------------------------------------------------------------------------
module chillus_dmss_ahb #(
  parameter  int ADDR_W = 32,                // address width
  parameter  int DATA_W = 32,                // data width (XLEN, 32: the HSIZE decode is for 4 lanes)
  localparam int N_LANE = DATA_W / 8         // byte lanes
) (
  input  logic              clk,
  input  logic              rst_n,           // async, active-low
  // LSU data port
  input  logic              mss_req,
  output logic              mss_gnt,
  input  logic              mss_we,
  input  logic [ADDR_W-1:0] mss_addr,        // word address
  input  logic [N_LANE-1:0] mss_be,          // byte enables
  input  logic [DATA_W-1:0] mss_wdata,       // replicated into every lane
  input  logic              mss_priv,        // privileged (M-mode) access
  output logic              mss_rvalid,
  output logic [DATA_W-1:0] mss_rdata,
  output logic              mss_err,
  // AHB-Lite manager
  output logic [ADDR_W-1:0] HADDR,
  output logic [1:0]        HTRANS,
  output logic              HWRITE,
  output logic [2:0]        HSIZE,
  output logic [DATA_W-1:0] HWDATA,
  output logic [3:0]        HPROT,
  input  logic              HREADY,
  input  logic              HRESP,
  input  logic [DATA_W-1:0] HRDATA
);

  logic       wdata_en;    // a store's address phase completes: capture its data
  logic       pending;     // an access is in its data phase
  logic       pending_d;
  logic [1:0] byte_off;    // HADDR[1:0] from mss_be
  logic [2:0] size;        // HSIZE from mss_be

  always_comb begin
    case (mss_be)
      4'b0001: begin size = 3'b000; byte_off = 2'd0; end
      4'b0010: begin size = 3'b000; byte_off = 2'd1; end
      4'b0100: begin size = 3'b000; byte_off = 2'd2; end
      4'b1000: begin size = 3'b000; byte_off = 2'd3; end
      4'b0011: begin size = 3'b001; byte_off = 2'd0; end
      4'b1100: begin size = 3'b001; byte_off = 2'd2; end
      default: begin size = 3'b010; byte_off = 2'd0; end
    endcase
  end

  assign HADDR  = {mss_addr[ADDR_W-1:2], byte_off};
  assign HTRANS = mss_req ? 2'b10 : 2'b00;         // NONSEQ / IDLE
  assign HWRITE = mss_we;
  assign HSIZE  = size;
  assign HPROT  = {2'b00, mss_priv, 1'b1};         // data access

  assign wdata_en = HREADY && mss_req && mss_we;

  basechili_dffe #(.WIDTH(DATA_W)) u_wdata (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (wdata_en),
    .d     (mss_wdata),
    .q     (HWDATA)
  );

  assign mss_gnt   = HREADY;
  assign pending_d = HREADY ? mss_req : pending;

  basechili_dff #(.WIDTH(1)) u_pending (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pending_d),
    .q     (pending)
  );

  assign mss_rvalid = pending && HREADY;
  assign mss_rdata  = HRDATA;
  assign mss_err    = HRESP;

endmodule
