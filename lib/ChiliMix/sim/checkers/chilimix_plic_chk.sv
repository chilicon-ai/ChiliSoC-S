// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_plic_chk (simulation and formal; bound into every chilimix_plic)
//   - pending and in_service never both set for a source     (header Invariant)
//   - eip[c] is the registered (best_valid[c] && best_prio[c] > threshold[c])
//                                                            (header Invariant)
//   - claim_rd and claim_wr are zero or one-hot              (header Invariant)
// (Source 0 has no pending bit: pending is [63:1].)
// -----------------------------------------------------------------------------
module chilimix_plic_chk #(
  parameter int N_CTX = 1
) (
  input logic                clk,
  input logic                rst_n,
  input logic [63:1]         pending,
  input logic [63:1]         in_service,
  input logic [N_CTX-1:0]    best_valid,
  input logic [N_CTX*3-1:0]  best_prio,
  input logic [16*3-1:0]     threshold,
  input logic [N_CTX-1:0]    claim_rd,
  input logic [N_CTX-1:0]    claim_wr,
  input logic [N_CTX-1:0]    eip
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic [N_CTX-1:0] eip_exp;   // what eip must be after the edge
  always_comb begin
    for (int c = 0; c < N_CTX; c++) eip_exp[c] = best_valid[c] && best_prio[c*3 +: 3] > threshold[c*3 +: 3];
  end

  plic_pend_svc_excl: assert property (@(posedge clk) disable iff (!rst_n) (pending & in_service) == '0)
    else $error("chilimix_plic: a source is both pending and in service: %b", pending & in_service);

  plic_eip_reg: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || eip == $past(eip_exp))
    else $error("chilimix_plic: eip %b is not the registered best_prio > threshold", eip);

  plic_claim_onehot: assert property (@(posedge clk) disable iff (!rst_n) $onehot0(claim_rd) && $onehot0(claim_wr))
    else $error("chilimix_plic: claim_rd %b / claim_wr %b not zero or one-hot", claim_rd, claim_wr);

endmodule

bind chilimix_plic chilimix_plic_chk #(.N_CTX(N_CTX)) u_chk (
  .clk        (clk),
  .rst_n      (rst_n),
  .pending    (pending),
  .in_service (in_service),
  .best_valid (best_valid),
  .best_prio  (best_prio),
  .threshold  (threshold),
  .claim_rd   (claim_rd),
  .claim_wr   (claim_wr),
  .eip        (eip)
);
