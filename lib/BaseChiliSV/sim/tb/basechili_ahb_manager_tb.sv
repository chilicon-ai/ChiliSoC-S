// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_manager and basechili_ahb_subordinate, back to
// back over AHB (also used by basechili_ahb_subordinate_tb).
//
// Manager user side: random reads / writes of USER_DATA_W bits (BEATS AHB
// beats each) to aligned addresses, random ack_accept delays; single-beat
// requests also with narrower sizes (req_size, aligned addresses).
// Subordinate user side: a memory model with random accept / response
// delays (including the same-cycle response) and random ERROR responses.
// Checked: every beat reaches the subordinate with the right address,
// direction and write data, in order; ack_rdata carries the returned beats
// of a read (non-error beats) and ack_error is the OR of the beat errors.
`include "tb_common.svh"
module basechili_ahb_manager_tb #(
  parameter int HDATA_W     = 32,
  parameter int USER_DATA_W = HDATA_W
);
  import basechili_ahb_pkg::*;
  localparam int HADDR_W = 32;
  localparam int BEATS   = USER_DATA_W / HDATA_W;
  localparam int N_TXN   = 3000;
  localparam int FULL    = $clog2(HDATA_W / 8);   // HSIZE of a full-width beat

  `TB_CLOCK_RESET

  // manager user side
  logic                   m_req_valid, m_req_write, m_req_accept;
  logic [HADDR_W-1:0]     m_req_addr;
  logic [USER_DATA_W-1:0] m_req_wdata;
  logic [2:0]             m_req_size;
  logic                   m_ack_valid, m_ack_error, m_ack_accept;
  logic [USER_DATA_W-1:0] m_ack_rdata;
  // AHB
  logic [HADDR_W-1:0]     HADDR;
  logic [1:0]             HTRANS;
  logic                   HWRITE, HMASTLOCK, HREADY, HRESP;
  logic [2:0]             HSIZE, HBURST;
  logic [3:0]             HPROT;
  logic [HDATA_W-1:0]     HWDATA, HRDATA;
  // subordinate user side
  logic                   s_req_valid, s_req_write, s_req_accept;
  logic [HADDR_W-1:0]     s_req_addr;
  logic [2:0]             s_req_size;
  logic [HDATA_W-1:0]     s_req_wdata;
  logic                   s_ack_valid, s_ack_error, s_ack_accept;
  logic [HDATA_W-1:0]     s_ack_rdata;

  basechili_ahb_manager #(.HADDR_W(HADDR_W), .HDATA_W(HDATA_W), .USER_DATA_W(USER_DATA_W)) u_mgr (
    .clk, .rst_n,
    .req_valid (m_req_valid), .req_write (m_req_write), .req_addr (m_req_addr), .req_wdata (m_req_wdata),
    .req_size (m_req_size), .req_accept (m_req_accept),
    .ack_valid (m_ack_valid), .ack_error (m_ack_error), .ack_rdata (m_ack_rdata), .ack_accept (m_ack_accept),
    .HADDR, .HTRANS, .HWRITE, .HSIZE, .HBURST, .HPROT, .HMASTLOCK, .HWDATA, .HREADY, .HRESP, .HRDATA);

  basechili_ahb_subordinate #(.HADDR_W(HADDR_W), .HDATA_W(HDATA_W)) u_sub (
    .clk, .rst_n,
    .HSEL (1'b1), .HADDR, .HTRANS, .HWRITE, .HSIZE, .HWDATA, .HREADY, .HREADYOUT (HREADY), .HRESP, .HRDATA,
    .req_valid (s_req_valid), .req_write (s_req_write), .req_addr (s_req_addr), .req_size (s_req_size),
    .req_wdata (s_req_wdata), .req_accept (s_req_accept),
    .ack_valid (s_ack_valid), .ack_error (s_ack_error), .ack_rdata (s_ack_rdata), .ack_accept (s_ack_accept));

  typedef struct { logic [HADDR_W-1:0] addr; logic write; logic [2:0] size; logic [HDATA_W-1:0] wdata; } beat_t;
  typedef struct { logic err; logic [HDATA_W-1:0] rdata; } resp_t;
  beat_t              exp_beats[$];   // beats the manager must send, in order
  resp_t              resps[$];       // responses the subordinate gave, in order
  logic [HDATA_W-1:0] mem [logic [HADDR_W-1:0]];
  logic               txn_write[$];   // direction of each issued request, in order
  int                 done, issued;

  // ---------------- manager user side ----------------
  logic m_req_fire_q, m_ack_fire_q;
  initial begin
    m_req_valid = 1'b0; m_req_write = 1'b0; m_req_addr = '0; m_req_wdata = '0; m_req_size = 3'(FULL); m_ack_accept = 1'b0;
    m_req_fire_q = 1'b0; m_ack_fire_q = 1'b0; done = 0; issued = 0;
    tb_reset();
    while (done < N_TXN) begin
      if (m_req_fire_q) m_req_valid = 1'b0;
      if (!m_req_valid && txn_write.size() == 0 && issued < N_TXN && ($urandom % 3 == 0)) begin
        issued++;
        m_req_valid = 1'b1;
        m_req_write = $urandom;
        // aligned; half to a small region (read after write), half anywhere
        m_req_addr  = HADDR_W'((($urandom % 2) ? ($urandom % 16) : ($urandom % (1 << 26))) * (USER_DATA_W / 8));
        m_req_size  = 3'(FULL);
        if (BEATS == 1 && $urandom % 2) begin             // narrow single beat, aligned
          m_req_size = 3'($urandom % (FULL + 1));
          m_req_addr = m_req_addr + HADDR_W'(($urandom % (HDATA_W / 8)) & ~((1 << m_req_size) - 1));
        end
        for (int i = 0; i < USER_DATA_W / 32 + 1; i++) m_req_wdata = {m_req_wdata, 32'($urandom)};
        txn_write.push_back(m_req_write);
        for (int i = 0; i < BEATS; i++) begin
          beat_t b;
          b.addr  = m_req_addr + HADDR_W'(i * HDATA_W / 8);
          b.write = m_req_write;
          b.size  = m_req_size;
          b.wdata = m_req_wdata[i*HDATA_W +: HDATA_W];
          exp_beats.push_back(b);
        end
      end
      m_ack_accept = $urandom % 3 != 0;
      #1;
      m_req_fire_q = m_req_valid && m_req_accept;
      m_ack_fire_q = m_ack_valid && m_ack_accept;
      if (m_ack_fire_q) begin
        logic err, wr;
        err = 1'b0;
        wr  = txn_write.pop_front();
        `CHECK(resps.size() >= BEATS, "ack before every beat was answered")
        for (int i = 0; i < BEATS; i++) begin
          resp_t r;
          r = resps.pop_front();
          err |= r.err;
          if (!r.err && !wr) `CHECK(m_ack_rdata[i*HDATA_W +: HDATA_W] == r.rdata,
                             $sformatf("beat %0d rdata=%h expected %h", i, m_ack_rdata[i*HDATA_W +: HDATA_W], r.rdata))
        end
        `CHECK(m_ack_error == err, "ack_error is the OR of the beat errors")
        done++;
      end
      @(negedge clk);
    end
    `CHECK(exp_beats.size() == 0 && resps.size() == 0, "no beat left over")
    tb_pass();
  end

  // ---------------- subordinate user side (memory) ----------------
  logic         pending;            // request taken, response not given yet
  beat_t        cur;                // the request being answered
  logic         s_ack_fire_q;
  initial begin
    s_req_accept = 1'b0; s_ack_valid = 1'b0; s_ack_error = 1'b0; s_ack_rdata = '0;
    pending = 1'b0; s_ack_fire_q = 1'b0;
    forever begin
      @(negedge clk);
      if (s_ack_fire_q) begin s_ack_valid = 1'b0; pending = 1'b0; end
      s_req_accept = 1'b0;
      if (!pending && s_req_valid && ($urandom % 2)) begin
        beat_t e;
        `CHECK(exp_beats.size() > 0, "unexpected beat")
        e = exp_beats.pop_front();
        `CHECK(s_req_addr == e.addr && s_req_write == e.write && (!e.write || s_req_wdata == e.wdata)
               && s_req_size == e.size,
               $sformatf("beat addr=%h write=%b wdata=%h expected %h %b %h", s_req_addr, s_req_write, s_req_wdata, e.addr, e.write, e.wdata))
        s_req_accept = 1'b1;
        pending = 1'b1;
        cur = e;
      end
      // respond (possibly in the same cycle as the accept); hold once valid
      if (pending && !s_ack_valid && ($urandom % 2)) begin
        s_ack_valid = 1'b1;
        s_ack_error = ($urandom % 16) == 0;
        if (cur.write) begin
          if (!s_ack_error) mem[cur.addr] = cur.wdata;
          s_ack_rdata = HDATA_W'($urandom);
        end else s_ack_rdata = mem.exists(cur.addr) ? mem[cur.addr] : '0;
        begin
          resp_t r;
          r.err   = s_ack_error;
          r.rdata = s_ack_rdata;
          resps.push_back(r);
        end
      end
      #1 s_ack_fire_q = s_ack_valid && s_ack_accept;
    end
  end

  // a stuck bus fails the run instead of hanging it
  initial begin
    #(N_TXN * BEATS * 400);
    `CHECK(1'b0, $sformatf("timeout after %0d transactions", done))
  end
endmodule
