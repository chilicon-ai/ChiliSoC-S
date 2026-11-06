// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_uart_rx -- serial frames with random line formats,
// errors, breaks and glitches against the characters and flags they encode.
//
// Stimulus: random ticks (16x baud enable); rxd driven bit by bit, each bit
// 16 ticks long, in a random format per frame (word length, parity, eps,
// stick, 1 or 2 stop bits). Some frames get a flipped parity bit or a 0 stop
// bit, some are breaks (all low for longer than a frame), some are start-bit
// glitches (low for fewer than 8 ticks, no character), with random idle
// time between frames. Now and then LCR is scrambled after the start bit
// (the frame keeps the format it started with).
// Checked: every out_valid matches the next expected character, data,
// pe, fe and bi, and no expected character is missing at the end.
`include "tb_common.svh"
module chilimix_uart_rx_tb;
  localparam int N_FRAME = 1500;

  `TB_CLOCK_RESET

  logic       tick;
  logic       rxd;
  logic [1:0] wls;
  logic       pen, eps, stick;
  logic       out_valid;
  logic [7:0] out_data;
  logic       out_pe, out_fe, out_bi;
  logic       busy;

  chilimix_uart_rx dut (.*);

  typedef struct packed {
    logic [7:0] data;
    logic       pe, fe, bi;
  } char_t;

  char_t exp_q [$];
  int    period, n_out;

  // ticks: random, density changes now and then
  always @(negedge clk) tick <= rst_n && ($urandom % period == 0);

  // received characters against the expected queue
  always @(posedge clk) if (rst_n && out_valid) begin
    char_t e;
    `CHECK(exp_q.size() != 0, "unexpected character")
    if (exp_q.size() != 0) begin
      e = exp_q.pop_front();
      `CHECK(out_data == e.data, "data")
      `CHECK(out_pe == e.pe, "parity error flag")
      `CHECK(out_fe == e.fe, "framing error flag")
      `CHECK(out_bi == e.bi, "break flag")
      n_out++;
    end
  end

  // hold rxd at v for n ticks (rxd changes just after a tick edge)
  task automatic hold(logic v, int n);
    rxd = v;
    repeat (n) begin
      @(posedge clk);
      while (!tick) @(posedge clk);
    end
    @(negedge clk);
  endtask

  task automatic frame(logic [7:0] d, bit bad_par, bit bad_stop, bit two_stop);
    int    nb;
    logic  par;
    char_t e;
    bit    f_pen;
    nb    = 5 + int'(wls);
    f_pen = pen;
    d     = d & 8'((1 << nb) - 1);
    par   = ^d;
    par   = stick ? !eps : (eps ? par : !par);
    e.data = d;
    e.pe   = pen && bad_par;
    e.fe   = bad_stop;
    e.bi   = bad_stop && d == 0 && !(pen && (par ^ bad_par));
    exp_q.push_back(e);
    hold(1'b0, 16);
    if ($urandom % 8 == 0) begin
      // an LCR write mid-frame: the frame keeps the format of its start bit
      wls = 2'($urandom); pen = $urandom % 2; eps = $urandom % 2; stick = $urandom % 4 == 0;
    end
    for (int b = 0; b < nb; b++) hold(d[b], 16);
    if (f_pen) hold(par ^ bad_par, 16);
    // a 0 stop bit lasts only just past its middle (the receiver samples at
    // tick 8 or 9: a tick in the start-detect cycle is not counted); a 16550
    // takes a line still low after the stop sample as the next start bit
    if (bad_stop) hold(1'b0, 9);
    else          hold(1'b1, two_stop ? 32 : 16);
  endtask

  initial begin
    tick = 0; rxd = 1; wls = 3; pen = 0; eps = 0; stick = 0;
    period = 1; n_out = 0;
    tb_reset();
    for (int f = 0; f < N_FRAME; f++) begin
      if (f % 150 == 0) period = 1 + $urandom % 3;
      wls = 2'($urandom); pen = $urandom % 2; eps = $urandom % 2; stick = $urandom % 4 == 0;
      case ($urandom % 12)
        0: begin   // break: low for a frame and more, the receiver waits for high
          char_t e;
          e.data = '0; e.fe = 1; e.bi = 1;
          e.pe = pen && !eps;   // parity bit 0 received, 1 expected for data 0 unless eps
          exp_q.push_back(e);
          hold(1'b0, 16 * (2 + 5 + int'(wls) + int'(pen)) + 16 * ($urandom % 4));
          hold(1'b1, 1 + $urandom % 8);
        end
        1: begin   // glitch: low for under half a bit, no character
          hold(1'b0, 1 + $urandom % 6);
          hold(1'b1, 16);
        end
        2: frame(8'($urandom), 1'b1, 1'b0, 1'b0);              // parity bit flipped
        3, 4: begin                                            // stop bit 0 (on zero data: a break)
          frame(($urandom % 2) ? 8'h00 : 8'($urandom), $urandom % 2 == 0, 1'b1, 1'b0);
          hold(1'b1, 16);   // the line must idle before the next start bit
        end
        default: frame(8'($urandom), 1'b0, 1'b0, $urandom % 2 == 0);
      endcase
      if ($urandom % 2) hold(1'b1, $urandom % 40);              // idle time
    end
    hold(1'b1, 64);
    `CHECK(exp_q.size() == 0, "missing characters")
    $display("received %0d characters", n_out);
    tb_pass();
  end
endmodule
