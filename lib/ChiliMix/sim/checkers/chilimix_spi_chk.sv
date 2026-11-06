// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_spi_chk (simulation and formal; bound into every chilimix_spi)
//   - a FIFO frame starts only with fctrl.en clear and no fill  (header Invariant)
//   - the RX FIFO accepts every frame received for it           (header Invariant)
//   - rx_pend never counts past the RX FIFO's free entries, and is set only
//     for a frame from the TX FIFO                              (header Invariant)
//   - irq is the registered |(ie & ip)                          (header Invariant)
//   - helper: rx_pend is set exactly while a TX FIFO frame with rx is in the phy
// -----------------------------------------------------------------------------
module chilimix_spi_chk (
  input logic       clk,
  input logic       rst_n,
  input logic       fifo_fire,
  input logic       fctrl_en,
  input logic       xip_busy,
  input logic       rx_push,
  input logic [3:0] rx_count,
  input logic       rx_pend,
  input logic       src_xip,
  input logic       irq_d,
  input logic       irq,
  input logic [2:0] phy_state,   // u_phy.state_q
  input logic       phy_fr_rx,   // u_phy.fr_rx: the frame in the phy returns its bits
  input logic       rx_valid
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  spi_fifo_start: assert property (@(posedge clk) disable iff (!rst_n)
                   !fifo_fire || (!fctrl_en && !xip_busy))
    else $error("chilimix_spi: FIFO frame started while the flash interface owns the pins");

  spi_rx_no_loss: assert property (@(posedge clk) disable iff (!rst_n)
                   !rx_push || rx_count < 4'd8)
    else $error("chilimix_spi: received frame pushed into a full RX FIFO");

  spi_rx_pend: assert property (@(posedge clk) disable iff (!rst_n)
                   {1'b0, rx_count} + {4'd0, rx_pend} <= 5'd8 && (!rx_pend || !src_xip))
    else $error("chilimix_spi: rx_pend inconsistent with the RX FIFO or the frame owner");

  // helper (makes spi_rx_no_loss inductive): rx_pend is set exactly while a
  // TX FIFO frame with rx is taken (lead, gap, transfer) or returning its bits
  logic fifo_rx_inflight;
  assign fifo_rx_inflight = !src_xip && ((phy_fr_rx && (phy_state == 3'd1 || phy_state == 3'd2
                                                        || phy_state == 3'd4)) || rx_valid);

  spi_rx_inflight: assert property (@(posedge clk) disable iff (!rst_n)
                   fifo_rx_inflight == rx_pend)
    else $error("chilimix_spi: rx_pend does not match the TX FIFO frame with rx in the phy");

  spi_irq: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || irq == $past(irq_d))
    else $error("chilimix_spi: irq is not the registered |(ie & ip)");

endmodule

bind chilimix_spi chilimix_spi_chk u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .fifo_fire (fifo_fire),
  .fctrl_en  (fctrl_en),
  .xip_busy  (xip_busy),
  .rx_push   (rx_push),
  .rx_count  (rx_count),
  .rx_pend   (rx_pend),
  .src_xip   (src_xip),
  .irq_d     (irq_d),
  .irq       (irq),
  .phy_state (u_phy.state_q),
  .phy_fr_rx (u_phy.fr_rx),
  .rx_valid  (rx_valid)
);
