// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_scoreboard_chk (bound into chillus_core: the invariant
// needs the decoder's wb stage; connected to u_sb's nets and u_dec's mem_op)
//   - no instruction in ex reads the rd of a load in wb (header Invariant;
//     prevented by load_use)
//   - forwarding never selects a load in wb (rs*_src == SRC_WB -> wb is not
//     a load)
//   - x0 is never forwarded (rs*_ex == 0 -> rs*_src == SRC_REG, data 0
//     because the decoder gives bubbles / non-readers rs = 0)
//   - the same for a late MUL (chillus_mdu.late) in wb
//   - load_use only for a load or late MUL in ex (rd != 0) read by id
//   - the registered selection is exact: rs*_data equals forwarding decided
//     in ex from rs*_ex and rd_wb (header Invariant)
// -----------------------------------------------------------------------------
module chillus_scoreboard_chk
  import chillus_dec_pkg::*;
(
  input logic            clk,
  input logic            rst_n,
  input logic [4:0]      rs1_ex,
  input logic [4:0]      rs2_ex,
  input logic [4:0]      rd_wb,
  input mem_op_e         mem_op_wb,
  input logic            rs1_src,
  input logic            rs2_src,
  input logic            load_use,
  input logic            valid_id,
  input logic [4:0]      rs1_id,
  input logic [4:0]      rs2_id,
  input logic [4:0]      rd_ex,
  input mem_op_e         mem_op_ex,
  input logic            late_ex,
  input logic            late_wb,       // u_result.late_wb
  input logic [31:0]     result_wb,
  input logic [31:0]     rs1_reg,
  input logic [31:0]     rs2_reg,
  input logic [31:0]     rs1_data,
  input logic [31:0]     rs2_data
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  localparam logic SRC_REG = 1'b0;
  localparam logic SRC_WB  = 1'b1;

  logic load_wb;   // a load / late MUL that writes a register is in wb
  assign load_wb = ((mem_op_wb == MEM_OP_LOAD) || late_wb) && (rd_wb != '0);

  `CHK(load_wb |-> rs1_ex != rd_wb && rs2_ex != rd_wb,
       ("chillus_scoreboard: ex reads the rd of a load / MUL in wb: rd_wb=x%0d rs1_ex=x%0d rs2_ex=x%0d",
        rd_wb, rs1_ex, rs2_ex))
  `CHK((rs1_src == SRC_WB || rs2_src == SRC_WB) |-> mem_op_wb != MEM_OP_LOAD && !late_wb,
       ("chillus_scoreboard: forwarding from a load / MUL in wb: rd_wb=x%0d rs1_src=%0d rs2_src=%0d",
        rd_wb, rs1_src, rs2_src))
  `CHK(rs1_ex == '0 |-> rs1_src == SRC_REG,
       ("chillus_scoreboard: x0 forwarded on rs1: rs1_src=%0d", rs1_src))
  `CHK(rs2_ex == '0 |-> rs2_src == SRC_REG,
       ("chillus_scoreboard: x0 forwarded on rs2: rs2_src=%0d", rs2_src))
  `CHK(load_use |-> (mem_op_ex == MEM_OP_LOAD || late_ex) && rd_ex != '0 && (rs1_id == rd_ex || rs2_id == rd_ex),
       ("chillus_scoreboard: load_use without a load-use hazard: mem_op_ex=%0d rd_ex=x%0d rs1_id=x%0d rs2_id=x%0d valid_id=%b",
        mem_op_ex, rd_ex, rs1_id, rs2_id, valid_id))

  logic [31:0] ref1, ref2;   // forwarding decided in ex
  always_comb begin
    ref1 = rs1_reg;
    if (rs1_ex != '0 && rs1_ex == rd_wb) ref1 = result_wb;
    ref2 = rs2_reg;
    if (rs2_ex != '0 && rs2_ex == rd_wb) ref2 = result_wb;
  end
  `CHK(rs1_data == ref1 && rs2_data == ref2,
       ("chillus_scoreboard: registered forwarding differs: rs1_ex=x%0d rs2_ex=x%0d rd_wb=x%0d rs1_src=%0d rs2_src=%0d rs1_data=%h ref=%h rs2_data=%h ref=%h",
        rs1_ex, rs2_ex, rd_wb, rs1_src, rs2_src, rs1_data, ref1, rs2_data, ref2))

  `undef CHK

endmodule

bind chillus_core chillus_scoreboard_chk u_sb_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .rs1_ex     (u_dec.rs1_ex),
  .rs2_ex     (u_dec.rs2_ex),
  .rd_wb      (rd_wb),
  .mem_op_wb  (u_dec.mem_op_wb),
  .rs1_src    (u_sb.rs1_src),
  .rs2_src    (u_sb.rs2_src),
  .load_use   (u_sb.load_use),
  .valid_id   (u_sb.valid_id),
  .rs1_id     (u_sb.rs1_id),
  .rs2_id     (u_sb.rs2_id),
  .rd_ex      (u_sb.rd_ex),
  .mem_op_ex  (u_sb.mem_op_ex),
  .late_ex    (u_sb.late_ex),
  .late_wb    (u_result.late_wb),
  .result_wb  (u_sb.result_wb),
  .rs1_reg    (u_sb.rs1_reg),
  .rs2_reg    (u_sb.rs2_reg),
  .rs1_data   (u_sb.rs1_data),
  .rs2_data   (u_sb.rs2_data)
);
