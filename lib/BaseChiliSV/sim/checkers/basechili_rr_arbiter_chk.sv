// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_rr_arbiter_chk (bound into every basechili_rr_arbiter)
//   - gnt is zero or one-hot; gnt is a subset of req; gnt_valid == (req != 0)
//     (header Invariants)
//   - gnt_idx is the index of gnt (header)
// -----------------------------------------------------------------------------
module basechili_rr_arbiter_chk #(
  parameter int N     = 4,
  parameter int IDX_W = 2
) (
  input logic             clk,
  input logic             rst_n,
  input logic [N-1:0]     req,
  input logic [N-1:0]     gnt,
  input logic [IDX_W-1:0] gnt_idx,
  input logic             gnt_valid
);

  assert property (@(posedge clk) disable iff (!rst_n) $onehot0(gnt))
    else $error("basechili_rr_arbiter: gnt zero or one-hot violated: gnt=%b", gnt);

  assert property (@(posedge clk) disable iff (!rst_n) (gnt & ~req) == '0)
    else $error("basechili_rr_arbiter: gnt subset of req violated: gnt=%b req=%b", gnt, req);

  assert property (@(posedge clk) disable iff (!rst_n) gnt_valid == (req != '0))
    else $error("basechili_rr_arbiter: gnt_valid == (req != 0) violated: gnt_valid=%b req=%b", gnt_valid, req);

  assert property (@(posedge clk) disable iff (!rst_n) gnt_valid |-> gnt[gnt_idx])
    else $error("basechili_rr_arbiter: gnt_idx is the index of gnt violated: gnt=%b gnt_idx=%0d", gnt, gnt_idx);

endmodule

bind basechili_rr_arbiter basechili_rr_arbiter_chk #(.N(N), .IDX_W(IDX_W)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .req       (req),
  .gnt       (gnt),
  .gnt_idx   (gnt_idx),
  .gnt_valid (gnt_valid)
);
