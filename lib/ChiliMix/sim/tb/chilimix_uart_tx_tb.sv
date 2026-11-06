// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_uart_tx -- characters with random line formats
// against a model of the expected waveform.
//
// Stimulus: random ticks (16x baud enable), characters offered at random
// times, a new random line format (word length, stop bits, parity, eps,
// stick) before each character, break toggled now and then, and LCR
// scrambled mid-frame now and then (the frame keeps its accepted format).
// Checked every cycle: in_accept == !busy == idle in the model; txd equals
// the model's frame bit (start, data LSB first, parity, stop bits of 16 /
// 24 / 32 ticks), forced low by brk.
`include "tb_common.svh"
module chilimix_uart_tx_tb;
  localparam int N_CHAR = 1500;

  `TB_CLOCK_RESET

  logic       tick;
  logic [1:0] wls;
  logic       stb, pen, eps, stick, brk;
  logic       in_valid, in_accept;
  logic [7:0] in_data;
  logic       txd, busy;

  chilimix_uart_tx dut (.*);

  bit   frame [$];   // expected line value per tick of the character in flight
  int   n_tick;      // ticks of the frame already on the line
  bit   active;      // model: a frame in flight
  int   sent, period;
  bit   fire;        // character accepted this cycle

  function automatic void build(logic [7:0] d);
    int nb;
    bit par;
    nb = 5 + int'(wls);
    frame.delete();
    for (int i = 0; i < 16; i++) frame.push_back(1'b0);
    par = 1'b0;
    for (int b = 0; b < nb; b++) begin
      for (int i = 0; i < 16; i++) frame.push_back(d[b]);
      par ^= d[b];
    end
    if (pen) begin
      par = stick ? !eps : (eps ? par : !par);
      for (int i = 0; i < 16; i++) frame.push_back(par);
    end
    for (int i = 0; i < (!stb ? 16 : (wls == 0) ? 24 : 32); i++) frame.push_back(1'b1);
  endfunction

  initial begin
    tick = 0; wls = 3; stb = 0; pen = 0; eps = 0; stick = 0; brk = 0;
    in_valid = 0; in_data = '0;
    active = 0; n_tick = 0; sent = 0; period = 1;
    tb_reset();
    while (sent < N_CHAR) begin
      // drive after the falling edge
      if (sent % 200 == 0) period = 1 + $urandom % 4;   // tick density
      tick = ($urandom % period == 0);
      if ($urandom % 3000 == 0) brk = !brk;
      if (active && $urandom % 300 == 0) begin
        // an LCR write mid-frame: the frame in flight keeps its format
        wls = 2'($urandom); stb = $urandom % 2; pen = $urandom % 2; eps = $urandom % 2; stick = $urandom % 4 == 0;
      end
      if (!active && !in_valid && $urandom % 4 == 0) begin
        // a new line format while idle, then offer a character
        wls = 2'($urandom); stb = $urandom % 2; pen = $urandom % 2; eps = $urandom % 2; stick = $urandom % 4 == 0;
        in_valid = 1; in_data = 8'($urandom);
      end
      #1;
      `CHECK(in_accept == !active, "in_accept is idle")
      `CHECK(busy == active, "busy")
      if (active) `CHECK(txd == (frame[n_tick] && !brk), "txd frame bit")
      else        `CHECK(txd == !brk, "txd idle high")
      fire = in_valid && in_accept;
      @(posedge clk);
      // model update at the edge
      if (active && tick) begin
        n_tick++;
        if (n_tick == frame.size()) active = 0;
      end
      if (fire) begin
        build(in_data);
        active = 1; n_tick = 0; sent++;
      end
      @(negedge clk);
      if (fire) in_valid = 0;   // inputs change only after the falling edge
    end
    tb_pass();
  end
endmodule
