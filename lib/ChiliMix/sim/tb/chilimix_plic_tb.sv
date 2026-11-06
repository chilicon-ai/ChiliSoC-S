// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_plic -- interrupt sources and a software-like APB
// manager against a model of the PLIC with N_CTX contexts.
//
// Stimulus: 63 level irq lines that change now and then; APB transfers to
// priorities (biased to 7 and to sources 31, 32 and 63), both pending words,
// both enable words, threshold and claim of a context (mostly present ones,
// sometimes any of the 16 in the map; enables sometimes all, none or only
// source 63), claim reads, complete writes (mostly the IDs in service,
// sometimes others or disabled ones), unused and unmapped addresses, random
// PSTRB, idle cycles.
// Checked every cycle: PREADY high; in ACCESS, PSLVERR exactly outside the
// registers and the read data (a claim returns the model's best source for
// the context, 0 for an absent one); after each edge eip, the pending and
// in-service bits against the model.
// At the end: claims and completes of sources above 31 happened, ID 63 was
// claimed, a priority tie across the word boundary (a winner in 1 .. 31 with
// an equal candidate in 32 .. 63) was claimed; with several contexts, the
// last context claimed and completed, and a source in service for one
// context was held off another that enables it; with fewer than 16, absent
// contexts were written and read back 0.
`include "tb_common.svh"
module chilimix_plic_tb #(
  parameter int N_CTX = 1
);
  localparam int N_CYC = 80000;
  localparam int N     = 64;            // IDs 0 .. 63
  localparam int M_CTX = 16;            // contexts in the register map

  `TB_CLOCK_RESET

  logic             PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [21:0]      PADDR;
  logic [31:0]      PWDATA, PRDATA;
  logic [3:0]       PSTRB;
  logic [63:1]      irq;
  logic [N_CTX-1:0] eip;

  chilimix_plic #(.N_CTX(N_CTX)) dut (.*);

  localparam logic [21:0] A_PEND = 22'h001000, A_EN = 22'h002000, A_THR = 22'h200000, A_CLAIM = 22'h200004;
  localparam logic [21:0] A_EN_END = A_EN + 22'h780 + 22'd4, A_CTX_END = A_THR + 22'hf000 + 22'd4;

  logic [2:0]  m_prio [N];
  logic [63:0] m_en [M_CTX];            // bit i: source i (bit 0 unused)
  logic [2:0]  m_thr [M_CTX];
  logic [63:0] m_pend, m_insvc;
  logic [M_CTX-1:0] m_eip;
  logic [31:0] exp_rd;
  bit          exp_err;
  int          phase;                   // 0 idle, 1 SETUP, 2 ACCESS
  int          best [M_CTX];            // model's best source per context (0: none)
  // coverage
  int          n_claim_hi, n_claim63, n_tie_cross, n_complete_hi, n_rd_pend1, n_wr_en1, n_wr_prio_hi;
  int          n_claim_last, n_complete_last, n_held_off, n_absent_wr, n_absent_rd;

  function automatic logic [31:0] strb_mask(logic [3:0] s);
    return {{8{s[3]}}, {8{s[2]}}, {8{s[1]}}, {8{s[0]}}};
  endfunction

  function automatic logic [31:0] wr(logic [31:0] old, logic [31:0] mask);
    logic [31:0] m;
    m = mask & strb_mask(PSTRB);
    return (old & ~m) | (PWDATA & m);
  endfunction

  function automatic bit cand(int c, int i);
    return m_pend[i] && m_en[c][i] && m_prio[i] != 0;
  endfunction

  function automatic int best_src(int c);
    int b;
    b = 0;
    if (c >= N_CTX) return 0;
    for (int i = 1; i < N; i++)
      if (cand(c, i) && (b == 0 || m_prio[i] > m_prio[b])) b = i;
    return b;
  endfunction

  // the best source is in 1 .. 31 and a source in 32 .. 63 ties with it
  function automatic bit tie_cross(int c, int b);
    if (b == 0 || b > 31) return 1'b0;
    for (int i = 32; i < N; i++) if (cand(c, i) && m_prio[i] == m_prio[b]) return 1'b1;
    return 1'b0;
  endfunction

  // decode a word address: kind 0 none, 1 enable0, 2 enable1, 3 threshold, 4 claim; c its context
  function automatic int ctx_reg(logic [21:0] w, output int c);
    c = 0;
    if (w >= A_EN && w <= A_EN_END) begin
      c = int'((w - A_EN) >> 7);
      if (w[6:0] == 7'h0) return 1;
      if (w[6:0] == 7'h4) return 2;
    end else if (w >= A_THR && w <= A_CTX_END) begin
      c = int'(w[15:12]);
      if (w[11:0] == 12'h0) return 3;
      if (w[11:0] == 12'h4) return 4;
    end
    return 0;
  endfunction

  task automatic expect_read(logic [21:0] a, output logic [31:0] d, output bit err);
    logic [21:0] w;
    int c, k;
    w = a & 22'h3ffffc;
    err = 1'b0;
    d = '0;
    k = ctx_reg(w, c);
    if (w < 22'h100)                         d = {29'b0, (w == 0) ? 3'b0 : m_prio[w[7:2]]};
    else if (w == A_PEND)                    d = {m_pend[31:1], 1'b0};
    else if (w == A_PEND + 22'd4)            d = m_pend[63:32];
    else if (w >= A_EN && w <= A_EN_END)     d = (k == 1) ? {m_en[c][31:1], 1'b0} : (k == 2) ? m_en[c][63:32] : '0;
    else if (w >= A_THR && w <= A_CTX_END)   d = (k == 3) ? {29'b0, m_thr[c]} : (k == 4) ? 32'(best[c]) : '0;
    else                                     err = 1'b1;
  endtask

  function automatic int pick_ctx();
    return ($urandom % 5 != 0) ? int'($urandom % N_CTX) : int'($urandom % M_CTX);
  endfunction

  function automatic logic [21:0] pick_addr();
    case ($urandom % 22)
      0, 1, 2:  return 22'(4 * ($urandom % N));
      3:        begin
                  case ($urandom % 3)
                    0:       return 22'(4 * 31);
                    1:       return 22'(4 * 32);
                    default: return 22'(4 * 63);
                  endcase
                end
      4:        return A_PEND;
      5:        return A_PEND + 22'd4;
      6, 7:     return A_EN + 22'(pick_ctx() * 'h80);
      8, 9:     return A_EN + 22'(pick_ctx() * 'h80) + 22'd4;
      10:       return A_THR + 22'(pick_ctx() * 'h1000);
      11, 12, 13, 14, 15, 16: return A_CLAIM + 22'(pick_ctx() * 'h1000);
      17:       return ($urandom % 2) ? A_PEND + 22'd8 : A_EN + 22'(4 * ($urandom % 'h200));
      18:       return ($urandom % 2) ? 22'h100 + 22'($urandom % 22'hf00) : A_THR + 22'(4 * ($urandom % 'h4000));
      default:  return 22'($urandom);
    endcase
  endfunction

  function automatic logic [31:0] pick_wdata(logic [21:0] a);
    int ids [$];
    int c, k;
    logic [21:0] w;
    w = a & 22'h3ffffc;
    k = ctx_reg(w, c);
    if (k == 4) begin
      for (int i = 1; i < N; i++) if (m_insvc[i]) ids.push_back(i);
      if (ids.size() != 0 && $urandom % 4 != 0) return 32'(ids[$urandom % ids.size()]);
      return ($urandom % 2) ? 32'($urandom % N) : $urandom;
    end
    if (k == 1) begin
      case ($urandom % 4)
        0, 1:    return 32'hffff_fffe;
        2:       return 32'h0;
        default: return $urandom;
      endcase
    end
    if (k == 2) begin
      case ($urandom % 4)
        0:       return 32'hffff_ffff;
        1:       return 32'h8000_0000;   // only source 63
        2:       return 32'h0000_0001;   // only source 32
        default: return $urandom;
      endcase
    end
    if (k == 3) return 32'($urandom % 8) & (($urandom % 2) ? 32'h3 : 32'h7);
    if (w < 22'h100) return ($urandom % 3 == 0) ? 32'h7 : $urandom;
    return $urandom;
  endfunction

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0; irq = '0;
    for (int i = 0; i < N; i++) m_prio[i] = '0;
    for (int c = 0; c < M_CTX; c++) begin m_en[c] = '0; m_thr[c] = '0; end
    m_pend = '0; m_insvc = '0; m_eip = '0;
    n_claim_hi = 0; n_claim63 = 0; n_tie_cross = 0; n_complete_hi = 0; n_rd_pend1 = 0; n_wr_en1 = 0; n_wr_prio_hi = 0;
    n_claim_last = 0; n_complete_last = 0; n_held_off = 0; n_absent_wr = 0; n_absent_rd = 0;
    tb_reset();
    phase = 0;
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      int c, k;
      // drive after the falling edge
      for (int i = 1; i < N; i++) if ($urandom % 24 == 0) irq[i] = ~irq[i];
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 4 != 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PADDR = pick_addr() | 22'($urandom % 4);
        PWRITE = (ctx_reg(PADDR & 22'h3ffffc, c) == 4) ? ($urandom % 3 == 0) : ($urandom % 2);
        PWDATA = pick_wdata(PADDR);
        PSTRB = ($urandom % 4 != 0) ? 4'hf : 4'($urandom);
      end else begin
        PWRITE = $urandom % 2; PADDR = 22'($urandom); PWDATA = $urandom; PSTRB = 4'($urandom);
      end
      #1;
      for (int x = 0; x < M_CTX; x++) best[x] = best_src(x);
      `CHECK(PREADY, "PREADY high")
      if (phase == 2) begin
        expect_read(PADDR, exp_rd, exp_err);
        `CHECK(PSLVERR == exp_err, "PSLVERR")
        if (!PWRITE && !exp_err) `CHECK(PRDATA == exp_rd, "read data")
      end
      @(posedge clk);
      // model update at the edge (values from before the edge)
      for (int x = 0; x < M_CTX; x++) m_eip[x] = best[x] != 0 && m_prio[best[x]] > m_thr[x];
      begin
        logic [63:0] claim, complete;
        logic [21:0] w;
        logic [5:0]  cid;
        claim = '0; complete = '0;
        w = PADDR & 22'h3ffffc;
        cid = PWDATA[5:0];
        k = ctx_reg(w, c);
        if (phase == 2 && !exp_err) begin
          if (c >= N_CTX && k != 0) begin
            if (PWRITE) n_absent_wr++;
            else if (k != 4) n_absent_rd++;
          end
          if (k == 4 && !PWRITE && best[c] != 0) begin
            claim[best[c]] = 1'b1;
            if (best[c] > 31) n_claim_hi++;
            if (best[c] == 63) n_claim63++;
            if (tie_cross(c, best[c])) n_tie_cross++;
            if (c == N_CTX - 1 && N_CTX > 1) n_claim_last++;
          end
          if (k == 4 && PWRITE && c < N_CTX && PSTRB[0] && cid != 0 && m_en[c][cid]) begin
            complete[cid] = 1'b1;
            if (cid > 31 && m_insvc[cid]) n_complete_hi++;
            if (c == N_CTX - 1 && N_CTX > 1 && m_insvc[cid]) n_complete_last++;
          end
          if (!PWRITE && w == A_PEND + 22'd4 && m_pend[63:32] != '0) n_rd_pend1++;
          if (PWRITE) begin
            if (w < 22'h100 && w != 0) begin
              m_prio[w[7:2]] = 3'(wr(32'(m_prio[w[7:2]]), 32'h7));
              if (w[7:2] > 31) n_wr_prio_hi++;
            end
            if (c < N_CTX) begin
              if (k == 1) m_en[c][31:0] = wr(m_en[c][31:0], 32'hffff_fffe);
              if (k == 2) begin
                m_en[c][63:32] = wr(m_en[c][63:32], 32'hffff_ffff);
                n_wr_en1++;
              end
              if (k == 3) m_thr[c] = 3'(wr(32'(m_thr[c]), 32'h7));
            end
          end
        end
        // a source in service with its irq high, enabled with a priority for a second context
        for (int i = 1; i < N; i++)
          if (m_insvc[i] && irq[i] && m_prio[i] != 0)
            for (int x = 1; x < N_CTX; x++) if (m_en[0][i] && m_en[x][i]) n_held_off++;
        m_pend  = (m_pend | ({irq, 1'b0} & ~m_insvc)) & ~claim;
        m_insvc = (m_insvc | claim) & ~complete;
      end
      @(negedge clk);
      `CHECK(eip == m_eip[N_CTX-1:0], "eip")
      `CHECK({dut.pending, 1'b0} == m_pend, "pending bits")
      `CHECK({dut.in_service, 1'b0} == m_insvc, "in-service bits")
    end
    $display("upper word: %0d claims > 31, %0d of ID 63, %0d cross-word ties, %0d completes > 31, %0d pending1 reads, %0d enable1 writes, %0d priority writes > 31",
             n_claim_hi, n_claim63, n_tie_cross, n_complete_hi, n_rd_pend1, n_wr_en1, n_wr_prio_hi);
    $display("contexts: %0d claims / %0d completes by the last, %0d held-off cycles, %0d absent writes, %0d absent reads",
             n_claim_last, n_complete_last, n_held_off, n_absent_wr, n_absent_rd);
    `CHECK(n_claim_hi > 0,    "claims of sources above 31")
    `CHECK(n_claim63 > 0,     "claim of ID 63")
    `CHECK(n_tie_cross > 0,   "tie-break across the word boundary")
    `CHECK(n_complete_hi > 0, "completes of sources above 31")
    `CHECK(n_rd_pend1 > 0,    "pending1 reads with bits set")
    `CHECK(n_wr_en1 > 0,      "enable1 writes")
    `CHECK(n_wr_prio_hi > 0,  "priority writes above 31")
    `CHECK(N_CTX == 1 || (n_claim_last > 0 && n_complete_last > 0 && n_held_off > 0), "several contexts")
    `CHECK(N_CTX == M_CTX || (n_absent_wr > 0 && n_absent_rd > 0), "absent contexts")
    tb_pass();
  end
endmodule
