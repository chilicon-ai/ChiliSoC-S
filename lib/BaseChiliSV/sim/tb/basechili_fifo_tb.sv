// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_fifo -- random valid / accept / flush against a
// queue model; count, order, full-rate streaming.
`include "tb_common.svh"
module basechili_fifo_tb #(
  parameter  int WIDTH = 32,
  parameter  int DEPTH = 4,
  localparam int CNT_W = $clog2(DEPTH + 1)
);
  `TB_CLOCK_RESET
  logic             flush, in_valid, in_accept, out_valid, out_accept, in_fire, out_fire;
  logic [WIDTH-1:0] in_data, out_data;
  logic [CNT_W-1:0] count;
  logic [WIDTH-1:0] q[$];

  basechili_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (.clk, .rst_n, .flush, .in_valid, .in_accept, .in_data,
                                                      .out_valid, .out_accept, .out_data, .count);

  initial begin
    flush = 1'b0; in_valid = 1'b0; in_data = '0; out_accept = 1'b0; in_fire = 1'b0;
    tb_reset();
    for (int t = 0; t < 30000; t++) begin
      if (!in_valid || in_fire || flush) begin
        in_valid = ($urandom % 4) != 0;
        in_data  = WIDTH'({$urandom, $urandom});
      end
      out_accept = (t % 2000 < 200) ? 1'b0 : ($urandom % 3 != 0);   // fill phases
      flush = ($urandom % 300) == 0;
      #1;
      `CHECK(int'(count) == q.size() && in_accept == (q.size() < DEPTH) && out_valid == (q.size() > 0),
             $sformatf("count=%0d model=%0d", count, q.size()))
      if (out_valid) `CHECK(out_data == q[0], $sformatf("out_data=%h expected %h", out_data, q[0]))
      in_fire  = in_valid && in_accept;
      out_fire = out_valid && out_accept;
      @(posedge clk); #1;
      if (flush) q.delete();
      else begin
        if (out_fire) void'(q.pop_front());
        if (in_fire) q.push_back(in_data);
      end
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
