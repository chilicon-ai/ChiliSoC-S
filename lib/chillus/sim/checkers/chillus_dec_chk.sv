// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_dec_chk (bound into chillus_dec)
//   header Invariants:
//   - at most one hit_<x> is high
//   - valid_<s> == 0 -> every <signal>_<s> is 0 (op_<s> == OP_NONE), per stage
//   - valid_<s> == 1 -> exactly one of illegal_<s>, fault_<s>, or op_<s> an
//     instruction (also: op == OP_ILLEGAL <-> illegal, OP_FETCH_FAULT <-> fault)
//   header Pipeline control:
//   - hold / kill propagate to younger stages (hold[s] -> hold[s-1], same kill)
//   - kill[s] (s >= ex) -> stage s holds a bubble after the edge
//   - hold[s] && !kill[s] -> stage s keeps its instruction (valid, op, pc, instr)
//   - adv_<s-1> -> stage s gets that instruction (no loss / duplication);
//     stage s loads without an advance -> bubble
// -----------------------------------------------------------------------------
module chillus_dec_chk
  import chillus_dec_pkg::*;
#(
  parameter int FW = 1                     // width of fields_ex
) (
  input logic                clk,
  input logic                rst_n,
  input logic [N_STAGES-1:0] hold,
  input logic [N_STAGES-1:0] kill,
  input logic                hit_any,
  input logic [57:0]         hits,
  // id
  input logic                valid_id,
  input op_e                 op_id,
  input logic                illegal_id,
  input logic                fault_id,
  input logic [4:0]          rs1_id,
  input logic [4:0]          rs2_id,
  input logic [XLEN-1:0]     pc_id,
  input logic [31:0]         instr_id,
  // ex
  input logic                valid_ex,
  input op_e                 op_ex,
  input logic                illegal_ex,
  input logic                fault_ex,
  input logic [XLEN-1:0]     pc_ex,
  input logic [31:0]         instr_ex,
  input logic [4:0]          rd_ex,
  input mem_op_e             mem_op_ex,
  input wb_src_e             wb_src_ex,
  input logic [FW-1:0]       fields_ex,   // every other ex output, concatenated
  // wb
  input logic                valid_wb,
  input op_e                 op_wb,
  input logic                illegal_wb,
  input logic                fault_wb,
  input logic [XLEN-1:0]     pc_wb,
  input logic [31:0]         instr_wb,
  input logic [4:0]          rd_wb,
  input mem_op_e             mem_op_wb,
  input wb_src_e             wb_src_wb,
  // advance
  input logic                adv_id,
  input logic                adv_ex,
  input logic                en_ex,
  input logic                en_wb
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  // op is an instruction (not NONE / ILLEGAL / FETCH_FAULT)
  function automatic logic is_instr(op_e op);
    return (op != OP_NONE) && (op != OP_ILLEGAL) && (op != OP_FETCH_FAULT);
  endfunction

  // ---- id ------------------------------------------------------------------
  `CHK($onehot0(hits),
       ("chillus_dec: at most one hit_<x> violated: hits=%h instr_id=%h", hits, instr_id))
  `CHK(hit_any == (hits != '0),
       ("chillus_dec: hit_any == |hit_<x> violated (checker hit list out of date?): hit_any=%b hits=%h", hit_any, hits))
  `CHK(!valid_id |-> op_id == OP_NONE && rs1_id == '0 && rs2_id == '0 && !illegal_id && !fault_id
                     && pc_id == '0 && instr_id == '0,
       ("chillus_dec: valid_id == 0 -> id outputs 0 violated: op=%s rs1=%0d rs2=%0d", op_id.name(), rs1_id, rs2_id))
  `CHK(valid_id |-> $onehot({illegal_id, fault_id, is_instr(op_id)}),
       ("chillus_dec: valid_id -> one of illegal / fault / instruction violated: illegal=%b fault=%b op=%s",
        illegal_id, fault_id, op_id.name()))

  // ---- ex / wb: bubble is all-zero, valid is exactly one kind ---------
  `CHK(!valid_ex |-> op_ex == OP_NONE && !illegal_ex && !fault_ex && pc_ex == '0 && instr_ex == '0
                     && fields_ex == '0,
       ("chillus_dec: valid_ex == 0 -> ex outputs 0 violated: op=%s pc=%h instr=%h fields=%h",
        op_ex.name(), pc_ex, instr_ex, fields_ex))
  `CHK(!valid_wb |-> op_wb == OP_NONE && !illegal_wb && !fault_wb && pc_wb == '0 && instr_wb == '0
                     && rd_wb == '0 && mem_op_wb == MEM_OP_NONE && wb_src_wb == WB_SRC_ALU,
       ("chillus_dec: valid_wb == 0 -> wb outputs 0 violated: op=%s pc=%h instr=%h rd=%0d",
        op_wb.name(), pc_wb, instr_wb, rd_wb))
  `CHK(valid_ex |-> $onehot({illegal_ex, fault_ex, is_instr(op_ex)}) && illegal_ex == (op_ex == OP_ILLEGAL)
                    && fault_ex == (op_ex == OP_FETCH_FAULT),
       ("chillus_dec: valid_ex -> one of illegal / fault / instruction violated: illegal=%b fault=%b op=%s",
        illegal_ex, fault_ex, op_ex.name()))
  `CHK(valid_wb |-> $onehot({illegal_wb, fault_wb, is_instr(op_wb)}) && illegal_wb == (op_wb == OP_ILLEGAL)
                    && fault_wb == (op_wb == OP_FETCH_FAULT),
       ("chillus_dec: valid_wb -> one of illegal / fault / instruction violated: illegal=%b fault=%b op=%s",
        illegal_wb, fault_wb, op_wb.name()))

  // ---- hold / kill ------------------------------------------------------------
  `CHK((hold[N_STAGES-1:1] & ~hold[N_STAGES-2:0]) == '0,
       ("chillus_dec: hold[s] -> hold[s-1] violated: hold=%b", hold))
  `CHK((kill[N_STAGES-1:1] & ~kill[N_STAGES-2:0]) == '0,
       ("chillus_dec: kill[s] -> kill[s-1] violated: kill=%b", kill))
  `CHK(kill[STAGE_EX] |=> !valid_ex,
       ("chillus_dec: kill[ex] -> ex bubble violated: op_ex=%s pc_ex=%h", op_ex.name(), pc_ex))
  `CHK(kill[STAGE_WB] |=> !valid_wb,
       ("chillus_dec: kill[wb] -> wb bubble violated: op_wb=%s pc_wb=%h", op_wb.name(), pc_wb))

  // ---- stage contents: hold keeps, advance moves, otherwise bubble ------------
  `CHK(hold[STAGE_EX] && !kill[STAGE_EX] |=> $stable(valid_ex) && $stable(op_ex) && $stable(pc_ex)
                                             && $stable(instr_ex) && $stable(fields_ex),
       ("chillus_dec: held ex changed: op_ex=%s (was %0d) pc_ex=%h (was %h)",
        op_ex.name(), $past(op_ex), pc_ex, $past(pc_ex)))
  `CHK(hold[STAGE_WB] && !kill[STAGE_WB] |=> $stable(valid_wb) && $stable(op_wb) && $stable(pc_wb),
       ("chillus_dec: held wb changed: op_wb=%s pc_wb=%h (was %h)", op_wb.name(), pc_wb, $past(pc_wb)))
  `CHK(adv_id |=> valid_ex && op_ex == $past(op_id) && pc_ex == $past(pc_id) && instr_ex == $past(instr_id),
       ("chillus_dec: id -> ex advance lost / changed: valid_ex=%b op_ex=%s (id was %0d) pc_ex=%h (id was %h)",
        valid_ex, op_ex.name(), $past(op_id), pc_ex, $past(pc_id)))
  `CHK(adv_ex |=> valid_wb && op_wb == $past(op_ex) && pc_wb == $past(pc_ex) && instr_wb == $past(instr_ex)
                  && rd_wb == $past(rd_ex) && mem_op_wb == $past(mem_op_ex) && wb_src_wb == $past(wb_src_ex),
       ("chillus_dec: ex -> wb advance lost / changed: valid_wb=%b op_wb=%s pc_wb=%h (ex was %h)",
        valid_wb, op_wb.name(), pc_wb, $past(pc_ex)))
  `CHK(en_ex && !adv_id |=> !valid_ex,
       ("chillus_dec: ex loaded without an advance is not a bubble: op_ex=%s", op_ex.name()))
  `CHK(en_wb && !adv_ex |=> !valid_wb,
       ("chillus_dec: wb loaded without an advance is not a bubble: op_wb=%s", op_wb.name()))

  `undef CHK

endmodule

bind chillus_dec chillus_dec_chk #(
  .FW ($bits({is32_ex, imm_ex, rd_ex, rs1_ex, rs2_ex, csr_ex, alu_op_ex, alu_src1_ex, alu_src2_ex,
              branch_op_ex, jump_op_ex, mem_op_ex, mem_size_ex, mem_unsigned_ex, wb_src_ex, csr_op_ex,
              csr_uimm_ex, fence_i_ex, ecall_ex, ebreak_ex, mret_ex, dret_ex, wfi_ex, md_op_ex}))
) u_chk (
  .clk         (clk),
  .rst_n       (rst_n),
  .hold        (hold),
  .kill        (kill),
  .hit_any     (hit_any),
  .hits        ({hit_lui, hit_auipc, hit_jal, hit_jalr, hit_beq, hit_bne, hit_blt, hit_bge,
                 hit_bltu, hit_bgeu, hit_lb, hit_lh, hit_lw, hit_lbu, hit_lhu, hit_sb, hit_sh,
                 hit_sw, hit_addi, hit_slti, hit_sltiu, hit_xori, hit_ori, hit_andi, hit_slli,
                 hit_srli, hit_srai, hit_add, hit_sub, hit_sll, hit_slt, hit_sltu, hit_xor,
                 hit_srl, hit_sra, hit_or, hit_and, hit_fence, hit_ecall, hit_ebreak, hit_mul,
                 hit_mulh, hit_mulhsu, hit_mulhu, hit_div, hit_divu, hit_rem, hit_remu,
                 hit_csrrw, hit_csrrs, hit_csrrc, hit_csrrwi, hit_csrrsi, hit_csrrci,
                 hit_fence_i, hit_mret, hit_wfi, hit_dret}),
  .valid_id    (valid_id),
  .op_id       (op_id),
  .illegal_id  (illegal_id),
  .fault_id    (fault_id),
  .rs1_id      (rs1_id),
  .rs2_id      (rs2_id),
  .pc_id       (pc_id),
  .instr_id    (instr_id),
  .valid_ex    (valid_ex),
  .op_ex       (op_ex),
  .illegal_ex  (illegal_ex),
  .fault_ex    (fault_ex),
  .pc_ex       (pc_ex),
  .instr_ex    (instr_ex),
  .rd_ex       (rd_ex),
  .mem_op_ex   (mem_op_ex),
  .wb_src_ex   (wb_src_ex),
  .fields_ex   ({is32_ex, imm_ex, rd_ex, rs1_ex, rs2_ex, csr_ex, alu_op_ex, alu_src1_ex, alu_src2_ex,
                 branch_op_ex, jump_op_ex, mem_op_ex, mem_size_ex, mem_unsigned_ex, wb_src_ex, csr_op_ex,
                 csr_uimm_ex, fence_i_ex, ecall_ex, ebreak_ex, mret_ex, dret_ex, wfi_ex, md_op_ex}),
  .valid_wb    (valid_wb),
  .op_wb       (op_wb),
  .illegal_wb  (illegal_wb),
  .fault_wb    (fault_wb),
  .pc_wb       (pc_wb),
  .instr_wb    (instr_wb),
  .rd_wb       (rd_wb),
  .mem_op_wb   (mem_op_wb),
  .wb_src_wb   (wb_src_wb),
  .adv_id      (adv_id),
  .adv_ex      (adv_ex),
  .en_ex       (en_ex),
  .en_wb       (en_wb)
);
