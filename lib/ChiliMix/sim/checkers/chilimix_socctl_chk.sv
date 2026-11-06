// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_socctl_chk (simulation and formal; bound into every chilimix_socctl)
//   - a request starts a system reset that stays on for HOLD cycles after the
//     last request, and it is never on otherwise           (header Invariant)
//   - a domain out of reset implies sys_rst_q low (outside test mode)
//                                                            (header Invariant)
//   - outside test mode, domain i out of reset implies every domain below it
//     out of reset, whatever software holds                 (header Invariant)
//   - a system reset releases the holds: hold_arm is low the cycle after
//     hold_clr                                               (header Invariant)
//   - outside test mode a hart out of reset implies the CPU domain (the last)
//     out of reset; a system reset releases hart_arm   (header Invariant)
//   - formal only: mission mode, test_en low (test_en bypasses the reset
//     synchronizers; the testbench covers scan mode)
// -----------------------------------------------------------------------------
module chilimix_socctl_chk #(
  parameter int N_DOM = 3,
  parameter int HOLD  = 16,
  parameter int N_HART = 1
) (
  input logic             clk,
  input logic             rst_n,
  input logic             test_en,
  input logic             sys_go,
  input logic             sys_rst_q,
  input logic [N_DOM-1:0] rst_n_out,
  input logic             hold_clr,
  input logic             hold_arm,
  input logic [N_HART-1:0] hart_rst_n,
  input logic             hart_arm
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  // model: system reset cycles still owed (HOLD after a request, then down to 0)
  logic [8:0] left;
  always @(posedge clk or negedge rst_n)
    if (!rst_n)      left <= '0;
    else if (sys_go) left <= 9'(HOLD);
    else if (left != '0) left <= left - 9'd1;

`ifdef FORMAL
  socctl_env_mission: assume property (@(posedge clk) !test_en);
`endif

  socctl_hold: assert property (@(posedge clk) disable iff (!rst_n)
                   left == '0 || sys_rst_q)
    else $error("chilimix_socctl: system reset ended before HOLD cycles (%0d left)", left);

  socctl_no_spurious: assert property (@(posedge clk) disable iff (!rst_n)
                   left != '0 || !sys_rst_q)
    else $error("chilimix_socctl: system reset on without a request");

  socctl_dom_in_reset: assert property (@(posedge clk) disable iff (!rst_n)
                   test_en || rst_n_out == '0 || !sys_rst_q)
    else $error("chilimix_socctl: a domain is out of reset during a system reset");

  logic order_ok;                    // the domains out of reset are a prefix 0 .. k
  always_comb begin
    order_ok = 1'b1;
    for (int i = 1; i < N_DOM; i++)
      order_ok &= !rst_n_out[i] || rst_n_out[i-1];
  end

  socctl_dom_order: assert property (@(posedge clk) disable iff (!rst_n) test_en || order_ok)
    else $error("chilimix_socctl: domain out of reset before a lower one: %b", rst_n_out);

  socctl_hold_release: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(hold_clr) || !hold_arm)
    else $error("chilimix_socctl: a hold survived a system reset");

  socctl_hart_in_dom: assert property (@(posedge clk) disable iff (!rst_n)
                   test_en || hart_rst_n == '0 || rst_n_out[N_DOM-1])
    else $error("chilimix_socctl: a hart is out of reset while the CPU domain is in reset");

  socctl_hart_release: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(hold_clr) || !hart_arm)
    else $error("chilimix_socctl: a hart_hold write survived a system reset");

endmodule

bind chilimix_socctl chilimix_socctl_chk #(.N_DOM(N_DOM), .HOLD(HOLD), .N_HART(N_HART)) u_chk (
  .clk       (clk),
  .rst_n     (rst_n),
  .test_en   (test_en),
  .sys_go    (sys_go),
  .sys_rst_q (sys_rst_q),
  .rst_n_out (rst_n_out),
  .hold_clr  (hold_clr),
  .hold_arm  (hold_arm),
  .hart_rst_n (hart_rst_n),
  .hart_arm  (hart_arm)
);
