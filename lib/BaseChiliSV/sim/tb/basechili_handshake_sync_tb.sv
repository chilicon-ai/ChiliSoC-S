// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_handshake_sync -- two unrelated clocks (half
// periods SRC_HALF / DST_HALF); random words with random src_valid gaps and
// random dst_accept stalls; every word arrives once, in order; dst_valid and
// dst_data hold until accepted; src_accept is low while a word is in flight
// and returns within the round-trip bound. Mid-run reset of both domains.
`include "tb_common.svh"
module basechili_handshake_sync_tb #(
  parameter int WIDTH    = 32,
  parameter int STAGES   = 2,
  parameter int SRC_HALF = 5,    // TB only: src_clk half period
  parameter int DST_HALF = 7     // TB only: dst_clk half period
);
  localparam time TRIP = (STAGES + 2) * 2 * (SRC_HALF + DST_HALF);   // one-way bound + margin

  logic             src_clk = 1'b0, dst_clk = 1'b0;
  logic             src_rst_n = 1'b0, dst_rst_n = 1'b0;
  logic             src_valid, src_accept, dst_valid, dst_accept;
  logic [WIDTH-1:0] src_data, dst_data;
  logic [WIDTH-1:0] q[$];          // words sent, not yet received
  int               n_rx;
  bit               dst_hold;      // dst_valid was high and not accepted
  logic [WIDTH-1:0] dst_last;      // dst_data while held
  bit               src_busy;      // a word in flight (TB view)
  time              t_dst_fire;    // last dst transfer

  always #(SRC_HALF) src_clk = ~src_clk;
  always #(DST_HALF) dst_clk = ~dst_clk;

  basechili_handshake_sync #(.WIDTH(WIDTH), .STAGES(STAGES)) dut (
    .src_clk, .src_rst_n, .src_valid, .src_accept, .src_data,
    .dst_clk, .dst_rst_n, .dst_valid, .dst_accept, .dst_data);

  function automatic logic [WIDTH-1:0] rnd();
    logic [WIDTH-1:0] v;
    for (int b = 0; b < WIDTH; b++) v[b] = 1'($urandom);
    return v;
  endfunction

  // source side: drive after the falling edge, transfer at the rising edge
  task automatic source(int n);
    int sent;
    sent = 0;
    while (sent < n) begin
      @(negedge src_clk);
      if (!src_valid) begin
        src_valid = ($urandom % 3) != 0;
        src_data  = rnd();
      end
      #1;
      if (src_busy) `CHECK(!src_accept, "src_accept high with a word in flight")
      if (!src_busy && !src_accept)
        `CHECK($time - t_dst_fire <= TRIP, $sformatf("src_accept late: t=%0t, dst transfer at %0t", $time, t_dst_fire))
      @(posedge src_clk);
      if (src_valid && src_accept) begin
        q.push_back(src_data); sent++; src_busy = 1'b1;
        @(negedge src_clk);
        src_valid = 1'b0;
      end
    end
  endtask

  // destination side
  task automatic sink(int n);
    int got;
    got = 0;
    while (got < n) begin
      @(negedge dst_clk);
      dst_accept = ($urandom % 3) != 0;
      #1;
      if (dst_hold) `CHECK(dst_valid && dst_data == dst_last, "dst_valid / dst_data not held until accepted")
      if (dst_valid) begin
        `CHECK(q.size() > 0, "dst_valid with no word sent")
        if (q.size() > 0) `CHECK(dst_data == q[0], $sformatf("dst_data=%h expected %h", dst_data, q[0]))
      end
      @(posedge dst_clk);
      dst_hold = dst_valid && !dst_accept;
      dst_last = dst_data;
      if (dst_valid && dst_accept) begin
        void'(q.pop_front()); got++; n_rx++;
        src_busy = 1'b0; t_dst_fire = $time;
      end
    end
  endtask

  task automatic do_reset();
    src_rst_n = 1'b0; dst_rst_n = 1'b0;
    src_valid = 1'b0; dst_accept = 1'b0; dst_hold = 1'b0; src_busy = 1'b0;
    q.delete();
    repeat (3) @(posedge src_clk);
    repeat (3) @(posedge dst_clk);
    @(negedge src_clk) src_rst_n = 1'b1;
    @(negedge dst_clk) dst_rst_n = 1'b1;
    t_dst_fire = $time;
  endtask

  initial begin
    src_data = '0; n_rx = 0;
    do_reset();
    fork source(1500); sink(1500); join
    do_reset();
    fork source(1500); sink(1500); join
    `CHECK(n_rx == 3000 && q.size() == 0, $sformatf("received %0d words", n_rx))
    tb_pass();
  end
endmodule
