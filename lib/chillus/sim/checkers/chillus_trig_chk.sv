// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_trig_chk (bound into chillus_trig)
//   - debug_mode -> no new hit is captured                (header Invariants)
//   - trig_exc -> !trig_dbg                               (header Invariants)
//   - tselect < NUM_TRIGGERS                              (header Invariants)
//   - a trigger with dmode = 1 keeps its configuration across a cycle
//     outside debug mode (writes from M-mode are ignored)
//   - action 1 only with dmode 1; DEBUG = 0: no dmode / action
//   - NUM_TRIGGERS = 0: no hit, no CSR
// -----------------------------------------------------------------------------
module chillus_trig_chk #(
  parameter int XLEN         = 32,
  parameter int NUM_TRIGGERS = 1,
  parameter bit DEBUG        = 1'b1
) (
  input logic clk,
  input logic rst_n,
  input logic debug_mode,
  input logic adv,
  input logic trig_exc,
  input logic trig_dbg,
  input logic csr_hit
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(!(trig_exc && trig_dbg),
       ("chillus_trig: trig_exc and trig_dbg both high"))
  `CHK(NUM_TRIGGERS == 0 |-> !trig_exc && !trig_dbg && !csr_hit,
       ("chillus_trig: NUM_TRIGGERS = 0 but trigger activity"))

  `undef CHK

  // per-trigger state, reached by upward name in the bound chillus_trig
  if (NUM_TRIGGERS > 0) begin : g_cfg_chk
    localparam int N  = NUM_TRIGGERS;
    localparam int SW = (N > 1) ? $clog2(N) : 1;
    chillus_trig_cfg_chk #(.N(N), .SW(SW), .DEBUG(DEBUG)) u_cfg_chk (
      .clk        (clk),
      .rst_n      (rst_n),
      .debug_mode (debug_mode),
      .adv        (adv),
      .match      (g_trig.match),
      .dmode      (g_trig.dmode),
      .action     (g_trig.action),
      .type6      (g_trig.type6),
      .tsel       (g_trig.tsel)
    );
  end

endmodule

// per-trigger state (instantiated by chillus_trig_chk when NUM_TRIGGERS > 0)
module chillus_trig_cfg_chk #(
  parameter int N  = 1,
  parameter int SW = 1,
  parameter bit DEBUG = 1'b1
) (
  input logic          clk,
  input logic          rst_n,
  input logic          debug_mode,
  input logic          adv,
  input logic [N-1:0]  match,
  input logic [N-1:0]  dmode,
  input logic [N-1:0]  action,
  input logic [N-1:0]  type6,
  input logic [SW-1:0] tsel
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(debug_mode |-> match == '0,
       ("chillus_trig: a trigger matches in debug mode: match=%b", match))
  `CHK(32'(tsel) < N,
       ("chillus_trig: tselect out of range: %0d", tsel))
  `CHK((action & ~dmode) == '0,
       ("chillus_trig: action 1 without dmode: action=%b dmode=%b", action, dmode))
  `CHK(!DEBUG |-> dmode == '0 && action == '0,
       ("chillus_trig: DEBUG = 0 with dmode / action set"))
  `CHK(!debug_mode |=> (($past(dmode) & ~dmode) == '0) &&
                        ((($past(dmode) & ($past(type6) ^ type6)) == '0)),
       ("chillus_trig: a dmode trigger changed outside debug mode"))

  `undef CHK

endmodule

bind chillus_trig chillus_trig_chk #(.XLEN(XLEN), .NUM_TRIGGERS(NUM_TRIGGERS), .DEBUG(DEBUG)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .debug_mode (debug_mode),
  .adv        (adv),
  .trig_exc   (trig_exc),
  .trig_dbg   (trig_dbg),
  .csr_hit    (csr_hit)
);
