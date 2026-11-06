// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_imss_ahb_chk (bound into chillus_imss_ahb)
//   - mss_rvalid only when rd_pending                       (header Invariants)
//   - an accepted request sets rd_pending for the next cycle (header Invariants)
//   - HTRANS is NONSEQ exactly while mss_req; never a write
// -----------------------------------------------------------------------------
module chillus_imss_ahb_chk (
  input logic       clk,
  input logic       rst_n,
  input logic       mss_req,
  input logic       mss_rvalid,
  input logic       rd_pending,
  input logic [1:0] HTRANS,
  input logic       HWRITE,
  input logic       HREADY
);

  assert property (@(posedge clk) disable iff (!rst_n) mss_rvalid |-> rd_pending)
    else $error("chillus_imss_ahb: ack without a fetch in its data phase");

  assert property (@(posedge clk) disable iff (!rst_n)
                   mss_req && HREADY |=> rd_pending)
    else $error("chillus_imss_ahb: accepted fetch did not enter its data phase");

  assert property (@(posedge clk) disable iff (!rst_n)
                   HTRANS == (mss_req ? 2'b10 : 2'b00) && !HWRITE)
    else $error("chillus_imss_ahb: HTRANS / HWRITE do not follow the request");

endmodule

bind chillus_imss_ahb chillus_imss_ahb_chk u_chk (
  .clk           (clk),
  .rst_n         (rst_n),
  .mss_req (mss_req),
  .mss_rvalid (mss_rvalid),
  .rd_pending    (rd_pending),
  .HTRANS        (HTRANS),
  .HWRITE        (HWRITE),
  .HREADY        (HREADY)
);
