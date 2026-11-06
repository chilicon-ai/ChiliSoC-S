// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim/tb/tb_common.svh :: shared testbench helpers (simulation only)
//
//   `TB_CLOCK_RESET   clk (10 time units) and rst_n, low for the first edges
//   `CHECK(c, msg)    stop with an error when c is false (a statement)
//   tb_reset()        hold rst_n low for 3 edges, release after a falling edge
//   tb_pass()         print TB PASS and finish (tools/sim.py requires it)
//
// Stimulus convention: drive inputs after a falling edge, sample outputs
// before the next rising edge (#1 after driving combinational inputs).
// -----------------------------------------------------------------------------
`ifndef BASECHILI_TB_COMMON_SVH
`define BASECHILI_TB_COMMON_SVH

`define TB_CLOCK_RESET \
  logic clk = 1'b0; \
  logic rst_n = 1'b0; \
  always #5 clk = ~clk; \
  task automatic tb_reset(); \
    rst_n = 1'b0; \
    repeat (3) @(posedge clk); \
    @(negedge clk); \
    rst_n = 1'b1; \
  endtask

`define CHECK(c, msg) begin if (!(c)) $error("CHECK failed: %s", msg); end

task automatic tb_pass();
  $display("TB PASS");
  $finish;
endtask

`endif
