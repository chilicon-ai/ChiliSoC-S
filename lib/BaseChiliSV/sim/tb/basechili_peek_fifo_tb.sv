// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_peek_fifo -- random push / pop / flush against a
// queue model (never push when full without a pop, never pop when empty);
// count, full, empty and the PEEK window.
`include "tb_common.svh"
module basechili_peek_fifo_tb #(
  parameter  int WIDTH = 32,
  parameter  int DEPTH = 4,
  parameter  int PEEK  = 2,
  localparam int CNT_W = $clog2(DEPTH + 1),
  parameter bit CLOCK_GATE = 1'b0
);
  `TB_CLOCK_RESET
  logic                  flush, push, pop, full, empty;
  logic [WIDTH-1:0]      wdata;
  logic [PEEK*WIDTH-1:0] rdata;
  logic [CNT_W-1:0]      count;
  logic [WIDTH-1:0]      q[$];

  basechili_peek_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH), .PEEK(PEEK), .CLOCK_GATE(CLOCK_GATE)) dut (.clk, .rst_n, .test_en(1'b0), .flush, .push, .wdata, .pop, .rdata, .count, .full, .empty);

  initial begin
    flush = 1'b0; push = 1'b0; pop = 1'b0; wdata = '0;
    tb_reset();
    for (int t = 0; t < 20000; t++) begin
      `CHECK(int'(count) == q.size() && full == (q.size() == DEPTH) && empty == (q.size() == 0), $sformatf("count=%0d model=%0d", count, q.size()))
      for (int i = 0; i < PEEK; i++)
        if (i < q.size()) `CHECK(rdata[i*WIDTH +: WIDTH] == q[i], $sformatf("window %0d: %h expected %h", i, rdata[i*WIDTH +: WIDTH], q[i]))
      flush = ($urandom % 200) == 0;
      pop   = (q.size() > 0) && ($urandom % 2) && (t % 1000 >= 100);   // fill phases: no pop
      push  = ((q.size() < DEPTH) || pop) && ($urandom % 2);
      wdata = WIDTH'({$urandom, $urandom});
      @(posedge clk); #1;
      if (flush) q.delete();
      else begin
        if (pop) void'(q.pop_front());
        if (push) q.push_back(wdata);
      end
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
