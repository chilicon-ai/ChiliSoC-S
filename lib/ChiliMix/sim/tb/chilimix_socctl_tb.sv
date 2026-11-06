// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_socctl -- random APB traffic, reset events and
// requests against a cycle model of the registers, the system reset hold,
// the domain release sequence and the clock dividers.
//
// Stimulus: APB transfers to every register and to the unused words, random
// PSTRB and idle cycles; sysrst writes with the key (full and partial
// strobes) and with wrong keys; rst_req pulses; dbg_rst_req levels of 1 .. 20
// cycles (ndmreset); ext_rst_n low pulses;
// power-on resets now and then; rst_hold writes (domains held and released
// mid-sequence); divisor writes, mostly small, sometimes with high bits
// set; a test_en window.
// Checked every cycle: PREADY high; in ACCESS, PSLVERR exactly past
// scratch[1] and the read data (id, causes, rst_status from the model);
// rst_n_out (asynchronous assertion, ordered release STEP cycles apart,
// rst_hold cascaded upward and released by a system reset, test_en pass-through); clk_div_tick period per divisor;
// hart_rst_n (the CPU domain and the registered hart holds: HART_HOLD_RST
// until hart_hold is written after a system reset) and boot_addr (BOOT_ADDR
// while a hart's boot words are 0). At the end: harts were released and
// held again by software (N_HART > 1).
`include "tb_common.svh"
module chilimix_socctl_tb #(
  parameter logic [31:0] SOC_ID = 32'hc0de_0001,
  parameter int          N_DOM  = 3,
  parameter int          STEP   = 16,
  parameter int          HOLD   = 16,
  parameter int          N_HART = 1,
  parameter logic [7:0]  HART_HOLD_RST = 8'hFE,
  parameter logic [63:0] BOOT_ADDR = 64'h0000_0000_8000_0000
);
  localparam int N_CYC = 60000;
  localparam logic [31:0] KEY = 32'h5253_5421;

  `TB_CLOCK_RESET   // clk; rst_n unused (the unit takes por_n)

  logic             por_n, ext_rst_n, test_en;
  logic             PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [7:0]       PADDR;
  logic [31:0]      PWDATA, PRDATA;
  logic [3:0]       PSTRB;
  logic             rst_req;
  logic             dbg_rst_req;
  int               dbg_left;             // cycles of dbg_rst_req still to come
  logic [N_DOM-1:0] rst_n_out;
  logic [1:0]       clk_div, clk_div_tick;
  logic [N_HART-1:0]    hart_rst_n;
  logic [N_HART*64-1:0] boot_addr;

  chilimix_socctl #(.SOC_ID(SOC_ID), .N_DOM(N_DOM), .STEP(STEP), .HOLD(HOLD), .N_HART(N_HART),
                    .HART_HOLD_RST(HART_HOLD_RST), .BOOT_ADDR(BOOT_ADDR)) dut (.*);

  // ---- model
  int          por_s, sys_s;            // reset synchronizer progress (2 = released)
  bit          own_n, srst_n, sys_n;    // power-on domain reset, synced system reset, its source
  bit          e1, e2;                  // ext_rst_n synchronizer
  logic [4:0]  cause;                   // {dbg, req, sw, ext, por}
  logic [7:0]  hold;
  bit          arm;                     // rst_hold in force (written since the last system reset)
  logic [15:0] dv [2];
  logic [31:0] scr [2];
  bit          sys_q;
  int          hcnt;
  int          step, cyc;
  logic [N_DOM-1:0] rel;
  int          dcnt [2], dq [2];        // divider count and period
  // per cycle
  bit          go, key_hit, exp_err, wr, hold_end;
  logic [7:0]  hold_pre;                // values before the edge
  bit          arm_pre;
  logic [15:0] dv_pre [2];
  logic [31:0] exp_rd, wmask;
  int          w, phase, n_sys, n_rel;
  logic [7:0]  hh, hh_pre;              // hart_hold register
  bit          harm, harm_pre;          // hart_hold in force
  logic [N_HART-1:0] hq;                // registered hart holds
  logic [31:0] blo [8], bhi [8];        // boot words
  logic [N_HART-1:0] exp_hart;
  int          n_hart_rel, n_hart_hold;

  function automatic logic [N_HART-1:0] hart_exp();
    return test_en ? {N_HART{sys_n}} : (rel[N_DOM-1] ? ~hq : '0);
  endfunction

  function automatic logic [31:0] strb_mask(logic [3:0] s);
    return {{8{s[3]}}, {8{s[2]}}, {8{s[1]}}, {8{s[0]}}};
  endfunction

  function automatic logic [31:0] merge(logic [31:0] o, logic [31:0] d, logic [3:0] s);
    return (o & ~strb_mask(s)) | (d & strb_mask(s));
  endfunction

  function automatic logic [31:0] read_val(int a);
    case (a)
      0: return SOC_ID;
      1: return 32'(cause);
      2: return '0;
      3: return 32'(hold);
      4: return {16'b0, 8'(test_en ? {N_DOM{sys_n}} : rel), 7'b0, 1'(step == N_DOM)};
      5: return 32'(dv[0]);
      6: return 32'(dv[1]);
      7: return scr[0];
      8: return scr[1];
      16: return 32'(hh);
      17: return 32'(hart_exp());
      default:
        if (a >= 32 && a < 48 && (a - 32) / 2 < N_HART) return (a % 2) ? bhi[(a - 32) / 2] : blo[(a - 32) / 2];
        else return '0;
    endcase
  endfunction

  // asynchronous resets of the model (por_n / sys_rst_n low)
  task automatic async_resets();
    if (!por_n) begin
      por_s = 0; e1 = 1; e2 = 1; cause = 5'b00001; hold = '0; arm = 0; dv[0] = 2; dv[1] = 2;
      scr[0] = '0; scr[1] = '0; sys_q = 0; hcnt = 0;
      hh = '0; harm = 0; hq = HART_HOLD_RST[N_HART-1:0];
      for (int h = 0; h < 8; h++) begin blo[h] = '0; bhi[h] = '0; end
      for (int i = 0; i < 2; i++) begin dcnt[i] = 0; dq[i] = 2; end
    end
    own_n = test_en ? por_n : (por_s == 2);
    sys_n = por_n && ext_rst_n && !sys_q;
    if (!sys_n) begin sys_s = 0; step = 0; cyc = 0; rel = '0; end
    srst_n = test_en ? sys_n : (sys_s == 2);
  endtask

  function automatic logic [15:0] pick_div();
    case ($urandom % 10)
      0:       return 16'($urandom);
      1:       return 16'($urandom % 2);
      default: return 16'(2 + $urandom % 9);
    endcase
  endfunction

  initial begin
    por_n = 1; ext_rst_n = 1; test_en = 0; rst_req = 0; dbg_rst_req = 0; dbg_left = 0;
    // the simulator starts every flop at 0, so the synchronized resets (flop
    // outputs) would never fall: pulse them high once so the asynchronous
    // resets of the power-on domain and the sequencer fire at time 0
    force dut.rst_n = 1'b1;
    force dut.u_rst.srst_n = 1'b1;
    #1 por_n = 0;
    release dut.rst_n;
    release dut.u_rst.srst_n;
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    n_sys = 0; n_rel = 0; phase = 0; n_hart_rel = 0; n_hart_hold = 0;
    async_resets();
    repeat (3) @(posedge clk);
    @(negedge clk);
    por_n = 1;
    for (int c = 0; c < N_CYC; c++) begin
      // ---- drive after the falling edge
      rst_req = own_n && ($urandom % 3000 == 0);
      if (own_n && dbg_left == 0 && $urandom % 3000 == 0) dbg_left = 1 + $urandom % 20;   // ndmreset: a level
      dbg_rst_req = own_n && dbg_left > 0;
      if (dbg_left > 0) dbg_left--;
      if ($urandom % 2500 == 0) ext_rst_n = 0;
      else if (!ext_rst_n && $urandom % 6 == 0) ext_rst_n = 1;
      if (c % 15000 == 14000) por_n = 0;
      else if (!por_n && $urandom % 3 == 0) por_n = 1;
      test_en = (c >= 30000 && c < 30400);
      if (phase == 2 || !own_n) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 3 != 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 2;
        case ($urandom % 16)
          0:       w = 9 + $urandom % 55;                  // unused words, and past the last register
          1, 2:    w = 16;                                 // hart_hold
          3:       w = 17;
          4, 5:    w = 32 + $urandom % (2 * N_HART);       // boot words of present harts
          6:       w = 32 + $urandom % 16;
          default: w = $urandom % 9;
        endcase
        if (w == 2 && $urandom % 6 != 0) PWRITE = 1;      // sysrst: mostly writes,
        if (w == 2 && PWRITE && $urandom % 4 != 0) w = 3;  // but not too many resets
        PADDR = 8'(w * 4 + $urandom % 4);
        PWDATA = (w == 2 && $urandom % 2) ? KEY : (w == 5 || w == 6) ? 32'(pick_div()) :
                 (w == 3 && $urandom % 3 != 0) ? 32'($urandom % 2 ? 0 : 1 << ($urandom % N_DOM)) :
                 (w == 16) ? 32'($urandom % 2 ? 0 : $urandom % 256) :
                 (w >= 32 && $urandom % 3 == 0) ? 32'h0 : $urandom;
        PSTRB = ($urandom % 4 != 0) ? 4'hf : 4'($urandom);
      end else begin
        PWRITE = $urandom % 2; PADDR = 8'($urandom); PWDATA = $urandom; PSTRB = 4'($urandom);
      end
      #1;
      async_resets();
      w = int'(PADDR[7:2]);
      // ---- check the cycle
      `CHECK(PREADY, "PREADY high")
      if (phase == 2 && own_n) begin
        exp_err = w > 47;
        `CHECK(PSLVERR == exp_err, "PSLVERR")
        if (!PWRITE && !exp_err) `CHECK(PRDATA == read_val(w), $sformatf("read word %0d", w))
      end
      if (test_en) `CHECK(rst_n_out == {N_DOM{sys_n}}, "test_en passes the system reset")
      else         `CHECK(rst_n_out == rel, "rst_n_out")
      for (int i = 0; i < 2; i++)
        `CHECK(clk_div_tick[i] == (dcnt[i] == dq[i] - 1), $sformatf("clk_div_tick[%0d]", i))
      exp_hart = hart_exp();
      `CHECK(hart_rst_n == exp_hart, "hart_rst_n")
      for (int h = 0; h < N_HART; h++)
        `CHECK(boot_addr[h*64 +: 64] == (({bhi[h], blo[h]} == '0) ? BOOT_ADDR : {bhi[h], blo[h]}), "boot_addr")
      // ---- next state (values from before the edge)
      wr = phase == 2 && own_n && PWRITE && w <= 47;
      key_hit = wr && w == 2 && PWDATA == KEY && PSTRB == 4'hf;
      go = key_hit || rst_req || dbg_rst_req;
      hold_end = hcnt == HOLD - 1;
      hold_pre = hold; arm_pre = arm; dv_pre = dv; hh_pre = hh; harm_pre = harm;
      @(posedge clk);
      if (go) n_sys++;
      if (own_n) begin
        // registers (w1c: a set wins over a clear)
        if (wr) case (w)
          1: cause = cause & ~(PWDATA[4:0] & {5{PSTRB[0]}});
          3: hold  = merge(32'(hold), PWDATA, PSTRB);
          5: dv[0] = 16'(merge(32'(dv[0]), PWDATA, PSTRB));
          6: dv[1] = 16'(merge(32'(dv[1]), PWDATA, PSTRB));
          7: scr[0] = merge(scr[0], PWDATA, PSTRB);
          8: scr[1] = merge(scr[1], PWDATA, PSTRB);
          16: hh = 8'(merge(32'(hh), PWDATA, PSTRB));
          default:
            if (w >= 32 && (w - 32) / 2 < N_HART) begin
              if (w % 2) bhi[(w - 32) / 2] = merge(bhi[(w - 32) / 2], PWDATA, PSTRB);
              else       blo[(w - 32) / 2] = merge(blo[(w - 32) / 2], PWDATA, PSTRB);
            end
        endcase
        // hart holds: hart_hold in force once written, until a system reset
        harm = !(sys_q || !e2) && ((wr && w == 16) || harm);
        hq = harm_pre ? hh_pre[N_HART-1:0] : HART_HOLD_RST[N_HART-1:0];
        // holds: written -> in force, until a system reset (ext pin or request)
        arm = !(sys_q || !e2) && ((wr && w == 3) || arm);
        cause = cause | {dbg_rst_req, rst_req, key_hit, !e2, 1'b0};
        e2 = e1; e1 = ext_rst_n;
        // system reset hold
        if (go) hcnt = 0; else if (sys_q) hcnt = (hcnt + 1) % (1 << $clog2(HOLD));
        sys_q = go || (sys_q && !hold_end);
      end
      if (por_n) por_s = (por_s < 2) ? por_s + 1 : 2;
      if (N_HART > 1 && rel[N_DOM-1] && !test_en && hart_exp() != exp_hart) begin
        if ((hart_exp() & ~exp_hart) != '0) n_hart_rel++;
        if ((exp_hart & ~hart_exp()) != '0) n_hart_hold++;
      end
      // reset sequencer
      if (srst_n) begin
        logic [N_DOM-1:0] rd;
        bit held;
        int step_d;
        held = 0;
        step_d = step;
        if (step != N_DOM && cyc == STEP - 1) begin step_d = step + 1; cyc = 0; end
        else if (step != N_DOM) cyc++;
        else cyc = 0;
        step = step_d;
        for (int i = 0; i < N_DOM; i++) begin
          held = held || (arm_pre && hold_pre[i]);          // a hold cascades upward
          rd[i] = step > i && !held;
        end
        if (rd != rel) n_rel++;
        rel = rd;
      end
      if (sys_n) sys_s = (sys_s < 2) ? sys_s + 1 : 2;
      // dividers
      if (own_n)
        for (int i = 0; i < 2; i++)
          if (dcnt[i] == dq[i] - 1) begin dcnt[i] = 0; dq[i] = (dv_pre[i] < 2) ? 2 : int'(dv_pre[i]); end
          else dcnt[i] = (dcnt[i] + 1) % 65536;
      @(negedge clk);
    end
    `CHECK(n_sys > 5, "few system reset requests")
    `CHECK(N_HART == 1 || (n_hart_rel > 5 && n_hart_hold > 5), $sformatf("hart releases %0d / holds %0d", n_hart_rel, n_hart_hold))
    $display("%0d system reset requests, %0d release steps", n_sys, n_rel);
    tb_pass();
  end
endmodule
