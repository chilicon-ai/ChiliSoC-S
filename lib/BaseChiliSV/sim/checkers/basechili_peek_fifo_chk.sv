// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_peek_fifo_chk (bound into every basechili_peek_fifo)
//
// Simulation-only invariant checks (not RTL; source/ rules do not apply).
//   - count <= DEPTH                         (header Invariants)
//   - wr_ptr == (rd_ptr + count) mod DEPTH   (header Invariants)
//   - no push while full without a pop, no pop while empty (header Debug:
//     "neither is checked in RTL"), unless flush
//   - data: a reference queue of the pushed entries; window entry i (i <
//     min(count, PEEK)) equals the i-th oldest pushed entry
// -----------------------------------------------------------------------------
module basechili_peek_fifo_chk #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 4,
  parameter int PEEK  = 2,
  parameter int AW    = 2,
  parameter int CNT_W = 3
) (
  input logic                  clk,
  input logic                  rst_n,
  input logic                  flush,
  input logic                  push,
  input logic [WIDTH-1:0]      wdata,
  input logic                  pop,
  input logic [PEEK*WIDTH-1:0] rdata,
  input logic [CNT_W-1:0]      count,
  input logic [AW-1:0]         wr_ptr,
  input logic [AW-1:0]         rd_ptr
);

  int unsigned ptr_sum;   // (rd_ptr + count) mod DEPTH
  assign ptr_sum = (32'(rd_ptr) + 32'(count)) % DEPTH;

  assert property (@(posedge clk) disable iff (!rst_n) 32'(count) <= DEPTH)
    else $error("basechili_peek_fifo: count <= DEPTH violated: count=%0d DEPTH=%0d", count, DEPTH);

  assert property (@(posedge clk) disable iff (!rst_n) 32'(wr_ptr) == ptr_sum)
    else $error("basechili_peek_fifo: wr_ptr == (rd_ptr + count) mod DEPTH violated: wr_ptr=%0d rd_ptr=%0d count=%0d",
                wr_ptr, rd_ptr, count);

  assert property (@(posedge clk) disable iff (!rst_n)
                   !(push && !pop && !flush && 32'(count) == DEPTH))
    else $error("basechili_peek_fifo: push while full (no pop): count=%0d DEPTH=%0d", count, DEPTH);

  assert property (@(posedge clk) disable iff (!rst_n) !(pop && !flush && count == '0))
    else $error("basechili_peek_fifo: pop while empty: push=%0b", push);

  // reference model: the entries in push order
  logic [WIDTH-1:0] model [$];
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      model.delete();
    end else begin
      for (int i = 0; i < PEEK; i++) begin
        if (i < model.size() && 32'(count) > i)
          assert (rdata[i*WIDTH +: WIDTH] == model[i])
            else $error("basechili_peek_fifo: window entry %0d != pushed data: rdata=%h expected=%h count=%0d",
                        i, rdata[i*WIDTH +: WIDTH], model[i], count);
      end
      assert (model.size() == 32'(count))
        else $error("basechili_peek_fifo: count != entries pushed - popped: count=%0d model=%0d", count, model.size());
      if (flush) begin
        model.delete();
      end else begin
        if (pop && model.size() != 0) void'(model.pop_front());
        if (push) model.push_back(wdata);
      end
    end
  end

endmodule

bind basechili_peek_fifo basechili_peek_fifo_chk #(
  .WIDTH (WIDTH),
  .DEPTH (DEPTH),
  .PEEK  (PEEK),
  .AW    (AW),
  .CNT_W (CNT_W)
) u_chk (
  .clk    (clk),
  .rst_n  (rst_n),
  .flush  (flush),
  .push   (push),
  .wdata  (wdata),
  .pop    (pop),
  .rdata  (rdata),
  .count  (count),
  .wr_ptr (wr_ptr),
  .rd_ptr (rd_ptr)
);
