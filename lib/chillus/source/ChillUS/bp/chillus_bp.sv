// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_bp
//
// Static branch predictor: backward taken / forward not taken (BTFN). A pure
// function of the instruction presented on its inputs, so the branch unit
// recomputes the same direction later (chillus_bru.predicted) and no
// prediction bit travels down the pipeline. Stage-agnostic and combinational.
//
// The offset (imm) comes from the raw fetched encoding, not from the decoder,
// so pc + imm (the IFU redirect address) does not wait for chillus_rvc and
// chillus_dec (timing, as chillus_rsdec does for the register numbers);
// in_valid / branch_op / jump_op still come from the decoder and only select:
//   32-bit  BRANCH (instr[3] = 0)  B-type offset
//           JAL    (instr[3] = 1)  J-type offset
//   16-bit  c.beqz / c.bnez (instr[14] = 1)  CB offset
//           c.j / c.jal     (instr[14] = 0)  CJ offset
// For any other instruction imm is meaningless, and taken is low.
//
//   conditional branch, -RANGE <= imm < 0    taken, target pc + imm
//   conditional branch, other imm            not taken (forward, or a long
//                                            backward branch)
//   JAL                                      taken, target pc + imm
//   JALR                                     not predicted (target needs x[rs1])
//
// RANGE limits the backward distance predicted taken: short backward
// branches are loop back edges, mostly taken; long ones (around unrolled or
// large loop bodies) are often not, and a wrong taken prediction costs a
// refetch while a right one saves one cycle. CoreMark (sim/profile.py,
// -O2 and tuned flags) gains most at 128 bytes.
//
// Timing   : combinational, no state. One adder (pc + imm); target depends
//            on instr / is32 / pc only (an offset mux, no decoder).
// Invariant: taken -> in_valid && (branch_op != NONE || jump_op == JAL).
//            taken && branch -> -RANGE <= imm < 0.
//            in_valid && (branch_op != NONE || jump_op == JAL) -> imm ==
//            u_dec.imm_id (the decoder's B / J immediate).
//            taken == chillus_bru.predicted for the same instruction.
// Debug    : backward shows imm's sign; a wrong target: compare imm with
//            u_dec.imm_id and imm_b / imm_j / imm_cb / imm_cj.
// -----------------------------------------------------------------------------
module chillus_bp
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                      // address / register width
) (
  input  logic              in_valid,          // real instruction; 0 for a bubble or a fetch fault
  input  branch_op_e        branch_op,
  input  jump_op_e          jump_op,
  input  logic [XLEN-1:0]   pc,
  input  logic [31:0]       instr,             // as fetched (16-bit in [15:0])
  input  logic              is32,              // 32-bit instruction
  output logic              taken,             // predicted taken: fetch from target next
  output logic [XLEN-1:0]   target             // pc + imm
);

  localparam int RANGE = 128;  // max backward branch distance predicted taken, bytes (power of 2; chillus_bru.RANGE)

  logic is_branch;   // conditional branch
  logic is_jal;
  logic backward;    // negative offset, within RANGE
  logic [XLEN-1:0] imm;     // offset of the branch / JAL, from the raw encoding
  logic [XLEN-1:0] imm_b;   // 32-bit B-type
  logic [XLEN-1:0] imm_j;   // 32-bit J-type
  logic [XLEN-1:0] imm_cb;  // c.beqz / c.bnez
  logic [XLEN-1:0] imm_cj;  // c.j / c.jal

  assign imm_b  = {{(XLEN-12){instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
  assign imm_j  = {{(XLEN-20){instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
  assign imm_cb = {{(XLEN-8){instr[12]}}, instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
  assign imm_cj = {{(XLEN-11){instr[12]}}, instr[8], instr[10:9], instr[6], instr[7], instr[2],
                   instr[11], instr[5:3], 1'b0};
  assign imm    = is32 ? (instr[3] ? imm_j : imm_b) : (instr[14] ? imm_cb : imm_cj);

  assign is_branch = in_valid && (branch_op != BRANCH_OP_NONE);
  assign is_jal    = in_valid && (jump_op == JUMP_OP_JAL);
  // -RANGE <= imm < 0: every bit from log2(RANGE) up is set
  assign backward = &imm[XLEN-1:$clog2(RANGE)];

  assign taken  = (is_branch && backward) || is_jal;
  assign target = pc + imm;

endmodule
