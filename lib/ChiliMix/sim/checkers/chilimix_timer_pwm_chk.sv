// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_timer_pwm_chk (simulation and formal; bound into every chilimix_timer_pwm)
//   - count changes only by +1 while counting, a restart or a write
//                                                            (header Invariant)
//   - a restart with no write leaves count at 0
//   - oneshot falls only on a restart or a write             (header Invariant)
//   - irq == ip                                              (header Invariant)
//   - a non-sticky ip bit is the registered elapsed bit (no write)
//   - with gang and invert clear, out == ip
// -----------------------------------------------------------------------------
module chilimix_timer_pwm_chk (
  input logic        clk,
  input logic        rst_n,
  input logic [30:0] count,
  input logic        count_en,
  input logic        count_load,
  input logic [3:0]  count_strb,
  input logic        restart,
  input logic        oneshot,
  input logic        oneshot_wr,
  input logic [3:0]  ip,
  input logic        ip_wr,
  input logic        sticky_q,
  input logic [3:0]  elapsed,
  input logic [3:0]  cfg_gang,
  input logic [3:0]  cfg_invert,
  input logic [3:0]  out,
  input logic [3:0]  irq
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  timer_pwm_count_step: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(count_load)
                   || count == $past(count) + 31'($past(count_en)))
    else $error("chilimix_timer_pwm: count moved without counting, a restart or a write");

  timer_pwm_restart: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(restart) || $past(count_strb) != 4'b0000
                   || count == 31'd0)
    else $error("chilimix_timer_pwm: count not 0 after a restart");

  timer_pwm_oneshot_fall: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(oneshot) || oneshot
                   || $past(restart) || $past(oneshot_wr))
    else $error("chilimix_timer_pwm: oneshot fell without a restart or a write");

  timer_pwm_irq: assert property (@(posedge clk) disable iff (!rst_n) irq == ip)
    else $error("chilimix_timer_pwm: irq is not ip");

  timer_pwm_ip_follow: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(sticky_q) || $past(ip_wr)
                   || ip == $past(elapsed))
    else $error("chilimix_timer_pwm: a non-sticky ip bit is not the registered elapsed bit");

  timer_pwm_out: assert property (@(posedge clk) disable iff (!rst_n)
                   cfg_gang != 4'b0000 || cfg_invert != 4'b0000 || out == ip)
    else $error("chilimix_timer_pwm: out differs from ip with gang and invert clear");

endmodule

bind chilimix_timer_pwm chilimix_timer_pwm_chk u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .count      (count),
  .count_en   (count_en),
  .count_load (count_load),
  .count_strb (count_strb),
  .restart    (restart),
  .oneshot    (oneshot),
  .oneshot_wr (oneshot_wr),
  .ip         (ip),
  .ip_wr      (ip_wr),
  .sticky_q   (sticky_q),
  .elapsed    (elapsed),
  .cfg_gang   (cfg_gang),
  .cfg_invert (cfg_invert),
  .out        (out),
  .irq        (irq)
);
