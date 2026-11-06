// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_debug_dtm_chk (simulation; bound into every chilimix_debug_dtm)
//   - a request starts only on Update-DR of dmi with op 1 / 2, no sticky
//     error and nothing in flight                            (header Invariant)
//   - the error is sticky: it changes from nonzero only by dmireset /
//     dtmhardreset                                           (header Invariant)
//   - in_flight falls only on a response                     (header Invariant)
// All on tck. Implication-free ("a |=> b" as !past_ok || !$past(a) || b).
// -----------------------------------------------------------------------------
module chilimix_debug_dtm_chk (
  input logic       tck,
  input logic       tck_rst_n,
  input logic       req_go,
  input logic       dmi_upd,
  input logic       dmi_rw,
  input logic [1:0] err,
  input logic       busy,
  input logic       dmi_reset,
  input logic       in_flight,
  input logic       rsp_valid
);

  logic past_ok = 1'b0;  // a previous rising edge of tck exists ($past is defined)
  always @(posedge tck) past_ok <= 1'b1;

  debug_dtm_req_start: assert property (@(posedge tck) disable iff (!tck_rst_n)
                   !req_go || (dmi_upd && dmi_rw && err == 2'd0 && !busy))
    else $error("chilimix_debug_dtm: request started outside a clean dmi Update-DR");

  debug_dtm_err_sticky: assert property (@(posedge tck) disable iff (!tck_rst_n)
                   !past_ok || !$past(tck_rst_n) || $past(err) == 2'd0 || $past(dmi_reset)
                   || err == $past(err))
    else $error("chilimix_debug_dtm: sticky error changed without dmireset");

  debug_dtm_in_flight: assert property (@(posedge tck) disable iff (!tck_rst_n)
                   !past_ok || !$past(tck_rst_n) || !$past(in_flight) || in_flight || $past(rsp_valid))
    else $error("chilimix_debug_dtm: in_flight fell without a response");

endmodule

bind chilimix_debug_dtm chilimix_debug_dtm_chk u_chk (
  .tck       (tck),
  .tck_rst_n (tck_rst_n),
  .req_go    (req_go),
  .dmi_upd   (dmi_upd),
  .dmi_rw    (dmi_rw),
  .err       (err),
  .busy      (busy),
  .dmi_reset (dmi_reset),
  .in_flight (in_flight),
  .rsp_valid (rsp_valid)
);
