// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_i2c_bit -- random bus commands against open-drain
// lines with a target model and a bus monitor.
//
// Stimulus: transactions START, 1 .. 20 bit writes and reads (now and then
// a repeated START), STOP, with a random prescale (2 .. 6, sometimes up to
// 40) set while ena is clear; the target answers reads with random bits
// and stretches scl (holds it low for 1 .. 20 clocks after the engine
// releases it) at random; another master pulls sda low during a written 1
// (arbitration); ena dropped in the middle of a command now and then.
// Checked: the monitor's bus events (START, STOP, and the bits sampled on
// scl high) equal the commands; dout is the bus bit of each command; done
// once per command, al only in the arbitration episodes and then both lines
// released; scl high and low times at least 2 * (prescale + 1) clocks;
// busy after START / STOP; ena clear releases both lines.
`include "tb_common.svh"
module chilimix_i2c_bit_tb;
  localparam int N_TR = 1500;
  localparam int EV_S = 2, EV_P = 3;     // monitor events besides bits 0 / 1

  `TB_CLOCK_RESET

  logic        ena;
  logic [15:0] prescale;
  logic        cmd_valid;
  logic [1:0]  cmd;
  logic        din;
  logic        cmd_accept, done, dout, al, busy;
  logic        scl_i, sda_i, scl_oe, sda_oe;

  chilimix_i2c_bit dut (.*);

  // ---- open-drain lines --------------------------------------------------------
  logic tgt_scl_low, tgt_sda_low, oth_sda_low;
  assign scl_i = !(scl_oe || tgt_scl_low);
  assign sda_i = !(sda_oe || tgt_sda_low || oth_sda_low);

  // ---- target: clock stretching ----------------------------------------------------
  logic scl_oe_q;
  int   stretch_left, n_stretch;
  always @(negedge clk) begin
    if (!rst_n) begin
      scl_oe_q = 0; tgt_scl_low = 0; stretch_left = 0;
    end else begin
      if (stretch_left > 0) begin
        stretch_left--;
        if (stretch_left == 0) tgt_scl_low = 0;
      end else if (scl_oe_q && !scl_oe && $urandom % 3 == 0) begin
        stretch_left = 1 + $urandom % 20;
        tgt_scl_low  = 1;
        n_stretch++;
      end
      scl_oe_q = scl_oe;
    end
  end

  // ---- bus monitor ----------------------------------------------------------------
  int   mon[$];
  logic scl_p, sda_p, hi_bit, hi_ev;
  int   t_edge, min_hi, min_lo;
  always @(posedge clk) begin
    if (!rst_n) begin
      scl_p = 1; sda_p = 1; hi_ev = 0; t_edge = 0; min_hi = 1 << 30; min_lo = 1 << 30;
    end else begin
      t_edge++;
      if (scl_i && !scl_p) begin                       // rise
        hi_bit = sda_i; hi_ev = 0;
        if (t_edge < min_lo) min_lo = t_edge;
        t_edge = 0;
      end else if (!scl_i && scl_p) begin              // fall
        if (!hi_ev) mon.push_back(int'(hi_bit));
        if (t_edge < min_hi) min_hi = t_edge;
        t_edge = 0;
      end else if (scl_i && scl_p && sda_i != sda_p) begin
        mon.push_back(sda_i ? EV_P : EV_S);
        hi_ev = 1;
      end
      scl_p = scl_i; sda_p = sda_i;
    end
  end

  // ---- commands -------------------------------------------------------------------
  int exp_ev[$];
  int n_cmd[4], n_al, n_abort;

  task automatic check_events();
    `CHECK(mon.size() == exp_ev.size(), "number of bus events")
    for (int i = 0; i < exp_ev.size() && i < mon.size(); i++)
      `CHECK(mon[i] == exp_ev[i], "bus event")
    mon.delete(); exp_ev.delete();
  endtask

  // run one command; returns 1 if arbitration was lost
  task automatic run(input logic [1:0] c, input logic d, input logic other, output logic lost);
    logic tb;
    int   n;
    tb = $urandom;
    cmd_valid = 1; cmd = c; din = d;
    if (c == 2'd3) tgt_sda_low = !tb;                // scl is low: the target sets its bit
    oth_sda_low = other;
    #1;
    `CHECK(cmd_accept, "the engine is idle between commands")
    @(negedge clk);
    cmd_valid = 0; cmd = $urandom; din = $urandom;
    lost = 0; n = 0;
    while (!done && !al && n < 1000000) begin @(negedge clk); n++; end
    `CHECK(n < 1000000, "the command finishes")
    `CHECK(!(done && al), "done and al together")
    if (al) begin
      `CHECK(other, "al only when another master drives")
      lost = 1;
      @(negedge clk);
      `CHECK(!scl_oe && !sda_oe, "lines released after al")
    end else begin
      `CHECK(!other || !d || c != 2'd2, "a written 1 under a 0 must lose")
      if (c == 2'd0) exp_ev.push_back(EV_S);
      else if (c == 2'd1) exp_ev.push_back(EV_P);
      else if (c == 2'd2) begin exp_ev.push_back(int'(d)); `CHECK(dout == d, "dout of a write") end
      else begin exp_ev.push_back(int'(tb)); `CHECK(dout == tb, "dout of a read") end
      @(negedge clk);
    end
    tgt_sda_low = 0;
    n_cmd[c]++;
  endtask

  task automatic settle();
    int n;
    repeat (4) @(negedge clk);
    n = 0;
    while ((!scl_i || !sda_i || stretch_left != 0) && n < 1000) begin @(negedge clk); n++; end
    repeat (4) @(negedge clk);
  endtask

  initial begin
    logic lost;
    ena = 0; prescale = 16'd3; cmd_valid = 0; cmd = 0; din = 0;
    tgt_sda_low = 0; oth_sda_low = 0;
    n_stretch = 0; n_al = 0; n_abort = 0; n_cmd = '{default: 0};
    tb_reset();
    @(negedge clk);
    for (int t = 0; t < N_TR; t++) begin
      int nb, p;
      // new prescale while disabled
      ena = 0;
      repeat (2) @(negedge clk);
      `CHECK(!scl_oe && !sda_oe, "ena clear releases the lines")
      p = ($urandom % 8 == 0) ? 2 + $urandom % 39 : 2 + $urandom % 5;
      prescale = 16'(p);
      ena = 1;
      @(negedge clk);
      min_hi = 1 << 30; min_lo = 1 << 30;
      run(2'd0, 0, 0, lost);
      repeat (4) @(negedge clk);
      `CHECK(busy, "busy after START")
      nb = 1 + $urandom % 20;
      for (int i = 0; i < nb && !lost; i++) begin
        if ($urandom % 12 == 0) begin
          run(2'd0, 0, 0, lost);                   // repeated START
        end else if ($urandom % 2 == 0) begin
          logic d, oth;
          d   = $urandom;
          oth = d && $urandom % 40 == 0;
          run(2'd2, d, oth, lost);
          if (lost) n_al++;
        end else begin
          run(2'd3, 0, 0, lost);
        end
        if (!lost && $urandom % 150 == 0) begin
          // ena dropped in the middle of a command
          cmd_valid = 1; cmd = 2'($urandom % 2 + 2); din = $urandom;
          repeat (1 + $urandom % (6 * p)) @(negedge clk);
          cmd_valid = 0; ena = 0;
          @(negedge clk);
          #1;
          `CHECK(!scl_oe && !sda_oe, "ena clear releases the lines")
          lost = 1; n_abort++;
        end
      end
      if (lost) begin
        // other master finishes: release sda (a STOP if scl is high)
        repeat (3 * p) @(negedge clk);
        oth_sda_low = 0;
        settle();
        // the other master's START and STOP on the idle bus: busy follows
        oth_sda_low = 1;
        repeat (10) @(negedge clk);
        `CHECK(busy, "busy after a foreign START")
        oth_sda_low = 0;
        repeat (10) @(negedge clk);
        `CHECK(!busy, "busy cleared by a foreign STOP")
        mon.delete(); exp_ev.delete();
        continue;
      end
      run(2'd1, 0, 0, lost);
      settle();
      `CHECK(!busy, "busy cleared by STOP")
      check_events();
      `CHECK(min_hi >= 2 * (p + 1) && min_lo >= 2 * (p + 1), "scl high / low time")
    end
    // the slowest prescale once (every bit of the phase counter)
    ena = 0;
    repeat (2) @(negedge clk);
    prescale = 16'hffff;
    ena = 1;
    @(negedge clk);
    run(2'd0, 0, 0, lost);
    run(2'd2, 1, 0, lost);
    run(2'd1, 0, 0, lost);
    settle();
    check_events();
    prescale = 16'h0;
    $display("commands: start %0d stop %0d write %0d read %0d; arbitration lost %0d, aborted %0d, stretches %0d",
             n_cmd[0], n_cmd[1], n_cmd[2], n_cmd[3], n_al, n_abort, n_stretch);
    `CHECK(n_al > 20 && n_abort > 5 && n_stretch > 1000, "coverage")
    tb_pass();
  end
endmodule
