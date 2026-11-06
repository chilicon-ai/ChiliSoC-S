// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_dma_ch_chk (simulation and formal; bound into every chilimix_dma_ch)
//   - run implies claim; stop only while run                         (header Invariants)
//   - req implies run and exec_bytes != 0                            (header Invariant)
//   - Exec changes only at a start, a reload or a beat
//   - an abort while the engine does not serve the channel stops it at once
//   - done_irq / err_irq are done & done_ie / error & error_ie
//   - environment (the engine): active only while run; beat_done only while
//     active, with a beat size of 1, 2 or 4 no larger than exec_bytes
//     (assume under FORMAL, assert otherwise)
// -----------------------------------------------------------------------------
module chilimix_dma_ch_chk (
  input logic        clk,
  input logic        rst_n,
  input logic        claim,
  input logic        run,
  input logic        stop,
  input logic        done,
  input logic        done_ie,
  input logic        error,
  input logic        error_ie,
  input logic        req,
  input logic [31:0] exec_bytes,
  input logic [31:0] exec_src,
  input logic [31:0] exec_dst,
  input logic        load,
  input logic        abort,
  input logic        active,
  input logic        beat_done,
  input logic [2:0]  beat_size,
  input logic        done_irq,
  input logic        err_irq
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  dma_ch_run_claim: assert property (@(posedge clk) disable iff (!rst_n) !run || claim)
    else $error("chilimix_dma_ch: run without claim");

  dma_ch_stop_run: assert property (@(posedge clk) disable iff (!rst_n) !stop || run)
    else $error("chilimix_dma_ch: stop pending without run");

  dma_ch_req: assert property (@(posedge clk) disable iff (!rst_n)
                !req || (run && exec_bytes != 32'd0))
    else $error("chilimix_dma_ch: req without run or bytes left");

  dma_ch_exec_hold: assert property (@(posedge clk) disable iff (!rst_n)
                !past_ok || !$past(rst_n) || $past(load) || $past(beat_done)
                || (exec_bytes == $past(exec_bytes) && exec_src == $past(exec_src)
                    && exec_dst == $past(exec_dst)))
    else $error("chilimix_dma_ch: Exec changed without a start, reload or beat");

  dma_ch_abort: assert property (@(posedge clk) disable iff (!rst_n)
                !past_ok || !$past(rst_n) || !$past(abort && !active) || !run)
    else $error("chilimix_dma_ch: run still set after an abort with no beat in flight");

  dma_ch_irq: assert property (@(posedge clk) disable iff (!rst_n)
                done_irq == (done && done_ie) && err_irq == (error && error_ie))
    else $error("chilimix_dma_ch: interrupt levels");

`ifdef FORMAL
  dma_ch_env_active: assume property (@(posedge clk) disable iff (!rst_n) !active || run);
  dma_ch_env_beat: assume property (@(posedge clk) disable iff (!rst_n)
                !beat_done || (active && (beat_size == 3'd1 || beat_size == 3'd2 || beat_size == 3'd4)
                               && {29'd0, beat_size} <= exec_bytes));
`else
  dma_ch_env_active: assert property (@(posedge clk) disable iff (!rst_n) !active || run)
    else $error("chilimix_dma_ch: the engine serves a channel that is not running");
  dma_ch_env_beat: assert property (@(posedge clk) disable iff (!rst_n)
                !beat_done || (active && (beat_size == 3'd1 || beat_size == 3'd2 || beat_size == 3'd4)
                               && {29'd0, beat_size} <= exec_bytes))
    else $error("chilimix_dma_ch: beat_done outside a beat, or a bad beat size");
`endif

endmodule

bind chilimix_dma_ch chilimix_dma_ch_chk u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .claim      (claim),
  .run        (run),
  .stop       (stop),
  .done       (done),
  .done_ie    (done_ie),
  .error      (error),
  .error_ie   (error_ie),
  .req        (req),
  .exec_bytes (exec_bytes),
  .exec_src   (exec_src),
  .exec_dst   (exec_dst),
  .load       (load),
  .abort      (abort),
  .active     (active),
  .beat_done  (beat_done),
  .beat_size  (beat_size),
  .done_irq   (done_irq),
  .err_irq    (err_irq)
);
