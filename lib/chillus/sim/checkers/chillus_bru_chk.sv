// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_bru_chk (chillus_bru is combinational: bound into
// chillus_core for its clock, connected to u_bru's ports / nets)
//   - jump, no_jump and target_misaligned: at most one high; all 0 (and the
//     RAS hints) when in_valid is low or the instruction is no jump / branch
//     (header Outputs, file list implementation)
//   - target_misaligned never for a not-taken branch, impossible with
//     IALIGN = 16 (header)
//   - a jump target is aligned (bit 0 = 0); JALR target bit 0 cleared
//   - link == pc + 4 (32-bit) / pc + 2 (16-bit) (header)
//   - ras_push / ras_pop only with jump (header: "valid with jump")
//   - a valid instruction is not both a branch and a jump (decoder)
//   - predicted only for a valid backward branch or JAL (header: static BTFN;
//     the exact rule is checked against chillus_bp in chillus_core_chk)
// -----------------------------------------------------------------------------
module chillus_bru_chk
  import chillus_dec_pkg::*;
(
  input logic            clk,
  input logic            rst_n,
  input int              ialign,
  input logic            in_valid,
  input branch_op_e      branch_op,
  input jump_op_e        jump_op,
  input logic            is32,
  input logic [XLEN-1:0] pc,
  input logic            jump,
  input logic            no_jump,
  input logic            target_misaligned,
  input logic [XLEN-1:0] target,
  input logic [XLEN-1:0] link,
  input logic            ras_push,
  input logic            ras_pop,
  input logic            predicted,
  input logic [XLEN-1:0] imm
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic ctrl_instr;   // a jump or branch is presented
  assign ctrl_instr = in_valid && (branch_op != BRANCH_OP_NONE || jump_op != JUMP_OP_NONE);

  `CHK($onehot0({jump, no_jump, target_misaligned}),
       ("chillus_bru: jump / no_jump / target_misaligned at most one violated: jump=%b no_jump=%b target_misaligned=%b",
        jump, no_jump, target_misaligned))
  `CHK(!ctrl_instr |-> !jump && !no_jump && !target_misaligned && !ras_push && !ras_pop,
       ("chillus_bru: outputs 0 without a valid jump / branch violated: in_valid=%b jump=%b no_jump=%b tm=%b ras=%b%b",
        in_valid, jump, no_jump, target_misaligned, ras_push, ras_pop))
  `CHK(ialign == 16 |-> !target_misaligned,
       ("chillus_bru: target_misaligned with IALIGN 16: target=%h", target))
  `CHK(jump |-> target[0] == 1'b0 && (ialign == 16 || target[1] == 1'b0),
       ("chillus_bru: jump to a misaligned target: target=%h IALIGN=%0d", target, ialign))
  `CHK(jump_op == JUMP_OP_JALR |-> target[0] == 1'b0,
       ("chillus_bru: JALR target bit 0 not cleared: target=%h", target))
  `CHK(link == pc + (is32 ? XLEN'(4) : XLEN'(2)),
       ("chillus_bru: link == pc + 4 / 2 violated: pc=%h is32=%b link=%h", pc, is32, link))
  `CHK((ras_push || ras_pop) |-> jump,
       ("chillus_bru: RAS hint without jump: ras_push=%b ras_pop=%b", ras_push, ras_pop))
  `CHK(in_valid |-> !(branch_op != BRANCH_OP_NONE && jump_op != JUMP_OP_NONE),
       ("chillus_bru: both branch_op and jump_op set: branch_op=%s jump_op=%s", branch_op.name(), jump_op.name()))

  `CHK(predicted |-> in_valid && ((branch_op != BRANCH_OP_NONE && imm[XLEN-1]) || jump_op == JUMP_OP_JAL),
       ("chillus_bru: predicted without a backward branch / JAL: branch_op=%s jump_op=%s imm=%h",
        branch_op.name(), jump_op.name(), imm))

  `undef CHK

endmodule

bind chillus_core chillus_bru_chk u_bru_chk (
  .clk               (clk),
  .rst_n             (rst_n),
  .ialign            (u_bru.IALIGN),
  .in_valid          (u_bru.in_valid),
  .branch_op         (u_bru.branch_op),
  .jump_op           (u_bru.jump_op),
  .is32              (u_bru.is32),
  .pc                (u_bru.pc),
  .jump              (u_bru.jump),
  .no_jump           (u_bru.no_jump),
  .target_misaligned (u_bru.target_misaligned),
  .target            (u_bru.target),
  .link              (u_bru.link),
  .ras_push          (u_bru.ras_push),
  .ras_pop           (u_bru.ras_pop),
  .predicted         (u_bru.predicted),
  .imm               (u_bru.imm)
);
