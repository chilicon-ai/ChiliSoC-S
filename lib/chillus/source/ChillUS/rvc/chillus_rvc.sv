// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_rvc
//
// RV32C instruction expander (riscv-unprivileged.pdf, "C" Standard Extension
// for Compressed Instructions / Zca, RVC opcode map). Sits between the IFU and
// the decoder: a 16-bit instruction is replaced by its 32-bit base-ISA
// equivalent, a 32-bit instruction passes through unchanged. Stage-agnostic.
//
// Scope: RV32 Zca for an RV32IM_Zicsr_Zifencei core without F / D, so the
// floating-point loads / stores (C.FLD, C.FSD, C.FLW, C.FSW, C.FLDSP,
// C.FSDSP, C.FLWSP, C.FSWSP) are illegal, as are the RV64-only C.SUBW /
// C.ADDW slots and the Zcb slots (quadrant 0 funct3 100, quadrant 1
// 100-1-11-xx).
//
//   quadrant / funct3   instruction        expansion
//   00 000              C.ADDI4SPN         addi  rd', x2, nzuimm
//   00 010              C.LW               lw    rd', uimm(rs1')
//   00 110              C.SW               sw    rs2', uimm(rs1')
//   01 000              C.ADDI / C.NOP     addi  rd, rd, imm
//   01 001              C.JAL              jal   x1, offset
//   01 010              C.LI               addi  rd, x0, imm
//   01 011  rd == 2     C.ADDI16SP         addi  x2, x2, nzimm
//   01 011  rd != 2     C.LUI              lui   rd, nzimm
//   01 100              C.SRLI / C.SRAI / C.ANDI / C.SUB / C.XOR / C.OR / C.AND
//   01 101              C.J                jal   x0, offset
//   01 110 / 111        C.BEQZ / C.BNEZ    beq / bne rs1', x0, offset
//   10 000              C.SLLI             slli  rd, rd, shamt
//   10 010              C.LWSP             lw    rd, uimm(x2)
//   10 100              C.JR / C.MV / C.EBREAK / C.JALR / C.ADD
//   10 110              C.SWSP             sw    rs2, uimm(x2)
//
// Reserved encodings are illegal: 0x0000 and C.ADDI4SPN with nzuimm == 0,
// C.LWSP with rd == 0, C.JR with rs1 == 0, C.ADDI16SP / C.LUI with
// nzimm == 0, C.SLLI / C.SRLI / C.SRAI with shamt[5] == 1 (RV32 NSE).
// HINT encodings are legal and expand to the base-ISA instruction they stand
// for (most write x0): C.NOP with imm != 0, C.ADDI with imm == 0,
// C.LI / C.LUI / C.MV / C.ADD / C.SLLI with rd == 0, shifts with shamt == 0.
// C.MV expands to add rd, x0, rs2 (as the spec defines), not addi rd, rs2, 0.
// An illegal 16-bit instruction drives instr_out = 0 (illegal to the decoder
// as well).
//
// Timing    : combinational, no state.
// Invariant : illegal == 0 whenever is32; instr_out[1:0] == 2'b11 whenever
//             !illegal (every expansion is a 32-bit instruction).
// Debug     : quadrant / funct3 select the row of the table above; the
//             register fields (rd_rs1, rs2, rd_rs1_p, rs2_p) and the
//             immediates (imm_*) are named per format, so a wrong expansion
//             shows as the field that differs from the 16-bit instruction.
//             illegal set for a valid instruction: check quadrant / funct3
//             and the reserved-field conditions (e.g. imm_addi4spn == 0).
// -----------------------------------------------------------------------------
module chillus_rvc (
  input  logic [31:0] instr_in,   // IFU instruction; a 16-bit instruction is in [15:0] (upper half 0) when !is32
  input  logic        is32,       // 32-bit instruction: pass through unchanged
  output logic [31:0] instr_out,  // 32-bit equivalent (instr_in when is32)
  output logic        illegal     // !is32 and instr_in[15:0] is not a valid RV32C instruction
);

  // ---------------------------------------------------------------------------
  // Base-ISA opcodes and fixed encodings
  // ---------------------------------------------------------------------------
  localparam logic [6:0]  OPC_LOAD   = 7'b0000011;
  localparam logic [6:0]  OPC_STORE  = 7'b0100011;
  localparam logic [6:0]  OPC_OP_IMM = 7'b0010011;
  localparam logic [6:0]  OPC_OP     = 7'b0110011;
  localparam logic [6:0]  OPC_LUI    = 7'b0110111;
  localparam logic [6:0]  OPC_BRANCH = 7'b1100011;
  localparam logic [6:0]  OPC_JAL    = 7'b1101111;
  localparam logic [6:0]  OPC_JALR   = 7'b1100111;
  localparam logic [31:0] EBREAK     = 32'h0010_0073;

  localparam logic [4:0]  X0 = 5'd0;           // zero
  localparam logic [4:0]  X1 = 5'd1;           // ra (link register)
  localparam logic [4:0]  X2 = 5'd2;           // sp

  // ---------------------------------------------------------------------------
  // 32-bit format packers
  // ---------------------------------------------------------------------------
  function automatic logic [31:0] enc_r(input logic [6:0] funct7, input logic [4:0] rs2_f,
                                        input logic [4:0] rs1_f, input logic [2:0] funct3_f,
                                        input logic [4:0] rd_f, input logic [6:0] opcode);
    return {funct7, rs2_f, rs1_f, funct3_f, rd_f, opcode};
  endfunction

  function automatic logic [31:0] enc_i(input logic [11:0] imm, input logic [4:0] rs1_f,
                                        input logic [2:0] funct3_f, input logic [4:0] rd_f,
                                        input logic [6:0] opcode);
    return {imm, rs1_f, funct3_f, rd_f, opcode};
  endfunction

  function automatic logic [31:0] enc_s(input logic [11:0] imm, input logic [4:0] rs2_f,
                                        input logic [4:0] rs1_f, input logic [2:0] funct3_f);
    return {imm[11:5], rs2_f, rs1_f, funct3_f, imm[4:0], OPC_STORE};
  endfunction

  function automatic logic [31:0] enc_b(input logic [12:0] imm, input logic [4:0] rs1_f,
                                        input logic [2:0] funct3_f);
    return {imm[12], imm[10:5], X0, rs1_f, funct3_f, imm[4:1], imm[11], OPC_BRANCH};
  endfunction

  function automatic logic [31:0] enc_u(input logic [19:0] imm, input logic [4:0] rd_f);
    return {imm, rd_f, OPC_LUI};
  endfunction

  function automatic logic [31:0] enc_j(input logic [20:0] imm, input logic [4:0] rd_f);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd_f, OPC_JAL};
  endfunction

  // ---------------------------------------------------------------------------
  // 16-bit instruction fields
  // ---------------------------------------------------------------------------
  logic [15:0] c_instr;        // the 16-bit instruction
  logic [1:0]  quadrant;       // c_instr[1:0]
  logic [2:0]  funct3;         // c_instr[15:13]
  logic [1:0]  funct2;         // c_instr[11:10]: quadrant 1 funct3 100 sub-op
  logic [1:0]  funct2_arith;   // c_instr[6:5]: C.SUB / C.XOR / C.OR / C.AND
  logic        bit12;          // c_instr[12]: imm[5] / shamt[5] / sub-op select
  logic [4:0]  rd_rs1;         // c_instr[11:7]: full register rd / rs1
  logic [4:0]  rs2;            // c_instr[6:2]: full register rs2
  logic [4:0]  rd_rs1_p;       // rd' / rs1' (x8..x15) from c_instr[9:7]
  logic [4:0]  rs2_p;          // rd' / rs2' (x8..x15) from c_instr[4:2]
  logic [5:0]  shamt;          // CI shift amount {bit12, c_instr[6:2]}

  // immediates, already scaled; extended to the 32-bit field width below
  logic [9:0]  imm_addi4spn;   // CIW: nzuimm[9:2], zero-extended
  logic [6:0]  imm_lw;         // CL / CS: uimm[6:2] of C.LW / C.SW
  logic [5:0]  imm_ci;         // CI: imm[5:0] of C.ADDI / C.LI / C.ANDI, signed
  logic [9:0]  imm_addi16sp;   // CI: nzimm[9:4] of C.ADDI16SP, signed
  logic [5:0]  imm_lui;        // CI: nzimm[17:12] of C.LUI, signed
  logic [11:0] imm_j;          // CJ: offset[11:1] of C.J / C.JAL, signed
  logic [8:0]  imm_b;          // CB: offset[8:1] of C.BEQZ / C.BNEZ, signed
  logic [7:0]  imm_lwsp;       // CI: uimm[7:2] of C.LWSP
  logic [7:0]  imm_swsp;       // CSS: uimm[7:2] of C.SWSP

  logic [11:0] imm_ci_i;       // imm_ci sign-extended to an I-immediate
  logic [11:0] imm_addi16sp_i; // imm_addi16sp sign-extended to an I-immediate
  logic [19:0] imm_lui_u;      // imm_lui sign-extended to a U-immediate [31:12]
  logic [20:0] imm_j_j;        // imm_j sign-extended to a J-immediate
  logic [12:0] imm_b_b;        // imm_b sign-extended to a B-immediate

  logic [31:0] c_expanded;     // expansion of c_instr (0 when c_illegal)
  logic        c_illegal;      // c_instr is reserved or not in RV32C (no F / D)

  assign c_instr      = instr_in[15:0];
  assign quadrant     = c_instr[1:0];
  assign funct3       = c_instr[15:13];
  assign funct2       = c_instr[11:10];
  assign funct2_arith = c_instr[6:5];
  assign bit12        = c_instr[12];
  assign rd_rs1       = c_instr[11:7];
  assign rs2          = c_instr[6:2];
  assign rd_rs1_p     = {2'b01, c_instr[9:7]};
  assign rs2_p        = {2'b01, c_instr[4:2]};
  assign shamt        = {c_instr[12], c_instr[6:2]};

  assign imm_addi4spn = {c_instr[10:7], c_instr[12:11], c_instr[5], c_instr[6], 2'b00};
  assign imm_lw       = {c_instr[5], c_instr[12:10], c_instr[6], 2'b00};
  assign imm_ci       = {c_instr[12], c_instr[6:2]};
  assign imm_addi16sp = {c_instr[12], c_instr[4:3], c_instr[5], c_instr[2], c_instr[6], 4'b0000};
  assign imm_lui      = {c_instr[12], c_instr[6:2]};
  assign imm_j        = {c_instr[12], c_instr[8], c_instr[10:9], c_instr[6], c_instr[7],
                         c_instr[2], c_instr[11], c_instr[5:3], 1'b0};
  assign imm_b        = {c_instr[12], c_instr[6:5], c_instr[2], c_instr[11:10], c_instr[4:3], 1'b0};
  assign imm_lwsp     = {c_instr[3:2], c_instr[12], c_instr[6:4], 2'b00};
  assign imm_swsp     = {c_instr[8:7], c_instr[12:9], 2'b00};

  assign imm_ci_i       = {{6{imm_ci[5]}}, imm_ci};
  assign imm_addi16sp_i = {{2{imm_addi16sp[9]}}, imm_addi16sp};
  assign imm_lui_u      = {{14{imm_lui[5]}}, imm_lui};
  assign imm_j_j        = {{9{imm_j[11]}}, imm_j};
  assign imm_b_b        = {{4{imm_b[8]}}, imm_b};

  // ---------------------------------------------------------------------------
  // Expansion (RVC opcode map)
  // ---------------------------------------------------------------------------
  always_comb begin
    c_expanded = '0;
    c_illegal  = 1'b1;
    case (quadrant)
      // ----- quadrant 0 -----
      2'b00: begin
        case (funct3)
          3'b000: begin  // C.ADDI4SPN (nzuimm == 0 reserved, includes 0x0000)
            c_expanded = enc_i({2'b00, imm_addi4spn}, X2, 3'b000, rs2_p, OPC_OP_IMM);
            c_illegal  = (imm_addi4spn == 10'd0);
          end
          3'b010: begin  // C.LW
            c_expanded = enc_i({5'b00000, imm_lw}, rd_rs1_p, 3'b010, rs2_p, OPC_LOAD);
            c_illegal  = 1'b0;
          end
          3'b110: begin  // C.SW
            c_expanded = enc_s({5'b00000, imm_lw}, rs2_p, rd_rs1_p, 3'b010);
            c_illegal  = 1'b0;
          end
          default: ;     // C.FLD, C.FLW, reserved (Zcb), C.FSD, C.FSW
        endcase
      end
      // ----- quadrant 1 -----
      2'b01: begin
        case (funct3)
          3'b000: begin  // C.ADDI / C.NOP (imm == 0 or rd == 0: HINT)
            c_expanded = enc_i(imm_ci_i, rd_rs1, 3'b000, rd_rs1, OPC_OP_IMM);
            c_illegal  = 1'b0;
          end
          3'b001: begin  // C.JAL (RV32)
            c_expanded = enc_j(imm_j_j, X1);
            c_illegal  = 1'b0;
          end
          3'b010: begin  // C.LI (rd == 0: HINT)
            c_expanded = enc_i(imm_ci_i, X0, 3'b000, rd_rs1, OPC_OP_IMM);
            c_illegal  = 1'b0;
          end
          3'b011: begin
            if (rd_rs1 == X2) begin  // C.ADDI16SP (nzimm == 0 reserved)
              c_expanded = enc_i(imm_addi16sp_i, X2, 3'b000, X2, OPC_OP_IMM);
              c_illegal  = (imm_addi16sp == 10'd0);
            end else begin           // C.LUI (nzimm == 0 reserved, rd == 0: HINT)
              c_expanded = enc_u(imm_lui_u, rd_rs1);
              c_illegal  = (imm_lui == 6'd0);
            end
          end
          3'b100: begin
            case (funct2)
              2'b00: begin  // C.SRLI (shamt[5] == 1: RV32 NSE, shamt == 0: HINT)
                c_expanded = enc_i({7'b0000000, shamt[4:0]}, rd_rs1_p, 3'b101, rd_rs1_p, OPC_OP_IMM);
                c_illegal  = shamt[5];
              end
              2'b01: begin  // C.SRAI (shamt[5] == 1: RV32 NSE, shamt == 0: HINT)
                c_expanded = enc_i({7'b0100000, shamt[4:0]}, rd_rs1_p, 3'b101, rd_rs1_p, OPC_OP_IMM);
                c_illegal  = shamt[5];
              end
              2'b10: begin  // C.ANDI
                c_expanded = enc_i(imm_ci_i, rd_rs1_p, 3'b111, rd_rs1_p, OPC_OP_IMM);
                c_illegal  = 1'b0;
              end
              default: begin
                // bit12 == 1: C.SUBW / C.ADDW (RV64) and reserved / Zcb slots
                c_illegal = bit12;
                case (funct2_arith)
                  2'b00:   c_expanded = enc_r(7'b0100000, rs2_p, rd_rs1_p, 3'b000, rd_rs1_p, OPC_OP);  // C.SUB
                  2'b01:   c_expanded = enc_r(7'b0000000, rs2_p, rd_rs1_p, 3'b100, rd_rs1_p, OPC_OP);  // C.XOR
                  2'b10:   c_expanded = enc_r(7'b0000000, rs2_p, rd_rs1_p, 3'b110, rd_rs1_p, OPC_OP);  // C.OR
                  default: c_expanded = enc_r(7'b0000000, rs2_p, rd_rs1_p, 3'b111, rd_rs1_p, OPC_OP);  // C.AND
                endcase
              end
            endcase
          end
          3'b101: begin  // C.J
            c_expanded = enc_j(imm_j_j, X0);
            c_illegal  = 1'b0;
          end
          3'b110: begin  // C.BEQZ
            c_expanded = enc_b(imm_b_b, rd_rs1_p, 3'b000);
            c_illegal  = 1'b0;
          end
          default: begin // 3'b111: C.BNEZ
            c_expanded = enc_b(imm_b_b, rd_rs1_p, 3'b001);
            c_illegal  = 1'b0;
          end
        endcase
      end
      // ----- quadrant 2 -----
      2'b10: begin
        case (funct3)
          3'b000: begin  // C.SLLI (shamt[5] == 1: RV32 NSE; rd == 0 or shamt == 0: HINT)
            c_expanded = enc_i({7'b0000000, shamt[4:0]}, rd_rs1, 3'b001, rd_rs1, OPC_OP_IMM);
            c_illegal  = shamt[5];
          end
          3'b010: begin  // C.LWSP (rd == 0 reserved)
            c_expanded = enc_i({4'b0000, imm_lwsp}, X2, 3'b010, rd_rs1, OPC_LOAD);
            c_illegal  = (rd_rs1 == X0);
          end
          3'b100: begin
            if (!bit12) begin
              if (rs2 == X0) begin  // C.JR (rs1 == 0 reserved)
                c_expanded = enc_i(12'd0, rd_rs1, 3'b000, X0, OPC_JALR);
                c_illegal  = (rd_rs1 == X0);
              end else begin        // C.MV (rd == 0: HINT)
                c_expanded = enc_r(7'b0000000, rs2, X0, 3'b000, rd_rs1, OPC_OP);
                c_illegal  = 1'b0;
              end
            end else begin
              if (rs2 == X0 && rd_rs1 == X0) begin  // C.EBREAK
                c_expanded = EBREAK;
                c_illegal  = 1'b0;
              end else if (rs2 == X0) begin         // C.JALR
                c_expanded = enc_i(12'd0, rd_rs1, 3'b000, X1, OPC_JALR);
                c_illegal  = 1'b0;
              end else begin                        // C.ADD (rd == 0: HINT)
                c_expanded = enc_r(7'b0000000, rs2, rd_rs1, 3'b000, rd_rs1, OPC_OP);
                c_illegal  = 1'b0;
              end
            end
          end
          3'b110: begin  // C.SWSP
            c_expanded = enc_s({4'b0000, imm_swsp}, rs2, X2, 3'b010);
            c_illegal  = 1'b0;
          end
          default: ;     // C.FLDSP, C.FLWSP, C.FSDSP, C.FSWSP
        endcase
      end
      default: ;         // 2'b11: not a 16-bit instruction (is32)
    endcase
    if (c_illegal) begin
      c_expanded = '0;
    end
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign instr_out = is32 ? instr_in : c_expanded;
  assign illegal   = !is32 && c_illegal;

endmodule
