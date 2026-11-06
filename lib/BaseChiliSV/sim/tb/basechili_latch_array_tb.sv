// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_latch_array -- random writes / reads against a model;
// out-of-range addresses (read zero, write dropped) when DEPTH is not a
// power of two. Entries are compared once written (latches are not reset).
`include "tb_common.svh"
module basechili_latch_array_tb #(
  parameter  int WIDTH = 32,
  parameter  int DEPTH = 4,
  parameter  int N_RD  = 1,
  localparam int AW    = (DEPTH > 1) ? $clog2(DEPTH) : 1
);
  `TB_CLOCK_RESET
  logic                  we;
  logic [AW-1:0]         waddr;
  logic [WIDTH-1:0]      wdata;
  logic [N_RD*AW-1:0]    raddr;
  logic [N_RD*WIDTH-1:0] rdata;
  logic [WIDTH-1:0]      model [2**AW];
  logic [2**AW-1:0]      written;   // entry written since reset

  basechili_latch_array #(.WIDTH(WIDTH), .DEPTH(DEPTH), .N_RD(N_RD)) dut (.clk, .rst_n, .test_en(1'b0), .we, .waddr, .wdata, .raddr, .rdata);

  initial begin
    we = 1'b0; waddr = '0; wdata = '0; raddr = '0;
    for (int i = 0; i < 2**AW; i++) model[i] = '0;
    written = '0;
    tb_reset();
    for (int t = 0; t < 5000; t++) begin
      for (int r = 0; r < N_RD; r++) raddr[r*AW +: AW] = AW'($urandom);
      #1;
      for (int r = 0; r < N_RD; r++) begin
        int ra;
        logic [WIDTH-1:0] e;
        ra = int'(raddr[r*AW +: AW]);
        e  = (ra < DEPTH) ? model[ra] : '0;
        if (ra >= DEPTH || written[ra]) `CHECK(rdata[r*WIDTH +: WIDTH] == e, $sformatf("port %0d addr %0d: %h expected %h", r, ra, rdata[r*WIDTH +: WIDTH], e))
      end
      we = $urandom; waddr = AW'($urandom); wdata = WIDTH'({$urandom, $urandom});
      @(posedge clk); #1;
      if (we && int'(waddr) < DEPTH) begin model[waddr] = wdata; written[waddr] = 1'b1; end
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
