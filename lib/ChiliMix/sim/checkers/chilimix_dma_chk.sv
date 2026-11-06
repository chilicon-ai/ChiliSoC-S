// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_dma_chk (simulation and formal; bound into every chilimix_dma)
//   - the engine state is S_IDLE or a beat state                     (header Invariant)
//   - in a beat: beat_size is 1, 2 or 4, HSIZE matches it, src_q /
//     dst_q are aligned to it, and it is no larger than the served
//     channel's exec_bytes; the served channel requests or stops   (header Invariants)
//   - gnt_accept only in S_IDLE                                       (header Invariant)
//   - irq is the registered done / error levels                       (header Invariant)
// -----------------------------------------------------------------------------
module chilimix_dma_chk #(
  parameter int N_CH  = 1,
  parameter int IDX_W = 1
) (
  input logic              clk,
  input logic              rst_n,
  input logic [2:0]        state_q,
  input logic              busy,
  input logic              gnt_accept,
  input logic [IDX_W-1:0]  cur,
  input logic [2:0]        size_q,
  input logic [2:0]        hsize_q,
  input logic [31:0]       src_q,
  input logic [31:0]       dst_q,
  input logic [N_CH*32-1:0] bytes_all,
  input logic [N_CH-1:0]   active,
  input logic [2*N_CH-1:0] irq_d,
  input logic [2*N_CH-1:0] irq
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic [31:0] cur_bytes;  // exec_bytes of the served channel
  logic [31:0] mask;       // size_q - 1
  assign cur_bytes = bytes_all[32*cur +: 32];
  assign mask      = {29'd0, size_q} - 32'd1;

  dma_state: assert property (@(posedge clk) disable iff (!rst_n) state_q <= 3'd4)
    else $error("chilimix_dma: engine state outside the enum");

  dma_beat_size: assert property (@(posedge clk) disable iff (!rst_n)
                   !busy || ((size_q == 3'd1 && hsize_q == 3'd0) || (size_q == 3'd2 && hsize_q == 3'd1)
                             || (size_q == 3'd4 && hsize_q == 3'd2)))
    else $error("chilimix_dma: beat size / HSIZE");

  dma_beat_align: assert property (@(posedge clk) disable iff (!rst_n)
                   !busy || ((src_q & mask) == 32'd0 && (dst_q & mask) == 32'd0))
    else $error("chilimix_dma: beat addresses not aligned to the beat size");

  dma_beat_bytes: assert property (@(posedge clk) disable iff (!rst_n)
                   !busy || (int'(cur) < N_CH && {29'd0, size_q} <= cur_bytes))
    else $error("chilimix_dma: beat larger than the bytes left");

  dma_beat_active: assert property (@(posedge clk) disable iff (!rst_n)
                   !busy || active[cur])
    else $error("chilimix_dma: the served channel is not active");

  dma_accept_idle: assert property (@(posedge clk) disable iff (!rst_n)
                   !gnt_accept || state_q == 3'd0)
    else $error("chilimix_dma: grant taken during a beat");

  dma_irq: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || irq == $past(irq_d))
    else $error("chilimix_dma: irq is not the registered done / error levels");

endmodule

bind chilimix_dma chilimix_dma_chk #(.N_CH(N_CH), .IDX_W(IDX_W)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .state_q    (state_q),
  .busy       (busy),
  .gnt_accept (gnt_accept),
  .cur        (cur),
  .size_q     (size_q),
  .hsize_q    (hsize_q),
  .src_q      (src_q),
  .dst_q      (dst_q),
  .bytes_all  (bytes_all),
  .active     (active),
  .irq_d      (irq_d),
  .irq        (irq)
);
