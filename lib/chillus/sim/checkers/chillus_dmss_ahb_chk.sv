// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_dmss_ahb_chk (bound into chillus_dmss_ahb)
//   - mss_rvalid only when pending                          (header Invariants)
//   - a granted request sets pending for the next cycle     (header Invariants)
//   - HWDATA changes only at an edge that grants a write    (header Invariants)
//   - HTRANS is NONSEQ exactly while mss_req
// -----------------------------------------------------------------------------
module chillus_dmss_ahb_chk #(
  parameter int DATA_W = 32
) (
  input logic              clk,
  input logic              rst_n,
  input logic              mss_req,
  input logic              mss_rvalid,
  input logic              pending,
  input logic              wdata_en,
  input logic [1:0]        HTRANS,
  input logic [DATA_W-1:0] HWDATA,
  input logic              HREADY
);

  assert property (@(posedge clk) disable iff (!rst_n) mss_rvalid |-> pending)
    else $error("chillus_dmss_ahb: rvalid without an access in its data phase");

  assert property (@(posedge clk) disable iff (!rst_n) mss_req && HREADY |=> pending)
    else $error("chillus_dmss_ahb: granted access did not enter its data phase");

  assert property (@(posedge clk) disable iff (!rst_n)
                   !wdata_en |=> HWDATA == $past(HWDATA))
    else $error("chillus_dmss_ahb: HWDATA changed without a write being granted");

  assert property (@(posedge clk) disable iff (!rst_n) HTRANS == (mss_req ? 2'b10 : 2'b00))
    else $error("chillus_dmss_ahb: HTRANS does not follow the request");

endmodule

bind chillus_dmss_ahb chillus_dmss_ahb_chk #(.DATA_W(DATA_W)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .mss_req    (mss_req),
  .mss_rvalid (mss_rvalid),
  .pending    (pending),
  .wdata_en   (wdata_en),
  .HTRANS     (HTRANS),
  .HWDATA     (HWDATA),
  .HREADY     (HREADY)
);
