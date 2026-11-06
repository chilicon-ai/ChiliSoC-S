// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_mdu_chk (bound into chillus_mdu)
//   - state != S_IDLE -> the stage held an M instruction in the previous
//     cycle (header Invariants, corrected: see the note at the assertion)
//   - busy -> in_valid && md_op != NONE (busy is for the presented M
//     instruction only)
//   - while an operation is in progress the presented operation is the one
//     that started it (op_q == md_op)
//   - result: in_valid && md_op != NONE && !busy && !late -> result == the
//     M-extension value of md_op on rs1_data / rs2_data (header, reference
//     model); a MUL that left: late_result == that value in the next cycle
//   - late -> state == S_IDLE && !busy (header Invariants)
//   - busy cycles of an operation that completes: XLEN + 2 for a divide and
//     a MULH* (header Timing)
// -----------------------------------------------------------------------------
module chillus_mdu_chk
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32
) (
  input logic             clk,
  input logic             rst_n,
  input logic             stall,
  input logic             in_valid,
  input md_op_e           md_op,
  input logic [XLEN-1:0]  rs1_data,
  input logic [XLEN-1:0]  rs2_data,
  input logic             busy,
  input logic [XLEN-1:0]  result,
  input logic             late,
  input logic [XLEN-1:0]  late_result,
  input logic [1:0]       state_q,
  input logic [3:0]       op_q
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  localparam logic [1:0] S_IDLE = 2'd0;

  logic             is_md;
  localparam int unsigned EXP_BUSY = XLEN + 2;   // busy cycles of a divide / MULH*
  logic [XLEN-1:0]  exp;          // reference result
  int unsigned      busy_run;     // consecutive busy cycles so far (before this one)

  assign is_md     = (md_op != MD_OP_NONE);

  always_comb begin
    logic signed [2*XLEN:0] p;    // 65-bit signed product (operands sign / zero extended)
    logic        [2*XLEN:0] ua, ub;
    ua = {{(XLEN+1){1'b0}}, rs1_data};
    ub = {{(XLEN+1){1'b0}}, rs2_data};
    exp = '0;
    p   = '0;
    case (md_op)
      MD_OP_MUL:    begin p = $signed(ua) * $signed(ub);                             exp = p[XLEN-1:0];      end
      MD_OP_MULH:   begin p = $signed({{(XLEN+1){rs1_data[XLEN-1]}}, rs1_data}) *
                              $signed({{(XLEN+1){rs2_data[XLEN-1]}}, rs2_data});     exp = p[2*XLEN-1:XLEN]; end
      MD_OP_MULHSU: begin p = $signed({{(XLEN+1){rs1_data[XLEN-1]}}, rs1_data}) * $signed(ub);
                                                                                     exp = p[2*XLEN-1:XLEN]; end
      MD_OP_MULHU:  begin p = $signed(ua) * $signed(ub);                             exp = p[2*XLEN-1:XLEN]; end
      MD_OP_DIV:    exp = (rs2_data == '0) ? '1 :
                          (rs1_data == {1'b1, {(XLEN-1){1'b0}}} && rs2_data == '1) ? rs1_data :
                          XLEN'($signed(rs1_data) / $signed(rs2_data));
      MD_OP_DIVU:   exp = (rs2_data == '0) ? '1 : rs1_data / rs2_data;
      MD_OP_REM:    exp = (rs2_data == '0) ? rs1_data :
                          (rs1_data == {1'b1, {(XLEN-1){1'b0}}} && rs2_data == '1) ? '0 :
                          XLEN'($signed(rs1_data) % $signed(rs2_data));
      MD_OP_REMU:   exp = (rs2_data == '0) ? rs1_data : rs1_data % rs2_data;
      default:      exp = '0;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy_run <= 0;
    end else begin
      busy_run <= busy ? busy_run + 1 : 0;
    end
  end

  // Header: "state != S_IDLE -> the stage holds an M instruction (in_valid)".
  // The state register leaves S_IDLE / returns to it at the edge after the
  // decision, so the instruction it belongs to was presented in the previous
  // cycle; in the current cycle in_valid may already be low (killed, e.g. an
  // interrupt taken on it: "Any state: in_valid low -> S_IDLE").
  `CHK(state_q != S_IDLE |-> $past(in_valid) && $past(is_md),
       ("chillus_mdu: state != S_IDLE without an M instruction in the stage: state=%0d in_valid=%b(prev %b) md_op=%s",
        state_q, in_valid, $past(in_valid), md_op.name()))
  `CHK(state_q != S_IDLE && in_valid |-> 4'(md_op) == op_q,
       ("chillus_mdu: operation changed while in progress: state=%0d md_op=%s op_q=%0d", state_q, md_op.name(), op_q))
  `CHK(busy |-> in_valid && is_md,
       ("chillus_mdu: busy without an M instruction: in_valid=%b md_op=%s", in_valid, md_op.name()))
  `CHK(late |-> state_q == S_IDLE && !busy,
       ("chillus_mdu: late MUL with state=%0d busy=%b", state_q, busy))
  `CHK($past(late && !stall) |-> late_result == $past(exp),
       ("chillus_mdu: MUL product: rs1=%h rs2=%h late_result=%h expected=%h",
        $past(rs1_data), $past(rs2_data), late_result, $past(exp)))
  `CHK(in_valid && is_md && !busy && !late |-> result == exp,
       ("chillus_mdu: result != M-extension value: md_op=%s rs1=%h rs2=%h result=%h expected=%h",
        md_op.name(), rs1_data, rs2_data, result, exp))
  `CHK(in_valid && is_md && !busy && $past(busy) && $past(in_valid) |->
       busy_run == EXP_BUSY,
       ("chillus_mdu: busy cycles of %s = %0d, expected %0d", md_op.name(), busy_run, EXP_BUSY))

  `undef CHK

endmodule

bind chillus_mdu chillus_mdu_chk #(
  .XLEN (XLEN)
) u_chk (
  .clk           (clk),
  .rst_n         (rst_n),
  .stall         (stall),
  .in_valid      (in_valid),
  .md_op         (md_op),
  .rs1_data      (rs1_data),
  .rs2_data      (rs2_data),
  .busy          (busy),
  .result        (result),
  .late          (late),
  .late_result   (late_result),
  .state_q       (state_q),
  .op_q          (op_q)
);
