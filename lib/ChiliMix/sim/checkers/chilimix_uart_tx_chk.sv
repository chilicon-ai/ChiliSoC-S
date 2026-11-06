// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_uart_tx_chk (simulation and formal; bound into every chilimix_uart_tx)
//   - in_accept only in S_IDLE; busy == (state != S_IDLE)  (header Invariants)
//   - bit_cnt never passes the last data bit (<= nbits_m1)  (header Invariant)
//   - bit_cnt is 0 outside S_DATA (proof helper)
//   - the latched line format changes only on in_fire       (header Invariant)
// -----------------------------------------------------------------------------
module chilimix_uart_tx_chk (
  input logic       clk,
  input logic       rst_n,
  input logic [2:0] state_q,
  input logic       in_accept,
  input logic       busy,
  input logic       in_fire,
  input logic [3:0] fmt,
  input logic [2:0] bit_cnt,
  input logic [2:0] nbits_m1
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |-> b" is written !a || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  uart_tx_accept_idle: assert property (@(posedge clk) disable iff (!rst_n) in_accept == (state_q == 3'd0))
    else $error("chilimix_uart_tx: in_accept outside S_IDLE (state %0d)", state_q);

  uart_tx_busy: assert property (@(posedge clk) disable iff (!rst_n) busy == (state_q != 3'd0))
    else $error("chilimix_uart_tx: busy is not state != S_IDLE");

  uart_tx_bit_cnt: assert property (@(posedge clk) disable iff (!rst_n) bit_cnt <= nbits_m1)
    else $error("chilimix_uart_tx: bit_cnt %0d past the last data bit %0d", bit_cnt, nbits_m1);

  // Helper for the k-induction proof of uart_tx_bit_cnt: outside S_DATA the
  // bit counter is cleared.
  uart_tx_bit_cnt_clr: assert property (@(posedge clk) disable iff (!rst_n) state_q == 3'd2 || bit_cnt == '0)
    else $error("chilimix_uart_tx: bit_cnt %0d outside S_DATA", bit_cnt);

  // The line format is latched per frame: it only changes on in_fire
  // (the accept), so an LCR write mid-frame cannot reshape the frame.
  uart_tx_fmt_hold: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(in_fire) || fmt == $past(fmt))
    else $error("chilimix_uart_tx: line format changed inside a frame");

endmodule

bind chilimix_uart_tx chilimix_uart_tx_chk u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .state_q   (state_q),
  .in_accept (in_accept),
  .busy      (busy),
  .in_fire   (in_fire),
  .fmt       (fmt),
  .bit_cnt   (bit_cnt),
  .nbits_m1  (nbits_m1)
);
