// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_imss_ahb
//
// Instruction fetch port (IFU, req / gnt, then in-order rvalid
// with rdata / err) to an AHB-Lite manager, zero added latency: a request is
// the address phase (NONSEQ word read), mss_gnt = HREADY (the address phase
// completes), and the data phase that follows returns rvalid in the cycle
// HREADY is high (HRESP = ERROR gives mss_err). One transfer per cycle back
// to back, so a zero-wait subordinate answers every fetch in the next cycle.
//
//   address phase : HTRANS = NONSEQ while mss_req, else IDLE; HPROT =
//                   opcode fetch, privileged when mss_priv (M-mode), not
//                   bufferable / cacheable
//   data phase    : rd_pending (u_pending) marks a read in its data phase;
//                   mss_rvalid = rd_pending && HREADY
//
// The IFU always takes a response (chillus_ifu_fetch reserves buffer space
// per outstanding fetch), so no response buffer. A request the IFU withdraws
// while HREADY is low (redirect) changes the address phase during a wait
// state; AHB-Lite subordinates sample it only with HREADY high, so nothing is
// lost or duplicated.
//
// Timing    : HADDR / HTRANS / HPROT combinational from mss_req / mss_addr /
//             mss_priv; mss_gnt,
//             mss_rvalid / mss_rdata / mss_err combinational from HREADY /
//             HRESP / HRDATA and the registered rd_pending.
// Invariants: mss_rvalid only when rd_pending; a granted request (mss_req &&
//             HREADY) sets rd_pending for the next cycle.
// Debug     : fetch hangs -> HREADY, rd_pending; wrong instruction ->
//             HRDATA in the cycle of mss_rvalid; spurious fault -> HRESP.
// -----------------------------------------------------------------------------
module chillus_imss_ahb #(
  parameter int ADDR_W = 32                  // address width
) (
  input  logic              clk,
  input  logic              rst_n,           // async, active-low
  // IFU fetch port
  input  logic              mss_req,
  output logic              mss_gnt,
  input  logic [ADDR_W-1:0] mss_addr,        // word aligned
  input  logic              mss_priv,        // privileged (M-mode) fetch
  output logic              mss_rvalid,
  output logic [31:0]       mss_rdata,
  output logic              mss_err,
  // AHB-Lite manager
  output logic [ADDR_W-1:0] HADDR,
  output logic [1:0]        HTRANS,
  output logic              HWRITE,
  output logic [2:0]        HSIZE,
  output logic [31:0]       HWDATA,
  output logic [3:0]        HPROT,
  input  logic              HREADY,
  input  logic              HRESP,
  input  logic [31:0]       HRDATA
);

  logic rd_pending;     // a fetch is in its data phase
  logic rd_pending_d;

  assign HADDR  = mss_addr;
  assign HTRANS = mss_req ? 2'b10 : 2'b00;         // NONSEQ / IDLE
  assign HWRITE = 1'b0;
  assign HSIZE  = 3'b010;                          // word
  assign HWDATA = '0;
  assign HPROT  = {2'b00, mss_priv, 1'b0};         // opcode fetch

  assign mss_gnt      = HREADY;
  assign rd_pending_d = HREADY ? mss_req : rd_pending;

  basechili_dff #(.WIDTH(1)) u_pending (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rd_pending_d),
    .q     (rd_pending)
  );

  assign mss_rvalid = rd_pending && HREADY;
  assign mss_rdata  = HRDATA;
  assign mss_err    = HRESP;

endmodule
