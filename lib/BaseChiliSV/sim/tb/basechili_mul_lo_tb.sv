// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_mul_lo -- random back-to-back operations plus
// corner operands; product = a * b mod 2^32, LATENCY edges later, in order
// (checked here and by the bound checker).
`include "tb_common.svh"
module basechili_mul_lo_tb #(
  parameter int LATENCY = 1,
  parameter bit CLOCK_GATE = 1'b0
);
  `TB_CLOCK_RESET
  logic        in_valid, out_valid;
  logic [31:0] a, b;
  logic [31:0] product;
  logic [31:0] exp_q[$];

  basechili_mul_lo #(.LATENCY(LATENCY), .CLOCK_GATE(CLOCK_GATE)) dut (.clk, .rst_n, .test_en(1'b0), .in_valid, .a, .b, .out_valid, .product);

  initial begin
    in_valid = 1'b0; a = '0; b = '0;
    tb_reset();
    for (int t = 0; t < 20000 + LATENCY; t++) begin
      if (out_valid) begin
        `CHECK(exp_q.size() > 0 && product == exp_q[0], $sformatf("product=%h expected %h", product, exp_q[0]))
        void'(exp_q.pop_front());
      end
      in_valid = (t < 20000) && ($urandom % 4 != 0);
      a = $urandom; b = $urandom;
      case (t % 13)
        0: a = 32'h8000_0000;
        1: b = 32'hFFFF_FFFF;
        2: begin a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; end
        3: a = '0;
        4: b = 32'h5555_5555;
        5: b = 32'hAAAA_AAAA;
        default: ;
      endcase
      if (in_valid) exp_q.push_back(a * b);
      @(negedge clk);
    end
    `CHECK(exp_q.size() == 0, "every operation came out")
    tb_pass();
  end
endmodule
