// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_ifu
//
// Instruction Fetch Unit. Prefetches aligned 32-bit words from the MSS into
// a DEPTH-word circular buffer and presents one 16-bit or 32-bit RISC-V
// instruction at a time, with its PC, to the decoder.
//
//   u_fetch (chillus_ifu_fetch)   : fetch address, request flow control,
//                                   stale-response drop
//   u_buf   (basechili_peek_fifo) : circular prefetch buffer ({error, word} entries)
//   u_align (chillus_ifu_align)   : PC, halfword read position, instruction
//                                   assembly
//
//   Data flow: mss_rvalid / mss_rdata -> u_fetch (buf_push) -> u_buf -> u_align -> dec_*
//
// PMP: rsp_addr is the address of a response word (pc's word + buf_count,
// from registers); rsp_deny marks it faulting like mss_err, so the PMP check
// is on the response, not on the request (fetches have no side effects).
//
// A redirect flushes the buffer, drops in-flight responses, restarts fetch
// at redirect_pc & ~3 and presents redirect_pc as the next instruction PC.
// An instruction accepted in the redirect cycle belongs to the old stream.
// halt (boot, WFI) stops new fetch requests; idle reports that fetch has
// drained. After reset the PC is 0 and halt is high: the core redirects to
// its boot address before the first request.
//
// Timing
//   A response arriving in cycle t can be presented on dec_* in cycle t+1 at
//   the earliest. dec_valid is decoded from registers only; so are
//   mss_req / mss_addr, except in a fast_valid redirect cycle,
//   where the request for fast_pc goes out in the same cycle (the target is
//   on dec_* two cycles after the redirect with a one-cycle MSS, instead of
//   three). The address select follows fast_cand, which does not wait for
//   hold / kill of the id prediction; only mss_req does.
//
// Debug (paths relative to this instance)
//   Wrong dec_instr at a correct dec_pc:
//     buffer words are u_buf.u_mem.mem; check u_align.word0 / word1,
//     u_align.in_upper_half (pc[1]) and u_align.is32.
//   Old-path instruction after a redirect (stale response in the buffer):
//     check u_fetch.rsp_stale, u_fetch.discard_cnt and u_fetch.stale_req on
//     mss_rvalid cycles.
//   dec_valid stuck low:
//     buf_count == 0 -> mss_req low? see u_fetch.space_ok / os_ok;
//     u_fetch.os_cnt stuck at MAX_OS means the MSS lost a response.
//     buf_count == 1 with a 32-bit instruction in the upper half waits for
//     the next word (u_align.have_word1).
//   dec_fault high: mss_err (or rsp_deny, PMP) was set on a word the instruction uses
//     (u_align.err0 / err1). dec_fault_hi: only on word1, which holds the
//     second halfword of a 32-bit instruction at pc[1] = 1 (mtval pc + 2).
//   Wrong dec_pc: pc advances by 2 or 4 per dec_fire and loads redirect_pc
//     on redirect_valid (u_align.pc_d, u_align.pc_en).
// -----------------------------------------------------------------------------
module chillus_ifu #(
  parameter  int                ADDR_W   = 32,    // address width in bits
  parameter  int                DEPTH    = 4,     // prefetch buffer depth in 32-bit words
  parameter  int                MAX_OS   = 2      // max outstanding fetch requests
) (
  input  logic              clk,
  input  logic              rst_n,           // async, active-low
  input  logic              test_en,         // scan / test: library clock gates (none built: CLOCK_GATE 0)
  // redirect (branch, jump, exception, return, ...)
  input  logic              redirect_valid,
  input  logic [ADDR_W-1:0] redirect_pc,
  input  logic              fast_valid,      // request fast_pc in this redirect cycle (u_fetch)
  input  logic              fast_cand,       // fast_valid without hold / kill: present fast_pc (u_fetch)
  input  logic [ADDR_W-1:0] fast_pc,         // = redirect_pc when fast_valid
  // halt (WFI)
  input  logic              halt,            // present no new fetch request (u_fetch)
  output logic              idle,            // no fetch outstanding or presented (u_fetch)
  // MSS fetch interface
  output logic              mss_req,
  input  logic              mss_gnt,
  output logic [ADDR_W-1:0] mss_addr,        // always 4-byte aligned
  input  logic              mss_rvalid,
  input  logic [31:0]       mss_rdata,
  input  logic              mss_err,
  // PMP fetch check (chillus_pmp) of the word arriving on mss_rvalid
  output logic [ADDR_W-1:0] rsp_addr,        // its address: the buffer tail (from registers)
  input  logic              rsp_deny,        // the PMP denies it: stored as a fetch error
  // decoder interface
  output logic              dec_valid,
  input  logic              dec_accept,
  output logic [31:0]       dec_instr,       // upper half zero for 16-bit
  output logic [ADDR_W-1:0] dec_pc,
  output logic              dec_is32,        // 32-bit instruction
  output logic              dec_fault,       // fetch error on any word used
  output logic              dec_fault_hi     // only the second halfword's word faulted (at dec_pc + 2)
);

  localparam int CNT_W   = $clog2(DEPTH + 1);
  localparam int ENTRY_W = 33;               // {fetch error, 32-bit word}

  logic [CNT_W-1:0]     buf_count;   // valid words in the prefetch buffer
  logic                 buf_push;    // response written into the buffer
  logic                 buf_pop;     // head word fully consumed
  logic [ENTRY_W-1:0]   buf_wdata;   // {mss_err || rsp_deny, mss_rdata}
  logic                 buf_err;     // the arriving word faults (bus error or PMP)
  logic [2*ENTRY_W-1:0] buf_rdata;   // {next word entry, head word entry}
  logic [ADDR_W-1:0]    pc;          // architectural PC (u_align), = dec_pc

  // The buffer holds the words from the head word (pc's) on, in address
  // order, so the arriving word goes to pc's word + buf_count.
  assign rsp_addr  = {pc[ADDR_W-1:2] + (ADDR_W-2)'(buf_count), 2'b00};
  assign buf_err   = mss_err || rsp_deny;
  assign buf_wdata = {buf_err, mss_rdata};

  chillus_ifu_fetch #(
    .ADDR_W   (ADDR_W),
    .DEPTH    (DEPTH),
    .MAX_OS   (MAX_OS)
  ) u_fetch (
    .clk            (clk),
    .rst_n          (rst_n),
    .redirect_valid (redirect_valid),
    .redirect_pc    (redirect_pc),
    .fast_valid     (fast_valid),
    .fast_cand      (fast_cand),
    .fast_pc        (fast_pc),
    .pc             (pc),
    .halt           (halt),
    .idle           (idle),
    .buf_count      (buf_count),
    .buf_push       (buf_push),
    .mss_req        (mss_req),
    .mss_gnt        (mss_gnt),
    .mss_addr       (mss_addr),
    .mss_rvalid     (mss_rvalid)
  );

  basechili_peek_fifo #(
    .WIDTH (ENTRY_W),
    .DEPTH (DEPTH),
    .PEEK  (2)
  ) u_buf (
    .clk     (clk),
    .rst_n   (rst_n),
    .test_en (test_en),
    .flush   (redirect_valid),
    .push    (buf_push),
    .wdata   (buf_wdata),
    .pop     (buf_pop),
    .rdata   (buf_rdata),
    .count   (buf_count),
    .full    (),
    .empty   ()
  );

  chillus_ifu_align #(
    .ADDR_W   (ADDR_W),
    .DEPTH    (DEPTH)
  ) u_align (
    .clk            (clk),
    .rst_n          (rst_n),
    .redirect_valid (redirect_valid),
    .redirect_pc    (redirect_pc),
    .buf_count      (buf_count),
    .buf_rdata      (buf_rdata),
    .buf_pop        (buf_pop),
    .pc             (pc),
    .dec_valid      (dec_valid),
    .dec_accept     (dec_accept),
    .dec_instr      (dec_instr),
    .dec_pc         (dec_pc),
    .dec_is32       (dec_is32),
    .dec_fault      (dec_fault),
    .dec_fault_hi   (dec_fault_hi)
  );

endmodule
