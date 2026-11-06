// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_timer_wdog -- random APB transfers, tick, halt and
// core_sleep against a cycle model of the SiFive AON watchdog (sifive-blocks
// mockaon WatchdogTimer): the key lock, feed, wdogcount / wdogs, ip0 and the
// held reset request.
//
// Stimulus: APB transfers (SETUP then ACCESS) to every word of the 0x40
// window, random PSTRB and idle cycles; a third of the writes are the key
// (mostly the right value with all strobes), so the write after it often
// takes effect; feed writes mostly the feed value; wdogcfg writes biased to
// small scales, counting and zerocmp, rsten rare; wdogcmp0 biased small.
// After rst_req has been high a while the testbench resets the unit, as
// chilimix_socctl would.
// Checked every cycle: PREADY high; in ACCESS, PSLVERR exactly past
// wdogcmp0 and the read data of every register; irq and rst_req.
`include "tb_common.svh"
module chilimix_timer_wdog_tb;
  localparam int N_CYC = 60000;
  localparam logic [31:0] KEY  = 32'h0051_F15E;
  localparam logic [31:0] FOOD = 32'h0D09_F00D;

  `TB_CLOCK_RESET

  logic        PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [5:0]  PADDR;
  logic [31:0] PWDATA, PRDATA;
  logic [3:0]  PSTRB;
  logic        tick, halt, core_sleep;
  logic        irq, rst_req;

  chilimix_timer_wdog dut (.*);

  // model state
  logic [3:0]  m_scale;
  logic        m_rsten, m_zerocmp, m_enalways, m_coreawake, m_ip0, m_unlocked, m_rst_req;
  logic [30:0] m_count;
  logic [15:0] m_cmp0;
  // model view of one cycle
  logic [15:0] s;
  logic [31:0] exp_rd, wmask;
  logic        elapsed, en, feed, restart, exp_err, wr, ok;
  int          phase, w, rst_wait;
  bit          after_key;              // the last transfer was a key write
  int          n_unlocked_wr, n_feed, n_zero, n_ip, n_rst;

  function automatic logic [31:0] strb_mask(logic [3:0] st);
    return {{8{st[3]}}, {8{st[2]}}, {8{st[1]}}, {8{st[0]}}};
  endfunction

  function automatic logic [31:0] pick_wdata(int word);
    logic [31:0] d;
    d = $urandom;
    case (word)
      0: begin                                            // wdogcfg
        d[3:0] = ($urandom % 4 != 0) ? 4'($urandom % 2) : d[3:0];
        d[8]   = ($urandom % 12 == 0);                    // rsten now and then
        if ($urandom % 2 == 0) d[12] = 1'b1;
        if ($urandom % 2 == 0) d[28] = 1'b0;
      end
      6: d = ($urandom % 4 != 0) ? FOOD : d;              // wdogfeed
      7: d = ($urandom % 8 != 0) ? KEY : d;               // wdogkey
      8: d = ($urandom % 2 == 0) ? 32'($urandom % 64) : d; // wdogcmp0
      default: ;
    endcase
    return d;
  endfunction

  task automatic model_reset();
    m_scale = '0; m_rsten = 0; m_zerocmp = 0; m_enalways = 0; m_coreawake = 0;
    m_ip0 = 0; m_unlocked = 0; m_rst_req = 0; m_count = '0; m_cmp0 = 16'hFFFF;
    rst_wait = 0;
  endtask

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    tick = 0; halt = 0; core_sleep = 0;
    n_unlocked_wr = 0; n_feed = 0; n_zero = 0; n_ip = 0; n_rst = 0;
    model_reset();
    tb_reset();
    `CHECK(irq == 0 && rst_req == 0, "reset values")
    phase = 0; after_key = 0;
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      // drive after the falling edge
      tick = $urandom % 2;
      halt = ($urandom % 16 == 0);
      if ($urandom % 64 == 0) core_sleep = !core_sleep;
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 3 == 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 4 != 0;
        // after a key write, mostly a register the key unlocks
        if (after_key && $urandom % 5 != 0) begin
          case ($urandom % 4)
            0: w = 0;
            1: w = 2;
            2: w = 6;
            default: w = 8;
          endcase
        end else w = ($urandom % 3 == 0) ? 7 : $urandom % 16;
        after_key = w == 7;
        PADDR = 6'(w * 4 + $urandom % 4);
        PWDATA = pick_wdata(w);
        PSTRB = ($urandom % 4 != 0) ? 4'hf : 4'($urandom);
      end else begin
        PWRITE = $urandom % 2; PADDR = 6'($urandom); PWDATA = $urandom; PSTRB = 4'($urandom);
      end
      #1;
      // model view of this cycle
      s       = 16'(m_count >> m_scale);
      elapsed = s >= m_cmp0;
      en      = (m_enalways || (m_coreawake && !core_sleep)) && tick && !halt;
      w       = int'(PADDR[5:2]);
      exp_err = w >= 9;
      wr      = phase == 2 && PWRITE;                     // every write locks (or unlocks)
      ok      = wr && !exp_err && m_unlocked;             // a write that takes effect
      feed    = ok && w == 6 && PSTRB == 4'hf && PWDATA == FOOD;
      restart = feed || (m_zerocmp && elapsed);
      case (w)
        0: exp_rd = 32'(m_scale) | (32'(m_rsten) << 8) | (32'(m_zerocmp) << 9) | (32'(m_enalways) << 12)
                    | (32'(m_coreawake) << 13) | (32'(m_ip0) << 28);
        2: exp_rd = 32'(m_count);
        4: exp_rd = 32'(s);
        7: exp_rd = 32'(m_unlocked);
        8: exp_rd = 32'(m_cmp0);
        default: exp_rd = '0;
      endcase
      `CHECK(PREADY, "PREADY high")
      if (phase == 2) begin
        `CHECK(PSLVERR == exp_err, "PSLVERR")
        if (!PWRITE && !exp_err) `CHECK(PRDATA == exp_rd, "read data")
      end
      `CHECK(irq == m_ip0, "irq")
      `CHECK(rst_req == m_rst_req, "rst_req")
      // next state (values from before the edge)
      wmask = strb_mask(PSTRB);
      if (ok && w != 7) n_unlocked_wr++;
      if (feed) n_feed++;
      if (restart && !feed) n_zero++;
      if (elapsed && !m_ip0) n_ip++;
      if (m_rsten && elapsed && !m_rst_req) n_rst++;
      @(posedge clk);
      // counter: a write loads its strobed bytes over the restart value
      if (restart) m_count = '0;
      if (ok && w == 2 && PSTRB != 4'b0000) m_count = 31'((32'(m_count) & ~wmask) | (PWDATA & wmask));
      else if (!restart && en) m_count = m_count + 1'b1;
      // ip0 and the reset request
      if (ok && w == 0 && PSTRB[3]) m_ip0 = PWDATA[28] || elapsed;
      else if (elapsed) m_ip0 = 1'b1;
      m_rst_req = m_rst_req || (m_rsten && elapsed);
      // configuration and comparator
      if (ok && w == 0 && PSTRB[0]) m_scale = PWDATA[3:0];
      if (ok && w == 0 && PSTRB[1]) begin
        m_rsten = PWDATA[8]; m_zerocmp = PWDATA[9]; m_enalways = PWDATA[12]; m_coreawake = PWDATA[13];
      end
      if (ok && w == 8) m_cmp0 = 16'((32'(m_cmp0) & ~wmask) | (PWDATA & wmask));
      // key lock
      if (wr) m_unlocked = w == 7 && PSTRB == 4'hf && PWDATA == KEY;
      @(negedge clk);
      // reset after a reset request (as chilimix_socctl), or now and then
      if (m_rst_req) rst_wait++;
      if (rst_wait > 20 || $urandom % 8000 == 0) begin
        PSEL = 0; PENABLE = 0; phase = 0;
        model_reset();
        tb_reset();
      end
    end
    $display("unlocked writes %0d, feeds %0d, zerocmp restarts %0d, ip0 sets %0d, reset requests %0d",
             n_unlocked_wr, n_feed, n_zero, n_ip, n_rst);
    `CHECK(n_unlocked_wr > 500, "few unlocked writes")
    `CHECK(n_feed > 50, "few feeds")
    `CHECK(n_zero > 20, "few zerocmp restarts")
    `CHECK(n_ip > 40, "few ip0 sets")
    `CHECK(n_rst > 3, "few reset requests")
    tb_pass();
  end
endmodule
