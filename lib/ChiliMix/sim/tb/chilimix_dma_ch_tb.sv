// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_dma_ch -- one PDMA channel through APB against an
// engine model on its beat interface.
//
// Stimulus: random transfers as sf-pdma issues them (claim, Next config /
// bytes / dst / src, then claim | run | done_ie | error_ie), with random
// addresses and sizes (0 .. 40 bytes); the engine model grants the channel
// after a random delay and finishes each beat after a random time, with
// the beat size the real engine picks (4, 2, 1 by alignment and bytes left)
// and an error at random; aborts (run 0) while the engine is idle, in the
// grant cycle or inside a beat; repeat transfers aborted after some
// reloads; claim cleared while running; run written without claim;
// done / error cleared by writing the control word back with the bit 0.
// Checked: Exec copies Next at start and after a repeat reload; every beat
// advances exec_src / exec_dst and lowers exec_bytes by its size (an error
// beat leaves them); done at the end (at once for 0 bytes), error after an
// error beat, run clear after either and after an abort (only once the
// beat in flight finished); no beat requested after an abort; claim held
// while run is set; the interrupt levels; register reset values and the
// high address words reading 0.
`include "tb_common.svh"
module chilimix_dma_ch_tb;
  localparam int N_TR = 600;
  localparam logic [11:0] CONTROL = 12'h000, NCFG = 12'h004, NBYTES = 12'h008, NDST = 12'h010,
                          NSRC = 12'h018, XCFG = 12'h104, XBYTES = 12'h108, XDST = 12'h110,
                          XSRC = 12'h118;
  localparam logic [31:0] CLAIM = 32'h1, RUN = 32'h2, DONE_IE = 32'h4000, ERR_IE = 32'h8000,
                          DONE = 32'h4000_0000, ERR = 32'h8000_0000;

  `TB_CLOCK_RESET

  logic        PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [11:0] PADDR;
  logic [31:0] PWDATA, PRDATA;
  logic [3:0]  PSTRB;
  logic        req, active, beat_done, beat_err;
  logic [31:0] exec_src, exec_dst, exec_bytes;
  logic [2:0]  beat_size;
  logic        done_irq, err_irq;

  chilimix_dma_ch dut (.*);

  // ---- APB ------------------------------------------------------------------------
  task automatic apb(input logic w, input logic [11:0] a, input logic [31:0] d, output logic [31:0] q);
    PSEL = 1; PENABLE = 0; PWRITE = w; PADDR = a; PWDATA = d; PSTRB = 4'hf;
    @(negedge clk);
    PENABLE = 1;
    #1;
    q = PRDATA;
    `CHECK(PREADY && !PSLVERR, "APB access")
    @(negedge clk);
    PSEL = 0; PENABLE = 0;
  endtask

  task automatic wr(input logic [11:0] a, input logic [31:0] d);
    logic [31:0] q;
    apb(1'b1, a, d, q);
  endtask

  task automatic rd(input logic [11:0] a, output logic [31:0] q);
    apb(1'b0, a, '0, q);
  endtask

  // ---- engine model -----------------------------------------------------------------
  logic        eng_busy;
  int          eng_cnt;
  int          err_pct;          // chance of an error beat, percent
  int          grant_pct;
  logic        chk_pending;      // check Exec after a beat
  logic [31:0] exp_src, exp_dst, exp_bytes;
  logic        exp_last;         // the checked beat was the last one
  int          n_beats, n_err_beats, n_grant_abort, n_beat_abort, n_idle_abort;

  function automatic logic [2:0] f_size(input logic [31:0] s, input logic [31:0] d, input logic [31:0] b);
    if (s[1:0] == 0 && d[1:0] == 0 && b >= 4) return 3'd4;
    if (!s[0] && !d[0] && b >= 2) return 3'd2;
    return 3'd1;
  endfunction

  always @(negedge clk) begin
    if (!rst_n) begin
      active = 0; beat_done = 0; beat_err = 0; beat_size = 3'd1; eng_busy = 0; chk_pending = 0;
    end else begin
      if (chk_pending) begin
        chk_pending = 0;
        if (!(exp_last && dut.exec_repeat)) begin
          `CHECK(exec_src == exp_src && exec_dst == exp_dst && exec_bytes == exp_bytes, "Exec after a beat")
        end
      end
      beat_done = 0; beat_err = 0;
      if (eng_busy) begin
        if (eng_cnt == 0) begin
          beat_size = f_size(exec_src, exec_dst, exec_bytes);
          beat_err  = ($urandom % 100) < err_pct;
          beat_done = 1;
          exp_last  = !beat_err && exec_bytes == {29'd0, beat_size};
          exp_src   = beat_err ? exec_src : exec_src + beat_size;
          exp_dst   = beat_err ? exec_dst : exec_dst + beat_size;
          exp_bytes = beat_err ? exec_bytes : exec_bytes - beat_size;
          chk_pending = 1;
          eng_busy = 0;
          n_beats++;
          if (beat_err) n_err_beats++;
        end else begin
          eng_cnt--;
        end
        active = 1;
      end else if (req && ($urandom % 100) < grant_pct) begin
        `CHECK(dut.run && exec_bytes != 0, "req with run and bytes left")
        active = 1;                   // the grant cycle
        eng_busy = 1;
        eng_cnt = $urandom % 5;
      end else begin
        active = 0;
      end
    end
  end

  // ---- invariants seen from outside -----------------------------------------------
  always @(negedge clk) begin
    if (rst_n) begin
      `CHECK(!dut.run || dut.claim, "claim held while run")
      `CHECK(done_irq == (dut.done && dut.done_ie), "done_irq")
      `CHECK(err_irq == (dut.error && dut.error_ie), "err_irq")
    end
  end

  // ---- driver -------------------------------------------------------------------
  logic [31:0] q;
  int          n_done, n_err, n_empty, n_repeat, n_noclaim, n_claimclr;

  task automatic wait_idle(output logic [31:0] c);
    int n = 0;
    do begin rd(CONTROL, c); n++; end while (c[1] && n < 2000);
    `CHECK(!c[1], "transfer ends")
  endtask

  task automatic set_next(input logic [31:0] cfg, input logic [31:0] b, input logic [31:0] d,
                         input logic [31:0] s);
    wr(NCFG, cfg); wr(NBYTES, b); wr(NDST, d); wr(NSRC, s);
  endtask

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    err_pct = 0; grant_pct = 50;
    tb_reset();
    // reset values, high words
    rd(CONTROL, q); `CHECK(q == 0, "control reset")
    rd(NBYTES, q);  `CHECK(q == 0, "next_bytes reset")
    rd(XSRC, q);    `CHECK(q == 0, "exec_src reset")
    wr(12'h00c, '1); rd(12'h00c, q); `CHECK(q == 0, "next_bytes high word")
    rd(12'h01c, q); `CHECK(q == 0, "next_src high word")
    wr(12'h11c, '1); rd(12'h11c, q); `CHECK(q == 0, "exec_src high word")
    // run without claim: nothing starts
    set_next(32'h2200_0000, 32'd8, 32'h100, 32'h200);
    wr(CONTROL, RUN);
    rd(CONTROL, q); `CHECK(q == 0, "run without claim ignored")
    n_noclaim++;
    for (int t = 0; t < N_TR; t++) begin
      int kind;
      logic [31:0] b, s, d, cfg, ie;
      kind = $urandom % 10;
      b   = ($urandom % 8 == 0) ? 32'd0 : 32'($urandom % 41);
      if (kind == 6 && $urandom % 2) b = $urandom;   // aborted anyway: any size
      s   = $urandom; d = $urandom;
      cfg = {4'($urandom), 4'($urandom), 20'd0, 1'b0, 1'b0, 2'd0};
      cfg[2] = (kind == 9);           // repeat
      cfg[3] = 1'($urandom);
      ie  = ($urandom % 2) ? (DONE_IE | ERR_IE) : 32'd0;
      err_pct   = (kind == 8) ? 30 : 0;
      grant_pct = 10 + $urandom % 90;
      wr(CONTROL, CLAIM);
      set_next(cfg, b, d, s);
      wr(CONTROL, CLAIM | RUN | ie);
      #1;
      if (b != 0) begin
        `CHECK(dut.run, "run after start")
        `CHECK(exec_bytes == b && exec_src == s && exec_dst == d, "Exec copies Next at start")
        rd(XCFG, q); `CHECK(q == cfg, "exec_config copies next_config")
      end
      if (b == 0) begin
        rd(CONTROL, q);
        `CHECK(q[30] && !q[1], "0 bytes: done at once")
        n_empty++;
      end else if (kind == 9) begin
        // repeat: let it reload a few times, then abort
        repeat (20 + $urandom % 200) @(negedge clk);
        rd(CONTROL, q);
        `CHECK(q[1], "repeat keeps running")
        if (q[30]) n_repeat++;
        wr(CONTROL, CLAIM | ie);      // abort
        wait_idle(q);
      end else if (kind == 7) begin
        // claim cleared while running: ignored
        wr(CONTROL, RUN | ie);
        rd(CONTROL, q);
        `CHECK(q[0], "claim held while running")
        n_claimclr++;
        wait_idle(q);
      end else if (kind == 6) begin
        // abort at a random point
        repeat ($urandom % 12) @(negedge clk);
        if (eng_busy) n_beat_abort++;
        else if (active) n_grant_abort++;
        else n_idle_abort++;
        wr(CONTROL, CLAIM | ie);
        wait_idle(q);
        repeat (3) @(negedge clk);
        `CHECK(!req && !eng_busy, "no beat after an abort")
      end else begin
        wait_idle(q);
        if (kind == 8 && q[31]) begin
          `CHECK(exec_bytes != 0, "error before the end leaves bytes")
          n_err++;
        end else begin
          `CHECK(q[30] && exec_bytes == 0, "done at the end")
          `CHECK(exec_src == s + b && exec_dst == d + b, "Exec addresses at the end")
          n_done++;
        end
      end
      // clear done / error by writing back the control word with them 0
      rd(CONTROL, q);
      wr(CONTROL, q & ~(DONE | ERR | RUN));
      rd(CONTROL, q);
      `CHECK(!q[30] && !q[31], "done / error cleared")
      `CHECK(!done_irq && !err_irq, "irq low after clearing")
      // release the channel
      if ($urandom % 2) begin
        wr(CONTROL, '0);
        rd(CONTROL, q);
        `CHECK(q == 0, "channel released")
      end
    end
    $display("done %0d error %0d empty %0d repeat %0d; beats %0d (errors %0d); aborts idle %0d grant %0d beat %0d; no claim %0d claim clear %0d",
             n_done, n_err, n_empty, n_repeat, n_beats, n_err_beats, n_idle_abort, n_grant_abort,
             n_beat_abort, n_noclaim, n_claimclr);
    `CHECK(n_done > 200 && n_err > 10 && n_empty > 20 && n_repeat > 10 && n_beat_abort > 5 && n_idle_abort > 2,
           "coverage")
    tb_pass();
  end
endmodule
