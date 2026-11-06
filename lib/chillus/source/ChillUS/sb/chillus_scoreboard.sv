// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_scoreboard
//
// Operand hazards of the in-order pipeline id -> ex -> wb (pipeline-aware:
// uses the STAGE_* indices). The register file is read in id; the operands
// are registered into ex here and forwarded (bypassed) in ex:
//
//   rs*_data (ex) = result_wb    if rs*_ex == rd_wb != x0
//                   operand register (register file value read in id)
//
// The selection (rs*_src) is decided in id, against the producer one stage
// ahead (rd_ex -> wb), and registered, so the ex operand path is a 2:1 mux
// from registers (no register-index compare).
//
// Producers covered: an instruction in wb (result register, computed in ex).
// A producer that is in wb while the consumer is in id is covered by the
// register file's write-before-read bypass (chillus_rf BYPASS = 1). While ex
// is held, its operand registers re-capture the forwarded value, so a
// producer that leaves wb during the hold is not lost.
//
// Load-use hazard: a load's data exists only in wb (rvalid), so a load in ex
// whose rd is read by the instruction in id stalls id for one cycle
// (load_use -> stall[STAGE_ID]); the consumer then reads the load value in
// id through the register file bypass when the load writes it. A late MUL
// (late_ex, chillus_mdu: product in wb) is treated the same way.
// x0 is never forwarded; rd / rs are 0 for bubbles and for instructions that
// do not write / read a register (decoder), so they never match.
//
// Timing   : rs*_data (a mux on registered rs*_src) and load_use are
//            combinational; operand and selection registers load every
//            cycle (bubble = 0, SRC_REG).
// Invariant: no instruction in ex reads the rd of a load or a late MUL in
//            wb (prevented by load_use).
//            rs*_data equals the forwarding decided in ex from rs*_ex and
//            rd_wb (the registered selection is exact).
// Debug    : rs1_src / rs2_src (enum) show where each ex operand comes from;
//            rs1_reg / rs2_reg are the operand registers.
// -----------------------------------------------------------------------------
module chillus_scoreboard
  import chillus_dec_pkg::*;
#(
  parameter int XLEN = 32                          // register width
) (
  input  logic                clk,
  input  logic                rst_n,               // async, active-low
  // pipeline control (decoder)
  input  logic [N_STAGES-1:0] hold,
  input  logic [N_STAGES-1:0] kill,
  // id: consumer and register file read
  input  logic                valid_id,
  input  logic [4:0]          rs1_id,
  input  logic [4:0]          rs2_id,
  input  logic [4:0]          dec_rs1_id,          // decoder's rs1 (0 when the instruction does not read it)
  input  logic [4:0]          dec_rs2_id,
  input  logic [XLEN-1:0]     rf_rs1_data,         // register file read of rs1_id
  input  logic [XLEN-1:0]     rf_rs2_data,         // register file read of rs2_id
  // ex: a possible load producer, and the producer forwarded from wb next cycle
  input  logic [4:0]          rd_ex,
  input  mem_op_e             mem_op_ex,
  input  logic                late_ex,             // late MUL in ex (chillus_mdu.late): result only in wb
  // wb: producer
  input  logic [XLEN-1:0]     result_wb,           // result register (computed in ex; not loads / late MUL)
  // outputs
  output logic [XLEN-1:0]     rs1_data,            // ex operand, hazards resolved
  output logic [XLEN-1:0]     rs2_data,
  output logic                load_use             // stall id for one cycle
);

  typedef enum logic {
    SRC_REG = 1'b0,                                // operand register (read in id)
    SRC_WB  = 1'b1                                 // forwarded from wb
  } src_e;

  logic            adv_id;      // the id instruction moves to ex at this edge
  logic            keep_ex;     // the ex instruction stays (held, not killed)
  logic [XLEN-1:0] rs1_reg;     // ex operand registers
  logic [XLEN-1:0] rs2_reg;
  logic [XLEN-1:0] rs1_reg_d;
  logic [XLEN-1:0] rs2_reg_d;
  src_e            rs1_src;     // forwarding selection (registered view)
  src_e            rs2_src;
  src_e            rs1_src_d;   // forwarding selection decided in id
  src_e            rs2_src_d;
  logic            rs1_src_q;   // u_rs*_src flop outputs
  logic            rs2_src_q;
  logic            load_ex;     // a load or late MUL that writes a register is in ex

  // ---------------------------------------------------------------------------
  // Operand registers id -> ex
  // ---------------------------------------------------------------------------
  assign adv_id  = valid_id && !hold[STAGE_ID] && !kill[STAGE_ID];
  assign keep_ex = hold[STAGE_EX] && !kill[STAGE_EX];

  assign rs1_reg_d = keep_ex ? rs1_data : (adv_id ? rf_rs1_data : '0);
  assign rs2_reg_d = keep_ex ? rs2_data : (adv_id ? rf_rs2_data : '0);

  basechili_dff #(.WIDTH(XLEN)) u_rs1_reg (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rs1_reg_d),
    .q     (rs1_reg)
  );

  basechili_dff #(.WIDTH(XLEN)) u_rs2_reg (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rs2_reg_d),
    .q     (rs2_reg)
  );

  // ---------------------------------------------------------------------------
  // Forwarding selection, decided in id and registered. When the id
  // instruction advances, the ex instruction advances too: the producer now
  // in ex is in wb next cycle (the one now in wb writes the register file
  // this cycle, seen through its bypass). A held ex instruction re-captured
  // its forwarded operands, so it reads its registers (SRC_REG).
  // ---------------------------------------------------------------------------
  always_comb begin
    rs1_src_d = SRC_REG;
    rs2_src_d = SRC_REG;
    if (adv_id && !keep_ex) begin
      if ((dec_rs1_id != '0) && (dec_rs1_id == rd_ex)) rs1_src_d = SRC_WB;
      if ((dec_rs2_id != '0) && (dec_rs2_id == rd_ex)) rs2_src_d = SRC_WB;
    end
  end

  basechili_dff #(.WIDTH(1)) u_rs1_src (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rs1_src_d),
    .q     (rs1_src_q)
  );

  basechili_dff #(.WIDTH(1)) u_rs2_src (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rs2_src_d),
    .q     (rs2_src_q)
  );

  assign rs1_src = src_e'(rs1_src_q);
  assign rs2_src = src_e'(rs2_src_q);

  always_comb begin
    case (rs1_src)
      SRC_WB:  rs1_data = result_wb;
      SRC_REG: rs1_data = rs1_reg;
      default: rs1_data = rs1_reg;
    endcase
    case (rs2_src)
      SRC_WB:  rs2_data = result_wb;
      SRC_REG: rs2_data = rs2_reg;
      default: rs2_data = rs2_reg;
    endcase
  end

  // ---------------------------------------------------------------------------
  // Load-use hazard
  // ---------------------------------------------------------------------------
  assign load_ex  = ((mem_op_ex == MEM_OP_LOAD) || late_ex) && (rd_ex != '0);
  assign load_use = load_ex && (((rs1_id != '0) && (rs1_id == rd_ex)) ||
                                ((rs2_id != '0) && (rs2_id == rd_ex)));

endmodule
