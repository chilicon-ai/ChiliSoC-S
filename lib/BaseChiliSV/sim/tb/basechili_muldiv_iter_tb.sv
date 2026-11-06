// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_muldiv_iter -- random and corner multiplies and
// divides (b = 0, b = 1, a < b, all ones), interleaved, plus a restart of a
// running operation; results checked after WIDTH busy cycles.
`include "tb_common.svh"
module basechili_muldiv_iter_tb #(
  parameter int WIDTH = 32,
  parameter bit CLOCK_GATE = 1'b0
);
  `TB_CLOCK_RESET
  logic               start, div, busy, op;   // op: the operation under test
  logic [WIDTH-1:0]   a, b, quotient, remainder, exp_q, exp_r;
  logic [2*WIDTH-1:0] product, exp_p;

  basechili_muldiv_iter #(.WIDTH(WIDTH), .CLOCK_GATE(CLOCK_GATE)) dut (.clk, .rst_n, .test_en(1'b0), .start, .div, .a, .b, .busy, .product,
                                              .quotient, .remainder);

  initial begin
    start = 1'b0; div = 1'b0; a = '0; b = '0;
    tb_reset();
    for (int t = 0; t < 1200; t++) begin
      a = WIDTH'({$urandom, $urandom}); b = WIDTH'({$urandom, $urandom});
      div = $urandom % 2;
      if (t % 3 == 0) b = b >> ($urandom % WIDTH);
      if (t % 7 == 0) b = '0;
      if (t % 11 == 0) b = 1;
      if (t % 13 == 0) a = '1;
      if (t % 17 == 0) b = '1;
      if (t % 19 == 0) a = '0;
      exp_p = (2*WIDTH)'(a) * (2*WIDTH)'(b);
      if (b == '0) begin exp_q = '1; exp_r = a; end
      else begin exp_q = a / b; exp_r = a % b; end
      if (t % 23 == 0) begin
        // a running operation of the other kind, restarted midway
        start = 1'b1; div = !div; @(negedge clk); start = 1'b0; div = !div;
        repeat ($urandom % WIDTH) @(negedge clk);
      end
      op = div; start = 1'b1; @(negedge clk); start = 1'b0;
      for (int k = 0; k < WIDTH; k++) begin
        `CHECK(busy, "busy for WIDTH cycles")
        a = WIDTH'($urandom); b = WIDTH'($urandom); div = $urandom % 2;
        @(negedge clk);
      end
      `CHECK(!busy, "busy after WIDTH cycles")
      if (op) begin
        `CHECK(quotient == exp_q && remainder == exp_r,
               $sformatf("divide: q=%h r=%h expected %h %h", quotient, remainder, exp_q, exp_r))
      end else begin
        `CHECK(product == exp_p, $sformatf("multiply: product=%h expected %h", product, exp_p))
      end
    end
    tb_pass();
  end
endmodule
