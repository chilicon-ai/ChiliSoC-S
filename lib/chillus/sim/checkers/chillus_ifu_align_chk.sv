// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_ifu_align_chk (bound into chillus_ifu_align)
//   - pc[0] == 0                                        (header Invariant)
//   - dec_valid -> the words it needs are in the buffer (word0; word1 for a
//     32-bit instruction in the upper half)
//   - 16-bit instruction: dec_instr[31:16] == 0          (port comment)
//   - buf_pop only on dec_fire (head word consumed)
//   - decoder handshake (BaseChiliSV doc/valid_accept_handshake.md): dec_valid &&
//     !dec_accept && !redirect_valid -> next cycle dec_valid with the same
//     dec_instr / dec_pc / dec_is32 (a redirect flushes, so it is exempt)
//   - pc: redirect -> next pc == redirect_pc; dec_fire -> pc + 2 / + 4
// -----------------------------------------------------------------------------
module chillus_ifu_align_chk #(
  parameter int ADDR_W = 32,
  parameter int CNT_W  = 3
) (
  input logic              clk,
  input logic              rst_n,
  input logic              redirect_valid,
  input logic [ADDR_W-1:0] redirect_pc,
  input logic [CNT_W-1:0]  buf_count,
  input logic              buf_pop,
  input logic [ADDR_W-1:0] pc,
  input logic              dec_valid,
  input logic              dec_accept,
  input logic [31:0]       dec_instr,
  input logic [ADDR_W-1:0] dec_pc,
  input logic              dec_is32
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  logic dec_fire;
  assign dec_fire = dec_valid && dec_accept;

  `CHK(pc[0] == 1'b0,
       ("chillus_ifu_align: pc[0] == 0 violated: pc=%h", pc))
  `CHK(dec_valid |-> buf_count != '0 && (!(dec_is32 && pc[1]) || 32'(buf_count) >= 2),
       ("chillus_ifu_align: dec_valid without its buffer words: buf_count=%0d is32=%b pc=%h",
        buf_count, dec_is32, pc))
  `CHK(dec_valid && !dec_is32 |-> dec_instr[31:16] == 16'h0,
       ("chillus_ifu_align: 16-bit dec_instr upper half zero violated: dec_instr=%h", dec_instr))
  `CHK(buf_pop |-> dec_fire,
       ("chillus_ifu_align: buf_pop without dec_fire: dec_valid=%b dec_accept=%b", dec_valid, dec_accept))
  `CHK(dec_valid && !dec_accept && !redirect_valid |=>
       dec_valid && $stable(dec_instr) && $stable(dec_pc) && $stable(dec_is32),
       ("chillus_ifu_align: dec handshake hold violated: dec_valid=%b instr=%h (was %h) pc=%h (was %h)",
        dec_valid, dec_instr, $past(dec_instr), dec_pc, $past(dec_pc)))
  `CHK(redirect_valid |=> pc == $past(redirect_pc),
       ("chillus_ifu_align: pc after redirect violated: pc=%h redirect_pc=%h", pc, $past(redirect_pc)))
  `CHK(dec_fire && !redirect_valid |=> pc == $past(pc) + (($past(dec_is32)) ? ADDR_W'(4) : ADDR_W'(2)),
       ("chillus_ifu_align: pc + 2 / 4 after dec_fire violated: pc=%h before=%h is32=%b",
        pc, $past(pc), $past(dec_is32)))
  `CHK(!dec_fire && !redirect_valid |=> $stable(pc),
       ("chillus_ifu_align: pc changed without dec_fire / redirect: pc=%h before=%h", pc, $past(pc)))
  `CHK(dec_pc == pc,
       ("chillus_ifu_align: dec_pc == pc violated: dec_pc=%h pc=%h", dec_pc, pc))

  `undef CHK

endmodule

bind chillus_ifu_align chillus_ifu_align_chk #(
  .ADDR_W (ADDR_W),
  .CNT_W  (CNT_W)
) u_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .redirect_valid (redirect_valid),
  .redirect_pc    (redirect_pc),
  .buf_count      (buf_count),
  .buf_pop        (buf_pop),
  .pc             (pc),
  .dec_valid      (dec_valid),
  .dec_accept     (dec_accept),
  .dec_instr      (dec_instr),
  .dec_pc         (dec_pc),
  .dec_is32       (dec_is32)
);
