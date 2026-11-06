// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_rsdec_chk (cross-module invariant: bound into
// chillus_core, connected to u_rsdec's ports and u_dec's id signals)
//   - valid && !fault && the instruction is legal -> rs1 == u_dec.rs1_id and
//     rs2 == u_dec.rs2_id                                (header Invariant)
//   - !valid || fault -> rs1 == rs2 == 0 (no registers read)
// -----------------------------------------------------------------------------
module chillus_rsdec_chk (
  input logic       clk,
  input logic       rst_n,
  input logic       valid,
  input logic       fault,
  input logic [4:0] rs1,
  input logic [4:0] rs2,
  input logic       dec_illegal,
  input logic [4:0] dec_rs1,
  input logic [4:0] dec_rs2,
  input logic [31:0] instr,
  input logic       is32
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(valid && !fault && !dec_illegal |-> rs1 == dec_rs1 && rs2 == dec_rs2,
       ("chillus_rsdec: rs1 / rs2 == decoder's for a legal instruction violated: instr=%h is32=%b rs1=x%0d (dec x%0d) rs2=x%0d (dec x%0d)",
        instr, is32, rs1, dec_rs1, rs2, dec_rs2))
  `CHK(!valid || fault |-> rs1 == '0 && rs2 == '0,
       ("chillus_rsdec: no instruction / fetch fault -> rs1 == rs2 == 0 violated: valid=%b fault=%b rs1=x%0d rs2=x%0d",
        valid, fault, rs1, rs2))

  `undef CHK

endmodule

bind chillus_core chillus_rsdec_chk u_rsdec_chk (
  .clk         (clk),
  .rst_n       (rst_n),
  .valid       (u_rsdec.valid),
  .fault       (u_rsdec.fault),
  .rs1         (u_rsdec.rs1),
  .rs2         (u_rsdec.rs2),
  .dec_illegal (u_dec.illegal_id),
  .dec_rs1     (u_dec.rs1_id),
  .dec_rs2     (u_dec.rs2_id),
  .instr       (u_rsdec.instr),
  .is32        (u_rsdec.is32)
);
