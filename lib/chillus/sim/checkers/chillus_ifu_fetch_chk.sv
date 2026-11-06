// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_ifu_fetch_chk (bound into chillus_ifu_fetch)
//   header Invariants:
//   - os_cnt <= MAX_OS
//   - discard_cnt <= os_cnt
//   - buf_count + live_cnt <= DEPTH
//   - stale_req -> mss_req && discard_cnt == os_cnt
//   - early_req -> fast_valid && redirect_valid && !req_wait, and it is the
//     presented request, for redirect_pc (fast_pc equals it)
//   - fast_slot && !fast_valid -> no request (its address is fast_pc)
//   - halt && !stale_req -> no request (WFI: only a waiting stale request)
//   - idle == (os_cnt == 0 && !mss_req)
//   interface:
//   - mss_req && !mss_gnt -> next cycle mss_req, same addr
//   - mss_addr is 4-byte aligned
//   - a response only for an outstanding request (or one accepted this
//     cycle): mss_rvalid -> os_cnt != 0 || req_fire
//   - a response is never pushed in a redirect cycle or while it is stale
// -----------------------------------------------------------------------------
module chillus_ifu_fetch_chk #(
  parameter int ADDR_W = 32,
  parameter int DEPTH  = 4,
  parameter int MAX_OS = 2,
  parameter int CNT_W  = 3,
  parameter int OS_W   = 2
) (
  input logic              clk,
  input logic              rst_n,
  input logic              redirect_valid,
  input logic [CNT_W-1:0]  buf_count,
  input logic              buf_push,
  input logic              mss_req,
  input logic              mss_gnt,
  input logic [ADDR_W-1:0] mss_addr,
  input logic              mss_rvalid,
  input logic              stale_req,
  input logic [OS_W-1:0]   os_cnt,
  input logic [OS_W-1:0]   discard_cnt,
  input logic [OS_W-1:0]   live_cnt,
  input logic              rsp_stale,
  input logic              early_req,
  input logic              fast_valid,
  input logic              fast_slot,
  input logic              req_wait,
  input logic [ADDR_W-1:0] redirect_pc,
  input logic              halt,
  input logic              idle
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(32'(os_cnt) <= MAX_OS,
       ("chillus_ifu_fetch: os_cnt <= MAX_OS violated: os_cnt=%0d MAX_OS=%0d", os_cnt, MAX_OS))
  `CHK(discard_cnt <= os_cnt,
       ("chillus_ifu_fetch: discard_cnt <= os_cnt violated: discard_cnt=%0d os_cnt=%0d", discard_cnt, os_cnt))
  `CHK(32'(buf_count) + 32'(live_cnt) <= DEPTH,
       ("chillus_ifu_fetch: buf_count + live_cnt <= DEPTH violated: buf_count=%0d live_cnt=%0d DEPTH=%0d",
        buf_count, live_cnt, DEPTH))
  `CHK(stale_req |-> mss_req && discard_cnt == os_cnt,
       ("chillus_ifu_fetch: stale_req -> mss_req && discard_cnt == os_cnt violated: req_valid=%b discard_cnt=%0d os_cnt=%0d",
        mss_req, discard_cnt, os_cnt))
  `CHK(mss_req && !mss_gnt |=> mss_req && $stable(mss_addr),
       ("chillus_ifu_fetch: req hold (valid && !accept -> valid, addr stable) violated: valid=%b addr=%h before=%h",
        mss_req, mss_addr, $past(mss_addr)))
  `CHK(mss_addr[1:0] == 2'b00,
       ("chillus_ifu_fetch: mss_addr 4-byte aligned violated: addr=%h", mss_addr))
  `CHK(mss_rvalid |-> os_cnt != '0 || (mss_req && mss_gnt),
       ("chillus_ifu_fetch: response without an outstanding request: os_cnt=%0d", os_cnt))
  `CHK(buf_push |-> mss_rvalid && !rsp_stale && !redirect_valid,
       ("chillus_ifu_fetch: push of a stale / redirect-cycle response: rsp_stale=%b redirect=%b",
        rsp_stale, redirect_valid))

  `CHK(early_req |-> fast_valid && redirect_valid && !req_wait && mss_req
                    && mss_addr == {redirect_pc[ADDR_W-1:2], 2'b00},
       ("chillus_ifu_fetch: early_req not a redirect-target request: redirect=%b req_wait=%b valid=%b addr=%h redirect_pc=%h",
        redirect_valid, req_wait, mss_req, mss_addr, redirect_pc))

  `CHK(fast_slot && !fast_valid |-> !mss_req,
       ("chillus_ifu_fetch: request at fast_pc without fast_valid: addr=%h", mss_addr))

  `CHK(halt && !stale_req |-> !mss_req,
       ("chillus_ifu_fetch: new request while halted: addr=%h", mss_addr))
  `CHK(idle == (os_cnt == '0 && !mss_req),
       ("chillus_ifu_fetch: idle=%b but os_cnt=%0d mss_req=%b", idle, os_cnt, mss_req))

  `undef CHK

endmodule

bind chillus_ifu_fetch chillus_ifu_fetch_chk #(
  .ADDR_W (ADDR_W),
  .DEPTH  (DEPTH),
  .MAX_OS (MAX_OS),
  .CNT_W  (CNT_W),
  .OS_W   (OS_W)
) u_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .redirect_valid (redirect_valid),
  .buf_count      (buf_count),
  .buf_push       (buf_push),
  .mss_req        (mss_req),
  .mss_gnt        (mss_gnt),
  .mss_addr       (mss_addr),
  .mss_rvalid     (mss_rvalid),
  .stale_req      (stale_req),
  .os_cnt         (os_cnt),
  .discard_cnt    (discard_cnt),
  .live_cnt       (live_cnt),
  .rsp_stale      (rsp_stale),
  .early_req      (early_req),
  .fast_valid     (fast_valid),
  .fast_slot      (fast_slot),
  .req_wait       (req_wait),
  .redirect_pc    (redirect_pc),
  .halt           (halt),
  .idle           (idle)
);
