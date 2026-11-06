// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_timer_pwm -- random APB transfers and halt against a
// cycle model of the SiFive PWM (sifive-blocks PWMTimer): pwmcount, pwms,
// the restart (wrap of the scaled window or zerocmp), oneshot, the ip bits
// (sticky, deglitch, center) and the gang / invert outputs.
//
// Stimulus: APB transfers (SETUP then ACCESS) to every word of the 0x40
// window, random PSTRB and idle cycles; pwmcfg writes biased to small scales
// and to counting; pwmcmp writes biased to small values or 0xFFFF; pwmcount
// writes biased to just below a wrap of the scaled window; halt now and then.
// Checked every cycle: PREADY high; in ACCESS, PSLVERR exactly past pwmcmp3
// and the read data of every register; out and irq from the model.
`include "tb_common.svh"
module chilimix_timer_pwm_tb;
  localparam int N_CYC = 60000;
  localparam logic [31:0] RW_MASK = 32'h0FFF_170F;   // pwmcfg bits stored in the regbank

  `TB_CLOCK_RESET

  logic        PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [5:0]  PADDR;
  logic [31:0] PWDATA, PRDATA;
  logic [3:0]  PSTRB;
  logic        halt;
  logic [3:0]  out, irq;

  chilimix_timer_pwm dut (.*);

  // model state
  logic [31:0] m_cfg;                // rw bits of pwmcfg
  logic        m_oneshot;
  logic [3:0]  m_ip;
  logic        m_sticky_q;
  logic [30:0] m_count;
  logic [15:0] m_cmp [4];
  // model view of one cycle
  logic [3:0]  scale, center, invert, gang, sel, elapsed, ip_rot, exp_out;
  logic [15:0] s;
  logic [63:0] low_mask;
  logic [31:0] exp_rd, wmask;
  logic        en, wrap, restart, exp_err, wr;
  int          phase, w;
  int          n_wrap, n_zero, n_oneshot_end, n_ip_rise, n_center_fold;

  function automatic logic [31:0] strb_mask(logic [3:0] st);
    return {{8{st[3]}}, {8{st[2]}}, {8{st[1]}}, {8{st[0]}}};
  endfunction

  function automatic logic [31:0] pick_wdata(int word);
    logic [31:0] d;
    d = $urandom;
    case (word)
      0: begin                                            // pwmcfg
        d[3:0] = ($urandom % 4 != 0) ? 4'($urandom % 3) : d[3:0];
        if ($urandom % 3 != 0) d[12] = 1'b1;              // mostly counting
        if ($urandom % 2 == 0) d[31:28] = 4'h0;           // clear ip
      end
      2: begin                                            // pwmcount, near a wrap
        if ($urandom % 2 == 0) d = {1'b0, 15'($urandom), 16'hFFFF - 16'($urandom % 32)};
      end
      8, 9, 10, 11: begin                                 // pwmcmpX
        case ($urandom % 4)
          0: d = 32'h0000_FFFF;
          1: d = 32'($urandom % 32);
          2: d = 32'h0000_8000 + 32'($urandom % 64);
          default: ;
        endcase
      end
      default: ;
    endcase
    return d;
  endfunction

  task automatic model_reset();
    m_cfg = '0; m_oneshot = 1'b0; m_ip = '0; m_sticky_q = 1'b0; m_count = '0;
    for (int i = 0; i < 4; i++) m_cmp[i] = 16'hFFFF;
  endtask

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0; halt = 0;
    n_wrap = 0; n_zero = 0; n_oneshot_end = 0; n_ip_rise = 0; n_center_fold = 0;
    model_reset();
    tb_reset();
    `CHECK(irq == '0 && out == '0, "reset values")
    phase = 0;
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      // drive after the falling edge
      halt = ($urandom % 16 == 0);
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 4 == 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 3 != 0;
        w = $urandom % 16;
        PADDR = 6'(w * 4 + $urandom % 4);
        PWDATA = pick_wdata(w);
        PSTRB = ($urandom % 4 != 0) ? 4'hf : 4'($urandom);
      end else begin
        PWRITE = $urandom % 2; PADDR = 6'($urandom); PWDATA = $urandom; PSTRB = 4'($urandom);
      end
      #1;
      // model view of this cycle
      scale   = m_cfg[3:0];
      center  = m_cfg[19:16];
      invert  = m_cfg[23:20];
      gang    = m_cfg[27:24];
      s       = 16'(m_count >> scale);
      for (int i = 0; i < 4; i++) begin
        sel[i]     = s[15] && center[i];
        elapsed[i] = (sel[i] ? ~s : s) >= m_cmp[i];
      end
      en       = (m_cfg[12] || m_oneshot) && !halt;
      low_mask = (64'd1 << (16 + scale)) - 1;
      wrap     = en && ((64'(m_count) & low_mask) == low_mask);
      restart  = wrap || (m_cfg[9] && elapsed[0]);
      ip_rot   = {m_ip[0], m_ip[3:1]};
      exp_out  = (m_ip & ~(gang & ip_rot)) ^ invert;
      w = int'(PADDR[5:2]);
      exp_err = w >= 12;
      case (w)
        0:  exp_rd = m_cfg | (32'(m_oneshot) << 13) | (32'(m_ip) << 28);
        2:  exp_rd = 32'(m_count);
        4:  exp_rd = 32'(s);
        8, 9, 10, 11: exp_rd = 32'(m_cmp[w - 8]);
        default: exp_rd = '0;
      endcase
      `CHECK(PREADY, "PREADY high")
      if (phase == 2) begin
        `CHECK(PSLVERR == exp_err, "PSLVERR")
        if (!PWRITE && !exp_err) `CHECK(PRDATA == exp_rd, "read data")
      end
      `CHECK(out == exp_out, "out")
      `CHECK(irq == m_ip, "irq")
      // next state (values from before the edge)
      wr    = phase == 2 && PWRITE && !exp_err;
      wmask = strb_mask(PSTRB);
      if (wrap) n_wrap++;
      if (restart && !wrap) n_zero++;
      if (restart && m_oneshot) n_oneshot_end++;
      if (|sel) n_center_fold++;
      @(posedge clk);
      // counter
      // a write loads its strobed bytes over the restart value (no increment)
      if (restart) m_count = '0;
      if (wr && w == 2 && PSTRB != 4'b0000) m_count = 31'((32'(m_count) & ~wmask) | (PWDATA & wmask));
      else if (!restart && en) m_count = m_count + 1'b1;
      // oneshot
      if (wr && w == 0 && PSTRB[1]) m_oneshot = PWDATA[13] && !restart;
      else if (restart) m_oneshot = 1'b0;
      // ip bits (sticky_q is the registered hold of the cycle before)
      if (wr && w == 0 && PSTRB[3]) m_ip = PWDATA[31:28];
      else begin
        if (|((sel & elapsed) | (~sel & (elapsed | ({4{m_sticky_q}} & m_ip)))) & ~m_ip) n_ip_rise++;
        m_ip = (sel & elapsed) | (~sel & (elapsed | ({4{m_sticky_q}} & m_ip)));
      end
      m_sticky_q = (m_cfg[10] && !restart) || m_cfg[8];
      // rw registers
      if (wr && w == 0) m_cfg = (m_cfg & ~(wmask & RW_MASK)) | (PWDATA & wmask & RW_MASK);
      if (wr && w >= 8 && w <= 11) m_cmp[w - 8] = 16'((32'(m_cmp[w - 8]) & ~wmask) | (PWDATA & wmask));
      @(negedge clk);
      // a reset now and then, so every run starts again from the reset state
      if ($urandom % 5000 == 0) begin
        PSEL = 0; PENABLE = 0; phase = 0;
        model_reset();
        tb_reset();
      end
    end
    $display("wraps %0d, zerocmp restarts %0d, oneshot ends %0d, ip rises %0d, centered cycles %0d",
             n_wrap, n_zero, n_oneshot_end, n_ip_rise, n_center_fold);
    `CHECK(n_wrap > 20, "few wraps")
    `CHECK(n_zero > 20, "few zerocmp restarts")
    `CHECK(n_oneshot_end > 5, "few oneshot ends")
    `CHECK(n_ip_rise > 50, "few ip rises")
    `CHECK(n_center_fold > 100, "few centered cycles")
    tb_pass();
  end
endmodule
