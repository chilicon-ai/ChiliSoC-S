// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChillU-S :: chillus_dec_pkg
//
// Types and constants shared by chillus_dec and the pipeline stages
// that consume its outputs.
// -----------------------------------------------------------------------------
package chillus_dec_pkg;

  localparam int XLEN = 32;

  // misa Extensions field [25:0] (bit 0 = A ... bit 25 = Z): the base ISA
  // and the single-letter extensions enabled in the decoder spec: C, I, M.
  localparam logic [25:0] MISA_EXT = 26'h0001104;

  // Pipeline stages: bit STAGE_<S> of stall / flush / hold / kill is stage <s>.
  localparam int N_STAGES = 3;
  localparam int STAGE_ID = 0;  // decode stage
  localparam int STAGE_EX = 1;
  localparam int STAGE_WB = 2;

  // Decoded instruction (op_<stage> ports).
  typedef enum logic [5:0] {
    OP_NONE        = 6'd0,  // no instruction (bubble)
    OP_ILLEGAL     = 6'd1,  // no enabled instruction matches
    OP_FETCH_FAULT = 6'd2,  // IFU fetch error, instruction not decoded
    OP_LUI         = 6'd3,  // RV32I: lui rd, imm: x[rd] = imm_u
    OP_AUIPC       = 6'd4,  // RV32I: auipc rd, imm: x[rd] = pc + imm_u
    OP_JAL         = 6'd5,  // RV32I: jal rd, offset: x[rd] = pc + 4; pc = pc + imm_j
    OP_JALR        = 6'd6,  // RV32I: jalr rd, offset(rs1): x[rd] = pc + 4; pc = (x[rs1] + imm_i) & ~1
    OP_BEQ         = 6'd7,  // RV32I: beq rs1, rs2, offset: if x[rs1] == x[rs2], pc = pc + imm_b
    OP_BNE         = 6'd8,  // RV32I: bne rs1, rs2, offset: if x[rs1] != x[rs2], pc = pc + imm_b
    OP_BLT         = 6'd9,  // RV32I: blt rs1, rs2, offset: if x[rs1] < x[rs2] (signed), pc = pc + imm_b
    OP_BGE         = 6'd10, // RV32I: bge rs1, rs2, offset: if x[rs1] >= x[rs2] (signed), pc = pc + imm_b
    OP_BLTU        = 6'd11, // RV32I: bltu rs1, rs2, offset: if x[rs1] < x[rs2] (unsigned), pc = pc + imm_b
    OP_BGEU        = 6'd12, // RV32I: bgeu rs1, rs2, offset: if x[rs1] >= x[rs2] (unsigned), pc = pc + imm_b
    OP_LB          = 6'd13, // RV32I: lb rd, offset(rs1): x[rd] = sext(M8[x[rs1] + imm_i])
    OP_LH          = 6'd14, // RV32I: lh rd, offset(rs1): x[rd] = sext(M16[x[rs1] + imm_i])
    OP_LW          = 6'd15, // RV32I: lw rd, offset(rs1): x[rd] = M32[x[rs1] + imm_i]
    OP_LBU         = 6'd16, // RV32I: lbu rd, offset(rs1): x[rd] = zext(M8[x[rs1] + imm_i])
    OP_LHU         = 6'd17, // RV32I: lhu rd, offset(rs1): x[rd] = zext(M16[x[rs1] + imm_i])
    OP_SB          = 6'd18, // RV32I: sb rs2, offset(rs1): M8[x[rs1] + imm_s] = x[rs2][7:0]
    OP_SH          = 6'd19, // RV32I: sh rs2, offset(rs1): M16[x[rs1] + imm_s] = x[rs2][15:0]
    OP_SW          = 6'd20, // RV32I: sw rs2, offset(rs1): M32[x[rs1] + imm_s] = x[rs2]
    OP_ADDI        = 6'd21, // RV32I: addi rd, rs1, imm: x[rd] = x[rs1] + imm_i
    OP_SLTI        = 6'd22, // RV32I: slti rd, rs1, imm: x[rd] = (x[rs1] < imm_i) signed
    OP_SLTIU       = 6'd23, // RV32I: sltiu rd, rs1, imm: x[rd] = (x[rs1] < imm_i) unsigned
    OP_XORI        = 6'd24, // RV32I: xori rd, rs1, imm: x[rd] = x[rs1] ^ imm_i
    OP_ORI         = 6'd25, // RV32I: ori rd, rs1, imm: x[rd] = x[rs1] | imm_i
    OP_ANDI        = 6'd26, // RV32I: andi rd, rs1, imm: x[rd] = x[rs1] & imm_i
    OP_SLLI        = 6'd27, // RV32I: slli rd, rs1, shamt: x[rd] = x[rs1] << shamt
    OP_SRLI        = 6'd28, // RV32I: srli rd, rs1, shamt: x[rd] = x[rs1] >> shamt (logical)
    OP_SRAI        = 6'd29, // RV32I: srai rd, rs1, shamt: x[rd] = x[rs1] >> shamt (arithmetic)
    OP_ADD         = 6'd30, // RV32I: add rd, rs1, rs2: x[rd] = x[rs1] + x[rs2]
    OP_SUB         = 6'd31, // RV32I: sub rd, rs1, rs2: x[rd] = x[rs1] - x[rs2]
    OP_SLL         = 6'd32, // RV32I: sll rd, rs1, rs2: x[rd] = x[rs1] << x[rs2][4:0]
    OP_SLT         = 6'd33, // RV32I: slt rd, rs1, rs2: x[rd] = (x[rs1] < x[rs2]) signed
    OP_SLTU        = 6'd34, // RV32I: sltu rd, rs1, rs2: x[rd] = (x[rs1] < x[rs2]) unsigned
    OP_XOR         = 6'd35, // RV32I: xor rd, rs1, rs2: x[rd] = x[rs1] ^ x[rs2]
    OP_SRL         = 6'd36, // RV32I: srl rd, rs1, rs2: x[rd] = x[rs1] >> x[rs2][4:0] (logical)
    OP_SRA         = 6'd37, // RV32I: sra rd, rs1, rs2: x[rd] = x[rs1] >> x[rs2][4:0] (arithmetic)
    OP_OR          = 6'd38, // RV32I: or rd, rs1, rs2: x[rd] = x[rs1] | x[rs2]
    OP_AND         = 6'd39, // RV32I: and rd, rs1, rs2: x[rd] = x[rs1] & x[rs2]
    OP_FENCE       = 6'd40, // RV32I: fence pred, succ: order memory accesses
    OP_ECALL       = 6'd41, // RV32I: ecall: environment call
    OP_EBREAK      = 6'd42, // RV32I: ebreak: breakpoint
    OP_MUL         = 6'd43, // M: mul rd, rs1, rs2: x[rd] = (x[rs1] * x[rs2])[XLEN-1:0]
    OP_MULH        = 6'd44, // M: mulh rd, rs1, rs2: x[rd] = (signed x[rs1] * signed x[rs2])[2*XLEN-1:XLEN]
    OP_MULHSU      = 6'd45, // M: mulhsu rd, rs1, rs2: x[rd] = (signed x[rs1] * unsigned x[rs2])[2*XLEN-1:XLEN]
    OP_MULHU       = 6'd46, // M: mulhu rd, rs1, rs2: x[rd] = (unsigned x[rs1] * unsigned x[rs2])[2*XLEN-1:XLEN]
    OP_DIV         = 6'd47, // M: div rd, rs1, rs2: x[rd] = signed x[rs1] / signed x[rs2], rounded toward zero; / 0 = -1, overflow (-2^(XLEN-1) / -1) = -2^(XLEN-1)
    OP_DIVU        = 6'd48, // M: divu rd, rs1, rs2: x[rd] = unsigned x[rs1] / unsigned x[rs2]; / 0 = 2^XLEN - 1
    OP_REM         = 6'd49, // M: rem rd, rs1, rs2: x[rd] = signed x[rs1] % signed x[rs2] (sign of the dividend); % 0 = x[rs1], overflow = 0
    OP_REMU        = 6'd50, // M: remu rd, rs1, rs2: x[rd] = unsigned x[rs1] % unsigned x[rs2]; % 0 = x[rs1]
    OP_CSRRW       = 6'd51, // Zicsr: csrrw rd, csr, rs1: x[rd] = CSR; CSR = x[rs1] (no CSR read when rd = x0)
    OP_CSRRS       = 6'd52, // Zicsr: csrrs rd, csr, rs1: x[rd] = CSR; CSR |= x[rs1] (no CSR write when rs1 = x0)
    OP_CSRRC       = 6'd53, // Zicsr: csrrc rd, csr, rs1: x[rd] = CSR; CSR &= ~x[rs1] (no CSR write when rs1 = x0)
    OP_CSRRWI      = 6'd54, // Zicsr: csrrwi rd, csr, uimm: x[rd] = CSR; CSR = uimm (no CSR read when rd = x0)
    OP_CSRRSI      = 6'd55, // Zicsr: csrrsi rd, csr, uimm: x[rd] = CSR; CSR |= uimm (no CSR write when uimm = 0)
    OP_CSRRCI      = 6'd56, // Zicsr: csrrci rd, csr, uimm: x[rd] = CSR; CSR &= ~uimm (no CSR write when uimm = 0)
    OP_FENCE_I     = 6'd57, // Zifencei: fence.i: make prior stores visible to instruction fetch
    OP_MRET        = 6'd58, // Sm: mret: return from a machine-mode trap: pc = mepc, MIE = MPIE, MPIE = 1
    OP_WFI         = 6'd59, // Sm: wfi: wait for interrupt: retires, then the core drains and sleeps (core_sleep) until (mie & mip) != 0 (whatever mstatus.MIE), an NMI or debug_req; an enabled interrupt is then taken at the next instruction (riscv-privileged.pdf 3.3.3)
    OP_DRET        = 6'd60  // Sm: dret: return from debug mode (Sdext, riscv-debug-specification.pdf 4.8): pc = dpc, leave debug mode; illegal outside debug mode
  } op_e;

  // alu_op: ALU operation on (alu_src1, alu_src2); also the load / store
  // address (ADD rs1 + imm) and the branch compare (SLT / SLTU on rs1, rs2 for
  // BLT / BGE / BLTU / BGEU; BEQ / BNE use the ALU's rs1 ^ rs2 whatever the
  // op). (first value = 0 = default)
  typedef enum logic [3:0] {
    ALU_OP_ADD  = 4'd0,
    ALU_OP_SUB  = 4'd1,
    ALU_OP_SLL  = 4'd2,
    ALU_OP_SLT  = 4'd3,
    ALU_OP_SLTU = 4'd4,
    ALU_OP_XOR  = 4'd5,
    ALU_OP_SRL  = 4'd6,
    ALU_OP_SRA  = 4'd7,
    ALU_OP_OR   = 4'd8,
    ALU_OP_AND  = 4'd9
  } alu_op_e;

  // alu_src1: ALU first operand: x[rs1], the instruction pc (AUIPC), or 0
  // (LUI). (first value = 0 = default)
  typedef enum logic [1:0] {
    ALU_SRC1_RS1  = 2'd0,
    ALU_SRC1_PC   = 2'd1,
    ALU_SRC1_ZERO = 2'd2
  } alu_src1_e;

  // alu_src2: ALU second operand: x[rs2] or imm. (first value = 0 = default)
  typedef enum logic [0:0] {
    ALU_SRC2_RS2 = 1'd0,
    ALU_SRC2_IMM = 1'd1
  } alu_src2_e;

  // branch_op: Conditional branch: the branch unit compares x[rs1] with x[rs2]
  // and computes the target pc + imm. (first value = 0 = default)
  typedef enum logic [2:0] {
    BRANCH_OP_NONE = 3'd0,
    BRANCH_OP_EQ   = 3'd1,
    BRANCH_OP_NE   = 3'd2,
    BRANCH_OP_LT   = 3'd3,
    BRANCH_OP_GE   = 3'd4,
    BRANCH_OP_LTU  = 3'd5,
    BRANCH_OP_GEU  = 3'd6
  } branch_op_e;

  // jump_op: Unconditional jump, resolved by the branch unit: target pc + imm
  // (JAL) or (x[rs1] + imm) & ~1 (JALR); rd gets the link address. (first value
  // = 0 = default)
  typedef enum logic [1:0] {
    JUMP_OP_NONE = 2'd0,
    JUMP_OP_JAL  = 2'd1,
    JUMP_OP_JALR = 2'd2
  } jump_op_e;

  // mem_op: LSU request to the data MSS: load / store at x[rs1] + imm (stores
  // write x[rs2]). FENCE makes no request (a nop: the MSS keeps accesses in
  // order). (first value = 0 = default)
  typedef enum logic [1:0] {
    MEM_OP_NONE  = 2'd0,
    MEM_OP_LOAD  = 2'd1,
    MEM_OP_STORE = 2'd2
  } mem_op_e;

  // mem_size: Access size when mem_op != NONE (encodes log2 of the byte count).
  // The LSU carries it internally after its first step. (first value = 0 =
  // default)
  typedef enum logic [1:0] {
    MEM_SIZE_BYTE = 2'd0,
    MEM_SIZE_HALF = 2'd1,
    MEM_SIZE_WORD = 2'd2
  } mem_size_e;

  // wb_src: Value written to x[rd] (rd = 0 means no write): ALU result, load
  // data, link address from the branch unit (pc + 4, or pc + 2 for a 16-bit
  // instruction), old CSR value, or multiply / divide unit result. (first value
  // = 0 = default)
  typedef enum logic [2:0] {
    WB_SRC_ALU  = 3'd0,
    WB_SRC_MEM  = 3'd1,
    WB_SRC_LINK = 3'd2,
    WB_SRC_CSR  = 3'd3,
    WB_SRC_MD   = 3'd4
  } wb_src_e;

  // csr_op: CSR access: write, set bits, clear bits. RS / RC with source x0 /
  // uimm 0 do not write the CSR. (first value = 0 = default)
  typedef enum logic [1:0] {
    CSR_OP_NONE = 2'd0,
    CSR_OP_RW   = 2'd1,
    CSR_OP_RS   = 2'd2,
    CSR_OP_RC   = 2'd3
  } csr_op_e;

  // md_op: Multiply / divide unit operation on (x[rs1], x[rs2]) (M extension);
  // the instruction stays in ex until the result is ready. (first value = 0 =
  // default)
  typedef enum logic [3:0] {
    MD_OP_NONE   = 4'd0,
    MD_OP_MUL    = 4'd1,
    MD_OP_MULH   = 4'd2,
    MD_OP_MULHSU = 4'd3,
    MD_OP_MULHU  = 4'd4,
    MD_OP_DIV    = 4'd5,
    MD_OP_DIVU   = 4'd6,
    MD_OP_REM    = 4'd7,
    MD_OP_REMU   = 4'd8
  } md_op_e;

endpackage
