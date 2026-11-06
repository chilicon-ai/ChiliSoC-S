// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_bp_chk (chillus_bp is combinational: bound into
// chillus_core for its clock, connected to u_bp's ports)
//   - taken -> in_valid and a backward conditional branch within RANGE, or
//     JAL (header Invariant); a backward branch within RANGE is always
//     predicted
//   - target == pc + imm, imm (from the raw encoding) == the decoder's
//     imm_id for a branch / JAL
// -----------------------------------------------------------------------------
module chillus_bp_chk
  import chillus_dec_pkg::*;
(
  input logic            clk,
  input logic            rst_n,
  input int              range,
  input logic            in_valid,
  input branch_op_e      branch_op,
  input jump_op_e        jump_op,
  input logic [XLEN-1:0] pc,
  input logic [XLEN-1:0] imm,
  input logic [XLEN-1:0] imm_dec,     // u_dec.imm_id
  input logic            taken,
  input logic [XLEN-1:0] target
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic short_back;   // -range <= imm < 0
  assign short_back = $signed(imm) < 0 && $signed(imm) >= -range;

  `CHK(taken |-> in_valid && ((branch_op != BRANCH_OP_NONE && short_back) || jump_op == JUMP_OP_JAL),
       ("chillus_bp: taken without a short backward branch / JAL: in_valid=%b branch_op=%s jump_op=%s imm=%h RANGE=%0d",
        in_valid, branch_op.name(), jump_op.name(), imm, range))
  `CHK(in_valid && (branch_op != BRANCH_OP_NONE && short_back || jump_op == JUMP_OP_JAL) |-> taken,
       ("chillus_bp: short backward branch / JAL not predicted: branch_op=%s jump_op=%s imm=%h RANGE=%0d",
        branch_op.name(), jump_op.name(), imm, range))
  `CHK(target == pc + imm,
       ("chillus_bp: target != pc + imm: target=%h pc=%h imm=%h", target, pc, imm))

  `CHK(in_valid && (branch_op != BRANCH_OP_NONE || jump_op == JUMP_OP_JAL) |-> imm == imm_dec,
       ("chillus_bp: raw-encoding offset != decoder imm_id: imm=%h imm_id=%h branch_op=%s jump_op=%s",
        imm, imm_dec, branch_op.name(), jump_op.name()))

  `undef CHK

endmodule

bind chillus_core chillus_bp_chk u_bp_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .range     (u_bp.RANGE),
  .in_valid  (u_bp.in_valid),
  .branch_op (u_bp.branch_op),
  .jump_op   (u_bp.jump_op),
  .pc        (u_bp.pc),
  .imm       (u_bp.imm),
  .imm_dec   (u_dec.imm_id),
  .taken     (u_bp.taken),
  .target    (u_bp.target)
);
