// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_jtag_tap -- random tms / tdi against a model of the
// 1149.1 TAP (state table, IR, IDCODE, BYPASS) with a USER_W-bit user data
// register selected by USER_IR, as a DTM would build it.
//
// Directed first: after reset the IDCODE scan returns IDCODE; an IR scan
// captures ...01; BYPASS delays tdi by one bit; a user DR scan captures and
// updates. Then random tms (biased towards staying in Shift / Run-Test-Idle,
// with the occasional tms-high run to Test-Logic-Reset), random tdi, and
// random IR scans of IDCODE / BYPASS / USER_IR / other codes.
// Checked before every rising edge of tck: tdo_en and tdo (driven on the
// falling edge) against the model; ir, the capture / shift / update outputs
// and tlr against the model state; the user register's updated value.
`include "tb_common.svh"
module basechili_jtag_tap_tb #(
  parameter int          IR_W   = 5,
  parameter logic [31:0] IDCODE = 32'h1234_5677
);
  localparam int              N_CYC     = 40000;
  localparam int              USER_W    = 9;
  localparam logic [IR_W-1:0] IDCODE_IR = IR_W'(1);
  localparam logic [IR_W-1:0] USER_IR   = IR_W'(2);
  localparam logic [IR_W-1:0] BYPASS_IR = '1;

  `TB_CLOCK_RESET

  logic            tms, tdi, tdo, tdo_en;
  logic [IR_W-1:0] ir;
  logic            tlr, capture_dr, shift_dr, update_dr, user_sel, user_tdo;

  basechili_jtag_tap #(.IR_W(IR_W), .IDCODE(IDCODE), .IDCODE_IR(IDCODE_IR)) dut (
    .tck (clk), .rst_n (rst_n), .tms (tms), .tdi (tdi), .tdo (tdo), .tdo_en (tdo_en),
    .ir (ir), .tlr (tlr), .capture_dr (capture_dr), .shift_dr (shift_dr), .update_dr (update_dr),
    .user_sel (user_sel), .user_tdo (user_tdo)
  );

  // ---- the user data register (TB side, as a DTM builds it)
  logic [USER_W-1:0] user_sr, user_val, user_cap;
  assign user_sel = ir == USER_IR;
  assign user_tdo = user_sr[0];
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin user_sr <= '0; user_val <= '0; end
    else if (user_sel && capture_dr) user_sr <= user_cap;
    else if (user_sel && shift_dr)   user_sr <= {tdi, user_sr[USER_W-1:1]};
    else if (user_sel && update_dr)  user_val <= user_sr;
  end

  // ---- model
  typedef enum int {TLR, RTI, SEL_DR, CAP_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPD_DR,
                    SEL_IR, CAP_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPD_IR} st_e;
  st_e               m_st;
  logic [IR_W-1:0]   m_ir, m_ir_sr;
  logic [31:0]       m_id_sr;
  logic              m_bypass;
  logic [USER_W-1:0] m_user_sr, m_user_val;
  logic              exp_tdo, exp_tdo_en, dr_lsb;
  logic [63:0]       got;
  int                n_user_upd, n_tlr, n_ir_upd;

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

  task automatic model_reset();
    m_st = TLR; m_ir = IDCODE_IR; m_ir_sr = '0; m_id_sr = '0; m_bypass = 0;
    m_user_sr = '0; m_user_val = '0;
  endtask

  // one tck cycle: drive tms / tdi after the falling edge, check before the
  // rising edge, then step the model
  task automatic step(input logic t, input logic d);
    tms = t; tdi = d;
    user_cap = USER_W'($urandom);
    #1;
    dr_lsb     = (m_ir == IDCODE_IR) ? m_id_sr[0] : (m_ir == USER_IR) ? m_user_sr[0] : m_bypass;
    exp_tdo_en = m_st == SHIFT_IR || m_st == SHIFT_DR;
    exp_tdo    = (m_st == SHIFT_IR) ? m_ir_sr[0] : (m_st == SHIFT_DR) ? dr_lsb : 1'b0;
    `CHECK(tdo_en == exp_tdo_en, "tdo_en")
    `CHECK(tdo == exp_tdo, "tdo")
    `CHECK(ir == m_ir, "ir")
    `CHECK(tlr == (m_st == TLR), "tlr")
    `CHECK(capture_dr == (m_st == CAP_DR) && shift_dr == (m_st == SHIFT_DR) && update_dr == (m_st == UPD_DR),
           "capture_dr / shift_dr / update_dr")
    `CHECK(user_val == m_user_val, "user register update")
    @(posedge clk);
    case (m_st)
      TLR:      m_ir = IDCODE_IR;
      CAP_IR:   m_ir_sr = IR_W'(2'b01);
      SHIFT_IR: m_ir_sr = {d, m_ir_sr[IR_W-1:1]};
      UPD_IR:   begin m_ir = m_ir_sr; n_ir_upd++; end
      CAP_DR:   begin
        if (m_ir == IDCODE_IR) m_id_sr = IDCODE;
        else if (m_ir == USER_IR) m_user_sr = user_cap;
        m_bypass = 1'b0;
      end
      SHIFT_DR: begin
        if (m_ir == IDCODE_IR) m_id_sr = {d, m_id_sr[31:1]};
        else if (m_ir == USER_IR) m_user_sr = {d, m_user_sr[USER_W-1:1]};
        m_bypass = d;
      end
      UPD_DR:   if (m_ir == USER_IR) begin m_user_val = m_user_sr; n_user_upd++; end
      default: ;
    endcase
    if (m_st != SHIFT_DR) m_bypass = 1'b0;
    if (m_st == TLR) n_tlr++;
    m_st = next_st(m_st, t);
    @(negedge clk);
  endtask

  // scans from Run-Test/Idle back to Run-Test/Idle; out = bits seen on tdo
  task automatic scan(input bit is_ir, input int n, input logic [63:0] in, output logic [63:0] out);
    step(1, 0);                          // Select-DR
    if (is_ir) step(1, 0);               // Select-IR
    step(0, 0);                          // Capture
    step(0, 0);                          // Shift (first bit appears)
    out = '0;
    for (int i = 0; i < n; i++) begin
      #1 out[i] = tdo;                   // after the falling-edge update
      step(i == n - 1, in[i]);           // last bit leaves Shift (Exit1)
    end
    step(1, 0);                          // Update
    step(0, 0);                          // Run-Test/Idle
  endtask

  initial begin
    tms = 1; tdi = 0; user_cap = '0;
    n_user_upd = 0; n_tlr = 0; n_ir_upd = 0;
    model_reset();
    tb_reset();
    // ---- directed
    step(0, 0);                                          // Run-Test/Idle
    scan(0, 32, '0, got);
    `CHECK(got[31:0] == IDCODE, "IDCODE after reset")
    scan(1, IR_W, 64'(BYPASS_IR), got);
    `CHECK(got[1:0] == 2'b01, "IR capture pattern")
    scan(0, 8, 64'hA5, got);
    `CHECK(got[7:0] == 8'h4A, "BYPASS delays tdi by one bit")
    scan(1, IR_W, 64'(USER_IR), got);
    scan(0, USER_W, 64'h15A, got);
    `CHECK(user_val == USER_W'(9'h15A), "user DR update")
    for (int i = 0; i < 5; i++) step(1, 0);
    `CHECK(tlr && ir == IDCODE_IR, "five tms-high edges reset the TAP")
    step(0, 0);
    // ---- random
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      if ($urandom % 400 == 0) begin
        for (int i = 0; i < 5; i++) step(1, $urandom);
      end else if ($urandom % 50 == 0 && m_st == RTI) begin
        case ($urandom % 4)
          0: scan(1, IR_W, 64'(IDCODE_IR), got);
          1: scan(1, IR_W, 64'(USER_IR), got);
          2: scan(1, IR_W, 64'(BYPASS_IR), got);
          default: scan(1, IR_W, 64'($urandom), got);
        endcase
      end else if (m_st == SHIFT_DR || m_st == SHIFT_IR || m_st == RTI || m_st == PAUSE_DR) begin
        step($urandom % 6 == 0, $urandom);               // mostly stay
      end else begin
        step($urandom % 2, $urandom);
      end
      if ($urandom % 10000 == 0) begin model_reset(); tb_reset(); end
    end
    $display("user updates %0d, IR updates %0d, TLR cycles %0d", n_user_upd, n_ir_upd, n_tlr);
    `CHECK(n_user_upd > 20, "few user DR updates")
    `CHECK(n_ir_upd > 100, "few IR updates")
    tb_pass();
  end
endmodule
