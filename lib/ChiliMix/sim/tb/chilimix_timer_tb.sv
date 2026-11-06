// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_timer -- the address map and wiring of the timer top:
// N_PWM PWM devices at 0x100 * k and the watchdog at 0x400 (each device's
// behavior is checked by its own testbench).
//
// Directed: per PWM device, distinct pwmcmp values written and read back
// through the top (so a decode to the wrong device shows), then a match on
// one comparator at a time must raise exactly that pwm_irq / pwm_out bit;
// halt freezes every counter; the watchdog behind its key: unlock, wdogcmp0
// write and readback, irq and rst_req. Random addresses outside the device
// windows must give PSLVERR, inside them never.
`include "tb_common.svh"
module chilimix_timer_tb #(
  parameter int N_PWM = 3
);
  localparam logic [31:0] KEY = 32'h0051_F15E;

  `TB_CLOCK_RESET

  logic               PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [10:0]        PADDR;
  logic [31:0]        PWDATA, PRDATA;
  logic [3:0]         PSTRB;
  logic               tick, halt, core_sleep;
  logic [4*N_PWM-1:0] pwm_out, pwm_irq;
  logic               wdog_irq, wdog_rst_req;

  chilimix_timer #(.N_PWM(N_PWM)) dut (.*);

  logic [31:0] rd, c1, c2;
  logic        err;
  int          n_err;
  logic [3:0]  apb_strb = 4'hf;     // PSTRB of the next transfer

  task automatic apb(input logic wr, input logic [10:0] a, input logic [31:0] d,
                     output logic [31:0] r, output logic e);
    PSEL = 1; PENABLE = 0; PWRITE = wr; PADDR = a; PWDATA = d; PSTRB = apb_strb;
    @(negedge clk);
    PENABLE = 1;
    #1;
    `CHECK(PREADY, "PREADY high")
    r = PRDATA; e = PSLVERR;
    @(negedge clk);
    PSEL = 0; PENABLE = 0;
  endtask

  task automatic wr32(input logic [10:0] a, input logic [31:0] d);
    logic [31:0] r; logic e;
    apb(1'b1, a, d, r, e);
    `CHECK(!e, "write PSLVERR")
  endtask

  task automatic rd32(input logic [10:0] a, output logic [31:0] r);
    logic e;
    apb(1'b0, a, '0, r, e);
    `CHECK(!e, "read PSLVERR")
  endtask

  function automatic bit in_window(logic [10:0] a);
    if (a >= 11'h400) return a < 11'h440;
    return int'(a[10:8]) < N_PWM && a[7:6] == 2'b00;
  endfunction

  // PSLVERR: outside every window, or past a device's last register
  function automatic bit exp_err(logic [10:0] a);
    if (!in_window(a)) return 1'b1;
    return int'(a[5:2]) >= ((a >= 11'h400) ? 9 : 12);
  endfunction

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    tick = 1; halt = 0; core_sleep = 0;
    tb_reset();
    `CHECK(pwm_irq == '0 && pwm_out == '0 && !wdog_irq && !wdog_rst_req, "reset values")

    // ---- PWM devices: comparator readback through the top
    for (int k = 0; k < N_PWM; k++)
      for (int x = 0; x < 4; x++) wr32(11'(k * 'h100 + 'h20 + 4 * x), 32'(k * 16 + x + 'h100));
    for (int k = 0; k < N_PWM; k++)
      for (int x = 0; x < 4; x++) begin
        rd32(11'(k * 'h100 + 'h20 + 4 * x), rd);
        `CHECK(rd == 32'(k * 16 + x + 'h100), "pwmcmp readback")
      end

    // ---- one comparator at a time: only its irq / out bit rises
    for (int k = 0; k < N_PWM; k++)
      for (int x = 0; x < 4; x++) begin
        for (int j = 0; j < N_PWM; j++) begin
          wr32(11'(j * 'h100), 32'h0);                    // stop, clear ip
          wr32(11'(j * 'h100 + 'h08), 32'h0);             // pwmcount = 0
        end
        wr32(11'(k * 'h100 + 'h20 + 4 * x), 32'd3);       // pwmcmpX = 3
        wr32(11'(k * 'h100), 32'h0000_1000);              // enalways, scale 0
        repeat (8) @(negedge clk);
        `CHECK(pwm_irq == (4*N_PWM)'(1) << (4 * k + x), "pwm_irq of one comparator")
        `CHECK(pwm_out == (4*N_PWM)'(1) << (4 * k + x), "pwm_out of one comparator")
        wr32(11'(k * 'h100 + 'h20 + 4 * x), 32'hFFFF);
      end

    // ---- halt freezes the PWM counters and the watchdog
    for (int k = 0; k < N_PWM; k++) wr32(11'(k * 'h100), 32'h0000_1000);
    wr32(11'h41C, KEY); wr32(11'h400, 32'h0000_1000);    // wdog enalways
    halt = 1;
    for (int k = 0; k < N_PWM; k++) begin
      rd32(11'(k * 'h100 + 'h08), c1);
      repeat (5) @(negedge clk);
      rd32(11'(k * 'h100 + 'h08), c2);
      `CHECK(c1 == c2, "halt freezes pwmcount")
    end
    rd32(11'h408, c1);
    repeat (5) @(negedge clk);
    rd32(11'h408, c2);
    `CHECK(c1 == c2, "halt freezes wdogcount")
    halt = 0;
    repeat (5) @(negedge clk);
    rd32(11'h408, c2);
    `CHECK(c2 != c1, "wdogcount runs again")

    // ---- full-width counter readback per device (halted, so they hold)
    halt = 1;
    for (int k = 0; k <= N_PWM; k++) begin
      for (int i = 0; i < 4; i++) begin
        c1 = (i % 2 == 0) ? {1'b0, 31'($urandom)} : 32'h7FFF_FFFF ^ (32'h5555_5555 << i);
        c1[31] = 1'b0;
        if (k == N_PWM) wr32(11'h41C, KEY);
        wr32(11'((k == N_PWM) ? 'h408 : k * 'h100 + 'h08), c1);
        rd32(11'((k == N_PWM) ? 'h408 : k * 'h100 + 'h08), rd);
        `CHECK(rd == c1, "counter readback")
      end
    end
    halt = 0;

    // ---- watchdog: coreawake counts only while the core is awake
    wr32(11'h41C, KEY); wr32(11'h400, 32'h0000_2000);    // coreawake only
    core_sleep = 1;
    rd32(11'h408, c1);
    repeat (5) @(negedge clk);
    rd32(11'h408, c2);
    `CHECK(c1 == c2, "core_sleep stops coreawake counting")
    core_sleep = 0;
    repeat (5) @(negedge clk);
    rd32(11'h408, c2);
    `CHECK(c2 != c1, "coreawake counts while awake")

    // ---- watchdog: key, cmp0, irq and reset request
    wr32(11'h420, 32'h0);                                 // locked: ignored
    rd32(11'h420, rd);
    `CHECK(rd == 32'hFFFF, "locked wdogcmp0 write ignored")
    wr32(11'h41C, KEY);
    rd32(11'h41C, rd);
    `CHECK(rd == 32'h1, "wdogkey reads unlocked")      // a read does not lock
    wr32(11'h420, 32'h4);
    rd32(11'h420, rd);
    `CHECK(rd == 32'h4, "unlocked wdogcmp0 write")
    rd32(11'h41C, rd);
    `CHECK(rd == 32'h0, "locked again after a write")
    wr32(11'h41C, KEY); wr32(11'h400, 32'h0000_1100);    // enalways, rsten
    repeat (20) @(negedge clk);
    `CHECK(wdog_irq && wdog_rst_req, "watchdog irq and reset request")

    // ---- addresses outside the device windows give PSLVERR
    n_err = 0;
    for (int i = 0; i < 400; i++) begin
      PADDR = 11'($urandom);
      apb_strb = 4'($urandom);
      apb($urandom % 2, PADDR, $urandom, rd, err);
      `CHECK(err == exp_err(PADDR), "PSLVERR decode")
      if (err) n_err++;
    end
    `CHECK(n_err > 100, "few hole accesses")
    tb_pass();
  end
endmodule
