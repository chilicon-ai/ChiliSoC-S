// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_uart_rx_chk (simulation and formal; bound into every chilimix_uart_rx)
//   - out_valid only in S_STOP                              (header Invariant)
//   - bit_cnt never passes the last data bit (<= nbits_m1)  (header Invariant)
//   - bit_cnt is 0 outside S_DATA (proof helper)
//   - the latched line format changes only on frame_go      (header Invariant)
// -----------------------------------------------------------------------------
module chilimix_uart_rx_chk (
  input logic       clk,
  input logic       rst_n,
  input logic [2:0] state_q,
  input logic       out_valid,
  input logic       frame_go,
  input logic [4:0] fmt,
  input logic [2:0] bit_cnt,
  input logic [2:0] nbits_m1
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |-> b" is written !a || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  uart_rx_valid_stop: assert property (@(posedge clk) disable iff (!rst_n) !out_valid || state_q == 3'd4)
    else $error("chilimix_uart_rx: out_valid outside S_STOP (state %0d)", state_q);

  uart_rx_bit_cnt: assert property (@(posedge clk) disable iff (!rst_n) bit_cnt <= nbits_m1)
    else $error("chilimix_uart_rx: bit_cnt %0d past the last data bit %0d", bit_cnt, nbits_m1);

  // Helper for the k-induction proof of uart_rx_bit_cnt: outside S_DATA the
  // bit counter is cleared.
  uart_rx_bit_cnt_clr: assert property (@(posedge clk) disable iff (!rst_n) state_q == 3'd2 || bit_cnt == '0)
    else $error("chilimix_uart_rx: bit_cnt %0d outside S_DATA", bit_cnt);

  // The line format is latched per frame: it only changes on frame_go
  // (the start bit), so an LCR write mid-frame cannot reshape the frame.
  uart_rx_fmt_hold: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(frame_go) || fmt == $past(fmt))
    else $error("chilimix_uart_rx: line format changed inside a frame");

endmodule

bind chilimix_uart_rx chilimix_uart_rx_chk u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state_q   (state_q),
  .out_valid (out_valid),
  .frame_go  (frame_go),
  .fmt       (fmt),
  .bit_cnt   (bit_cnt),
  .nbits_m1  (nbits_m1)
);
