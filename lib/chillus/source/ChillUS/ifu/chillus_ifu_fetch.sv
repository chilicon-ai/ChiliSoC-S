// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_ifu_fetch
//
// IFU fetch-request control. Issues word-aligned fetch requests to the MSS
// whenever the prefetch buffer has a free word (counting words still in
// flight) and fewer than MAX_OS requests are outstanding. Tracks responses
// that belong to a stream abandoned by a redirect and keeps them out of the
// buffer.
//
// Redirect handling:
// - fast_valid (a redirect whose address fast_pc comes early in the cycle,
//   chillus_ctrl: an id prediction or an ex branch mispredict): in the redirect cycle, unless a
//   request from an earlier cycle is still waiting for accept (req_wait),
//   the request presented is for fast_pc itself (early_req: address taken
//   from fast_pc combinationally), so the target word returns one cycle
//   sooner. It is part of the new stream and not counted as stale. A fresh
//   request of the old stream that would have been presented this cycle is
//   replaced by it (nothing was presented yet, so the handshake allows it).
// - The address select does not wait for fast_valid: whenever fast_cand
//   (chillus_ctrl: fast_valid without hold / kill of an id prediction)
//   holds with no request waiting and os_ok (fast_slot), the address is
//   fast_pc, and the request is valid only if fast_valid. A cycle with
//   fast_slot but no fast_valid presents nothing (one fetch slot lost).
// - All requests in flight after the redirect cycle become stale:
//   discard_cnt is loaded with them, and the next discard_cnt responses
//   are dropped (responses are in order).
// - A request that is presented but not accepted cannot be withdrawn (the
//   req channel must hold). It is kept as a stale request (stale_req) until
//   accepted and counted for discard; the next fetch then starts at pc,
//   which still equals the redirect target because nothing can be consumed
//   while the buffer is empty.
//
// Halt (WFI, chillus_ctrl): while halt is high no new request is presented
// (a waiting stale request still is: it cannot be withdrawn), so fetch
// drains; idle = nothing outstanding and nothing presented. Fetch resumes
// at fetch_word when halt drops.
//
// Timing
//   mss_req / mss_addr are decoded from registered state only,
//   except in a fast_slot cycle: there mss_addr depends on fast_pc and
//   fast_cand (id prediction, or the ex comparator for a conditional
//   branch), and mss_req also on fast_valid (hold / kill of id).
//   Constant 0 when the core disables both fast sources. A response is pushed
//   (buf_push) in the cycle it arrives; buf_count shows it next cycle.
//
// Invariants (hold every cycle; check these first in a failing waveform)
//   os_cnt <= MAX_OS
//   discard_cnt <= os_cnt
//   buf_count + live_cnt <= DEPTH
//   stale_req -> mss_req && (discard_cnt == os_cnt)
//   early_req -> fast_valid && redirect_valid && !req_wait
//   fast_valid -> fast_cand (so early_req -> fast_slot)
//   halt && !stale_req -> !mss_req
//
// Debug
//   No requests  : space_ok (buffer full incl. in-flight) or os_ok (MAX_OS
//                  outstanding). os_cnt stuck high means the MSS lost a
//                  response.
//   Old-path data: rsp_stale must be high for each of the first discard_cnt
//                  responses after a redirect.
//   WFI never sleeps: idle stays low; os_cnt (a lost response) or
//                  stale_req (request never accepted).
// -----------------------------------------------------------------------------
module chillus_ifu_fetch #(
  parameter  int                ADDR_W   = 32,    // address width in bits
  parameter  int                DEPTH    = 4,     // prefetch buffer depth in words
  parameter  int                MAX_OS   = 2,     // max outstanding fetch requests
  localparam int                CNT_W    = $clog2(DEPTH + 1)
) (
  input  logic              clk,
  input  logic              rst_n,           // async, active-low
  // redirect
  input  logic              redirect_valid,
  input  logic [ADDR_W-1:0] redirect_pc,
  input  logic              fast_valid,      // request fast_pc in this redirect cycle
  input  logic              fast_cand,       // fast_valid without hold / kill (chillus_ctrl): present fast_pc
  input  logic [ADDR_W-1:0] fast_pc,         // = redirect_pc when fast_valid
  input  logic [ADDR_W-1:0] pc,              // architectural PC from the aligner
  // halt (WFI)
  input  logic              halt,            // present no new request
  output logic              idle,            // nothing outstanding, no request presented
  // prefetch buffer
  input  logic [CNT_W-1:0]  buf_count,       // valid words in the buffer
  output logic              buf_push,        // write the response into the buffer
  // MSS fetch interface
  output logic              mss_req,
  input  logic              mss_gnt,
  output logic [ADDR_W-1:0] mss_addr,
  input  logic              mss_rvalid       // a response (in order); always taken: space is reserved at issue
);

  localparam int              WA_W       = ADDR_W - 2;                 // word address width
  localparam int              OS_W       = $clog2(MAX_OS + 1);
  localparam int              SUM_W      = $clog2(DEPTH + MAX_OS + 1);

  logic [WA_W-1:0]  fetch_word;     // next word address to request
  logic [WA_W-1:0]  fetch_word_d;
  logic             fetch_en;
  logic             stale_req;      // presented request belongs to an old stream
  logic             stale_req_d;
  logic [OS_W-1:0]  os_cnt;         // requests accepted, response not yet received
  logic [OS_W-1:0]  os_cnt_d;
  logic [OS_W-1:0]  discard_cnt;    // outstanding responses to drop
  logic [OS_W-1:0]  live_cnt;       // outstanding responses to keep
  logic [SUM_W-1:0] buf_used;       // buffer words valid or reserved in flight
  logic             space_ok;       // buffer has a free, unreserved word
  logic             os_ok;          // fewer than MAX_OS requests outstanding
  logic             req_fire;       // request accepted this cycle
  logic             req_hold;       // request presented but not accepted
  logic             rsp_stale;      // a response this cycle would be dropped
  logic             discard_inc;
  logic             req_wait;       // the request presented last cycle was not accepted
  logic             req_wait_d;
  logic             fast_slot;      // address is fast_pc this cycle (fast_cand, nothing waiting, os_ok)
  logic             early_req;      // fast redirect cycle: request fast_pc now
  logic             early_fire;     // early_req accepted
  logic             base_valid;     // request from registered state (no early request)
  logic [WA_W-1:0]  redirect_word;  // redirect_pc word address
  logic [WA_W-1:0]  fast_word;      // fast_pc word address
  logic [OS_W-1:0]  discard_load;   // stale responses after a redirect
  logic             discard_dec;
  logic             no_load;        // constant 0: u_os_cnt is never loaded
  logic [OS_W-1:0]  zero_os;        // constant 0 load value for u_os_cnt

  // ---------------------------------------------------------------------------
  // Outstanding and discard tracking
  // ---------------------------------------------------------------------------
  // While stale_req is set, every outstanding response is stale
  // (discard_cnt == os_cnt), so a response is stale if either holds; this also
  // covers a response returned in the same cycle as the stale request.
  assign rsp_stale   = stale_req || (discard_cnt != '0);
  assign discard_inc = req_fire && stale_req;
  assign discard_dec = mss_rvalid && rsp_stale;
  assign buf_push    = mss_rvalid && !rsp_stale && !redirect_valid;
  assign no_load     = 1'b0;
  assign zero_os     = '0;

  basechili_updown_counter #(.WIDTH(OS_W)) u_os_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (no_load),
    .load_val (zero_os),
    .inc      (req_fire),
    .dec      (mss_rvalid),
    .count    (os_cnt),
    .count_d  (os_cnt_d)
  );

  // On redirect, everything still in flight after this cycle is stale,
  // except an accepted early request (new stream).
  assign discard_load = os_cnt_d - OS_W'(early_fire);

  basechili_updown_counter #(.WIDTH(OS_W)) u_discard_cnt (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (redirect_valid),
    .load_val (discard_load),
    .inc      (discard_inc),
    .dec      (discard_dec),
    .count    (discard_cnt),
    .count_d  ()
  );

  // ---------------------------------------------------------------------------
  // Request generation
  // ---------------------------------------------------------------------------
  // mss_req is decoded from registered state only. Without a redirect
  // it can only stay high until accepted: consumption frees space, and a
  // response moves a word from in-flight to valid without changing buf_used.
  assign live_cnt      = os_cnt - discard_cnt;
  assign buf_used      = SUM_W'(buf_count) + SUM_W'(live_cnt);
  assign space_ok      = (buf_used < unsigned'(SUM_W'(DEPTH)));
  assign os_ok         = (os_cnt < unsigned'(OS_W'(MAX_OS)));
  // early_req: the flushed buffer has room for it; os_ok still limits it.
  assign redirect_word = redirect_pc[ADDR_W-1:2];
  assign fast_word     = fast_pc[ADDR_W-1:2];
  assign base_valid    = stale_req || (space_ok && os_ok && !halt);
  assign fast_slot     = fast_cand && !req_wait && os_ok && !halt;
  assign early_req     = fast_valid && fast_slot;
  assign mss_req       = (fast_cand && !req_wait) ? early_req : base_valid;
  assign req_fire      = mss_req && mss_gnt;
  assign req_hold      = mss_req && !mss_gnt;
  assign early_fire    = early_req && mss_gnt;
  assign mss_addr      = fast_slot ? {fast_word, 2'b00} : {fetch_word, 2'b00};
  assign idle          = (os_cnt == '0) && !mss_req;

  // An early request not accepted holds next cycle as a normal request of
  // the new stream (fetch_word = redirect_word), never as a stale one.
  assign stale_req_d = redirect_valid ? (req_hold && !early_req) : (stale_req && !mss_gnt);
  assign req_wait_d  = req_hold;

  basechili_dff u_req_wait (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (req_wait_d),
    .q     (req_wait)
  );

  basechili_dff u_stale_req (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (stale_req_d),
    .q     (stale_req)
  );

  // fetch_word holds while a request of the old stream is pending, including
  // across a redirect; an early request loads redirect_word (+1 if accepted).
  assign fetch_en     = req_fire || (redirect_valid && !mss_req) || early_req;
  assign fetch_word_d = early_fire     ? fast_word + 1'b1        :
                        redirect_valid ? redirect_word           :
                        stale_req      ? pc[ADDR_W-1:2]          :
                                         fetch_word + 1'b1;

  basechili_dffe #(.WIDTH(WA_W)) u_fetch_word (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (fetch_en),
    .d     (fetch_word_d),
    .q     (fetch_word)
  );

endmodule
