// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_alu
//
// Integer ALU for RV32I (riscv-unprivileged.pdf, Chapter 2.4). Combinational
// and stage-agnostic: it computes result = alu_op(a, b) for one instruction
// from the decoder indications of whatever stage it is placed in.
//
//   a = rs1_data | pc | 0      (alu_src1)
//   b = rs2_data | imm         (alu_src2)
//
//   ADD  a + b              SLL  a << b[SHAMT_W-1:0]
//   SUB  a - b              SRL  a >> b[SHAMT_W-1:0]  (zero fill)
//   SLT  a < b  signed      SRA  a >> b[SHAMT_W-1:0]  (sign fill)
//   SLTU a < b  unsigned    XOR / OR / AND  bitwise
//
// Uses: arithmetic / logic (OP, OP-IMM), LUI (0 + imm), AUIPC (pc + imm),
// the load / store address (ADD rs1 + imm: result goes to chillus_lsu) and
// the branch compare for chillus_bru (hardware alu_adder /
// alu_logic):
//   cmp_eq  rs1 == rs2: the reduction of op_a ^ op_b, whatever alu_op
//   cmp_lt  a < b: signed for SLT, unsigned for SLTU (the decoder sets SLT
//           for BLT / BGE and SLTU for BLTU / BGEU)
// Jump targets and the branch target are computed by chillus_bru.
// imm arrives sign-extended from the decoder, so SLTIU compares the
// sign-extended immediate as unsigned, as the ISA requires. Overflow is
// ignored (low XLEN bits); the ALU raises no exceptions. Branch comparison
// and write-back selection are outside the ALU.
//
// Implementation: one adder serves ADD, SUB, SLT and SLTU. For SUB / SLT /
// SLTU it computes a + ~b + 1 = a - b; then carry = 1 <-> a >= b unsigned, and
// a < b signed is a's sign when the signs differ, else the difference's sign.
//
// Timing   : combinational, no state.
// Invariant: cmp_eq == (op_a == op_b); alu_op == SLTU -> cmp_lt == (op_a < op_b)
//            unsigned; alu_op == SLT -> cmp_lt == (op_a < op_b) signed.
// Debug    : op_a / op_b show the selected operands; sum, carry, lt_signed,
//            lt_unsigned and the shift results are named per operation.
//            Wrong load/store address: alu_op must be ADD and alu_src2 IMM.
// -----------------------------------------------------------------------------
module chillus_alu
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                      // operand width (RV32: 32)
) (
  // decoder indications
  input  alu_op_e         alu_op,
  input  alu_src1_e       alu_src1,
  input  alu_src2_e       alu_src2,
  // operand values
  input  logic [XLEN-1:0] rs1_data,            // x[rs1] (after forwarding)
  input  logic [XLEN-1:0] rs2_data,            // x[rs2] (after forwarding)
  input  logic [XLEN-1:0] pc,                  // address of this instruction
  input  logic [XLEN-1:0] imm,                 // decoded immediate, already extended
  // result
  output logic [XLEN-1:0] result,
  // branch compare (chillus_bru)
  output logic            cmp_eq,              // op_a == op_b
  output logic            cmp_lt               // op_a < op_b: unsigned for SLTU, else signed
);

  localparam int SHAMT_W = $clog2(XLEN);       // shift amount bits (5 for RV32)

  logic [XLEN-1:0]    op_a;           // first operand
  logic [XLEN-1:0]    op_b;           // second operand
  logic               subtract;       // adder computes a - b (SUB, SLT, SLTU)
  logic [XLEN-1:0]    add_b;          // b or ~b into the adder
  logic [XLEN-1:0]    sum;            // a + b, or a - b when subtract
  logic               carry;          // adder carry out; a >= b unsigned when subtract
  logic               lt_signed;      // a < b, signed
  logic               lt_unsigned;    // a < b, unsigned
  logic [SHAMT_W-1:0] shamt;          // shift amount
  logic [XLEN-1:0]    sll_res;
  logic [XLEN-1:0]    srl_res;
  logic [XLEN-1:0]    sra_res;
  logic [XLEN-1:0]    xor_res;        // op_a ^ op_b (XOR, and cmp_eq)

  // ---------------------------------------------------------------------------
  // Operand selection
  // ---------------------------------------------------------------------------
  always_comb begin
    case (alu_src1)
      ALU_SRC1_RS1:  op_a = rs1_data;
      ALU_SRC1_PC:   op_a = pc;
      ALU_SRC1_ZERO: op_a = '0;
      default:       op_a = '0;
    endcase
  end

  assign op_b = (alu_src2 == ALU_SRC2_IMM) ? imm : rs2_data;

  // ---------------------------------------------------------------------------
  // Shared adder / subtractor and comparisons
  // ---------------------------------------------------------------------------
  assign subtract = (alu_op == ALU_OP_SUB) || (alu_op == ALU_OP_SLT) ||
                    (alu_op == ALU_OP_SLTU);
  assign add_b    = subtract ? ~op_b : op_b;

  assign {carry, sum} = {1'b0, op_a} + {1'b0, add_b} + (XLEN+1)'(subtract);

  assign lt_unsigned = !carry;
  assign lt_signed   = (op_a[XLEN-1] != op_b[XLEN-1]) ? op_a[XLEN-1] : sum[XLEN-1];
  assign xor_res     = op_a ^ op_b;
  assign cmp_eq      = (xor_res == '0);
  assign cmp_lt      = (alu_op == ALU_OP_SLTU) ? lt_unsigned : lt_signed;

  // ---------------------------------------------------------------------------
  // Shifts
  // ---------------------------------------------------------------------------
  assign shamt   = op_b[SHAMT_W-1:0];
  assign sll_res = op_a << shamt;
  assign srl_res = op_a >> shamt;
  assign sra_res = unsigned'($signed(op_a) >>> shamt);

  // ---------------------------------------------------------------------------
  // Result
  // ---------------------------------------------------------------------------
  always_comb begin
    case (alu_op)
      ALU_OP_ADD:  result = sum;
      ALU_OP_SUB:  result = sum;
      ALU_OP_SLL:  result = sll_res;
      ALU_OP_SLT:  result = XLEN'(lt_signed);
      ALU_OP_SLTU: result = XLEN'(lt_unsigned);
      ALU_OP_XOR:  result = xor_res;
      ALU_OP_SRL:  result = srl_res;
      ALU_OP_SRA:  result = sra_res;
      ALU_OP_OR:   result = op_a | op_b;
      ALU_OP_AND:  result = op_a & op_b;
      default:     result = '0;
    endcase
  end

endmodule
