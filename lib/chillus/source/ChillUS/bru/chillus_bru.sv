// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_bru
//
// Branch unit for RV32I control transfers (riscv-unprivileged.pdf, Chapter
// 2.5): JAL, JALR and the conditional branches. Combinational and stage-
// agnostic: it resolves the instruction presented on its inputs, in whatever
// single stage the pipeline places it.
//
//   target  JAL, Bxx: pc + imm         JALR: (rs1_data + imm) & ~1   (one adder)
//   cond    from the ALU's compare (chillus_alu cmp_eq / cmp_lt; the decoder
//           sets SLT / SLTU for the less-than branches):
//           BEQ ==  BNE !=  BLT / BGE signed <  / >=  BLTU / BGEU unsigned
//   link    pc + 4 (pc + 2 for a 16-bit instruction): rd value of JAL / JALR,
//           and the fall-through after a mispredicted branch
//   alt_target  conditional branch: the address the front end did NOT
//           follow, predicted ? link : pc + imm (the target adder; its base
//           mux selects pc for a conditional branch, from the registered
//           jump_op); a mispredicted branch always redirects there, so the
//           fast redirect address does not wait for the compare
//   cond_branch  branch_op != NONE (decode only, not gated by in_valid)
//   cond_flip    a conditional branch whose condition differs from its static
//           prediction (decode and compare, not gated by in_valid: the
//           fast-redirect address select, chillus_ctrl fast_cand)
//
// Outputs (all 0 when in_valid is low or the instruction is not a jump or
// branch; at most one of jump / no_jump / target_misaligned is high):
//   jump               control transfers to target: JAL, JALR, taken branch.
//   no_jump            a conditional branch resolved not taken.
//   target_misaligned  the transfer would happen, but target is not aligned to
//                      IALIGN: instruction-address-misaligned exception,
//                      reported on this instruction (no jump, no rd write).
//                      Never for a not-taken branch; impossible with
//                      IALIGN = 16 (C extension).
//   ras_push / ras_pop return-address-stack hints from rd / rs1 (x1, x5 are
//                      link registers), Table 3; valid with jump.
//   predicted          the front end predicted this instruction taken and
//                      already fetches from target (static BTFN, the same
//                      rule as chillus_bp: backward branch within
//                      RANGE, or JAL). The
//                      pipeline redirects only on a misprediction:
//                      jump && !predicted (to target) or no_jump && predicted
//                      (to link). Independent of the condition.
// An access fault at the target is reported on the target instruction, not
// here. imm is the decoder's sign-extended B / J / I immediate.
//
// Timing   : combinational, no state. For a conditional branch alt_target
//            depends on pc / imm / is32 / jump_op only (rs1_data reaches the
//            adder through the base mux, which selects pc; no compare);
//            cond_branch on branch_op only.
// Debug    : base / sum show the adder; cmp_eq / cmp_lt the ALU compare; cond the
//            branch condition; predicted the front end's direction.
//            JALR target odd? It cannot be: bit 0 is
//            cleared. Wrong link: check is32.
// -----------------------------------------------------------------------------
module chillus_bru
  import chillus_dec_pkg::*;
#(
  parameter int XLEN   = 32,                   // address / register width
  parameter int IALIGN = 32                    // 32 without C, 16 with C (Chapter 2.2)
) (
  // instruction (decoder indications of its stage)
  input  logic              in_valid,          // real instruction; 0 when killed or a bubble
  input  branch_op_e        branch_op,
  input  jump_op_e          jump_op,
  input  logic              is32,              // 32-bit instruction (link pc + 4, else pc + 2)
  input  logic [4:0]        rd,                // RAS hints only
  input  logic [4:0]        rs1,               // RAS hints only
  // operand values
  input  logic [XLEN-1:0]   pc,
  input  logic [XLEN-1:0]   rs1_data,          // after forwarding (JALR base)
  input  logic              cmp_eq,            // chillus_alu: rs1_data == rs2_data
  input  logic              cmp_lt,            // chillus_alu: rs1_data < rs2_data (signed / unsigned per branch_op)
  input  logic [XLEN-1:0]   imm,
  // results
  output logic              jump,
  output logic              no_jump,
  output logic              target_misaligned,
  output logic [XLEN-1:0]   target,
  output logic [XLEN-1:0]   link,
  output logic [XLEN-1:0]   alt_target,        // conditional branch: predicted ? link : pc + imm
  output logic              cond_branch,       // a conditional branch is presented (not gated by in_valid)
  output logic              cond_flip,         // cond_branch && cond != predicted direction (not gated by in_valid)
  output logic              ras_push,
  output logic              ras_pop,
  output logic              predicted
);

  localparam logic [XLEN-1:0] ALIGN_MASK = XLEN'(IALIGN / 8 - 1);  // target bits that must be 0
  localparam int              RANGE      = 128;  // chillus_bp.RANGE: max backward distance predicted taken, bytes

  logic            is_branch;     // conditional branch
  logic            is_jump;       // JAL or JALR
  logic            is_jalr;
  logic [XLEN-1:0] base;          // pc, or rs1_data for JALR
  logic [XLEN-1:0] sum;           // base + imm
  logic            cond;          // branch condition of branch_op
  logic            transfer;      // control would transfer (jump, or taken branch)
  logic            unaligned;     // target & ALIGN_MASK != 0
  logic [XLEN-1:0] ilen;          // instruction length in bytes: 4 or 2
  logic            rd_link;       // rd is x1 or x5
  logic            rs1_link;      // rs1 is x1 or x5
  logic            backward;      // -RANGE <= imm < 0 (chillus_bp.backward)
  logic            pred_dir;      // the static direction of a conditional branch (predicted, ungated)

  assign is_branch = in_valid && (branch_op != BRANCH_OP_NONE);
  assign is_jump   = in_valid && (jump_op != JUMP_OP_NONE);
  assign is_jalr   = jump_op == JUMP_OP_JALR;

  // ---------------------------------------------------------------------------
  // Target adder
  // ---------------------------------------------------------------------------
  assign base   = is_jalr ? rs1_data : pc;
  assign sum    = base + imm;
  assign target = is_jalr ? {sum[XLEN-1:1], 1'b0} : sum;

  // ---------------------------------------------------------------------------
  // Branch condition (compare in chillus_alu)
  // ---------------------------------------------------------------------------
  always_comb begin
    case (branch_op)
      BRANCH_OP_EQ:   cond = cmp_eq;
      BRANCH_OP_NE:   cond = !cmp_eq;
      BRANCH_OP_LT:   cond = cmp_lt;
      BRANCH_OP_GE:   cond = !cmp_lt;
      BRANCH_OP_LTU:  cond = cmp_lt;
      BRANCH_OP_GEU:  cond = !cmp_lt;
      BRANCH_OP_NONE: cond = 1'b0;
      default:        cond = 1'b0;
    endcase
  end

  // ---------------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------------
  assign transfer          = is_jump || (is_branch && cond);
  assign unaligned         = (target & ALIGN_MASK) != '0;
  assign jump              = transfer && !unaligned;
  assign target_misaligned = transfer && unaligned;
  assign no_jump           = is_branch && !cond;

  // Static BTFN direction the front end used (chillus_bp): a backward branch
  // within RANGE, or JAL. Low for JALR, non-control instructions and
  // in_valid low.
  assign backward  = &imm[XLEN-1:$clog2(RANGE)];
  assign predicted = (is_branch && backward) || (is_jump && !is_jalr);
  assign pred_dir  = backward;

  // ---------------------------------------------------------------------------
  // Link address and return-address-stack hints (Table 3)
  // ---------------------------------------------------------------------------
  assign ilen = is32 ? unsigned'(XLEN'(4)) : unsigned'(XLEN'(2));
  assign link = pc + ilen;
  // ---------------------------------------------------------------------------
  // Fast redirect address of a conditional branch (chillus_ctrl)
  // ---------------------------------------------------------------------------
  // sum is pc + imm for a conditional branch (is_jalr low)
  assign cond_branch = (branch_op != BRANCH_OP_NONE);
  assign alt_target  = pred_dir ? link : sum;
  assign cond_flip   = cond_branch && (cond != pred_dir);

  assign rd_link  = (rd == 5'd1) || (rd == 5'd5);
  assign rs1_link = (rs1 == 5'd1) || (rs1 == 5'd5);

  // JAL: push when rd is a link register. JALR:
  //   rd link, rs1 not          push      rd not, rs1 link       pop
  //   both, rd != rs1           pop+push  both, rd == rs1        push
  assign ras_push = jump && is_jump && rd_link;    // never for a branch (no rd)
  assign ras_pop  = jump && is_jalr && rs1_link && (!rd_link || (rd != rs1));

endmodule
