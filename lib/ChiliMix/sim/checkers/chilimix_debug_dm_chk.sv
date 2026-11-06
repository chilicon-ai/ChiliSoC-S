// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_debug_dm_chk (simulation and formal; bound into every chilimix_debug_dm)
//   - go is set only in S_GO; busy == (state != S_IDLE)        (header Invariant)
//   - cmderr changes from nonzero only by an abstractcs write or dmactive = 0
//                                                              (header Invariant)
//   - after a cycle with dmactive low: debug_req, ndmreset and busy are low
//                                                              (header Invariant)
//   - the resume flag rises only while the hart is halted
//   - a command starts (go) only while the hart is halted
//   - one DMI response at a time: no request is accepted while a response waits
//   - a system bus access starts only with sbbusyerror and sberror clear
//   - a system bus request has a supported size (64-bit only on a 64-bit bus)
//     and an aligned address
// -----------------------------------------------------------------------------
module chilimix_debug_dm_chk #(
  parameter int SB_DATA_W = 32
) (
  input logic       clk,
  input logic       rst_n,
  input logic [1:0] state_q,
  input logic       busy,
  input logic       go,
  input logic [2:0] cmderr,
  input logic       wr_abstractcs,
  input logic       dmactive,
  input logic       debug_req,
  input logic       ndmreset,
  input logic       resume,
  input logic       halted,
  input logic       dmi_req_accept,
  input logic       dmi_rsp_valid,
  input logic       sb_busy,
  input logic       sb_blocked,
  input logic       sb_req_valid,
  input logic [2:0] sb_req_size,
  input logic [2:0] sb_req_addr_lo
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  debug_dm_go_state: assert property (@(posedge clk) disable iff (!rst_n)
                   go == (state_q == 2'd1) && busy == (state_q != 2'd0) && state_q != 2'd3)
    else $error("chilimix_debug_dm: go / busy do not follow the command state");

  debug_dm_cmderr_sticky: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(cmderr) == 3'd0 || $past(wr_abstractcs)
                   || !$past(dmactive) || cmderr == $past(cmderr))
    else $error("chilimix_debug_dm: cmderr changed without an abstractcs write");

  debug_dm_inactive: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(dmactive) || (!debug_req && !ndmreset && !busy))
    else $error("chilimix_debug_dm: debug_req / ndmreset / busy while the DM is inactive");

  debug_dm_resume_halted: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(resume) || !resume || $past(halted))
    else $error("chilimix_debug_dm: resume flag set while the hart was not halted");

  debug_dm_go_halted: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(go) || !go || $past(halted))
    else $error("chilimix_debug_dm: a command started while the hart was not halted");

  debug_dm_one_rsp: assert property (@(posedge clk) disable iff (!rst_n)
                   !dmi_rsp_valid || !dmi_req_accept)
    else $error("chilimix_debug_dm: request accepted while a response waits");

  debug_dm_sb_start: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(sb_busy) || !sb_busy || !$past(sb_blocked))
    else $error("chilimix_debug_dm: system bus access started while an SBA error was set");

  debug_dm_sb_req: assert property (@(posedge clk) disable iff (!rst_n)
                   !sb_req_valid || sb_req_size == 3'd0
                   || (sb_req_size == 3'd1 && !sb_req_addr_lo[0])
                   || (sb_req_size == 3'd2 && sb_req_addr_lo[1:0] == 2'b00)
                   || (SB_DATA_W == 64 && sb_req_size == 3'd3 && sb_req_addr_lo == 3'b000))
    else $error("chilimix_debug_dm: system bus request with a bad size or a misaligned address");

endmodule

bind chilimix_debug_dm chilimix_debug_dm_chk #(.SB_DATA_W(SB_DATA_W)) u_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .state_q        (state_q),
  .busy           (busy),
  .go             (go),
  .cmderr         (cmderr),
  .wr_abstractcs  (wr_abstractcs),
  .dmactive       (dmactive),
  .debug_req      (debug_req),
  .ndmreset       (ndmreset),
  .resume         (resume),
  .halted         (halted),
  .dmi_req_accept (dmi_req_accept),
  .dmi_rsp_valid  (dmi_rsp_valid),
  .sb_busy        (sb_busy),
  .sb_blocked     (sb_blocked),
  .sb_req_valid   (sb_req_valid),
  .sb_req_size    (sb_req_size),
  .sb_req_addr_lo (sb_req_addr[2:0])
);
