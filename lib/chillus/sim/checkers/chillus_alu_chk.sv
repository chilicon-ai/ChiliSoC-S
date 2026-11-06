// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_alu_chk (chillus_alu is combinational: bound into
// chillus_core for its clock, connected to u_alu's ports)
//   - result == the header's operation table on the header's operand
//     selection (a = rs1_data | pc | 0, b = rs2_data | imm), every cycle
// -----------------------------------------------------------------------------
module chillus_alu_chk
  import chillus_dec_pkg::*;
(
  input logic            clk,
  input logic            rst_n,
  input alu_op_e         alu_op,
  input alu_src1_e       alu_src1,
  input alu_src2_e       alu_src2,
  input logic [XLEN-1:0] rs1_data,
  input logic [XLEN-1:0] rs2_data,
  input logic [XLEN-1:0] pc,
  input logic [XLEN-1:0] imm,
  input logic [XLEN-1:0] result
);

  logic [XLEN-1:0] a, b, exp;
  logic [4:0]      sh;

  always_comb begin
    case (alu_src1)
      ALU_SRC1_PC:   a = pc;
      ALU_SRC1_ZERO: a = '0;
      default:       a = rs1_data;
    endcase
    b  = (alu_src2 == ALU_SRC2_IMM) ? imm : rs2_data;
    sh = b[4:0];
    case (alu_op)
      ALU_OP_ADD:  exp = a + b;
      ALU_OP_SUB:  exp = a - b;
      ALU_OP_SLL:  exp = a << sh;
      ALU_OP_SLT:  exp = XLEN'($signed(a) < $signed(b));
      ALU_OP_SLTU: exp = XLEN'(a < b);
      ALU_OP_XOR:  exp = a ^ b;
      ALU_OP_SRL:  exp = a >> sh;
      ALU_OP_SRA:  exp = XLEN'($signed(a) >>> sh);
      ALU_OP_OR:   exp = a | b;
      ALU_OP_AND:  exp = a & b;
      default:     exp = result;
    endcase
  end

  assert property (@(posedge clk) disable iff (!rst_n) result == exp)
    else $error("chillus_alu: result != operation table: op=%s a=%h b=%h result=%h expected=%h",
                alu_op.name(), a, b, result, exp);

endmodule

bind chillus_core chillus_alu_chk u_alu_chk (
  .clk      (clk),
  .rst_n    (rst_n),
  .alu_op   (u_alu.alu_op),
  .alu_src1 (u_alu.alu_src1),
  .alu_src2 (u_alu.alu_src2),
  .rs1_data (u_alu.rs1_data),
  .rs2_data (u_alu.rs2_data),
  .pc       (u_alu.pc),
  .imm      (u_alu.imm),
  .result   (u_alu.result)
);
