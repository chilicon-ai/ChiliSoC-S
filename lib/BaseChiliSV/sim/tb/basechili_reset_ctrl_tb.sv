// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_reset_ctrl -- outputs against a cycle model (reset
// synchronizer, step / cycle counters, registered releases, asynchronous
// assertion, test_en bypass), compared at every non-edge time, plus directed
// checks: every output falls at once when rst_n_async falls (also mid-
// sequence and between clock edges); domain i is released exactly on the
// STAGES + (i + 1) * STEP-th rising edge after rst_n_async rises and done
// with the last one; sw_rst holds a domain and releases it one edge after
// it falls; test_en passes rst_n_async through.
// Timing: clk edges at multiples of 5; stimulus at 5k+2; compares at 5k+1,
// 5k+3, 5k+4.
`include "tb_common.svh"
module basechili_reset_ctrl_tb #(
  parameter int N      = 3,
  parameter int STEP   = 16,
  parameter int STAGES = 2
);
  `TB_CLOCK_RESET
  localparam int LAST = STAGES + N * STEP;   // edge of the last release

  logic         rst_n_async = 1'b1;
  logic         test_en     = 1'b0;
  logic [N-1:0] sw_rst      = '0;
  logic [N-1:0] rst_n_out;
  logic         done;
  logic         chk_on      = 1'b0;   // model valid (after the first reset)

  basechili_reset_ctrl #(.N(N), .STEP(STEP), .STAGES(STAGES)) dut (
    .clk, .rst_n_async, .test_en, .sw_rst, .rst_n_out, .done);

  // ---- model ----
  int           m_cnt;    // ones shifted into the synchronizer
  int           m_step;   // domains whose turn has come
  int           m_cyc;    // cycle in the step
  logic [N-1:0] m_rel;    // registered releases
  logic         m_srst;   // synchronized reset

  always @(posedge clk or negedge rst_n_async)
    if (!rst_n_async)       m_cnt <= 0;
    else if (m_cnt < STAGES) m_cnt <= m_cnt + 1;

  assign m_srst = test_en ? rst_n_async : (m_cnt == STAGES);

  always @(posedge clk or negedge m_srst)
    if (!m_srst) begin
      m_step <= 0; m_cyc <= 0; m_rel <= '0;
    end else begin
      int ns;
      ns = m_step;
      if (m_step != N && m_cyc == STEP - 1) ns = m_step + 1;
      m_cyc  <= (m_step != N && m_cyc != STEP - 1) ? m_cyc + 1 : 0;
      m_step <= ns;
      for (int i = 0; i < N; i++) m_rel[i] <= (ns > i) && !sw_rst[i];
    end

  task automatic compare();
    logic [N-1:0] exp;
    exp = test_en ? {N{rst_n_async}} : m_rel;
    `CHECK(rst_n_out == exp, $sformatf("t=%0t rst_n_out=%b expected %b", $time, rst_n_out, exp))
    `CHECK(done == (m_step == N), $sformatf("t=%0t done=%b step=%0d", $time, done, m_step))
  endtask

  always begin
    #1;
    if (chk_on && ($time % 5 == 1 || $time % 5 == 3 || $time % 5 == 4)) compare();
  end

  // move to the stimulus slot (5k+2) after the next rising / falling edge
  task automatic slot_pos(); @(posedge clk); #2; endtask
  task automatic slot_neg(); @(negedge clk); #2; endtask

  task automatic assert_async();
    rst_n_async = 1'b0;
    #1;
    `CHECK(rst_n_out == '0 && !done, $sformatf("async assertion: rst_n_out=%b done=%b", rst_n_out, done))
    #1;
  endtask

  // release rst_n_async (after a rising or a falling edge) and check every
  // domain's release edge; sw_rst must be zero
  task automatic release_and_measure(bit after_neg);
    if (after_neg) slot_neg(); else slot_pos();
    rst_n_async = 1'b1;
    #1 `CHECK(rst_n_out == '0 && !done, "still in reset right after the release")
    for (int n = 1; n <= LAST + 2; n++) begin
      @(posedge clk); #1;
      for (int i = 0; i < N; i++)
        `CHECK(rst_n_out[i] == (n >= STAGES + (i + 1) * STEP),
               $sformatf("domain %0d at edge %0d: rst_n_out=%b (release at %0d)", i, n, rst_n_out[i],
                         STAGES + (i + 1) * STEP))
      `CHECK(done == (n >= LAST), $sformatf("done=%b at edge %0d (expected from %0d)", done, n, LAST))
    end
  endtask

  initial begin
    #2;
    assert_async();          // first reset: everything known
    chk_on = 1'b1;
    repeat (3) slot_pos();

    // exact release edges, released after a rising and after a falling edge
    release_and_measure(1'b0);
    slot_pos(); assert_async();
    repeat (2) slot_neg();
    release_and_measure(1'b1);

    // asynchronous assertion mid-sequence, at each point of the sequence
    for (int k = 0; k <= LAST; k++) begin
      slot_pos(); assert_async();
      slot_neg(); rst_n_async = 1'b1;
      repeat (k) @(posedge clk);
      if (k % 2) slot_neg(); else slot_pos();
      assert_async();
    end

    // sw_rst after done: domain i alone falls one edge later, rises one edge
    // after sw_rst falls
    slot_pos(); rst_n_async = 1'b1;
    repeat (LAST + 1) @(posedge clk);
    for (int i = 0; i < N; i++) begin
      slot_neg(); sw_rst = N'(1) << i;
      `CHECK(rst_n_out == '1, "sw_rst is synchronous")
      @(posedge clk); #1 `CHECK(rst_n_out == ~(N'(1) << i), $sformatf("sw_rst[%0d] held: %b", i, rst_n_out))
      repeat (3) @(posedge clk);
      #1 `CHECK(rst_n_out == ~(N'(1) << i) && done, "sw_rst hold, done stays")
      slot_neg(); sw_rst = '0;
      `CHECK(rst_n_out[i] == 1'b0, "still held until the edge")
      @(posedge clk); #1 `CHECK(rst_n_out == '1, "re-release one edge after sw_rst falls")
    end

    // sw_rst held through the sequence: domain i leaves reset after it falls
    for (int i = 0; i < N; i++) begin
      slot_pos(); assert_async();
      sw_rst = N'(1) << i;
      slot_neg(); rst_n_async = 1'b1;
      repeat (LAST + 3) @(posedge clk);
      #1 `CHECK(rst_n_out == ~(N'(1) << i) && done, $sformatf("sw_rst[%0d] holds past its turn", i))
      slot_neg(); sw_rst = '0;
      @(posedge clk); #1 `CHECK(rst_n_out == '1, "released after sw_rst")
    end

    // test_en: rst_n_async straight through, both directions, between edges
    slot_pos(); test_en = 1'b1;
    for (int k = 0; k < 8; k++) begin
      slot_neg(); rst_n_async = 1'b0;
      #1 `CHECK(rst_n_out == '0, "test_en passes 0");
      #1 if (k % 2) slot_pos(); else slot_neg();
      rst_n_async = 1'b1;
      #1 `CHECK(rst_n_out == '1, "test_en passes 1");
      repeat (k * STEP) @(posedge clk);
    end
    slot_pos(); test_en = 1'b0;

    // random: rst_n_async, sw_rst and test_en at random times
    for (int t = 0; t < 4000; t++) begin
      int r;
      repeat ($urandom_range(0, (t % 3 == 0) ? LAST + 8 : 6)) @(posedge clk);
      if ($urandom_range(0, 1)) slot_pos(); else slot_neg();
      r = $urandom_range(0, 15);
      if (r < 6)       rst_n_async = ~rst_n_async;
      else if (r < 12) sw_rst = ($urandom_range(0, 2) == 0) ? N'($urandom) : '0;
      else if (r < 13) test_en = ~test_en;
      else             rst_n_async = 1'b1;
    end
    slot_pos(); test_en = 1'b0; sw_rst = '0; rst_n_async = 1'b1;
    repeat (LAST + 2) @(posedge clk);
    #1 `CHECK(rst_n_out == '1 && done, "all released at the end");
    tb_pass();
  end
endmodule
