// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_aclint_chk (simulation and formal; bound into every chilimix_aclint)
//   - mtip[h] is the registered (mtime >= mtimecmp[h]) of the cycle before
//                                                            (header Invariant)
//   - mtime changes only by a tick (+1) or an mtime write    (header Invariant)
//   - ssip_set is zero or one-hot                            (header Invariant)
// -----------------------------------------------------------------------------
module chilimix_aclint_chk #(
  parameter int N_HART = 1
) (
  input logic                 clk,
  input logic                 rst_n,
  input logic                 tick,
  input logic [7:0]           mtime_load,
  input logic [63:0]          mtime,
  input logic [N_HART*64-1:0] mtimecmp,
  input logic [N_HART-1:0]    mtip,
  input logic [N_HART-1:0]    ssip_set
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic [N_HART-1:0] mtip_exp;   // what mtip must be after the edge
  always_comb begin
    for (int h = 0; h < N_HART; h++) mtip_exp[h] = mtime >= mtimecmp[h*64 +: 64];
  end

  aclint_mtip_reg: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || mtip == $past(mtip_exp))
    else $error("chilimix_aclint: mtip %b is not the registered mtime >= mtimecmp", mtip);

  aclint_mtime_step: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || $past(mtime_load) != 8'h00
                   || mtime == $past(mtime) + 64'($past(tick)))
    else $error("chilimix_aclint: mtime moved without a tick or a write");

  aclint_ssip_onehot: assert property (@(posedge clk) disable iff (!rst_n) $onehot0(ssip_set))
    else $error("chilimix_aclint: ssip_set %b not zero or one-hot", ssip_set);

endmodule

bind chilimix_aclint chilimix_aclint_chk #(.N_HART(N_HART)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .tick       (tick),
  .mtime_load (mtime_load),
  .mtime      (mtime),
  .mtimecmp   (mtimecmp),
  .mtip       (mtip),
  .ssip_set   (ssip_set)
);
