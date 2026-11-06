// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_clock_div -- clk_out and tick against a model of
// the periods (div sampled at the end of each period, values below 2 act as
// 2, 2 after reset), checked in every clk half cycle; clk_out high and low
// times measured in simulation time (high = div / 2 clk cycles for even and
// odd divisors, low the same between periods of equal parity), and no pulse
// of clk_out shorter than half a clk period. Directed: every divisor 0 ..
// 2**W - 1, a divisor change mid-period, reset mid-period; then random.
`include "tb_common.svh"
module basechili_clock_div_tb #(
  parameter int W = 8
);
  `TB_CLOCK_RESET
  localparam int HALF = 5;              // half a clk period in time units
  localparam int MAXD = (1 << W) - 1;

  logic [W-1:0] div = '0;
  logic         clk_out, tick;

  basechili_clock_div #(.W(W)) dut (.clk, .rst_n, .div, .clk_out, .tick);

  function automatic int eff(logic [W-1:0] d);
    return (int'(d) < 2) ? 2 : int'(d);
  endfunction

  // ---- model: period divisor and cycle in it (blocking, before the DUT's
  // flops update, so it is current when clk_out changes) ----
  int m_cnt = 0;
  int m_d   = 2;
  always @(posedge clk or negedge rst_n)
    if (!rst_n)                 begin m_cnt = 0; m_d = 2; end
    else if (m_cnt == m_d - 1)  begin m_cnt = 0; m_d = eff(div); end
    else                        m_cnt = m_cnt + 1;

  // expected clk_out in half cycle slot s (0 .. 2 * d - 1) of a period
  function automatic logic exp_out(int d, int s);
    return (d % 2 == 0) ? (s < d) : (s >= 1 && s <= d);
  endfunction

  // half-cycle compare, 1 time unit after each clk edge
  always @(clk) if (rst_n) begin
    #1;
    `CHECK(clk_out == exp_out(m_d, 2 * m_cnt + (clk ? 0 : 1)),
           $sformatf("t=%0t clk_out=%b d=%0d cnt=%0d", $time, clk_out, m_d, m_cnt))
    `CHECK(tick == (m_cnt == m_d - 1), $sformatf("t=%0t tick=%b d=%0d cnt=%0d", $time, tick, m_d, m_cnt))
  end

  // ---- clk_out timing in simulation time ----
  bit  meas = 1'b0;               // measuring (cleared by reset)
  bit  have_last, have_rise, have_fall;
  time t_last, t_rise, t_fall;
  int  pd;                        // divisor of the last high pulse
  always @(clk_out) if (meas) begin
    if (have_last)
      `CHECK($time - t_last >= HALF, $sformatf("t=%0t clk_out glitch: %0t long pulse", $time, $time - t_last))
    t_last = $time; have_last = 1'b1;
    if (clk_out) begin
      if (have_fall)
        `CHECK($time - t_fall == HALF * (pd + m_d % 2 - pd % 2),
               $sformatf("t=%0t low time %0t after d=%0d, next d=%0d", $time, $time - t_fall, pd, m_d))
      t_rise = $time; pd = m_d; have_rise = 1'b1;
    end else begin
      if (have_rise)
        `CHECK($time - t_rise == HALF * pd, $sformatf("t=%0t high time %0t for d=%0d", $time, $time - t_rise, pd))
      t_fall = $time; have_fall = have_rise;
    end
  end

  task automatic do_reset();
    meas = 1'b0; have_last = 1'b0; have_rise = 1'b0; have_fall = 1'b0;
    rst_n = 1'b0;
    #1 `CHECK(clk_out && !tick, "reset: clk_out high, no tick")
    tb_reset();
    meas = 1'b1;
  endtask

  task automatic wait_ticks(int n);
    repeat (n) begin
      @(posedge clk iff tick);
    end
    @(negedge clk);
  endtask

  initial begin
    int d0, d1, c;
    rst_n = 1'b1;           // a falling edge for the first reset
    #2 do_reset();
    // first period after reset is 2 cycles, whatever div is
    div = W'(MAXD);
    @(posedge clk); #1 `CHECK(tick, "first period after reset is 2 cycles")
    @(negedge clk);

    // every divisor, three periods each
    for (int d = 0; d <= MAXD; d++) begin
      div = W'(d);
      wait_ticks(3);
    end
    for (int d = MAXD; d >= 0; d--) begin
      div = W'(d);
      wait_ticks(2);
    end

    // a change mid-period takes effect with the next period
    d0 = (W >= 3) ? 7 : 3;
    d1 = (W >= 3) ? 4 : 2;
    div = W'(d0);
    wait_ticks(2);                    // now in a d0 period, cycle 0
    @(posedge clk); @(negedge clk);   // cycle 1
    div = W'(d1);
    c = 2;
    while (!tick) begin @(posedge clk); @(negedge clk); c++; end
    `CHECK(c == d0, $sformatf("period after the change was %0d cycles, expected %0d", c, d0))
    c = 1;
    @(posedge clk); @(negedge clk);
    while (!tick) begin @(posedge clk); @(negedge clk); c++; end
    `CHECK(c == d1, $sformatf("next period %0d cycles, expected %0d", c, d1))

    // reset mid-period
    div = W'(MAXD);
    wait_ticks(1);
    repeat (MAXD / 2) @(posedge clk);
    #2 do_reset();

    // random divisors at random times
    for (int t = 0; t < 3000; t++) begin
      repeat ($urandom_range(0, 12)) @(negedge clk);
      div = ($urandom_range(0, 3) == 0 || W <= 4) ? W'($urandom) : W'($urandom_range(0, 9));
    end
    wait_ticks(2);
    tb_pass();
  end
endmodule
