// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_spi_xip_chk (simulation and formal; bound into every chilimix_spi_xip)
//   - f_valid only while a fill runs                            (header Invariant)
//   - no two valid lines hold the same tag                      (header Invariant)
//   - while a fill runs its line is invalid, holds the fill tag, and no
//     valid line holds that tag                                 (header Invariant)
//   - a write or a read with en clear is answered with ERROR at once
//   environment (assert in simulation, assume in formal):
//   - rx_valid only while a fill runs (the phy returns the fill's bytes)
// -----------------------------------------------------------------------------
module chilimix_spi_xip_chk #(
  parameter int LINES = 4,
  parameter int TAG_W = 25,
  parameter int IDX_W = 2
) (
  input logic                   clk,
  input logic                   rst_n,
  input logic                   f_valid,
  input logic                   busy,
  input logic [LINES*TAG_W-1:0] tags,
  input logic [LINES-1:0]       valid,
  input logic [IDX_W-1:0]       victim,
  input logic [TAG_W-1:0]       fill_tag,
  input logic                   req_valid,
  input logic                   bad,
  input logic                   ack_valid,
  input logic                   ack_error,
  input logic                   rx_valid
);

  logic dup;          // two valid lines share a tag
  logic fill_seen;    // a valid line holds the fill tag
  logic victim_bad;   // the line being filled is valid or holds another tag

  always_comb begin
    dup       = 1'b0;
    fill_seen = 1'b0;
    for (int i = 0; i < LINES; i++) begin
      if (valid[i] && tags[i*TAG_W +: TAG_W] == fill_tag) fill_seen = 1'b1;
      for (int j = i + 1; j < LINES; j++) begin
        if (valid[i] && valid[j] && tags[i*TAG_W +: TAG_W] == tags[j*TAG_W +: TAG_W]) dup = 1'b1;
      end
    end
    victim_bad = valid[victim] || tags[victim*TAG_W +: TAG_W] != fill_tag;
  end

  spi_xip_fvalid: assert property (@(posedge clk) disable iff (!rst_n) !f_valid || busy)
    else $error("chilimix_spi_xip: frame offered with no fill");

  spi_xip_unique: assert property (@(posedge clk) disable iff (!rst_n) !dup)
    else $error("chilimix_spi_xip: two valid lines hold the same tag");

  spi_xip_fill_line: assert property (@(posedge clk) disable iff (!rst_n)
                   !busy || (!fill_seen && !victim_bad))
    else $error("chilimix_spi_xip: the line being filled is valid, or its tag is elsewhere");

  spi_xip_error: assert property (@(posedge clk) disable iff (!rst_n)
                   !req_valid || !bad || (ack_valid && ack_error))
    else $error("chilimix_spi_xip: a write or a read with en clear not answered with ERROR");

`ifdef FORMAL
  spi_xip_env_rx: assume property (@(posedge clk) disable iff (!rst_n) !rx_valid || busy);
`else
  spi_xip_env_rx: assert property (@(posedge clk) disable iff (!rst_n) !rx_valid || busy)
    else $error("chilimix_spi_xip: data byte returned with no fill");
`endif

endmodule

bind chilimix_spi_xip chilimix_spi_xip_chk #(.LINES(LINES), .TAG_W(TAG_W), .IDX_W(IDX_W)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .f_valid   (f_valid),
  .busy      (busy),
  .tags      (tags),
  .valid     (valid),
  .victim    (victim),
  .fill_tag  (fill_tag),
  .req_valid (req_valid),
  .bad       (bad),
  .ack_valid (ack_valid),
  .ack_error (ack_error),
  .rx_valid  (rx_valid)
);
