// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_reg_array -- random writes (N_WR ports, the highest
// port winning a shared address) and reads against a model; out-of-range
// addresses (read zero, write dropped) when DEPTH is not a power of two;
// RESET_INIT = 1 checks a per-entry reset value (entry i resets to i + 1).
`include "tb_common.svh"
module basechili_reg_array_tb #(
  parameter  int WIDTH = 32,
  parameter  int DEPTH = 4,
  parameter  int N_RD  = 1,
  parameter  int N_WR  = 1,
  parameter  bit RESET_INIT = 1'b0,
  localparam int AW    = (DEPTH > 1) ? $clog2(DEPTH) : 1,
  parameter bit CLOCK_GATE = 1'b0
);
  `TB_CLOCK_RESET
  function automatic logic [DEPTH*WIDTH-1:0] init_val();
    logic [DEPTH*WIDTH-1:0] v;
    v = '0;
    if (RESET_INIT) for (int i = 0; i < DEPTH; i++) v[i*WIDTH +: WIDTH] = WIDTH'(i + 1);
    return v;
  endfunction
  localparam logic [DEPTH*WIDTH-1:0] RV = init_val();

  logic [N_WR-1:0]       we;
  logic [N_WR*AW-1:0]    waddr;
  logic [N_WR*WIDTH-1:0] wdata;
  logic [N_RD*AW-1:0]    raddr;
  logic [N_RD*WIDTH-1:0] rdata;
  logic [WIDTH-1:0]      model [2**AW];

  basechili_reg_array #(.WIDTH(WIDTH), .DEPTH(DEPTH), .N_RD(N_RD), .N_WR(N_WR), .CLOCK_GATE(CLOCK_GATE),
                        .RESET_VAL(RV)) dut (.clk, .rst_n, .test_en(1'b0), .we, .waddr, .wdata, .raddr, .rdata);

  initial begin
    we = '0; waddr = '0; wdata = '0; raddr = '0;
    for (int i = 0; i < 2**AW; i++) model[i] = (i < DEPTH) ? RV[i*WIDTH +: WIDTH] : '0;
    tb_reset();
    for (int t = 0; t < 5000; t++) begin
      for (int r = 0; r < N_RD; r++) raddr[r*AW +: AW] = AW'($urandom);
      #1;
      for (int r = 0; r < N_RD; r++) begin
        int ra;
        logic [WIDTH-1:0] e;
        ra = int'(raddr[r*AW +: AW]);
        e  = (ra < DEPTH) ? model[ra] : '0;
        `CHECK(rdata[r*WIDTH +: WIDTH] == e, $sformatf("port %0d addr %0d: %h expected %h", r, ra, rdata[r*WIDTH +: WIDTH], e))
      end
      for (int p = 0; p < N_WR; p++) begin
        we[p] = $urandom;
        waddr[p*AW +: AW] = AW'($urandom);
        wdata[p*WIDTH +: WIDTH] = WIDTH'({$urandom, $urandom});
      end
      // a shared address now and then (the highest port wins)
      if (N_WR > 1 && $urandom_range(3) == 0) waddr[(N_WR-1)*AW +: AW] = waddr[0 +: AW];
      @(posedge clk); #1;
      for (int p = 0; p < N_WR; p++)
        if (we[p] && int'(waddr[p*AW +: AW]) < DEPTH) model[waddr[p*AW +: AW]] = wdata[p*WIDTH +: WIDTH];
      @(negedge clk);
    end
    tb_pass();
  end
endmodule
