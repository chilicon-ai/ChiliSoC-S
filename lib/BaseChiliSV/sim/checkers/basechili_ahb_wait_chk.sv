// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_ahb_wait_chk (bound into every basechili_ahb_wait)
//   - wait_cnt != 0 exactly in S_WAIT, and wait_cnt < WAIT  (header Invariant)
//   - the downstream address phase is NONSEQ only in S_ISSUE, and never IDLE
//     with HSEL_s high                                      (header Invariant)
//   - HREADYOUT is low only in S_WAIT, S_ISSUE, or S_DATA with HREADYOUT_s
//     low; HRESP is high only in S_DATA                     (header Invariant)
//   - WAIT = 0: the state stays S_IDLE (wires)
// -----------------------------------------------------------------------------
module basechili_ahb_wait_chk #(
  parameter int WAIT  = 1,
  parameter int CNT_W = 1
) (
  input logic             clk,
  input logic             rst_n,
  input logic [1:0]       state,       // 0 S_IDLE, 1 S_WAIT, 2 S_ISSUE, 3 S_DATA
  input logic [CNT_W-1:0] wait_cnt,
  input logic             HSEL_s,
  input logic [1:0]       HTRANS_s,
  input logic             HREADYOUT,
  input logic             HRESP,
  input logic             HREADYOUT_s
);

  localparam logic [1:0] S_IDLE = 2'd0, S_WAIT = 2'd1, S_ISSUE = 2'd2, S_DATA = 2'd3;

  basechili_ahb_wait_cnt: assert property (@(posedge clk) disable iff (!rst_n)
      ((wait_cnt != '0) == (state == S_WAIT)) && (int'(wait_cnt) < (WAIT > 0 ? WAIT : 1)))
    else $error("basechili_ahb_wait: wait_cnt=%0d in state %0d (WAIT=%0d)", wait_cnt, state, WAIT);

  basechili_ahb_wait_issue: assert property (@(posedge clk) disable iff (!rst_n)
      WAIT == 0 || ((HSEL_s == (state == S_ISSUE)) && (HTRANS_s == (state == S_ISSUE ? 2'b10 : 2'b00))))
    else $error("basechili_ahb_wait: downstream HSEL_s=%b HTRANS_s=%b in state %0d", HSEL_s, HTRANS_s, state);

  basechili_ahb_wait_ready: assert property (@(posedge clk) disable iff (!rst_n)
      WAIT == 0 || HREADYOUT || state == S_WAIT || state == S_ISSUE || (state == S_DATA && !HREADYOUT_s))
    else $error("basechili_ahb_wait: HREADYOUT low in state %0d (HREADYOUT_s=%b)", state, HREADYOUT_s);

  basechili_ahb_wait_resp: assert property (@(posedge clk) disable iff (!rst_n)
      WAIT == 0 || !HRESP || state == S_DATA)
    else $error("basechili_ahb_wait: HRESP high in state %0d", state);

  basechili_ahb_wait_wire: assert property (@(posedge clk) disable iff (!rst_n)
      WAIT != 0 || state == S_IDLE)
    else $error("basechili_ahb_wait: WAIT=0 but state %0d", state);

endmodule

bind basechili_ahb_wait basechili_ahb_wait_chk #(.WAIT(WAIT), .CNT_W(CNT_W)) u_chk (
  .clk         (clk),
  .rst_n       (rst_n),
  .state       (state_q),
  .wait_cnt    (wait_cnt),
  .HSEL_s      (HSEL_s),
  .HTRANS_s    (HTRANS_s),
  .HREADYOUT   (HREADYOUT),
  .HRESP       (HRESP),
  .HREADYOUT_s (HREADYOUT_s)
);
