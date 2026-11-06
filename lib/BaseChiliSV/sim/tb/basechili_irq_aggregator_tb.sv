// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_irq_aggregator -- pending / active / irq against a
// model: level sources (edge_sel 0) set while high, edge sources on a rising
// edge, clr clears unless a set comes in the same cycle; active = pending &
// enable, irq = |active.
`include "tb_common.svh"
module basechili_irq_aggregator_tb #(
  parameter int N = 8
);
  `TB_CLOCK_RESET
  logic [N-1:0] src, edge_sel, enable, clr;
  logic [N-1:0] pending, active;
  logic         irq;
  logic [N-1:0] m_pend, m_prev;   // model: pending and previous src

  basechili_irq_aggregator #(.N(N)) dut (.clk, .rst_n, .src, .edge_sel, .enable, .clr,
                                         .pending, .active, .irq);

  task automatic check_out();
    `CHECK(pending == m_pend, $sformatf("pending=%b expected %b", pending, m_pend))
    `CHECK(active == (m_pend & enable), $sformatf("active=%b expected %b", active, m_pend & enable))
    `CHECK(irq == ((m_pend & enable) != '0), $sformatf("irq=%b pending=%b enable=%b", irq, m_pend, enable))
  endtask

  // one cycle: drive (after negedge), check, clock, update the model
  task automatic cycle(logic [N-1:0] s, logic [N-1:0] e, logic [N-1:0] en, logic [N-1:0] c);
    logic [N-1:0] set;
    src = s; edge_sel = e; enable = en; clr = c;
    #1 check_out();
    set    = (e & s & ~m_prev) | (~e & s);
    @(posedge clk);
    m_pend = set | (m_pend & ~c);
    m_prev = s;
    @(negedge clk);
  endtask

  initial begin
    src = '0; edge_sel = '0; enable = '0; clr = '0;
    tb_reset();
    m_pend = '0; m_prev = '0;
    #1 check_out();
    @(negedge clk);

    // corners: level set held, clr while high (set wins), edge set once
    cycle('1, '0, '1, '0);
    cycle('1, '0, '1, '1);
    `CHECK(pending == '1, "level source still high re-sets after clr")
    cycle('0, '0, '1, '1);
    cycle('0, '0, '1, '0);
    `CHECK(pending == '0 && !irq, "cleared")
    cycle('1, '1, '0, '0);   // rising edge on edge sources, irq masked
    `CHECK(pending == '1 && !irq && active == '0, "edge set, masked")
    cycle('1, '1, '1, '1);   // still high, no edge: clr clears
    `CHECK(pending == '0, "edge source held high does not re-set")
    cycle('0, '1, '1, '0);
    cycle('1, '1, '1, '1);   // edge and clr together: set wins
    `CHECK(pending == '1 && irq, "edge set wins over clr")
    cycle('0, '1, '1, '1);
    // one enabled source at a time
    for (int i = 0; i < N; i++) begin
      cycle(N'(1) << i, '0, N'(1) << i, '0);
      `CHECK(irq && active == N'(1) << i, "single source")
      cycle('0, '0, '0, '1);
    end

    // random
    for (int t = 0; t < 20000; t++)
      cycle(N'($urandom), N'($urandom), N'($urandom), ($urandom % 4 == 0) ? N'($urandom) : '0);

    // reset mid-run clears pending and the edge history
    cycle('1, '0, '1, '0);
    rst_n = 1'b0;
    #1 m_pend = '0; m_prev = '0;
    check_out();
    tb_reset();
    m_prev = '0;
    cycle('1, '1, '1, '0);
    `CHECK(pending == '1, "edge after reset")
    tb_pass();
  end
endmodule
