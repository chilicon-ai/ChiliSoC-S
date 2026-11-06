// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_aclint -- random APB transfers and timebase ticks
// against a model of the ACLINT registers, mtime, mtip, msip and ssip_set
// for N_HART harts.
//
// Stimulus: APB transfers (SETUP then ACCESS) to msip, mtimecmp and setssip
// of a hart (mostly present ones, sometimes any of the 8 in the map), mtime
// and to unmapped or unused addresses, random PSTRB, idle cycles, random
// ticks. Write data is biased so mtime crosses its 32-bit carry and
// mtimecmp lands just below and above mtime, so mtip toggles both ways.
// Checked every cycle: PREADY high; in ACCESS, PSLVERR exactly outside the
// registers and the read data (absent harts and setssip read 0); after each
// edge mtime (+1 per tick, a write loads the strobed bytes and wins over a
// tick), registered mtip[h] = (mtime >= mtimecmp[h]) of the cycle before,
// msip, and the ssip_set pulse of a setssip write with bit 0 set.
// At the end: every present hart saw mtip both ways, msip and ssip_set; with
// fewer than 8 harts, absent harts were written.
`include "tb_common.svh"
module chilimix_aclint_tb #(
  parameter int N_HART = 1
);
  localparam int N_CYC = 40000;
  localparam int M_HART = 8;    // harts in the register map

  `TB_CLOCK_RESET

  logic              PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [15:0]       PADDR;
  logic [31:0]       PWDATA, PRDATA;
  logic [3:0]        PSTRB;
  logic              tick;
  logic [N_HART-1:0] mtip, msip, ssip_set;
  logic [63:0]       mtime;

  chilimix_aclint #(.N_HART(N_HART)) dut (.*);

  localparam logic [15:0] A_MSIP = 16'h0000, A_CMP = 16'h4000, A_TIME_LO = 16'hbff8, A_TIME_HI = 16'hbffc,
                          A_SSWI = 16'hc000;

  logic [63:0] m_time;            // model
  logic [63:0] m_cmp [M_HART];
  logic [M_HART-1:0] m_msip, m_mtip, m_ssip;
  logic [31:0] exp_rd;
  bit          exp_err;
  int          phase;             // 0 idle, 1 SETUP, 2 ACCESS
  int          n_mtip_rise [M_HART], n_mtip_fall [M_HART], n_msip [M_HART], n_ssip [M_HART];
  int          n_absent_wr;

  function automatic logic [31:0] strb_mask(logic [3:0] s);
    return {{8{s[3]}}, {8{s[2]}}, {8{s[1]}}, {8{s[0]}}};
  endfunction

  function automatic logic [31:0] merge(logic [31:0] old, logic [31:0] wd, logic [3:0] s);
    return (old & ~strb_mask(s)) | (wd & strb_mask(s));
  endfunction

  // decode a word address: kind 0 none, 1 msip, 2 mtimecmp low, 3 mtimecmp high, 4 setssip; h its hart
  function automatic int hart_reg(logic [15:0] w, output int h);
    h = 0;
    if (w < 16'h0020)                    begin h = int'(w[4:2]); return 1; end
    if (w >= A_CMP && w < A_CMP + 16'h40) begin h = int'(w[5:3]); return w[2] ? 3 : 2; end
    if (w >= A_SSWI && w < A_SSWI + 16'h20) begin h = int'(w[4:2]); return 4; end
    return 0;
  endfunction

  // read value and error of a word address in the model
  task automatic expect_read(logic [15:0] a, output logic [31:0] d, output bit err);
    logic [15:0] w;
    int h, k;
    w = a & 16'hfffc;
    err = 1'b0;
    d = '0;
    k = hart_reg(w, h);
    if (k == 1)                d = {31'b0, m_msip[h]};
    else if (k == 2)           d = (h < N_HART) ? m_cmp[h][31:0] : '0;
    else if (k == 3)           d = (h < N_HART) ? m_cmp[h][63:32] : '0;
    else if (k == 4)           d = '0;
    else if (w == A_TIME_LO)   d = m_time[31:0];
    else if (w == A_TIME_HI)   d = m_time[63:32];
    else                       err = 1'b1;
  endtask

  // write data biased towards carries and compare edges
  function automatic logic [31:0] pick_wdata(logic [15:0] a);
    logic [31:0] base;
    case ($urandom % 4)
      0: return $urandom;
      1: return 32'hffff_fff0 | 32'($urandom % 16);
      2: return 32'($urandom % 4);
      default: begin
        base = (a[2]) ? m_time[63:32] : m_time[31:0];
        return base + 32'($urandom % 32) - 32'd8;
      end
    endcase
  endfunction

  function automatic int pick_hart();
    return ($urandom % 5 != 0) ? int'($urandom % N_HART) : int'($urandom % M_HART);
  endfunction

  function automatic logic [15:0] pick_addr();
    case ($urandom % 14)
      0, 1:    return A_MSIP + 16'(4 * pick_hart());
      2, 3:    return A_CMP + 16'(8 * pick_hart());
      4, 5:    return A_CMP + 16'(8 * pick_hart()) + 16'd4;
      6, 7:    return A_TIME_LO;
      8:       return A_TIME_HI;
      9, 10:   return A_SSWI + 16'(4 * pick_hart());
      11:      return ($urandom % 2) ? 16'h0020 + 16'($urandom % 16'h3fe0)    // past the msip / setssip words
                                     : A_SSWI + 16'h0020 + 16'($urandom % 16'h3fe0);
      12:      return 16'h4040 + 16'($urandom % 16'h7000);   // unmapped
      default: return 16'($urandom);
    endcase
  endfunction

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0; tick = 0;
    m_time = '0; m_msip = '0; m_mtip = '0; m_ssip = '0; n_absent_wr = 0;
    for (int h = 0; h < M_HART; h++) begin
      m_cmp[h] = (h < N_HART) ? '1 : '0;
      n_mtip_rise[h] = 0; n_mtip_fall[h] = 0; n_msip[h] = 0; n_ssip[h] = 0;
    end
    tb_reset();
    `CHECK(mtime == 64'd0 && mtip == '0 && msip == '0 && ssip_set == '0, "reset values")
    phase = 0;
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      int h, k;
      // drive after the falling edge
      tick = ($urandom % 3) == 0;
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 3 != 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 2;
        PADDR = pick_addr() | 16'($urandom % 4);
        PWDATA = pick_wdata(PADDR);
        PSTRB = ($urandom % 3 != 0) ? 4'hf : 4'($urandom);
      end else begin
        PWRITE = $urandom % 2; PADDR = 16'($urandom); PWDATA = $urandom; PSTRB = 4'($urandom);
      end
      #1;
      `CHECK(PREADY, "PREADY high")
      if (phase == 2) begin
        expect_read(PADDR, exp_rd, exp_err);
        `CHECK(PSLVERR == exp_err, "PSLVERR")
        if (!PWRITE && !exp_err) `CHECK(PRDATA == exp_rd, "read data")
      end
      @(posedge clk);
      // model update at the edge (values from before the edge)
      for (int x = 0; x < N_HART; x++) begin
        if (!m_mtip[x] && m_time >= m_cmp[x]) n_mtip_rise[x]++;
        if (m_mtip[x] && m_time < m_cmp[x]) n_mtip_fall[x]++;
        m_mtip[x] = m_time >= m_cmp[x];
      end
      m_ssip = '0;
      k = hart_reg(PADDR & 16'hfffc, h);
      if (phase == 2 && PWRITE && !exp_err) begin
        if (k != 0 && h >= N_HART) n_absent_wr++;
        if (h < N_HART) begin
          case (k)
            1: if (PSTRB[0]) begin m_msip[h] = PWDATA[0]; if (PWDATA[0]) n_msip[h]++; end
            2: m_cmp[h][31:0]  = merge(m_cmp[h][31:0], PWDATA, PSTRB);
            3: m_cmp[h][63:32] = merge(m_cmp[h][63:32], PWDATA, PSTRB);
            4: if (PSTRB[0] && PWDATA[0]) begin m_ssip[h] = 1'b1; n_ssip[h]++; end
            default: ;
          endcase
        end
        case (PADDR & 16'hfffc)
          A_TIME_LO: m_time[31:0] = merge(m_time[31:0], PWDATA, PSTRB);
          A_TIME_HI: m_time[63:32] = merge(m_time[63:32], PWDATA, PSTRB);
          default: ;
        endcase
        if (((PADDR & 16'hfff8) != A_TIME_LO || PSTRB == '0) && tick) m_time = m_time + 64'd1;
      end else if (tick) begin
        m_time = m_time + 64'd1;
      end
      @(negedge clk);
      `CHECK(mtime == m_time, "mtime")
      `CHECK(mtip == m_mtip[N_HART-1:0], "mtip")
      `CHECK(msip == m_msip[N_HART-1:0], "msip")
      `CHECK(ssip_set == m_ssip[N_HART-1:0], "ssip_set")
    end
    for (int x = 0; x < N_HART; x++)
      `CHECK(n_mtip_rise[x] > 0 && n_mtip_fall[x] > 0 && n_msip[x] > 0 && n_ssip[x] > 0,
             $sformatf("hart %0d: %0d mtip rises, %0d falls, %0d msip sets, %0d ssip_set", x,
                       n_mtip_rise[x], n_mtip_fall[x], n_msip[x], n_ssip[x]))
    `CHECK(N_HART == M_HART || n_absent_wr > 0, "writes to absent harts")
    tb_pass();
  end
endmodule
