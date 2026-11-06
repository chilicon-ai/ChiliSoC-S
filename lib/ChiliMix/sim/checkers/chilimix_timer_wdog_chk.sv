// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_timer_wdog_chk (simulation and formal; bound into every chilimix_timer_wdog)
//   - unlocked falls on every APB write other than a key write
//                                                            (header Invariant)
//   - while locked, wdogcfg and wdogcmp0 hold and wdogcount only counts or
//     restarts on a zerocmp match                            (header Invariant)
//   - rst_req never falls while rst_n is high                (header Invariant)
//   - irq == ip0                                             (header Invariant)
//   - ip0 is set the cycle after elapsed
// -----------------------------------------------------------------------------
module chilimix_timer_wdog_chk (
  input logic        clk,
  input logic        rst_n,
  input logic        apb_wr,
  input logic        key_wr,
  input logic        unlocked,
  input logic [3:0]  cfg_scale,
  input logic [3:0]  cfg_mid,
  input logic [15:0] cmp0,
  input logic [30:0] count,
  input logic        count_en,
  input logic        cfg_zerocmp,
  input logic        elapsed,
  input logic        ip0,
  input logic        irq,
  input logic        rst_req
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  timer_wdog_lock: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(apb_wr && !key_wr) || !unlocked)
    else $error("chilimix_timer_wdog: still unlocked after a write");

  timer_wdog_locked_cfg: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(unlocked)
                   || {cfg_scale, cfg_mid, cmp0} == $past({cfg_scale, cfg_mid, cmp0}))
    else $error("chilimix_timer_wdog: wdogcfg / wdogcmp0 changed while locked");

  timer_wdog_locked_count: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(unlocked)
                   || count == ($past(cfg_zerocmp && elapsed) ? 31'd0 : $past(count) + 31'($past(count_en))))
    else $error("chilimix_timer_wdog: wdogcount written while locked");

  timer_wdog_rst_hold: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(rst_req) || rst_req)
    else $error("chilimix_timer_wdog: rst_req fell before reset");

  timer_wdog_irq: assert property (@(posedge clk) disable iff (!rst_n) irq == ip0)
    else $error("chilimix_timer_wdog: irq is not ip0");

  timer_wdog_ip0_set: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(elapsed) || ip0)
    else $error("chilimix_timer_wdog: ip0 not set after elapsed");

endmodule

bind chilimix_timer_wdog chilimix_timer_wdog_chk u_chk (
  .clk         (clk),
  .rst_n       (rst_n),
  .apb_wr      (apb_wr),
  .key_wr      (key_wr),
  .unlocked    (unlocked),
  .cfg_scale   (cfg_scale),
  .cfg_mid     (cfg_mid),
  .cmp0        (cmp0),
  .count       (count),
  .count_en    (count_en),
  .cfg_zerocmp (cfg_zerocmp),
  .elapsed     (elapsed),
  .ip0         (ip0),
  .irq         (irq),
  .rst_req     (rst_req)
);
