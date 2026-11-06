// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chilisocs_fabric_chk (bound into chilisocs_fabric)
//   - i_sel / b_sel are zero or one-hot                         (header Invariant)
//   - a gated transfer is never active while its manager's HREADY is low:
//     the layer transfers of I and of the D bus, and the D bus arbiter's
//     manager ports (D, SBA, DMA)                               (header Invariant)
//   - the I manager never writes                                (header Invariant)
// Widths follow the fabric (N_SH layers, N_DREG D bus regions, three D bus
// managers). default_nettype none: a bind port naming no fabric signal fails
// the build (an implicit net would make the check vacuous).
// -----------------------------------------------------------------------------
`default_nettype none   // a bind port that names no signal of the target is an error
module chilisocs_fabric_chk #(
  parameter int N_SH   = 4,
  parameter int N_DREG = 9
) (
  input logic              clk,
  input logic              rst_n,
  input logic [N_SH-1:0]   i_sel,
  input logic [N_DREG-1:0] b_sel,
  input logic [N_SH*2-1:0] i_trans_m,
  input logic [N_SH*2-1:0] b_trans_m,
  input logic [5:0]        db_trans_m,
  input logic [2:0]        db_ready_m,
  input logic              i_HREADY,
  input logic              b_HREADY,
  input logic [1:0]        i_HTRANS,
  input logic              i_HWRITE
);

  logic layer_ok;                    // no gated layer transfer while its manager waits
  logic db_ok;                       // no gated D bus manager transfer while it waits

  always_comb begin
    layer_ok = 1'b1;
    for (int s = 0; s < N_SH; s++)
      layer_ok &= (i_HREADY || !i_trans_m[s*2+1]) && (b_HREADY || !b_trans_m[s*2+1]);
    db_ok = 1'b1;
    for (int m = 0; m < 3; m++)
      db_ok &= db_ready_m[m] || !db_trans_m[m*2+1];
  end

  chilisocs_fabric_sel_onehot: assert property (@(posedge clk) disable iff (!rst_n) $onehot0(i_sel) && $onehot0(b_sel))
    else $error("chilisocs_fabric: decoder select not zero or one-hot: i_sel=%b b_sel=%b", i_sel, b_sel);

  chilisocs_fabric_layer_gate: assert property (@(posedge clk) disable iff (!rst_n) layer_ok)
    else $error("chilisocs_fabric: transfer to an arbiter layer while the manager waits");

  chilisocs_fabric_db_gate: assert property (@(posedge clk) disable iff (!rst_n) db_ok)
    else $error("chilisocs_fabric: D bus arbiter sees a transfer of a waiting manager: %b ready %b",
                db_trans_m, db_ready_m);

  chilisocs_fabric_i_read: assert property (@(posedge clk) disable iff (!rst_n) !(i_HTRANS[1] && i_HWRITE))
    else $error("chilisocs_fabric: the I manager writes");

endmodule

bind chilisocs_fabric chilisocs_fabric_chk #(.N_SH(N_SH), .N_DREG(N_DREG)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .i_sel      (i_sel),
  .b_sel      (b_sel),
  .i_trans_m  (i_trans_m),
  .b_trans_m  (b_trans_m),
  .db_trans_m (db_trans_m),
  .db_ready_m (db_ready_m),
  .i_HREADY   (i_HREADY),
  .b_HREADY   (b_HREADY),
  .i_HTRANS   (i_HTRANS),
  .i_HWRITE   (i_HWRITE)
);
`default_nettype wire
