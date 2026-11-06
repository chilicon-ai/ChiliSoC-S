// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// checker :: chilimix_gpio_chk (simulation and formal; bound into every chilimix_gpio)
//   - irq is the registered OR of the ip & ie bits of each pin (header Invariant)
// -----------------------------------------------------------------------------
module chilimix_gpio_chk #(
  parameter int N_GPIO = 32
) (
  input logic              clk,
  input logic              rst_n,
  input logic [N_GPIO-1:0] irq_d,
  input logic [N_GPIO-1:0] irq
);

  // Implication-free so the same file runs in Verilator and SymbiYosys
  // (yosys-slang rejects |-> and |=>): "a |=> b" is written
  // !past_ok || !$past(rst_n) || !$past(a) || b.
  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  gpio_irq_reg: assert property (@(posedge clk) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || irq == $past(irq_d))
    else $error("chilimix_gpio: irq is not the registered OR of ip & ie");

endmodule

bind chilimix_gpio chilimix_gpio_chk #(.N_GPIO(N_GPIO)) u_chk (
  .clk   (clk),
  .rst_n (rst_n),
  .irq_d (irq_d),
  .irq   (irq)
);
