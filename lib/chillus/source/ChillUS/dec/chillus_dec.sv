// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChillU-S :: chillus_dec
//
// ChillU-S instruction decoder. Decodes the IFU instruction into an op name,
// register fields, the immediate operand and per-instruction indications, and
// carries them down the pipeline stages (stall / flush per stage).
//
// Stages : id (0, decode), ex (1), wb (2)
// ISA    : RV32, RV32I, M, Zicsr, Zifencei, Sm (58 instructions)
//
// Outputs per stage (port <signal>_<stage>):
//   id : valid op imm rs1 rs2 branch_op jump_op
//   ex : valid op illegal fault fault_hi pc instr is32 imm rd rs1 rs2 csr
//        alu_op alu_src1 alu_src2 branch_op jump_op mem_op mem_size
//        mem_unsigned wb_src csr_op csr_uimm fence_i ecall ebreak mret dret wfi
//        md_op
//   wb : valid op illegal fault pc instr rd mem_op wb_src
//
// Pipeline control (bit s = stage s, see STAGE_* in the package)
//   hold[s] = stall[s] || hold[s+1] : a stall holds its stage and all
//                                     younger (lower index) stages.
//   kill[s] = flush[s] || kill[s+1] : a flush kills its stage and all
//                                     younger stages.
//   Stage s >= 1 loads when !hold[s] || kill[s]: the stage s-1 contents
//   if that instruction advances (adv_<s-1>), otherwise a bubble.
//   ifu_accept = !hold[0] || kill[0]: a killed id instruction is dropped.
//
// Timing
//   id outputs are combinational from ifu_*; later stages are registers.
//   No output except ifu_accept depends combinationally on stall / flush;
//   a stall or flush takes effect at the next clock edge.
//
// Invariants
//   valid_<s> == 0 -> every <signal>_<s> is 0 (op_<s> == OP_NONE).
//   valid_<s> == 1 -> exactly one of: illegal_<s>, fault_<s>, or op_<s> is
//                     an instruction.
//   fault_hi_<s> -> fault_<s>.
//   At most one hit_<x> is high (no two encodings
//   overlap).
//
// Debug
//   op_<stage> names the instruction in each stage.
//   Wrong op in id: compare ifu_instr with the bit pattern above hit_<x>.
//   Instruction lost or duplicated between stages: check adv_<s>, en_<s>,
//   hold and kill at that clock edge.
//   Wrong indication / field: the lists below show which instructions set
//   each value; edit the JSON spec, not this file.
// -----------------------------------------------------------------------------
module chillus_dec
  import chillus_dec_pkg::*;
(
  input  logic                clk,
  input  logic                rst_n,            // async, active-low
  // IFU (valid/accept, lib/BaseChiliSV/doc/valid_accept_handshake.md)
  input  logic                ifu_valid,
  output logic                ifu_accept,
  input  logic [31:0]         ifu_instr,        // 32-bit form: 16-bit instructions expanded by chillus_rvc
  input  logic [31:0]         ifu_raw,          // as fetched (16-bit in [15:0]): carried as instr_<stage>
  input  logic [XLEN-1:0]     ifu_pc,
  input  logic                ifu_is32,         // 16-bit instruction (link pc + 2)
  input  logic                ifu_fault,        // fetch error: not decoded, reported on fault_<stage>
  input  logic                ifu_fault_hi,     // with ifu_fault: only the second halfword (at pc + 2) faulted
  // pipeline control, bit s = stage s
  input  logic [N_STAGES-1:0] stall,            // hold stage s (and younger stages)
  input  logic [N_STAGES-1:0] flush,            // kill stage s (and younger stages)
  output logic [N_STAGES-1:0] hold,             // effective hold per stage
  output logic [N_STAGES-1:0] kill,             // effective kill per stage
  // stage id
  output logic                valid_id,
  output op_e                 op_id,
  output logic [XLEN-1:0]     imm_id,
  output logic [4:0]          rs1_id,
  output logic [4:0]          rs2_id,
  output branch_op_e          branch_op_id,
  output jump_op_e            jump_op_id,
  // stage ex
  output logic                valid_ex,
  output op_e                 op_ex,
  output logic                illegal_ex,
  output logic                fault_ex,
  output logic                fault_hi_ex,
  output logic [XLEN-1:0]     pc_ex,
  output logic [31:0]         instr_ex,
  output logic                is32_ex,
  output logic [XLEN-1:0]     imm_ex,
  output logic [4:0]          rd_ex,
  output logic [4:0]          rs1_ex,
  output logic [4:0]          rs2_ex,
  output logic [11:0]         csr_ex,
  output alu_op_e             alu_op_ex,
  output alu_src1_e           alu_src1_ex,
  output alu_src2_e           alu_src2_ex,
  output branch_op_e          branch_op_ex,
  output jump_op_e            jump_op_ex,
  output mem_op_e             mem_op_ex,
  output mem_size_e           mem_size_ex,
  output logic                mem_unsigned_ex,
  output wb_src_e             wb_src_ex,
  output csr_op_e             csr_op_ex,
  output logic                csr_uimm_ex,
  output logic                fence_i_ex,
  output logic                ecall_ex,
  output logic                ebreak_ex,
  output logic                mret_ex,
  output logic                dret_ex,
  output logic                wfi_ex,
  output md_op_e              md_op_ex,
  // stage wb
  output logic                valid_wb,
  output op_e                 op_wb,
  output logic                illegal_wb,
  output logic                fault_wb,
  output logic [XLEN-1:0]     pc_wb,
  output logic [31:0]         instr_wb,
  output logic [4:0]          rd_wb,
  output mem_op_e             mem_op_wb,
  output wb_src_e             wb_src_wb
);

  logic                          dec_en;             // instruction without fetch error presented
  logic                          hit_any;            // some hit_<x> is high
  logic                          hit_lui;
  logic                          hit_auipc;
  logic                          hit_jal;
  logic                          hit_jalr;
  logic                          hit_beq;
  logic                          hit_bne;
  logic                          hit_blt;
  logic                          hit_bge;
  logic                          hit_bltu;
  logic                          hit_bgeu;
  logic                          hit_lb;
  logic                          hit_lh;
  logic                          hit_lw;
  logic                          hit_lbu;
  logic                          hit_lhu;
  logic                          hit_sb;
  logic                          hit_sh;
  logic                          hit_sw;
  logic                          hit_addi;
  logic                          hit_slti;
  logic                          hit_sltiu;
  logic                          hit_xori;
  logic                          hit_ori;
  logic                          hit_andi;
  logic                          hit_slli;
  logic                          hit_srli;
  logic                          hit_srai;
  logic                          hit_add;
  logic                          hit_sub;
  logic                          hit_sll;
  logic                          hit_slt;
  logic                          hit_sltu;
  logic                          hit_xor;
  logic                          hit_srl;
  logic                          hit_sra;
  logic                          hit_or;
  logic                          hit_and;
  logic                          hit_fence;
  logic                          hit_ecall;
  logic                          hit_ebreak;
  logic                          hit_mul;
  logic                          hit_mulh;
  logic                          hit_mulhsu;
  logic                          hit_mulhu;
  logic                          hit_div;
  logic                          hit_divu;
  logic                          hit_rem;
  logic                          hit_remu;
  logic                          hit_csrrw;
  logic                          hit_csrrs;
  logic                          hit_csrrc;
  logic                          hit_csrrwi;
  logic                          hit_csrrsi;
  logic                          hit_csrrci;
  logic                          hit_fence_i;
  logic                          hit_mret;
  logic                          hit_wfi;
  logic                          hit_dret;
  logic                          use_rd;             // instruction uses field rd
  logic                          use_rs1;            // instruction uses field rs1
  logic                          use_rs2;            // instruction uses field rs2
  logic                          use_csr;            // instruction uses field csr
  logic                          use_imm_i;          // instruction operand is immediate imm_i
  logic [XLEN-1:0]               imm_i_val;          // I-immediate (loads, JALR, OP-IMM).
  logic                          use_imm_s;          // instruction operand is immediate imm_s
  logic [XLEN-1:0]               imm_s_val;          // S-immediate (stores).
  logic                          use_imm_b;          // instruction operand is immediate imm_b
  logic [XLEN-1:0]               imm_b_val;          // B-immediate (branch offset, multiple of 2).
  logic                          use_imm_u;          // instruction operand is immediate imm_u
  logic [XLEN-1:0]               imm_u_val;          // U-immediate (LUI, AUIPC), low 12 bits zero.
  logic                          use_imm_j;          // instruction operand is immediate imm_j
  logic [XLEN-1:0]               imm_j_val;          // J-immediate (JAL offset, multiple of 2).
  logic                          use_shamt;          // instruction operand is immediate shamt
  logic [XLEN-1:0]               shamt_val;          // RV32 shift amount (SLLI / SRLI / SRAI), zero-extended.
  logic                          use_uimm;           // instruction operand is immediate uimm
  logic [XLEN-1:0]               uimm_val;           // Zicsr 5-bit unsigned immediate (CSRR*I), zero-extended.
  logic                          adv_id;             // instruction in id moves to ex
  logic                          adv_ex;             // instruction in ex moves to wb
  logic                          en_ex;              // stage ex registers load
  logic                          en_wb;              // stage wb registers load
  logic                          valid_ex_d;
  logic                          valid_wb_d;
  logic [$bits(op_e)-1:0]        op_ex_d;
  logic [$bits(op_e)-1:0]        op_ex_q;            // register bits of op_ex
  logic [$bits(op_e)-1:0]        op_wb_d;
  logic [$bits(op_e)-1:0]        op_wb_q;            // register bits of op_wb
  logic                          illegal_id;
  logic                          illegal_ex_d;
  logic                          illegal_wb_d;
  logic                          fault_id;
  logic                          fault_ex_d;
  logic                          fault_wb_d;
  logic                          fault_hi_id;
  logic                          fault_hi_ex_d;
  logic [XLEN-1:0]               pc_id;
  logic [XLEN-1:0]               pc_ex_d;
  logic [XLEN-1:0]               pc_wb_d;
  logic [31:0]                   instr_id;
  logic [31:0]                   instr_ex_d;
  logic [31:0]                   instr_wb_d;
  logic                          is32_id;
  logic                          is32_ex_d;
  logic [XLEN-1:0]               imm_ex_d;
  logic [4:0]                    rd_id;
  logic [4:0]                    rd_ex_d;
  logic [4:0]                    rd_wb_d;
  logic [4:0]                    rs1_ex_d;
  logic [4:0]                    rs2_ex_d;
  logic [11:0]                   csr_id;
  logic [11:0]                   csr_ex_d;
  alu_op_e                       alu_op_id;
  logic [$bits(alu_op_e)-1:0]    alu_op_ex_d;
  logic [$bits(alu_op_e)-1:0]    alu_op_ex_q;        // register bits of alu_op_ex
  alu_src1_e                     alu_src1_id;
  logic [$bits(alu_src1_e)-1:0]  alu_src1_ex_d;
  logic [$bits(alu_src1_e)-1:0]  alu_src1_ex_q;      // register bits of alu_src1_ex
  alu_src2_e                     alu_src2_id;
  logic [$bits(alu_src2_e)-1:0]  alu_src2_ex_d;
  logic [$bits(alu_src2_e)-1:0]  alu_src2_ex_q;      // register bits of alu_src2_ex
  logic [$bits(branch_op_e)-1:0] branch_op_ex_d;
  logic [$bits(branch_op_e)-1:0] branch_op_ex_q;     // register bits of branch_op_ex
  logic [$bits(jump_op_e)-1:0]   jump_op_ex_d;
  logic [$bits(jump_op_e)-1:0]   jump_op_ex_q;       // register bits of jump_op_ex
  mem_op_e                       mem_op_id;
  logic [$bits(mem_op_e)-1:0]    mem_op_ex_d;
  logic [$bits(mem_op_e)-1:0]    mem_op_ex_q;        // register bits of mem_op_ex
  logic [$bits(mem_op_e)-1:0]    mem_op_wb_d;
  logic [$bits(mem_op_e)-1:0]    mem_op_wb_q;        // register bits of mem_op_wb
  mem_size_e                     mem_size_id;
  logic [$bits(mem_size_e)-1:0]  mem_size_ex_d;
  logic [$bits(mem_size_e)-1:0]  mem_size_ex_q;      // register bits of mem_size_ex
  logic                          mem_unsigned_id;
  logic                          mem_unsigned_ex_d;
  wb_src_e                       wb_src_id;
  logic [$bits(wb_src_e)-1:0]    wb_src_ex_d;
  logic [$bits(wb_src_e)-1:0]    wb_src_ex_q;        // register bits of wb_src_ex
  logic [$bits(wb_src_e)-1:0]    wb_src_wb_d;
  logic [$bits(wb_src_e)-1:0]    wb_src_wb_q;        // register bits of wb_src_wb
  csr_op_e                       csr_op_id;
  logic [$bits(csr_op_e)-1:0]    csr_op_ex_d;
  logic [$bits(csr_op_e)-1:0]    csr_op_ex_q;        // register bits of csr_op_ex
  logic                          csr_uimm_id;
  logic                          csr_uimm_ex_d;
  logic                          fence_i_id;
  logic                          fence_i_ex_d;
  logic                          ecall_id;
  logic                          ecall_ex_d;
  logic                          ebreak_id;
  logic                          ebreak_ex_d;
  logic                          mret_id;
  logic                          mret_ex_d;
  logic                          dret_id;
  logic                          dret_ex_d;
  logic                          wfi_id;
  logic                          wfi_ex_d;
  md_op_e                        md_op_id;
  logic [$bits(md_op_e)-1:0]     md_op_ex_d;
  logic [$bits(md_op_e)-1:0]     md_op_ex_q;         // register bits of md_op_ex

  // ===========================================================================
  // Pipeline control
  // ===========================================================================
  assign hold[STAGE_WB] = stall[STAGE_WB];
  assign hold[STAGE_EX] = stall[STAGE_EX] || hold[STAGE_WB];
  assign hold[STAGE_ID] = stall[STAGE_ID] || hold[STAGE_EX];
  assign kill[STAGE_WB] = flush[STAGE_WB];
  assign kill[STAGE_EX] = flush[STAGE_EX] || kill[STAGE_WB];
  assign kill[STAGE_ID] = flush[STAGE_ID] || kill[STAGE_EX];

  assign ifu_accept = !hold[STAGE_ID] || kill[STAGE_ID];

  assign adv_id = valid_id && !hold[STAGE_ID] && !kill[STAGE_ID];
  assign adv_ex = valid_ex && !hold[STAGE_EX] && !kill[STAGE_EX];
  assign en_ex  = !hold[STAGE_EX] || kill[STAGE_EX];
  assign en_wb  = !hold[STAGE_WB] || kill[STAGE_WB];

  // ===========================================================================
  // Stage id: decode (combinational from ifu_*)
  // ===========================================================================
  // 16-bit instructions arrive expanded (chillus_rvc); an invalid one
  // arrives as 0, which matches no instruction (illegal).
  assign dec_en = ifu_valid && !ifu_fault;

  // hit_<x>: (ifu_instr & MASK) == MATCH. Comment: name [extension] and the
  // Chapter 36 bit pattern, inst[31] first (fixed bits, else field names).

  // LUI [RV32I] imm_u rd 0110111
  assign hit_lui     = dec_en && ((ifu_instr & 32'h0000_007F) == 32'h0000_0037);
  // AUIPC [RV32I] imm_u rd 0010111
  assign hit_auipc   = dec_en && ((ifu_instr & 32'h0000_007F) == 32'h0000_0017);
  // JAL [RV32I] imm_j rd 1101111
  assign hit_jal     = dec_en && ((ifu_instr & 32'h0000_007F) == 32'h0000_006F);
  // JALR [RV32I] imm_i rs1 000 rd 1100111
  assign hit_jalr    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_0067);
  // BEQ [RV32I] imm_b rs2 rs1 000 imm_b 1100011
  assign hit_beq     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_0063);
  // BNE [RV32I] imm_b rs2 rs1 001 imm_b 1100011
  assign hit_bne     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_1063);
  // BLT [RV32I] imm_b rs2 rs1 100 imm_b 1100011
  assign hit_blt     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_4063);
  // BGE [RV32I] imm_b rs2 rs1 101 imm_b 1100011
  assign hit_bge     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_5063);
  // BLTU [RV32I] imm_b rs2 rs1 110 imm_b 1100011
  assign hit_bltu    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_6063);
  // BGEU [RV32I] imm_b rs2 rs1 111 imm_b 1100011
  assign hit_bgeu    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_7063);
  // LB [RV32I] imm_i rs1 000 rd 0000011
  assign hit_lb      = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_0003);
  // LH [RV32I] imm_i rs1 001 rd 0000011
  assign hit_lh      = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_1003);
  // LW [RV32I] imm_i rs1 010 rd 0000011
  assign hit_lw      = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_2003);
  // LBU [RV32I] imm_i rs1 100 rd 0000011
  assign hit_lbu     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_4003);
  // LHU [RV32I] imm_i rs1 101 rd 0000011
  assign hit_lhu     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_5003);
  // SB [RV32I] imm_s rs2 rs1 000 imm_s 0100011
  assign hit_sb      = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_0023);
  // SH [RV32I] imm_s rs2 rs1 001 imm_s 0100011
  assign hit_sh      = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_1023);
  // SW [RV32I] imm_s rs2 rs1 010 imm_s 0100011
  assign hit_sw      = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_2023);
  // ADDI [RV32I] imm_i rs1 000 rd 0010011
  // ADDI x0, x0, 0 is the canonical NOP; other ADDI with rd = x0 are HINTs.
  // Both decode as ADDI.
  assign hit_addi    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_0013);
  // SLTI [RV32I] imm_i rs1 010 rd 0010011
  assign hit_slti    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_2013);
  // SLTIU [RV32I] imm_i rs1 011 rd 0010011
  assign hit_sltiu   = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_3013);
  // XORI [RV32I] imm_i rs1 100 rd 0010011
  assign hit_xori    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_4013);
  // ORI [RV32I] imm_i rs1 110 rd 0010011
  assign hit_ori     = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_6013);
  // ANDI [RV32I] imm_i rs1 111 rd 0010011
  assign hit_andi    = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_7013);
  // SLLI [RV32I] 0000000 shamt rs1 001 rd 0010011
  assign hit_slli    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_1013);
  // SRLI [RV32I] 0000000 shamt rs1 101 rd 0010011
  assign hit_srli    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_5013);
  // SRAI [RV32I] 0100000 shamt rs1 101 rd 0010011
  assign hit_srai    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h4000_5013);
  // ADD [RV32I] 0000000 rs2 rs1 000 rd 0110011
  assign hit_add     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_0033);
  // SUB [RV32I] 0100000 rs2 rs1 000 rd 0110011
  assign hit_sub     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h4000_0033);
  // SLL [RV32I] 0000000 rs2 rs1 001 rd 0110011
  assign hit_sll     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_1033);
  // SLT [RV32I] 0000000 rs2 rs1 010 rd 0110011
  assign hit_slt     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_2033);
  // SLTU [RV32I] 0000000 rs2 rs1 011 rd 0110011
  assign hit_sltu    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_3033);
  // XOR [RV32I] 0000000 rs2 rs1 100 rd 0110011
  assign hit_xor     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_4033);
  // SRL [RV32I] 0000000 rs2 rs1 101 rd 0110011
  assign hit_srl     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_5033);
  // SRA [RV32I] 0100000 rs2 rs1 101 rd 0110011
  assign hit_sra     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h4000_5033);
  // OR [RV32I] 0000000 rs2 rs1 110 rd 0110011
  assign hit_or      = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_6033);
  // AND [RV32I] 0000000 rs2 rs1 111 rd 0110011
  assign hit_and     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0000_7033);
  // FENCE [RV32I] fm pred succ rs1 000 rd 0001111
  // A nop: the data MSS completes accesses in order (one outstanding), so no
  // request is needed.
  // FENCE.TSO (fm = 1000, pred = succ = RW) and PAUSE (pred = W, succ = 0) are
  // FENCE encodings and decode as FENCE.
  // rs1 / rd are reserved; base implementations ignore them (Chapter 2.7).
  assign hit_fence   = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_000F);
  // ECALL [RV32I] 000000000000 00000 000 00000 1110011
  assign hit_ecall   = dec_en && ((ifu_instr & 32'hFFFF_FFFF) == 32'h0000_0073);
  // EBREAK [RV32I] 000000000001 00000 000 00000 1110011
  assign hit_ebreak  = dec_en && ((ifu_instr & 32'hFFFF_FFFF) == 32'h0010_0073);
  // MUL [M] 0000001 rs2 rs1 000 rd 0110011
  assign hit_mul     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_0033);
  // MULH [M] 0000001 rs2 rs1 001 rd 0110011
  assign hit_mulh    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_1033);
  // MULHSU [M] 0000001 rs2 rs1 010 rd 0110011
  assign hit_mulhsu  = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_2033);
  // MULHU [M] 0000001 rs2 rs1 011 rd 0110011
  assign hit_mulhu   = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_3033);
  // DIV [M] 0000001 rs2 rs1 100 rd 0110011
  assign hit_div     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_4033);
  // DIVU [M] 0000001 rs2 rs1 101 rd 0110011
  assign hit_divu    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_5033);
  // REM [M] 0000001 rs2 rs1 110 rd 0110011
  assign hit_rem     = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_6033);
  // REMU [M] 0000001 rs2 rs1 111 rd 0110011
  assign hit_remu    = dec_en && ((ifu_instr & 32'hFE00_707F) == 32'h0200_7033);
  // CSRRW [Zicsr] csr rs1 001 rd 1110011
  assign hit_csrrw   = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_1073);
  // CSRRS [Zicsr] csr rs1 010 rd 1110011
  assign hit_csrrs   = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_2073);
  // CSRRC [Zicsr] csr rs1 011 rd 1110011
  assign hit_csrrc   = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_3073);
  // CSRRWI [Zicsr] csr uimm 101 rd 1110011
  assign hit_csrrwi  = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_5073);
  // CSRRSI [Zicsr] csr uimm 110 rd 1110011
  assign hit_csrrsi  = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_6073);
  // CSRRCI [Zicsr] csr uimm 111 rd 1110011
  assign hit_csrrci  = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_7073);
  // FENCE_I [Zifencei] funct12 rs1 001 rd 0001111
  // imm[11:0], rs1 and rd are reserved; base implementations ignore them
  // (Chapter 5).
  assign hit_fence_i = dec_en && ((ifu_instr & 32'h0000_707F) == 32'h0000_100F);
  // MRET [Sm] 001100000010 00000 000 00000 1110011
  assign hit_mret    = dec_en && ((ifu_instr & 32'hFFFF_FFFF) == 32'h3020_0073);
  // WFI [Sm] 000100000101 00000 000 00000 1110011
  assign hit_wfi     = dec_en && ((ifu_instr & 32'hFFFF_FFFF) == 32'h1050_0073);
  // DRET [Sm] 011110110010 00000 000 00000 1110011
  assign hit_dret    = dec_en && ((ifu_instr & 32'hFFFF_FFFF) == 32'h7B20_0073);

  assign hit_any = hit_lui || hit_auipc || hit_jal || hit_jalr || hit_beq ||
                   hit_bne || hit_blt || hit_bge || hit_bltu || hit_bgeu ||
                   hit_lb || hit_lh || hit_lw || hit_lbu || hit_lhu ||
                   hit_sb || hit_sh || hit_sw || hit_addi || hit_slti ||
                   hit_sltiu || hit_xori || hit_ori || hit_andi || hit_slli ||
                   hit_srli || hit_srai || hit_add || hit_sub || hit_sll ||
                   hit_slt || hit_sltu || hit_xor || hit_srl || hit_sra ||
                   hit_or || hit_and || hit_fence || hit_ecall || hit_ebreak ||
                   hit_mul || hit_mulh || hit_mulhsu || hit_mulhu || hit_div ||
                   hit_divu || hit_rem || hit_remu || hit_csrrw || hit_csrrs ||
                   hit_csrrc || hit_csrrwi || hit_csrrsi || hit_csrrci ||
                   hit_fence_i || hit_mret || hit_wfi || hit_dret;

  // ---------------------------------------------------------------------------
  // Built-ins
  // ---------------------------------------------------------------------------
  assign valid_id    = ifu_valid;
  assign fault_id    = ifu_valid && ifu_fault;
  assign fault_hi_id = ifu_valid && ifu_fault && ifu_fault_hi;
  assign illegal_id  = ifu_valid && !ifu_fault && !hit_any;
  assign pc_id       = ifu_valid ? ifu_pc : '0;
  assign instr_id    = ifu_valid ? ifu_raw : '0;
  assign is32_id     = ifu_valid && ifu_is32;

  always_comb begin
    op_id = OP_NONE;
    if (ifu_valid)   op_id = OP_ILLEGAL;  // replaced below by a hit or a fetch fault
    if (fault_id)    op_id = OP_FETCH_FAULT;
    if (hit_lui)     op_id = OP_LUI;
    if (hit_auipc)   op_id = OP_AUIPC;
    if (hit_jal)     op_id = OP_JAL;
    if (hit_jalr)    op_id = OP_JALR;
    if (hit_beq)     op_id = OP_BEQ;
    if (hit_bne)     op_id = OP_BNE;
    if (hit_blt)     op_id = OP_BLT;
    if (hit_bge)     op_id = OP_BGE;
    if (hit_bltu)    op_id = OP_BLTU;
    if (hit_bgeu)    op_id = OP_BGEU;
    if (hit_lb)      op_id = OP_LB;
    if (hit_lh)      op_id = OP_LH;
    if (hit_lw)      op_id = OP_LW;
    if (hit_lbu)     op_id = OP_LBU;
    if (hit_lhu)     op_id = OP_LHU;
    if (hit_sb)      op_id = OP_SB;
    if (hit_sh)      op_id = OP_SH;
    if (hit_sw)      op_id = OP_SW;
    if (hit_addi)    op_id = OP_ADDI;
    if (hit_slti)    op_id = OP_SLTI;
    if (hit_sltiu)   op_id = OP_SLTIU;
    if (hit_xori)    op_id = OP_XORI;
    if (hit_ori)     op_id = OP_ORI;
    if (hit_andi)    op_id = OP_ANDI;
    if (hit_slli)    op_id = OP_SLLI;
    if (hit_srli)    op_id = OP_SRLI;
    if (hit_srai)    op_id = OP_SRAI;
    if (hit_add)     op_id = OP_ADD;
    if (hit_sub)     op_id = OP_SUB;
    if (hit_sll)     op_id = OP_SLL;
    if (hit_slt)     op_id = OP_SLT;
    if (hit_sltu)    op_id = OP_SLTU;
    if (hit_xor)     op_id = OP_XOR;
    if (hit_srl)     op_id = OP_SRL;
    if (hit_sra)     op_id = OP_SRA;
    if (hit_or)      op_id = OP_OR;
    if (hit_and)     op_id = OP_AND;
    if (hit_fence)   op_id = OP_FENCE;
    if (hit_ecall)   op_id = OP_ECALL;
    if (hit_ebreak)  op_id = OP_EBREAK;
    if (hit_mul)     op_id = OP_MUL;
    if (hit_mulh)    op_id = OP_MULH;
    if (hit_mulhsu)  op_id = OP_MULHSU;
    if (hit_mulhu)   op_id = OP_MULHU;
    if (hit_div)     op_id = OP_DIV;
    if (hit_divu)    op_id = OP_DIVU;
    if (hit_rem)     op_id = OP_REM;
    if (hit_remu)    op_id = OP_REMU;
    if (hit_csrrw)   op_id = OP_CSRRW;
    if (hit_csrrs)   op_id = OP_CSRRS;
    if (hit_csrrc)   op_id = OP_CSRRC;
    if (hit_csrrwi)  op_id = OP_CSRRWI;
    if (hit_csrrsi)  op_id = OP_CSRRSI;
    if (hit_csrrci)  op_id = OP_CSRRCI;
    if (hit_fence_i) op_id = OP_FENCE_I;
    if (hit_mret)    op_id = OP_MRET;
    if (hit_wfi)     op_id = OP_WFI;
    if (hit_dret)    op_id = OP_DRET;
  end

  // ---------------------------------------------------------------------------
  // Fields: inst[hi:lo] when the instruction uses the field, else 0
  // ---------------------------------------------------------------------------
  assign use_rd = hit_lui || hit_auipc || hit_jal || hit_jalr || hit_lb ||
                  hit_lh || hit_lw || hit_lbu || hit_lhu || hit_addi ||
                  hit_slti || hit_sltiu || hit_xori || hit_ori || hit_andi ||
                  hit_slli || hit_srli || hit_srai || hit_add || hit_sub ||
                  hit_sll || hit_slt || hit_sltu || hit_xor || hit_srl ||
                  hit_sra || hit_or || hit_and || hit_ecall || hit_ebreak ||
                  hit_mul || hit_mulh || hit_mulhsu || hit_mulhu || hit_div ||
                  hit_divu || hit_rem || hit_remu || hit_csrrw || hit_csrrs ||
                  hit_csrrc || hit_csrrwi || hit_csrrsi || hit_csrrci ||
                  hit_mret || hit_wfi || hit_dret;
  assign rd_id = use_rd ? ifu_instr[11:7] : '0;

  assign use_rs1 = hit_jalr || hit_beq || hit_bne || hit_blt || hit_bge ||
                   hit_bltu || hit_bgeu || hit_lb || hit_lh || hit_lw ||
                   hit_lbu || hit_lhu || hit_sb || hit_sh || hit_sw ||
                   hit_addi || hit_slti || hit_sltiu || hit_xori || hit_ori ||
                   hit_andi || hit_slli || hit_srli || hit_srai || hit_add ||
                   hit_sub || hit_sll || hit_slt || hit_sltu || hit_xor ||
                   hit_srl || hit_sra || hit_or || hit_and || hit_ecall ||
                   hit_ebreak || hit_mul || hit_mulh || hit_mulhsu ||
                   hit_mulhu || hit_div || hit_divu || hit_rem || hit_remu ||
                   hit_csrrw || hit_csrrs || hit_csrrc || hit_mret ||
                   hit_wfi || hit_dret;
  assign rs1_id = use_rs1 ? ifu_instr[19:15] : '0;

  assign use_rs2 = hit_beq || hit_bne || hit_blt || hit_bge || hit_bltu ||
                   hit_bgeu || hit_sb || hit_sh || hit_sw || hit_add ||
                   hit_sub || hit_sll || hit_slt || hit_sltu || hit_xor ||
                   hit_srl || hit_sra || hit_or || hit_and || hit_mul ||
                   hit_mulh || hit_mulhsu || hit_mulhu || hit_div ||
                   hit_divu || hit_rem || hit_remu;
  assign rs2_id = use_rs2 ? ifu_instr[24:20] : '0;

  assign use_csr = hit_csrrw || hit_csrrs || hit_csrrc || hit_csrrwi ||
                   hit_csrrsi || hit_csrrci;
  assign csr_id = use_csr ? ifu_instr[31:20] : '0;

  // ---------------------------------------------------------------------------
  // Immediate: the instruction's immediate operand, else 0
  // ---------------------------------------------------------------------------
  // imm_i: I-immediate (loads, JALR, OP-IMM).
  assign imm_i_val = {{20{ifu_instr[31]}}, ifu_instr[31:20]};
  assign use_imm_i = hit_jalr || hit_lb || hit_lh || hit_lw || hit_lbu ||
                     hit_lhu || hit_addi || hit_slti || hit_sltiu ||
                     hit_xori || hit_ori || hit_andi;

  // imm_s: S-immediate (stores).
  assign imm_s_val = {{20{ifu_instr[31]}}, ifu_instr[31:25], ifu_instr[11:7]};
  assign use_imm_s = hit_sb || hit_sh || hit_sw;

  // imm_b: B-immediate (branch offset, multiple of 2).
  assign imm_b_val = {{19{ifu_instr[31]}}, ifu_instr[31], ifu_instr[7],
                      ifu_instr[30:25], ifu_instr[11:8], 1'b0};
  assign use_imm_b = hit_beq || hit_bne || hit_blt || hit_bge || hit_bltu ||
                     hit_bgeu;

  // imm_u: U-immediate (LUI, AUIPC), low 12 bits zero.
  assign imm_u_val = {ifu_instr[31:12], 12'b0};
  assign use_imm_u = hit_lui || hit_auipc;

  // imm_j: J-immediate (JAL offset, multiple of 2).
  assign imm_j_val = {{11{ifu_instr[31]}}, ifu_instr[31], ifu_instr[19:12],
                      ifu_instr[20], ifu_instr[30:21], 1'b0};
  assign use_imm_j = hit_jal;

  // shamt: RV32 shift amount (SLLI / SRLI / SRAI), zero-extended.
  assign shamt_val = {{27{1'b0}}, ifu_instr[24:20]};
  assign use_shamt = hit_slli || hit_srli || hit_srai;

  // uimm: Zicsr 5-bit unsigned immediate (CSRR*I), zero-extended.
  assign uimm_val = {{27{1'b0}}, ifu_instr[19:15]};
  assign use_uimm = hit_csrrwi || hit_csrrsi || hit_csrrci;

  always_comb begin
    imm_id = '0;
    if (use_imm_i) imm_id = imm_i_val;
    if (use_imm_s) imm_id = imm_s_val;
    if (use_imm_b) imm_id = imm_b_val;
    if (use_imm_u) imm_id = imm_u_val;
    if (use_imm_j) imm_id = imm_j_val;
    if (use_shamt) imm_id = shamt_val;
    if (use_uimm)  imm_id = uimm_val;
  end

  // ---------------------------------------------------------------------------
  // Indications: value from each instruction's JSON section, else 0
  // ---------------------------------------------------------------------------
  // alu_op (enum): ALU operation on (alu_src1, alu_src2); also the load / store
  // address (ADD rs1 + imm) and the branch compare (SLT / SLTU on rs1, rs2 for
  // BLT / BGE / BLTU / BGEU; BEQ / BNE use the ALU's rs1 ^ rs2 whatever the
  // op).
  always_comb begin
    alu_op_id = ALU_OP_ADD;
    if (hit_sub)                                       alu_op_id = ALU_OP_SUB;
    if (hit_slli || hit_sll)                           alu_op_id = ALU_OP_SLL;
    if (hit_blt || hit_bge || hit_slti || hit_slt)     alu_op_id = ALU_OP_SLT;
    if (hit_bltu || hit_bgeu || hit_sltiu || hit_sltu) alu_op_id = ALU_OP_SLTU;
    if (hit_xori || hit_xor)                           alu_op_id = ALU_OP_XOR;
    if (hit_srli || hit_srl)                           alu_op_id = ALU_OP_SRL;
    if (hit_srai || hit_sra)                           alu_op_id = ALU_OP_SRA;
    if (hit_ori || hit_or)                             alu_op_id = ALU_OP_OR;
    if (hit_andi || hit_and)                           alu_op_id = ALU_OP_AND;
  end

  // alu_src1 (enum): ALU first operand: x[rs1], the instruction pc (AUIPC), or
  // 0 (LUI).
  always_comb begin
    alu_src1_id = ALU_SRC1_RS1;
    if (hit_auipc) alu_src1_id = ALU_SRC1_PC;
    if (hit_lui)   alu_src1_id = ALU_SRC1_ZERO;
  end

  // alu_src2 (enum): ALU second operand: x[rs2] or imm.
  always_comb begin
    alu_src2_id = ALU_SRC2_RS2;
    if (hit_lui || hit_auipc || hit_lb || hit_lh || hit_lw || hit_lbu ||
        hit_lhu || hit_sb || hit_sh || hit_sw || hit_addi || hit_slti ||
        hit_sltiu || hit_xori || hit_ori || hit_andi || hit_slli || hit_srli ||
        hit_srai)
      alu_src2_id = ALU_SRC2_IMM;
  end

  // branch_op (enum): Conditional branch: the branch unit compares x[rs1] with
  // x[rs2] and computes the target pc + imm.
  always_comb begin
    branch_op_id = BRANCH_OP_NONE;
    if (hit_beq)  branch_op_id = BRANCH_OP_EQ;
    if (hit_bne)  branch_op_id = BRANCH_OP_NE;
    if (hit_blt)  branch_op_id = BRANCH_OP_LT;
    if (hit_bge)  branch_op_id = BRANCH_OP_GE;
    if (hit_bltu) branch_op_id = BRANCH_OP_LTU;
    if (hit_bgeu) branch_op_id = BRANCH_OP_GEU;
  end

  // jump_op (enum): Unconditional jump, resolved by the branch unit: target pc
  // + imm (JAL) or (x[rs1] + imm) & ~1 (JALR); rd gets the link address.
  always_comb begin
    jump_op_id = JUMP_OP_NONE;
    if (hit_jal)  jump_op_id = JUMP_OP_JAL;
    if (hit_jalr) jump_op_id = JUMP_OP_JALR;
  end

  // mem_op (enum): LSU request to the data MSS: load / store at x[rs1] + imm
  // (stores write x[rs2]). FENCE makes no request (a nop: the MSS keeps
  // accesses in order).
  always_comb begin
    mem_op_id = MEM_OP_NONE;
    if (hit_lb || hit_lh || hit_lw || hit_lbu || hit_lhu) mem_op_id = MEM_OP_LOAD;
    if (hit_sb || hit_sh || hit_sw)                       mem_op_id = MEM_OP_STORE;
  end

  // mem_size (enum): Access size when mem_op != NONE (encodes log2 of the byte
  // count). The LSU carries it internally after its first step.
  always_comb begin
    mem_size_id = MEM_SIZE_BYTE;
    if (hit_lh || hit_lhu || hit_sh) mem_size_id = MEM_SIZE_HALF;
    if (hit_lw || hit_sw)            mem_size_id = MEM_SIZE_WORD;
  end

  // mem_unsigned (flag): Zero-extend the loaded value (LBU, LHU) instead of
  // sign-extending. The LSU carries it internally after its first step.
  assign mem_unsigned_id = hit_lbu || hit_lhu;

  // wb_src (enum): Value written to x[rd] (rd = 0 means no write): ALU result,
  // load data, link address from the branch unit (pc + 4, or pc + 2 for a
  // 16-bit instruction), old CSR value, or multiply / divide unit result.
  always_comb begin
    wb_src_id = WB_SRC_ALU;
    if (hit_lb || hit_lh || hit_lw || hit_lbu || hit_lhu) wb_src_id = WB_SRC_MEM;
    if (hit_jal || hit_jalr)                              wb_src_id = WB_SRC_LINK;
    if (hit_csrrw || hit_csrrs || hit_csrrc || hit_csrrwi || hit_csrrsi ||
        hit_csrrci)
      wb_src_id = WB_SRC_CSR;
    if (hit_mul || hit_mulh || hit_mulhsu || hit_mulhu || hit_div ||
        hit_divu || hit_rem || hit_remu)
      wb_src_id = WB_SRC_MD;
  end

  // csr_op (enum): CSR access: write, set bits, clear bits. RS / RC with source
  // x0 / uimm 0 do not write the CSR.
  always_comb begin
    csr_op_id = CSR_OP_NONE;
    if (hit_csrrw || hit_csrrwi) csr_op_id = CSR_OP_RW;
    if (hit_csrrs || hit_csrrsi) csr_op_id = CSR_OP_RS;
    if (hit_csrrc || hit_csrrci) csr_op_id = CSR_OP_RC;
  end

  // csr_uimm (flag): CSR source is imm (uimm) instead of x[rs1] (CSRR*I).
  assign csr_uimm_id = hit_csrrwi || hit_csrrsi || hit_csrrci;

  // fence_i (flag): FENCE.I: synchronize instruction fetch with prior stores
  // (pipeline control refetches from the next instruction).
  assign fence_i_id = hit_fence_i;

  // ecall (flag): ECALL: environment call exception.
  assign ecall_id = hit_ecall;

  // ebreak (flag): EBREAK: breakpoint exception.
  assign ebreak_id = hit_ebreak;

  // mret (flag): MRET: return from a machine-mode trap (trap unit: pc = mepc,
  // MIE = MPIE).
  assign mret_id = hit_mret;

  // dret (flag): DRET: return from debug mode (debug unit: pc = dpc); illegal
  // outside debug mode (trap unit).
  assign dret_id = hit_dret;

  // wfi (flag): WFI: wait for interrupt (pipeline control refetches the next
  // instruction, halts fetch, drains and sleeps until a wake-up).
  assign wfi_id = hit_wfi;

  // md_op (enum): Multiply / divide unit operation on (x[rs1], x[rs2]) (M
  // extension); the instruction stays in ex until the result is ready.
  always_comb begin
    md_op_id = MD_OP_NONE;
    if (hit_mul)    md_op_id = MD_OP_MUL;
    if (hit_mulh)   md_op_id = MD_OP_MULH;
    if (hit_mulhsu) md_op_id = MD_OP_MULHSU;
    if (hit_mulhu)  md_op_id = MD_OP_MULHU;
    if (hit_div)    md_op_id = MD_OP_DIV;
    if (hit_divu)   md_op_id = MD_OP_DIVU;
    if (hit_rem)    md_op_id = MD_OP_REM;
    if (hit_remu)   md_op_id = MD_OP_REMU;
  end

  // ===========================================================================
  // Stage ex (1): registered from id; bubble (all 0) unless adv_id
  // ===========================================================================
  assign valid_ex_d        = adv_id ? valid_id : '0;
  assign op_ex_d           = adv_id ? op_id : '0;
  assign illegal_ex_d      = adv_id ? illegal_id : '0;
  assign fault_ex_d        = adv_id ? fault_id : '0;
  assign fault_hi_ex_d     = adv_id ? fault_hi_id : '0;
  assign pc_ex_d           = adv_id ? pc_id : '0;
  assign instr_ex_d        = adv_id ? instr_id : '0;
  assign is32_ex_d         = adv_id ? is32_id : '0;
  assign imm_ex_d          = adv_id ? imm_id : '0;
  assign rd_ex_d           = adv_id ? rd_id : '0;
  assign rs1_ex_d          = adv_id ? rs1_id : '0;
  assign rs2_ex_d          = adv_id ? rs2_id : '0;
  assign csr_ex_d          = adv_id ? csr_id : '0;
  assign alu_op_ex_d       = adv_id ? alu_op_id : '0;
  assign alu_src1_ex_d     = adv_id ? alu_src1_id : '0;
  assign alu_src2_ex_d     = adv_id ? alu_src2_id : '0;
  assign branch_op_ex_d    = adv_id ? branch_op_id : '0;
  assign jump_op_ex_d      = adv_id ? jump_op_id : '0;
  assign mem_op_ex_d       = adv_id ? mem_op_id : '0;
  assign mem_size_ex_d     = adv_id ? mem_size_id : '0;
  assign mem_unsigned_ex_d = adv_id ? mem_unsigned_id : '0;
  assign wb_src_ex_d       = adv_id ? wb_src_id : '0;
  assign csr_op_ex_d       = adv_id ? csr_op_id : '0;
  assign csr_uimm_ex_d     = adv_id ? csr_uimm_id : '0;
  assign fence_i_ex_d      = adv_id ? fence_i_id : '0;
  assign ecall_ex_d        = adv_id ? ecall_id : '0;
  assign ebreak_ex_d       = adv_id ? ebreak_id : '0;
  assign mret_ex_d         = adv_id ? mret_id : '0;
  assign dret_ex_d         = adv_id ? dret_id : '0;
  assign wfi_ex_d          = adv_id ? wfi_id : '0;
  assign md_op_ex_d        = adv_id ? md_op_id : '0;

  basechili_dffe #(.WIDTH(1)) u_valid_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (valid_ex_d),
    .q     (valid_ex)
  );

  basechili_dffe #(.WIDTH($bits(op_e))) u_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (op_ex_d),
    .q     (op_ex_q)
  );
  assign op_ex = op_e'(op_ex_q);

  basechili_dffe #(.WIDTH(1)) u_illegal_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (illegal_ex_d),
    .q     (illegal_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_fault_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (fault_ex_d),
    .q     (fault_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_fault_hi_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (fault_hi_ex_d),
    .q     (fault_hi_ex)
  );

  basechili_dffe #(.WIDTH(XLEN)) u_pc_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (pc_ex_d),
    .q     (pc_ex)
  );

  basechili_dffe #(.WIDTH(32)) u_instr_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (instr_ex_d),
    .q     (instr_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_is32_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (is32_ex_d),
    .q     (is32_ex)
  );

  basechili_dffe #(.WIDTH(XLEN)) u_imm_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (imm_ex_d),
    .q     (imm_ex)
  );

  basechili_dffe #(.WIDTH(5)) u_rd_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (rd_ex_d),
    .q     (rd_ex)
  );

  basechili_dffe #(.WIDTH(5)) u_rs1_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (rs1_ex_d),
    .q     (rs1_ex)
  );

  basechili_dffe #(.WIDTH(5)) u_rs2_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (rs2_ex_d),
    .q     (rs2_ex)
  );

  basechili_dffe #(.WIDTH(12)) u_csr_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (csr_ex_d),
    .q     (csr_ex)
  );

  basechili_dffe #(.WIDTH($bits(alu_op_e))) u_alu_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (alu_op_ex_d),
    .q     (alu_op_ex_q)
  );
  assign alu_op_ex = alu_op_e'(alu_op_ex_q);

  basechili_dffe #(.WIDTH($bits(alu_src1_e))) u_alu_src1_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (alu_src1_ex_d),
    .q     (alu_src1_ex_q)
  );
  assign alu_src1_ex = alu_src1_e'(alu_src1_ex_q);

  basechili_dffe #(.WIDTH($bits(alu_src2_e))) u_alu_src2_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (alu_src2_ex_d),
    .q     (alu_src2_ex_q)
  );
  assign alu_src2_ex = alu_src2_e'(alu_src2_ex_q);

  basechili_dffe #(.WIDTH($bits(branch_op_e))) u_branch_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (branch_op_ex_d),
    .q     (branch_op_ex_q)
  );
  assign branch_op_ex = branch_op_e'(branch_op_ex_q);

  basechili_dffe #(.WIDTH($bits(jump_op_e))) u_jump_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (jump_op_ex_d),
    .q     (jump_op_ex_q)
  );
  assign jump_op_ex = jump_op_e'(jump_op_ex_q);

  basechili_dffe #(.WIDTH($bits(mem_op_e))) u_mem_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (mem_op_ex_d),
    .q     (mem_op_ex_q)
  );
  assign mem_op_ex = mem_op_e'(mem_op_ex_q);

  basechili_dffe #(.WIDTH($bits(mem_size_e))) u_mem_size_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (mem_size_ex_d),
    .q     (mem_size_ex_q)
  );
  assign mem_size_ex = mem_size_e'(mem_size_ex_q);

  basechili_dffe #(.WIDTH(1)) u_mem_unsigned_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (mem_unsigned_ex_d),
    .q     (mem_unsigned_ex)
  );

  basechili_dffe #(.WIDTH($bits(wb_src_e))) u_wb_src_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (wb_src_ex_d),
    .q     (wb_src_ex_q)
  );
  assign wb_src_ex = wb_src_e'(wb_src_ex_q);

  basechili_dffe #(.WIDTH($bits(csr_op_e))) u_csr_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (csr_op_ex_d),
    .q     (csr_op_ex_q)
  );
  assign csr_op_ex = csr_op_e'(csr_op_ex_q);

  basechili_dffe #(.WIDTH(1)) u_csr_uimm_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (csr_uimm_ex_d),
    .q     (csr_uimm_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_fence_i_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (fence_i_ex_d),
    .q     (fence_i_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_ecall_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (ecall_ex_d),
    .q     (ecall_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_ebreak_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (ebreak_ex_d),
    .q     (ebreak_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_mret_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (mret_ex_d),
    .q     (mret_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_dret_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (dret_ex_d),
    .q     (dret_ex)
  );

  basechili_dffe #(.WIDTH(1)) u_wfi_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (wfi_ex_d),
    .q     (wfi_ex)
  );

  basechili_dffe #(.WIDTH($bits(md_op_e))) u_md_op_ex (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_ex),
    .d     (md_op_ex_d),
    .q     (md_op_ex_q)
  );
  assign md_op_ex = md_op_e'(md_op_ex_q);

  // ===========================================================================
  // Stage wb (2): registered from ex; bubble (all 0) unless adv_ex
  // ===========================================================================
  assign valid_wb_d   = adv_ex ? valid_ex : '0;
  assign op_wb_d      = adv_ex ? op_ex : '0;
  assign illegal_wb_d = adv_ex ? illegal_ex : '0;
  assign fault_wb_d   = adv_ex ? fault_ex : '0;
  assign pc_wb_d      = adv_ex ? pc_ex : '0;
  assign instr_wb_d   = adv_ex ? instr_ex : '0;
  assign rd_wb_d      = adv_ex ? rd_ex : '0;
  assign mem_op_wb_d  = adv_ex ? mem_op_ex : '0;
  assign wb_src_wb_d  = adv_ex ? wb_src_ex : '0;

  basechili_dffe #(.WIDTH(1)) u_valid_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (valid_wb_d),
    .q     (valid_wb)
  );

  basechili_dffe #(.WIDTH($bits(op_e))) u_op_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (op_wb_d),
    .q     (op_wb_q)
  );
  assign op_wb = op_e'(op_wb_q);

  basechili_dffe #(.WIDTH(1)) u_illegal_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (illegal_wb_d),
    .q     (illegal_wb)
  );

  basechili_dffe #(.WIDTH(1)) u_fault_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (fault_wb_d),
    .q     (fault_wb)
  );

  basechili_dffe #(.WIDTH(XLEN)) u_pc_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (pc_wb_d),
    .q     (pc_wb)
  );

  basechili_dffe #(.WIDTH(32)) u_instr_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (instr_wb_d),
    .q     (instr_wb)
  );

  basechili_dffe #(.WIDTH(5)) u_rd_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (rd_wb_d),
    .q     (rd_wb)
  );

  basechili_dffe #(.WIDTH($bits(mem_op_e))) u_mem_op_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (mem_op_wb_d),
    .q     (mem_op_wb_q)
  );
  assign mem_op_wb = mem_op_e'(mem_op_wb_q);

  basechili_dffe #(.WIDTH($bits(wb_src_e))) u_wb_src_wb (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (en_wb),
    .d     (wb_src_wb_d),
    .q     (wb_src_wb_q)
  );
  assign wb_src_wb = wb_src_e'(wb_src_wb_q);

endmodule
