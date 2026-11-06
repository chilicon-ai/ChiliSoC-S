// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_uart_chk (simulation and formal; bound into every chilimix_uart)
//   - the RX error count is 0 when the RX FIFO is empty, and never above the
//     RX FIFO count                                         (header Invariant)
//   - irq is the registered (iir_id != 1)                   (header Invariant)
//   - helpers that make uart_err_cnt inductive: the error count equals the
//     number of RX FIFO entries with an error bit (bits 10:8: bi, fe, pe),
//     and the RX FIFO's pointers and count agree (wr_ptr = rd_ptr + count,
//     count <= DEPTH)
// -----------------------------------------------------------------------------
module chilimix_uart_chk #(
  parameter int DEPTH = 16,                // RX FIFO entries (chilimix_uart DEPTH)
  localparam int AW = $clog2(DEPTH)
) (
  input logic                  clk,
  input logic                  rst_n,
  input logic [4:0]            err_cnt,
  input logic [4:0]            rx_count,
  input logic [3:0]            iir_id,
  input logic                  irq,
  input logic [DEPTH*11-1:0]   rx_mem,     // RX FIFO storage: entry i at [i*11 +: 11]
  input logic [AW-1:0]         rx_rd_ptr,  // RX FIFO head entry
  input logic [AW-1:0]         rx_wr_ptr   // RX FIFO next entry written
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  uart_err_cnt: assert property (@(posedge clk) disable iff (!rst_n) err_cnt <= rx_count)
    else $error("chilimix_uart: %0d error characters in an RX FIFO of %0d", err_cnt, rx_count);

  // error entries among the rx_count valid ones from the head
  logic [4:0] err_ref;
  always_comb begin
    err_ref = '0;
    for (int i = 0; i < DEPTH; i++)
      if (5'(i) < rx_count && |rx_mem[32'(AW'(rx_rd_ptr + AW'(i))) * 11 + 8 +: 3])
        err_ref = err_ref + 5'd1;
  end

  uart_err_exact: assert property (@(posedge clk) disable iff (!rst_n) err_cnt == err_ref)
    else $error("chilimix_uart: error count %0d, %0d error entries in the RX FIFO", err_cnt, err_ref);

  uart_rx_ptrs: assert property (@(posedge clk) disable iff (!rst_n)
                   rx_count <= 5'(DEPTH) && rx_wr_ptr == AW'(rx_rd_ptr + AW'(rx_count)))
    else $error("chilimix_uart: RX FIFO count %0d, rd_ptr %0d, wr_ptr %0d disagree", rx_count, rx_rd_ptr, rx_wr_ptr);

  uart_irq_reg: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || irq == $past(iir_id != 4'h1))
    else $error("chilimix_uart: irq is not the registered iir_id != 1");

endmodule

bind chilimix_uart chilimix_uart_chk u_chk (
  .clk      (clk),
  .rst_n    (rst_n),
  .err_cnt  (err_cnt),
  .rx_count (rx_count),
  .iir_id   (iir_id),
  .irq      (irq),
  .rx_mem   (u_rx_fifo.u_q.u_mem.mem),
  .rx_rd_ptr(u_rx_fifo.u_q.rd_ptr),
  .rx_wr_ptr(u_rx_fifo.u_q.wr_ptr)
);
