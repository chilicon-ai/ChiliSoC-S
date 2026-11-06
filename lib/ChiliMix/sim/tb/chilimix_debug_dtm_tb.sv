// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_debug_dtm -- JTAG scans against a model of the debug
// spec 1.0 DTM (dtmcs, dmi, sticky errors), with a DM model on clk behind
// the DMI port.
//
// tck is driven by the testbench (half period TCK_H; clk has period 10), so
// both "tck slower" and "tck faster than clk" are covered by the parameter
// sets. The only thing the model cannot know from the pins is whether a
// request is still crossing the clock domains: it reads busy and rsp_take
// from the DUT just before each rising edge of tck and predicts everything
// else (captured dmi / dtmcs values, the sticky error, which updates start
// a request, the read data returned).
// Stimulus: random IR scans (dmi mostly, dtmcs, IDCODE, BYPASS), dmi scans
// with random op / address / data and 0 .. 12 Run-Test/Idle cycles (few idle
// cycles make busy errors), dtmcs writes of dmireset / dtmhardreset, the
// odd five-tms reset and trst_n pulse. The DM model accepts after random
// waits, answers after random waits, fails the top address (op 2) and
// answers busy (op 3) one below it.
// Checked: every bit shifted out of dmi / dtmcs / IDCODE against the model;
// every DMI request against the queue of requests the model started, in
// order; one request at a time on the DMI.
`include "tb_common.svh"
module chilimix_debug_dtm_tb #(
  parameter int ABITS  = 7,
  parameter int TCK_H  = 13      // tck half period (clk period is 10)
);
  localparam int          N_OPS  = 4000;
  localparam int          DMI_W  = ABITS + 34;
  localparam logic [31:0] IDCODE = 32'h1C0D_E0A3;
  localparam int          IDLE   = 2;
  localparam logic [ABITS-1:0] FAIL_ADDR = '1;
  localparam logic [ABITS-1:0] BUSY_ADDR = FAIL_ADDR - 1'b1;

  `TB_CLOCK_RESET

  logic             tck = 0, trst_n = 1, tms = 1, tdi = 0, tdo, tdo_en;
  logic             dmi_req_valid, dmi_req_accept, dmi_rsp_valid, dmi_rsp_accept;
  logic [ABITS-1:0] dmi_req_addr;
  logic [31:0]      dmi_req_data, dmi_rsp_data;
  logic [1:0]       dmi_req_op, dmi_rsp_op;

  chilimix_debug_dtm #(.ABITS(ABITS), .IDCODE(IDCODE), .IDLE(IDLE)) dut (.*);

  // ---- DM model (clk domain)
  logic [31:0]      mem [2**ABITS];
  logic [ABITS+33:0] exp_req [$];       // requests the model started {addr, data, op}
  logic [33:0]      exp_rsp [$];        // responses on their way to tck {data, op}
  int               rsp_wait;
  bit               rsp_pending;
  logic             dmi_rsp_accept_q;   // dmi_rsp_accept at the last clk edge
  int               n_req;

  initial begin
    for (int i = 0; i < 2**ABITS; i++) mem[i] = '0;
    dmi_req_accept = 0; dmi_rsp_valid = 0; dmi_rsp_data = '0; dmi_rsp_op = '0;
    rsp_pending = 0; n_req = 0;
    forever begin
      @(negedge clk);
      if (dmi_rsp_valid && dmi_rsp_accept_q) begin dmi_rsp_valid = 0; rsp_pending = 0; end
      if (rsp_pending && !dmi_rsp_valid) begin
        if (rsp_wait == 0) dmi_rsp_valid = 1; else rsp_wait--;
      end
      dmi_req_accept = !rsp_pending && ($urandom % 3 != 0);
    end
  end

  // sample the handshakes at the rising edge of clk
  always @(posedge clk) begin
    dmi_rsp_accept_q <= dmi_rsp_accept;
    if (rst_n && dmi_req_valid && dmi_req_accept) begin
      `CHECK(!rsp_pending, "one DMI request at a time")
      `CHECK(exp_req.size() > 0, "DMI request the model did not start")
      if (exp_req.size() > 0) begin
        `CHECK({dmi_req_addr, dmi_req_data, dmi_req_op} == exp_req[0], "DMI request contents")
        void'(exp_req.pop_front());
      end
      n_req++;
      rsp_pending <= 1;
      rsp_wait <= $urandom % 6;
      if (dmi_req_addr == FAIL_ADDR) begin
        dmi_rsp_data <= 32'hDEAD_0002; dmi_rsp_op <= 2'd2;
      end else if (dmi_req_addr == BUSY_ADDR) begin
        dmi_rsp_data <= 32'hDEAD_0003; dmi_rsp_op <= 2'd3;
      end else if (dmi_req_op == 2'd2) begin
        mem[dmi_req_addr] <= dmi_req_data; dmi_rsp_data <= 32'h0; dmi_rsp_op <= 2'd0;
      end else begin
        dmi_rsp_data <= mem[dmi_req_addr]; dmi_rsp_op <= 2'd0;
      end
    end
  end

  // ---- DTM model (tck domain)
  typedef enum int {TLR, RTI, SEL_DR, CAP_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPD_DR,
                    SEL_IR, CAP_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPD_IR} st_e;
  st_e              m_st;
  logic [4:0]       m_ir, m_ir_sr;
  logic [1:0]       m_err;
  logic [ABITS-1:0] m_addr;
  logic [31:0]      m_rsp_data;
  logic [63:0]      m_cap;            // value captured by the last Capture-DR
  logic [DMI_W-1:0] m_upd;            // dmi value at Update-DR
  logic [63:0]      shifted_in;       // bits shifted in this DR scan
  logic [63:0]      shifted_out;      // bits seen on tdo this DR scan
  int               n_shift;
  int               n_issued, n_busy_err, n_fail_err, n_dmireset, n_reads_ok;

  function automatic st_e next_st(st_e s, logic t);
    case (s)
      TLR:      return t ? TLR      : RTI;
      RTI:      return t ? SEL_DR   : RTI;
      SEL_DR:   return t ? SEL_IR   : CAP_DR;
      CAP_DR:   return t ? EXIT1_DR : SHIFT_DR;
      SHIFT_DR: return t ? EXIT1_DR : SHIFT_DR;
      EXIT1_DR: return t ? UPD_DR   : PAUSE_DR;
      PAUSE_DR: return t ? EXIT2_DR : PAUSE_DR;
      EXIT2_DR: return t ? UPD_DR   : SHIFT_DR;
      UPD_DR:   return t ? SEL_DR   : RTI;
      SEL_IR:   return t ? TLR      : CAP_IR;
      CAP_IR:   return t ? EXIT1_IR : SHIFT_IR;
      SHIFT_IR: return t ? EXIT1_IR : SHIFT_IR;
      EXIT1_IR: return t ? UPD_IR   : PAUSE_IR;
      PAUSE_IR: return t ? EXIT2_IR : PAUSE_IR;
      EXIT2_IR: return t ? UPD_IR   : SHIFT_IR;
      default:  return t ? SEL_DR   : RTI;
    endcase
  endfunction

  // one tck period: drive, model the rising edge, pulse tck
  task automatic step(input logic t, input logic d);
    logic        busy, take;
    logic [33:0] rsp;
    logic [1:0]  op;
    logic [1:0]  err0;                // the error before this edge
    tms = t; tdi = d;
    #(TCK_H);
    busy = dut.busy;                  // oracle: request crossing the domains
    take = dut.rsp_take;              // oracle: its response arrives at this edge
    case (m_st)
      SHIFT_DR: begin
        shifted_out[n_shift] = tdo;
        shifted_in[n_shift]  = d;
        n_shift++;
      end
      SHIFT_IR: m_ir_sr = {d, m_ir_sr[4:1]};
      default: ;
    endcase
    // sticky error and dmi, same priority as the DUT
    op = shifted_in[1:0];
    err0 = m_err;
    if (m_st == CAP_DR) begin
      n_shift = 0; shifted_in = '0; shifted_out = '0;
      if (m_ir == 5'h11)      m_cap = 64'({m_addr, m_rsp_data, (m_err != 0) ? m_err : (busy ? 2'd3 : 2'd0)});
      else if (m_ir == 5'h10) m_cap = 64'({11'd0, 3'd0, 2'b00, 1'b0, 3'(IDLE), m_err, 6'(ABITS), 4'd1});
      else if (m_ir == 5'h01) m_cap = 64'(IDCODE);
      else                    m_cap = '0;
    end
    if (take) begin
      `CHECK(exp_rsp.size() > 0, "response with nothing in flight")
      if (exp_rsp.size() > 0) rsp = exp_rsp.pop_front();
    end
    if (m_st == UPD_DR && m_ir == 5'h10 && (shifted_in[16] || shifted_in[17])) begin
      m_err = 2'd0; n_dmireset++;
    end else if (m_err != 0) begin
    end else if (((m_st == CAP_DR && m_ir == 5'h11) || (m_st == UPD_DR && m_ir == 5'h11 && (op == 1 || op == 2)))
                 && busy) begin
      m_err = 2'd3; n_busy_err++;
    end else if (take && rsp[1]) begin
      m_err = rsp[1:0]; n_fail_err++;
    end
    if (take) m_rsp_data = rsp[33:2];
    if (m_st == UPD_DR && m_ir == 5'h11 && (op == 1 || op == 2) && err0 == 2'd0 && !busy) begin
      m_upd = shifted_in[DMI_W-1:0];
      exp_req.push_back(m_upd);
      m_addr = m_upd[DMI_W-1:34];
      n_issued++;
    end
    if (m_st == UPD_IR) m_ir = m_ir_sr;
    if (m_st == TLR)    m_ir = 5'h01;
    if (m_st == CAP_IR) m_ir_sr = 5'b00001;
    m_st = next_st(m_st, t);
    tck = 1;
    #(TCK_H);
    tck = 0;
  endtask

  // DR scan from Run-Test/Idle, n bits of v, idle cycles after; returns captured bits
  task automatic dr_scan(input int n, input logic [63:0] v, input int idle, output logic [63:0] out);
    step(1, 0); step(0, 0); step(0, 0);           // Select-DR, Capture-DR, Shift-DR
    for (int i = 0; i < n; i++) step(i == n - 1, v[i]);
    step(1, 0);                                   // Update-DR
    for (int i = 0; i <= idle; i++) step(0, 0);   // Run-Test/Idle
    out = shifted_out;
  endtask

  task automatic ir_scan(input logic [4:0] v);
    step(1, 0); step(1, 0); step(0, 0); step(0, 0);   // Select-DR, -IR, Capture-IR, Shift-IR
    for (int i = 0; i < 5; i++) step(i == 4, v[i]);
    step(1, 0); step(0, 0);                           // Update-IR, Run-Test/Idle
  endtask

  logic [63:0] got, v;
  logic [ABITS-1:0] a;
  int idle;

  initial begin
    m_st = TLR; m_ir = 5'h01; m_ir_sr = '0; m_err = '0; m_addr = '0; m_rsp_data = '0;
    n_shift = 0; shifted_in = '0; shifted_out = '0;
    n_issued = 0; n_busy_err = 0; n_fail_err = 0; n_dmireset = 0; n_reads_ok = 0;
    tb_reset();
    // tms high while the tck-domain reset is released (its synchronizer
    // needs tck edges), as a debugger starts a session
    for (int i = 0; i < 6; i++) step(1, 0);
    step(0, 0);                                        // Run-Test/Idle
    // ---- directed: IDCODE, dtmcs, a write and a read back
    dr_scan(32, '0, 0, got);
    `CHECK(got[31:0] == IDCODE, "IDCODE")
    ir_scan(5'h10);
    dr_scan(32, '0, 0, got);
    `CHECK(got[31:0] == 32'(m_cap), "dtmcs")
    `CHECK(got[3:0] == 4'd1 && got[9:4] == 6'(ABITS), "dtmcs version / abits")
    ir_scan(5'h11);
    dr_scan(DMI_W, 64'({ABITS'(5), 32'hCAFE_F00D, 2'd2}), 30, got);
    dr_scan(DMI_W, 64'({ABITS'(5), 32'h0, 2'd1}), 30, got);
    dr_scan(DMI_W, 64'({ABITS'(0), 32'h0, 2'd0}), 30, got);
    `CHECK(got[DMI_W-1:0] == DMI_W'({ABITS'(5), 32'hCAFE_F00D, 2'd0}), "dmi write then read")
    // ---- random
    for (int k = 0; k < N_OPS; k++) begin
      case ($urandom % 20)
        0: ir_scan(5'h10);
        1: ir_scan(5'h01);
        2: ir_scan(5'h1f);
        3: ir_scan(5'($urandom));
        4: begin                                       // dtmcs write: dmireset / dtmhardreset
          ir_scan(5'h10);
          dr_scan(32, 64'($urandom) & 64'h0003_0000, 0, got);
          `CHECK(got[31:0] == 32'(m_cap), "dtmcs capture")
          ir_scan(5'h11);
        end
        5: begin for (int i = 0; i < 5; i++) step(1, 0); step(0, 0); end
        6: if ($urandom % 4 == 0) begin
          trst_n = 0; #3; trst_n = 1;                  // TAP reset only
          m_st = TLR; m_ir = 5'h01;
          step(0, 0);
        end
        default: begin
          if (m_ir != 5'h11 && $urandom % 2 == 0) ir_scan(5'h11);
          case ($urandom % 8)
            0:       a = FAIL_ADDR;
            1:       a = BUSY_ADDR;
            default: a = ABITS'($urandom % 8);
          endcase
          v = 64'({a, 32'($urandom), 2'($urandom)});
          idle = ($urandom % 3 == 0) ? 0 : $urandom % 13;
          dr_scan((m_ir == 5'h01) ? 32 : (m_ir == 5'h10) ? 32 : (m_ir == 5'h11) ? DMI_W : 1 + $urandom % 8,
                  v, idle, got);
          if (m_ir == 5'h11 || m_ir == 5'h10 || m_ir == 5'h01) begin
            `CHECK(got == m_cap, "captured value shifted out")
            if (m_ir == 5'h11 && m_cap[1:0] == 2'd0 && m_cap[33:2] != 32'h0) n_reads_ok++;
          end
          // an error seen: mostly clear it at once, as OpenOCD does
          if (m_ir == 5'h11 && m_cap[1:0] != 2'd0 && $urandom % 4 != 0) begin
            ir_scan(5'h10);
            dr_scan(32, 64'h0001_0000, $urandom % 4, got);
            ir_scan(5'h11);
          end
        end
      endcase
    end
    // drain: dmireset and idle until nothing is in flight
    ir_scan(5'h10);
    dr_scan(32, 64'h0001_0000, 40, got);
    `CHECK(exp_req.size() == 0, "requests the model started never reached the DM")
    $display("issued %0d, DM requests %0d, busy errors %0d, DM errors %0d, dmiresets %0d, reads with data %0d",
             n_issued, n_req, n_busy_err, n_fail_err, n_dmireset, n_reads_ok);
    `CHECK(n_issued == n_req, "issued requests reach the DM")
    `CHECK(n_issued > 300, "few requests")
    `CHECK(n_busy_err > 20, "few busy errors")
    `CHECK(n_fail_err > 20, "few DM errors")
    `CHECK(n_reads_ok > 50, "few reads with data")
    tb_pass();
  end

  // response queue for the tck model: the DM model's answer, in order
  always @(posedge clk) if (rst_n && dmi_rsp_valid && dmi_rsp_accept) exp_rsp.push_back({dmi_rsp_data, dmi_rsp_op});
endmodule
