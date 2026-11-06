// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_ifu_align
//
// IFU instruction aligner. Holds the architectural PC and extracts the next
// 16-bit or 32-bit instruction from the two oldest prefetch-buffer words.
// The read position is the head word plus pc[1] (halfword select), so the
// read pointer has 16-bit granularity without a separate halfword register.
//
//   pc[1] = 0: low half = word0[15:0],  high half = word0[31:16]
//   pc[1] = 1: low half = word0[31:16], high half = word1[15:0]
//
// An instruction is 32-bit when its low half has bits [1:0] == 2'b11.
// On accept, pc advances by 2 or 4 and the head word is popped when the
// read position leaves it (pc[1] was set, or a 32-bit instruction).
//
// dec_fault: a word the instruction uses has a fetch error; dec_fault_hi:
// only the word of its second halfword (pc[1] = 1, 32-bit), so the faulting
// address is pc + 2 (mtval), else pc.
//
// Timing    : dec_* is combinational from pc and the buffer head words; pc
//             and the buffer head update on the edge after dec_fire.
// Invariant : pc[0] == 0 (a set bit means redirect_pc was odd).
//             dec_fault_hi -> dec_fault.
// Debug     : instr_lo / instr_hi show the halfwords picked for dec_instr;
//             have_word0 / have_word1 show why dec_valid is low.
// -----------------------------------------------------------------------------
module chillus_ifu_align #(
  parameter  int                ADDR_W   = 32,    // address width in bits
  parameter  int                DEPTH    = 4,     // prefetch buffer depth in words
  localparam int                CNT_W    = $clog2(DEPTH + 1),
  localparam int                ENTRY_W  = 33     // {fetch error, 32-bit word}
) (
  input  logic                 clk,
  input  logic                 rst_n,           // async, active-low
  // redirect
  input  logic                 redirect_valid,
  input  logic [ADDR_W-1:0]    redirect_pc,
  // prefetch buffer
  input  logic [CNT_W-1:0]     buf_count,       // valid words in the buffer
  input  logic [2*ENTRY_W-1:0] buf_rdata,       // head word, then the next word
  output logic                 buf_pop,
  output logic [ADDR_W-1:0]    pc,              // architectural PC
  // decoder interface
  output logic                 dec_valid,
  input  logic                 dec_accept,
  output logic [31:0]          dec_instr,       // upper half zero for 16-bit
  output logic [ADDR_W-1:0]    dec_pc,
  output logic                 dec_is32,        // 32-bit instruction
  output logic                 dec_fault,       // fetch error on any word used
  output logic                 dec_fault_hi     // fetch error in the second halfword only (at dec_pc + 2)
);

  logic [31:0]       word0;          // head buffer word (oldest)
  logic [31:0]       word1;          // next buffer word
  logic              err0;           // fetch error of word0
  logic              err1;           // fetch error of word1
  logic              in_upper_half;  // pc[1]: instruction starts at word0[31:16]
  logic [15:0]       instr_lo;       // first halfword of the instruction
  logic [15:0]       instr_hi;       // second halfword (used only when is32)
  logic              is32;           // 32-bit instruction (instr_lo[1:0] == 2'b11)
  logic              have_word0;     // buffer holds word0
  logic              have_word1;     // buffer holds word0 and word1
  logic              dec_fire;       // decoder takes the instruction this cycle
  logic [ADDR_W-1:0] pc_step;        // 2 or 4
  logic [ADDR_W-1:0] pc_d;
  logic              pc_en;

  assign {err0, word0} = buf_rdata[0       +: ENTRY_W];
  assign {err1, word1} = buf_rdata[ENTRY_W +: ENTRY_W];

  assign in_upper_half = pc[1];
  assign instr_lo      = in_upper_half ? word0[31:16] : word0[15:0];
  assign instr_hi      = in_upper_half ? word1[15:0]  : word0[31:16];
  assign is32          = (instr_lo[1:0] == 2'b11);

  // ---------------------------------------------------------------------------
  // Decoder handshake (decoded from registered state only)
  // ---------------------------------------------------------------------------
  assign have_word0 = (buf_count != '0);
  assign have_word1 = (buf_count >= unsigned'(CNT_W'(2)));

  // word1 is needed only by a 32-bit instruction starting in the upper half.
  assign dec_valid = have_word0 && (!is32 || !in_upper_half || have_word1);
  assign dec_instr = is32 ? {instr_hi, instr_lo} : {16'h0000, instr_lo};
  assign dec_pc    = pc;
  assign dec_is32  = is32;
  assign dec_fault = err0 || (is32 && in_upper_half && err1);
  // A 32-bit instruction at pc[1] = 1 whose first halfword (word0) is good:
  // only its second halfword, at pc + 2 (word1), faulted.
  assign dec_fault_hi = !err0 && is32 && in_upper_half && err1;
  assign dec_fire  = dec_valid && dec_accept;

  // The head word is fully consumed when the read position moves past it.
  assign buf_pop = dec_fire && (in_upper_half || is32);

  // ---------------------------------------------------------------------------
  // Architectural PC (redirect has priority over consumption)
  // ---------------------------------------------------------------------------
  assign pc_step = ADDR_W'({is32, !is32, 1'b0});   // 4 or 2
  assign pc_d    = redirect_valid ? redirect_pc : pc + pc_step;
  assign pc_en   = redirect_valid || dec_fire;

  basechili_dffe #(.WIDTH(ADDR_W)) u_pc (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (pc_en),
    .d     (pc_d),
    .q     (pc)
  );

endmodule
