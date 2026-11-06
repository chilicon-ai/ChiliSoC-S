// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_mux -- a random manager (address held while
// HREADY is low) and N subordinate models: the data-phase subordinate
// inserts random wait states and two-cycle ERROR responses, the others
// drive random outputs the mux must ignore. The bus response is checked
// against the subordinate selected in the address phase (model), and a
// zero-wait OKAY with zero HRDATA when no subordinate is in the data phase.
`include "tb_common.svh"
module basechili_ahb_mux_tb #(
  parameter int N      = 2,
  parameter int DATA_W = 32
);
  `TB_CLOCK_RESET
  logic [N-1:0]        sel, HREADYOUT_s, HRESP_s;
  logic [1:0]          HTRANS;
  logic [N*DATA_W-1:0] HRDATA_s;
  logic                HREADY, HRESP;
  logic [DATA_W-1:0]   HRDATA;

  int  dsel;        // model: data-phase subordinate, -1 for none
  int  err;         // model: ERROR response cycle of the data-phase subordinate (0 none, 1, 2)
  bit  hold;        // the manager holds its address phase (HREADY was low)
  int  n_wait, n_err, n_none, n_sub[N];

  basechili_ahb_mux #(.N(N), .DATA_W(DATA_W)) dut (.clk, .rst_n, .sel, .HTRANS, .HREADYOUT_s, .HRESP_s,
                                                   .HRDATA_s, .HREADY, .HRESP, .HRDATA);

  function automatic logic [DATA_W-1:0] rnd_data();
    return DATA_W'({$urandom, $urandom, $urandom, $urandom});   // DATA_W <= 128
  endfunction

  initial begin
    bit e_ready, e_resp;
    logic [DATA_W-1:0] e_data;
    sel = '0; HTRANS = 2'b00; HREADYOUT_s = '1; HRESP_s = '0; HRDATA_s = '0;
    tb_reset();
    dsel = -1; err = 0; hold = 0; n_wait = 0; n_err = 0; n_none = 0;
    for (int i = 0; i < N; i++) n_sub[i] = 0;
    for (int t = 0; t < 20000; t++) begin
      // manager: a new address phase unless the last one is still held
      if (!hold) begin
        HTRANS = ($urandom % 4 == 0) ? 2'($urandom) : {1'b1, 1'($urandom)};
        sel    = ($urandom % 6 == 0) ? '0 : N'(1) << ($urandom % N);
      end
      // subordinates: random outputs; the data-phase one follows AHB
      HREADYOUT_s = N'($urandom);
      HRESP_s     = N'($urandom);
      for (int i = 0; i < N; i++) HRDATA_s[i*DATA_W +: DATA_W] = rnd_data();
      if (dsel >= 0) begin
        if (err == 1) begin
          HREADYOUT_s[dsel] = 1'b1; HRESP_s[dsel] = 1'b1; err = 2;
        end else begin
          err = 0;
          case ($urandom % 6)
            0, 1:    begin HREADYOUT_s[dsel] = 1'b0; HRESP_s[dsel] = 1'b0; end   // wait state
            2:       begin HREADYOUT_s[dsel] = 1'b0; HRESP_s[dsel] = 1'b1; err = 1; end
            default: begin HREADYOUT_s[dsel] = 1'b1; HRESP_s[dsel] = 1'b0; end
          endcase
        end
      end
      #1;
      if (dsel < 0) begin
        e_ready = 1'b1; e_resp = 1'b0; e_data = '0; n_none++;
      end else begin
        e_ready = HREADYOUT_s[dsel]; e_resp = HRESP_s[dsel]; e_data = HRDATA_s[dsel*DATA_W +: DATA_W];
        n_sub[dsel]++;
        if (!e_ready) n_wait++;
        if (err == 1) n_err++;
      end
      `CHECK(HREADY == e_ready && HRESP == e_resp && HRDATA == e_data,
             $sformatf("t=%0d dsel=%0d HREADY=%b HRESP=%b HRDATA=%h expected %b %b %h",
                       t, dsel, HREADY, HRESP, HRDATA, e_ready, e_resp, e_data))
      @(posedge clk); #1;
      hold = !e_ready;
      if (e_ready) begin
        dsel = -1;
        if (HTRANS[1])
          for (int i = 0; i < N; i++) if (sel[i]) dsel = i;
      end
      @(negedge clk);
    end
    `CHECK(n_wait > 100 && n_err > 100 && n_none > 100, $sformatf("coverage wait=%0d err=%0d none=%0d", n_wait, n_err, n_none))
    for (int i = 0; i < N; i++) `CHECK(n_sub[i] > 100, $sformatf("subordinate %0d rarely in the data phase", i))
    tb_pass();
  end
endmodule
