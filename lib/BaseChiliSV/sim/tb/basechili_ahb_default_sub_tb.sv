// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_default_sub -- random HSEL / HTRANS / HREADY
// (HREADY from another subordinate when the data phase is not ours, the
// DUT's HREADYOUT when it is) against a model: NONSEQ / SEQ get the
// two-cycle ERROR, IDLE / BUSY a zero-wait OKAY, HRDATA is always zero.
`include "tb_common.svh"
module basechili_ahb_default_sub_tb #(
  parameter int DATA_W = 32
);
  `TB_CLOCK_RESET
  logic              HSEL, HREADY, HREADYOUT, HRESP;
  logic [1:0]        HTRANS;
  logic [DATA_W-1:0] HRDATA;
  int                st;        // model: 0 OKAY, 1 ERROR first cycle, 2 ERROR second cycle
  bit                dp_ours;   // model: the data phase this cycle is ours
  int                n_err, n_b2b, n_okay;

  basechili_ahb_default_sub #(.DATA_W(DATA_W)) dut (.clk, .rst_n, .HSEL, .HTRANS, .HREADY, .HREADYOUT, .HRESP, .HRDATA);

  initial begin
    HSEL = 1'b0; HTRANS = 2'b00; HREADY = 1'b1;
    tb_reset();
    st = 0; dp_ours = 0; n_err = 0; n_b2b = 0; n_okay = 0;
    for (int t = 0; t < 20000; t++) begin
      bit take;
      HSEL   = ($urandom % 4) != 0;
      HTRANS = ($urandom % 3 == 0) ? 2'($urandom) : {1'b1, 1'($urandom)};
      HREADY = dp_ours ? (st != 1) : (($urandom % 4) != 0);
      #1;
      `CHECK(HREADYOUT == (st != 1) && HRESP == (st != 0) && HRDATA == '0,
             $sformatf("t=%0d st=%0d HREADYOUT=%b HRESP=%b HRDATA=%h", t, st, HREADYOUT, HRESP, HRDATA))
      if (dp_ours && st == 0) n_okay++;
      take = HSEL && HREADY && HTRANS[1];
      if (take && st == 2) n_b2b++;
      @(posedge clk); #1;
      dp_ours = (st == 1) || (HSEL && HREADY);
      st = (st == 1) ? 2 : (take ? 1 : 0);
      if (st == 1) n_err++;
      @(negedge clk);
    end
    `CHECK(n_err > 1000 && n_b2b > 100 && n_okay > 100, $sformatf("coverage err=%0d b2b=%0d okay=%0d", n_err, n_b2b, n_okay))
    tb_pass();
  end
endmodule
