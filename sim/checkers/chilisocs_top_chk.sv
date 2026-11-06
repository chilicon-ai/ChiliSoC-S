// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chilisocs_top_chk (bound into chilisocs_top)
//   - rst_cpu_n is low whenever rst_bus_n is low (domain order)  (header Invariant)
//   - while core_sleep is high both core buses are idle (WFI drains the
//     IMSS / DMSS first; chillus_ahb holds no transfer of its own)
//                                                               (header Invariant)
//   - the cycle after wdog_rst_req is high, rst_bus_n is low (a watchdog
//     bite resets the system through socctl)                   (header Invariant)
//   - the timers', SPI0's, I2C0's and the DMA channels' interrupts reach
//     their PLIC sources (chilisocs_pkg numbers)
//   - the DMA engine's transfers are privileged data accesses (HPROT[1:0]
//     = 2'b11), so PMP-style user checks downstream never see them as user
//   - the cycle after ndmreset is high, rst_bus_n is low (the debugger's
//     system reset)                                            (header Invariant)
//   - rst_dbg_n falls only with por_n: system resets (software, watchdog,
//     ndmreset, ext_rst_n) keep the debug session
//   - debug_req is low while rst_dbg_n is low                  (header Invariant)
//   - environment rule: test_en is low (functional mode)
// Formal (tools/formal.py, chilisocs_top with the core, memories, fabric and
// most peripherals cut): the core's core_sleep contract is assumed there.
// -----------------------------------------------------------------------------
`default_nettype none   // a bind port that names no signal of the target is an error
module chilisocs_top_chk
  import chilisocs_pkg::*;
(
  input logic       clk,
  input logic       rst_bus_n,
  input logic       rst_cpu_n,
  input logic       core_sleep,
  input logic [1:0] i_HTRANS,
  input logic [1:0] d_HTRANS,
  input logic       wdog_rst_req,
  input logic       wdog_irq,
  input logic [4*N_PWM-1:0] pwm_irq,
  input logic [N_IRQ:1] plic_irq,
  input logic       spi0_irq,
  input logic       i2c0_irq,
  input logic [2*N_DMA_CH-1:0] dma_irq,
  input logic [1:0] dma_HTRANS,
  input logic [3:0] dma_HPROT,
  input logic       por_n,
  input logic       rst_dbg_n,
  input logic       ndmreset,
  input logic       debug_req,
  input logic       test_en
);

  logic past_ok;                     // a clock edge has passed (for $past)

  initial past_ok = 1'b0;
  always @(posedge clk) past_ok <= 1'b1;

  logic por_seen;                    // por_n was low since the last clock edge (it resets asynchronously)
  always @(posedge clk or negedge por_n)
    if (!por_n) por_seen <= 1'b1;
    else        por_seen <= 1'b0;

  // environment rule: functional mode (test_en is for scan: domain resets
  // then follow the reset pins only)
`ifdef FORMAL
  always_comb chilisocs_top_env_func: assume (!test_en);   // every step: test_en bypasses resets asynchronously
`else
  chilisocs_top_env_func: assert property (@(posedge clk) !test_en)
    else $error("chilisocs_top: test_en high in a functional run");
`endif

  chilisocs_top_domain_order: assert property (@(posedge clk) rst_bus_n || !rst_cpu_n)
    else $error("chilisocs_top: CPU domain out of reset while the bus domain is in reset");

`ifdef FORMAL
  // the core's contract (checked in chillus); the core is a cut point here
  chilisocs_top_sleep_idle: assume property (@(posedge clk) disable iff (!rst_cpu_n) !core_sleep || (!i_HTRANS[1] && !d_HTRANS[1]));
`else
  chilisocs_top_sleep_idle: assert property (@(posedge clk) disable iff (!rst_cpu_n) !core_sleep || (!i_HTRANS[1] && !d_HTRANS[1]))
    else $error("chilisocs_top: core_sleep with a bus transfer: i_HTRANS=%b d_HTRANS=%b", i_HTRANS, d_HTRANS);
`endif

  chilisocs_top_wdog_reset: assert property (@(posedge clk) !past_ok || !$past(wdog_rst_req) || !$past(rst_bus_n) || !rst_bus_n)
    else $error("chilisocs_top: watchdog reset request did not reset the system");

  chilisocs_top_irq_timers: assert property (@(posedge clk) plic_irq[IRQ_WDOG] == wdog_irq && plic_irq[IRQ_PWM0 +: 4*N_PWM] == pwm_irq)
    else $error("chilisocs_top: timer interrupts not on their PLIC sources: plic_irq=%h", plic_irq);

  chilisocs_top_irq_periph: assert property (@(posedge clk) plic_irq[IRQ_SPI0] == spi0_irq && plic_irq[IRQ_I2C0] == i2c0_irq
                   && plic_irq[IRQ_DMA0 +: 2*N_DMA_CH] == dma_irq)
    else $error("chilisocs_top: SPI0 / I2C0 / DMA interrupts not on their PLIC sources: plic_irq=%h", plic_irq);

  chilisocs_top_dma_hprot: assert property (@(posedge clk) disable iff (!rst_bus_n) !dma_HTRANS[1] || dma_HPROT[1:0] == 2'b11)
    else $error("chilisocs_top: DMA transfer with HPROT %b", dma_HPROT);

  chilisocs_top_ndmreset: assert property (@(posedge clk) !past_ok || !$past(ndmreset) || !$past(rst_bus_n) || !rst_bus_n)
    else $error("chilisocs_top: ndmreset did not reset the system");

  chilisocs_top_dbg_keep: assert property (@(posedge clk) !past_ok || !$past(rst_dbg_n) || rst_dbg_n || por_seen)
    else $error("chilisocs_top: debug unit reset without power-on reset");

  chilisocs_top_dbg_req_rst: assert property (@(posedge clk) rst_dbg_n || !debug_req)
    else $error("chilisocs_top: debug_req while the debug unit is in reset");

endmodule

bind chilisocs_top chilisocs_top_chk u_chk (
  .clk          (clk),
  .rst_bus_n    (rst_bus_n),
  .rst_cpu_n    (rst_cpu_n),
  .core_sleep   (core_sleep),
  .i_HTRANS     (i_HTRANS),
  .d_HTRANS     (d_HTRANS),
  .wdog_rst_req (wdog_rst_req),
  .wdog_irq     (wdog_irq),
  .pwm_irq      (pwm_irq),
  .plic_irq     (plic_irq),
  .spi0_irq     (spi0_irq),
  .i2c0_irq     (i2c0_irq),
  .dma_irq      (dma_irq),
  .dma_HTRANS   (dma_HTRANS),
  .dma_HPROT    (dma_HPROT),
  .por_n        (por_n),
  .rst_dbg_n    (rst_dbg_n),
  .ndmreset     (ndmreset),
  .debug_req    (debug_req),
  .test_en      (test_en)
);
`default_nettype wire
