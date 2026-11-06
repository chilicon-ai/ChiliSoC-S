// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_rvc_chk (chillus_rvc is combinational: bound into
// chillus_core for its clock, connected to u_rvc's ports)
//   - illegal == 0 whenever is32                         (header Invariant)
//   - instr_out[1:0] == 2'b11 whenever !illegal          (header Invariant)
//   - illegal -> instr_out == 0; is32 -> instr_out == instr_in (header)
// -----------------------------------------------------------------------------
module chillus_rvc_chk (
  input logic        clk,
  input logic        rst_n,
  input logic [31:0] instr_in,
  input logic        is32,
  input logic [31:0] instr_out,
  input logic        illegal
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(is32 |-> !illegal && instr_out == instr_in,
       ("chillus_rvc: is32 -> !illegal, pass-through violated: instr_in=%h instr_out=%h illegal=%b",
        instr_in, instr_out, illegal))
  `CHK(!illegal |-> instr_out[1:0] == 2'b11,
       ("chillus_rvc: !illegal -> instr_out[1:0] == 11 violated: instr_in=%h instr_out=%h", instr_in, instr_out))
  `CHK(illegal |-> instr_out == '0,
       ("chillus_rvc: illegal -> instr_out == 0 violated: instr_in=%h instr_out=%h", instr_in, instr_out))

  `undef CHK

endmodule

bind chillus_core chillus_rvc_chk u_rvc_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .instr_in  (u_rvc.instr_in),
  .is32      (u_rvc.is32),
  .instr_out (u_rvc.instr_out),
  .illegal   (u_rvc.illegal)
);
