// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_rr_arbiter
//
// Round-robin arbiter over N requesters. Combinational grant: the first
// requester after the last served one (wrapping), lowest index first after
// reset. gnt_accept says the granted requester was served this cycle; only
// then does the priority move past it, so a grant is stable while it waits.
//
//   mask   : requesters above the last served index (all ones after reset)
//   gnt    : lowest set bit of req & mask if any, else lowest set bit of req
//
// Timing    : gnt / gnt_idx / gnt_valid follow req combinationally; the
//             priority moves the cycle after gnt_accept.
// Invariants: gnt is zero or one-hot, gnt is a subset of req, gnt_valid ==
//             (req != 0).
// Debug     : starvation -> mask (u_mask.q) and gnt_accept; mask must move
//             past every served requester.
// -----------------------------------------------------------------------------
module basechili_rr_arbiter #(
  parameter  int N     = 4,                          // number of requesters
  localparam int IDX_W = (N > 1) ? $clog2(N) : 1
) (
  input  logic             clk,
  input  logic             rst_n,        // async, active-low
  input  logic [N-1:0]     req,
  input  logic             gnt_accept,   // the granted requester is served this cycle
  output logic [N-1:0]     gnt,          // one-hot grant
  output logic [IDX_W-1:0] gnt_idx,      // index of the grant
  output logic             gnt_valid     // a grant is given (req != 0)
);

  logic [N-1:0]     mask;          // requesters after the last served one
  logic [N-1:0]     mask_d;        // bits above the current grant
  logic             mask_en;
  logic [N-1:0]     req_m;         // req & mask
  logic [N-1:0]     gnt_m;         // first of req_m
  logic [N-1:0]     gnt_a;         // first of req
  logic [IDX_W-1:0] idx_m;
  logic [IDX_W-1:0] idx_a;
  logic             use_m;         // a requester after the last served one waits

  assign req_m = req & mask;

  basechili_priority_encoder #(.N(N)) u_pe_m (
    .in     (req_m),
    .onehot (gnt_m),
    .idx    (idx_m),
    .valid  (use_m)
  );

  basechili_priority_encoder #(.N(N)) u_pe_a (
    .in     (req),
    .onehot (gnt_a),
    .idx    (idx_a),
    .valid  (gnt_valid)
  );

  assign gnt     = use_m ? gnt_m : gnt_a;
  assign gnt_idx = use_m ? idx_m : idx_a;

  assign mask_d  = ~(gnt | (gnt - 1'b1));
  assign mask_en = gnt_accept && gnt_valid;

  basechili_dffe #(.WIDTH(N), .RESET_VAL('1)) u_mask (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (mask_en),
    .d     (mask_d),
    .q     (mask)
  );

endmodule
