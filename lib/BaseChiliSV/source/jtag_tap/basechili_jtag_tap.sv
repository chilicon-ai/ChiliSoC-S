// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_jtag_tap
//
// IEEE 1149.1 TAP controller: the 16-state TAP state machine, an IR_W-bit
// instruction register, the IDCODE and BYPASS data registers, and a generic
// port for user data registers (e.g. the RISC-V debug DTM's dtmcs and dmi),
// which live in the module that uses the TAP.
//   ir        the current instruction; IDCODE_IR after reset and in
//             Test-Logic-Reset. Shift-IR captures ...01 (the standard
//             capture pattern), shifts LSB first, loads ir in Update-IR.
//   IDCODE    selected by ir == IDCODE_IR: captures IDCODE (bit 0 must be 1).
//   user DR   selected by user_sel (decoded by the user from ir): the user
//             register loads / shifts / updates on the rising edge of tck
//             while capture_dr / shift_dr / update_dr is high, shifting tdi
//             in at its MSB, and drives its LSB on user_tdo.
//   BYPASS    every other instruction (1 bit, captures 0); BYPASS_IR (all
//             ones) is one of them.
// tdo changes on the falling edge of tck (1149.1): the IR or the selected
// DR's LSB, with tdo_en high while in Shift-IR / Shift-DR (the pad's output
// enable; tdo is 0 otherwise).
//
// 1149.1 deviation (kept on purpose): the instruction
// and the user registers update at the rising edge that leaves Update-IR /
// Update-DR, half a tck period after the standard's falling edge (as most
// debug TAPs; nothing at the pins depends on it). For strict timing
// compliance, move ir (u_ir) and the users' update stages to tck_n. Also not
// 1149.1: no boundary-scan register, EXTEST or SAMPLE / PRELOAD (a debug TAP).
//
// Timing    : the state, ir and the shift registers change on the rising
//             edge of tck; capture_dr / shift_dr / update_dr / tlr are
//             combinational from the state; tdo / tdo_en are registered on
//             the falling edge (half a cycle after the rising edge).
// Invariants: five rising edges of tck with tms high end in
//             Test-Logic-Reset; at most one of Capture / Shift / Update of
//             IR and DR is active; one cycle in Test-Logic-Reset sets ir to
//             IDCODE_IR; tdo_en == in Shift-IR or Shift-DR.
// Debug     : nothing shifts out -> state, tdo_en (u_tdo_en.q); wrong IDCODE
//             -> ir against IDCODE_IR, idcode_sr; user DR not selected ->
//             ir, user_sel.
// -----------------------------------------------------------------------------
module basechili_jtag_tap #(
  parameter int                IR_W      = 5,               // instruction bits, >= 2
  parameter logic [31:0]       IDCODE    = 32'h0000_0001,   // IDCODE value, bit 0 = 1
  parameter logic [IR_W-1:0]   IDCODE_IR = IR_W'(1)         // IDCODE instruction
) (
  input  logic            tck,
  input  logic            rst_n,       // async, active-low (TRST_N and / or power-on)
  input  logic            tms,
  input  logic            tdi,
  output logic            tdo,         // changes on the falling edge of tck
  output logic            tdo_en,      // tdo is driven (Shift-IR / Shift-DR)
  // user data registers
  output logic [IR_W-1:0] ir,          // current instruction
  output logic            tlr,         // in Test-Logic-Reset
  output logic            capture_dr,  // in Capture-DR: load the selected DR
  output logic            shift_dr,    // in Shift-DR: shift the selected DR
  output logic            update_dr,   // in Update-DR: apply the selected DR
  input  logic            user_sel,    // ir selects a user DR (0 for IDCODE / BYPASS)
  input  logic            user_tdo     // LSB of the selected user DR
);

  typedef enum logic [3:0] {
    S_TLR      = 4'd0,    // Test-Logic-Reset
    S_RTI      = 4'd1,    // Run-Test/Idle
    S_SEL_DR   = 4'd2,    // Select-DR-Scan
    S_CAP_DR   = 4'd3,    // Capture-DR
    S_SHIFT_DR = 4'd4,    // Shift-DR
    S_EXIT1_DR = 4'd5,    // Exit1-DR
    S_PAUSE_DR = 4'd6,    // Pause-DR
    S_EXIT2_DR = 4'd7,    // Exit2-DR
    S_UPD_DR   = 4'd8,    // Update-DR
    S_SEL_IR   = 4'd9,    // Select-IR-Scan
    S_CAP_IR   = 4'd10,   // Capture-IR
    S_SHIFT_IR = 4'd11,   // Shift-IR
    S_EXIT1_IR = 4'd12,   // Exit1-IR
    S_PAUSE_IR = 4'd13,   // Pause-IR
    S_EXIT2_IR = 4'd14,   // Exit2-IR
    S_UPD_IR   = 4'd15    // Update-IR
  } state_e;

  logic [3:0]      state_q;     // state register bits
  state_e          state;       // state_q as an enum
  state_e          state_d;     // next state
  logic            capture_ir;  // in Capture-IR
  logic            shift_ir;    // in Shift-IR
  logic            update_ir;   // in Update-IR
  logic [IR_W-1:0] ir_sr;       // instruction shift register
  logic [IR_W-1:0] ir_sr_d;
  logic            ir_en;       // ir loads (Update-IR or Test-Logic-Reset)
  logic [IR_W-1:0] ir_d;
  logic            sel_idcode;  // ir selects IDCODE
  logic [31:0]     idcode_sr;   // IDCODE shift register
  logic [31:0]     idcode_sr_d;
  logic            bypass;      // BYPASS register
  logic            bypass_d;
  logic            dr_tdo;      // LSB of the selected DR
  logic            tdo_d;       // next tdo (falling edge)
  logic            tdo_en_d;    // next tdo_en (falling edge)
  logic            tck_n;       // inverted tck for the falling-edge flops

  // ---- TAP state machine (1149.1 figure 6-1)
  always_comb begin
    case (state)
      S_TLR:      state_d = tms ? S_TLR      : S_RTI;
      S_RTI:      state_d = tms ? S_SEL_DR   : S_RTI;
      S_SEL_DR:   state_d = tms ? S_SEL_IR   : S_CAP_DR;
      S_CAP_DR:   state_d = tms ? S_EXIT1_DR : S_SHIFT_DR;
      S_SHIFT_DR: state_d = tms ? S_EXIT1_DR : S_SHIFT_DR;
      S_EXIT1_DR: state_d = tms ? S_UPD_DR   : S_PAUSE_DR;
      S_PAUSE_DR: state_d = tms ? S_EXIT2_DR : S_PAUSE_DR;
      S_EXIT2_DR: state_d = tms ? S_UPD_DR   : S_SHIFT_DR;
      S_UPD_DR:   state_d = tms ? S_SEL_DR   : S_RTI;
      S_SEL_IR:   state_d = tms ? S_TLR      : S_CAP_IR;
      S_CAP_IR:   state_d = tms ? S_EXIT1_IR : S_SHIFT_IR;
      S_SHIFT_IR: state_d = tms ? S_EXIT1_IR : S_SHIFT_IR;
      S_EXIT1_IR: state_d = tms ? S_UPD_IR   : S_PAUSE_IR;
      S_PAUSE_IR: state_d = tms ? S_EXIT2_IR : S_PAUSE_IR;
      S_EXIT2_IR: state_d = tms ? S_UPD_IR   : S_SHIFT_IR;
      S_UPD_IR:   state_d = tms ? S_SEL_DR   : S_RTI;
      default:    state_d = S_TLR;
    endcase
  end

  basechili_dff #(.WIDTH(4), .RESET_VAL(4'(S_TLR))) u_state (
    .clk   (tck),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state      = state_e'(state_q);
  assign tlr        = state == S_TLR;
  assign capture_dr = state == S_CAP_DR;
  assign shift_dr   = state == S_SHIFT_DR;
  assign update_dr  = state == S_UPD_DR;
  assign capture_ir = state == S_CAP_IR;
  assign shift_ir   = state == S_SHIFT_IR;
  assign update_ir  = state == S_UPD_IR;

  // ---- instruction register
  always_comb begin
    if (capture_ir)    ir_sr_d = IR_W'(2'b01);
    else if (shift_ir) ir_sr_d = {tdi, ir_sr[IR_W-1:1]};
    else               ir_sr_d = ir_sr;
  end

  basechili_dff #(.WIDTH(IR_W)) u_ir_sr (
    .clk   (tck),
    .rst_n (rst_n),
    .d     (ir_sr_d),
    .q     (ir_sr)
  );

  assign ir_en = update_ir || tlr;
  assign ir_d  = tlr ? IDCODE_IR : ir_sr;

  basechili_dffe #(.WIDTH(IR_W), .RESET_VAL(IDCODE_IR)) u_ir (
    .clk   (tck),
    .rst_n (rst_n),
    .en    (ir_en),
    .d     (ir_d),
    .q     (ir)
  );

  // ---- IDCODE and BYPASS
  assign sel_idcode = ir == IDCODE_IR;

  always_comb begin
    if (capture_dr && sel_idcode)    idcode_sr_d = IDCODE;
    else if (shift_dr && sel_idcode) idcode_sr_d = {tdi, idcode_sr[31:1]};
    else                             idcode_sr_d = idcode_sr;
  end

  basechili_dff #(.WIDTH(32)) u_idcode_sr (
    .clk   (tck),
    .rst_n (rst_n),
    .d     (idcode_sr_d),
    .q     (idcode_sr)
  );

  assign bypass_d = shift_dr && tdi;   // captures 0 (Capture-DR is not Shift-DR)

  basechili_dff #(.WIDTH(1)) u_bypass (
    .clk   (tck),
    .rst_n (rst_n),
    .d     (bypass_d),
    .q     (bypass)
  );

  // ---- tdo on the falling edge
  always_comb begin
    if (sel_idcode)    dr_tdo = idcode_sr[0];
    else if (user_sel) dr_tdo = user_tdo;
    else               dr_tdo = bypass;
  end

  assign tdo_en_d = shift_ir || shift_dr;
  assign tdo_d    = shift_ir ? ir_sr[0] : (shift_dr && dr_tdo);
  assign tck_n    = ~tck;

  basechili_dff #(.WIDTH(1)) u_tdo (
    .clk   (tck_n),
    .rst_n (rst_n),
    .d     (tdo_d),
    .q     (tdo)
  );

  basechili_dff #(.WIDTH(1)) u_tdo_en (
    .clk   (tck_n),
    .rst_n (rst_n),
    .d     (tdo_en_d),
    .q     (tdo_en)
  );

endmodule
