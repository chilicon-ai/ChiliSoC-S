// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_irq_aggregator_chk (bound into every
// basechili_irq_aggregator)
//   - irq == ((pending & enable) != 0)                      (header Invariant)
//   - active == pending & enable                            (header)
// -----------------------------------------------------------------------------
module basechili_irq_aggregator_chk #(
  parameter int N = 8
) (
  input logic         clk,
  input logic         rst_n,
  input logic [N-1:0] pending,
  input logic [N-1:0] enable,
  input logic [N-1:0] active,
  input logic         irq
);

  assert property (@(posedge clk) irq == ((pending & enable) != '0))
    else $error("basechili_irq_aggregator: irq == |(pending & enable) violated: irq=%b pending=%b enable=%b",
                irq, pending, enable);

  assert property (@(posedge clk) active == (pending & enable))
    else $error("basechili_irq_aggregator: active == pending & enable violated: active=%b pending=%b enable=%b",
                active, pending, enable);

endmodule

bind basechili_irq_aggregator basechili_irq_aggregator_chk #(.N(N)) u_chk (
  .clk     (clk),
  .rst_n   (rst_n),
  .pending (pending),
  .enable  (enable),
  .active  (active),
  .irq     (irq)
);
