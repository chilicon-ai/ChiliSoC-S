// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_rsdec
//
// Source-register numbers of the fetched instruction, decoded straight from
// its raw 16-bit (RV32C) or 32-bit encoding, in parallel with chillus_rvc and
// chillus_dec. Stage-agnostic (first top: id). It feeds the register file read
// and the scoreboard's load-use check, which then do not wait for the
// expander and the full decoder (timing).
//
// rs1 / rs2 = the register the instruction reads, 0 (x0) when it reads none,
// equal to chillus_dec's rs1_id / rs2_id for every legal instruction:
//   32-bit (opcode)  rs1: LOAD, STORE, OP-IMM, OP, BRANCH, JALR,
//                         SYSTEM with funct3 001 / 010 / 011 (CSRRW/S/C)
//                    rs2: STORE, OP, BRANCH
//   16-bit (quadrant, funct3, as the RVC expansion reads them)
//     Q0 000 c.addi4spn rs1 = x2         010 c.lw rs1'
//        110 c.sw       rs1', rs2'
//     Q1 000 c.addi     rs1 = rd         011 c.addi16sp (rd = x2) rs1 = x2
//        100 c.srli / srai / andi rs1'; c.sub / xor / or / and rs1', rs2'
//        110 / 111 c.beqz / bnez rs1'
//     Q2 000 c.slli     rs1 = rd         010 c.lwsp rs1 = x2
//        100 c.jr / c.jalr rs1; c.mv rs2; c.add rs1 = rd, rs2
//        110 c.swsp     rs1 = x2, rs2
// Illegal or reserved encodings may give nonzero numbers (chillus_dec gives
// 0): the only effect is a possible extra load-use stall for an instruction
// that traps anyway.
//
// Timing   : combinational from instr / is32 / valid / fault.
// Invariant: valid && !fault && the instruction is legal -> rs1 ==
//            u_dec.rs1_id and rs2 == u_dec.rs2_id (checked exhaustively for
//            16-bit and per opcode for 32-bit).
// Debug    : wrong register read in id -> compare rs1 / rs2 with
//            u_dec.rs1_id / rs2_id; use32_* / use16_* show the decision.
// -----------------------------------------------------------------------------
module chillus_rsdec (
  input  logic        valid,              // an instruction is presented
  input  logic        fault,              // fetch error: no registers read
  input  logic [31:0] instr,              // as fetched (16-bit in [15:0])
  input  logic        is32,               // 32-bit instruction
  output logic [4:0]  rs1,
  output logic [4:0]  rs2
);

  localparam logic [6:0] OPC_LOAD   = 7'b0000011;
  localparam logic [6:0] OPC_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPC_STORE  = 7'b0100011;
  localparam logic [6:0] OPC_OP     = 7'b0110011;
  localparam logic [6:0] OPC_BRANCH = 7'b1100011;
  localparam logic [6:0] OPC_JALR   = 7'b1100111;
  localparam logic [6:0] OPC_SYSTEM = 7'b1110011;
  localparam logic [4:0] X2         = 5'd2;

  // 32-bit
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic       use32_rs1;          // the 32-bit instruction reads rs1
  logic       use32_rs2;
  // 16-bit fields
  logic [1:0] quadrant;
  logic [2:0] c_funct3;
  logic [4:0] c_rd_rs1;           // [11:7]
  logic [4:0] c_rs2;              // [6:2]
  logic [4:0] c_rs1_p;            // x8 + [9:7]
  logic [4:0] c_rs2_p;            // x8 + [4:2]
  logic [4:0] rs1_16;             // register numbers of the 16-bit instruction
  logic [4:0] rs2_16;
  logic [4:0] rs1_32;
  logic [4:0] rs2_32;
  logic       live;               // valid && !fault

  // ---------------------------------------------------------------------------
  // 32-bit: by opcode
  // ---------------------------------------------------------------------------
  assign opcode    = instr[6:0];
  assign funct3    = instr[14:12];
  assign use32_rs1 = (opcode == OPC_LOAD)   || (opcode == OPC_STORE)  ||
                     (opcode == OPC_OP_IMM) || (opcode == OPC_OP)     ||
                     (opcode == OPC_BRANCH) || (opcode == OPC_JALR)   ||
                     ((opcode == OPC_SYSTEM) && (funct3[2] == 1'b0) && (funct3[1:0] != 2'b00));
  assign use32_rs2 = (opcode == OPC_STORE)  || (opcode == OPC_OP)     ||
                     (opcode == OPC_BRANCH);
  assign rs1_32    = use32_rs1 ? instr[19:15] : '0;
  assign rs2_32    = use32_rs2 ? instr[24:20] : '0;

  // ---------------------------------------------------------------------------
  // 16-bit: by quadrant / funct3 (as chillus_rvc expands them)
  // ---------------------------------------------------------------------------
  assign quadrant = instr[1:0];
  assign c_funct3 = instr[15:13];
  assign c_rd_rs1 = instr[11:7];
  assign c_rs2    = instr[6:2];
  assign c_rs1_p  = {2'b01, instr[9:7]};
  assign c_rs2_p  = {2'b01, instr[4:2]};

  always_comb begin
    rs1_16 = '0;
    rs2_16 = '0;
    case (quadrant)
      2'b00: begin
        case (c_funct3)
          3'b000:  rs1_16 = X2;                              // c.addi4spn
          3'b010:  rs1_16 = c_rs1_p;                         // c.lw
          3'b110:  begin rs1_16 = c_rs1_p; rs2_16 = c_rs2_p; end   // c.sw
          default: ;
        endcase
      end
      2'b01: begin
        case (c_funct3)
          3'b000:  rs1_16 = c_rd_rs1;                        // c.addi / c.nop
          3'b011:  if (c_rd_rs1 == X2) rs1_16 = X2;          // c.addi16sp (c.lui: none)
          3'b100:  begin                                     // c.srli / srai / andi / arith
            rs1_16 = c_rs1_p;
            if (instr[11:10] == 2'b11) rs2_16 = c_rs2_p;     // c.sub / xor / or / and
          end
          3'b110,
          3'b111:  rs1_16 = c_rs1_p;                         // c.beqz / c.bnez
          default: ;                                         // c.jal, c.li, c.j
        endcase
      end
      2'b10: begin
        case (c_funct3)
          3'b000:  rs1_16 = c_rd_rs1;                        // c.slli
          3'b010:  rs1_16 = X2;                              // c.lwsp
          3'b100:  begin
            if (c_rs2 == '0) begin
              rs1_16 = c_rd_rs1;                             // c.jr / c.jalr (c.ebreak: 0)
            end else begin
              rs2_16 = c_rs2;                                // c.mv / c.add
              if (instr[12]) rs1_16 = c_rd_rs1;              // c.add
            end
          end
          3'b110:  begin rs1_16 = X2; rs2_16 = c_rs2; end    // c.swsp
          default: ;
        endcase
      end
      default: ;
    endcase
  end

  // ---------------------------------------------------------------------------
  // select
  // ---------------------------------------------------------------------------
  assign live = valid && !fault;
  assign rs1  = !live ? '0 : is32 ? rs1_32 : rs1_16;
  assign rs2  = !live ? '0 : is32 ? rs2_32 : rs2_16;

endmodule
