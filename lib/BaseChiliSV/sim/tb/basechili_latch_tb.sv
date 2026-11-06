// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_latch -- transparent while en, holds after en falls.
`include "tb_common.svh"
module basechili_latch_tb #(
  parameter int WIDTH = 1
);
  logic             en;
  logic [WIDTH-1:0] d, q, held;

  basechili_latch #(.WIDTH(WIDTH)) dut (.en, .d, .q);

  initial begin
    en = 1'b0; d = '0;
    for (int t = 0; t < 2000; t++) begin
      en = 1'b1;
      for (int k = 0; k < 3; k++) begin
        d = WIDTH'({$urandom, $urandom}); if (t % 40 == 0) d = ~d;
        #1 `CHECK(q == d, "transparent while en")
      end
      held = d;
      en = 1'b0; #1;
      for (int k = 0; k < 3; k++) begin
        d = WIDTH'({$urandom, $urandom});
        #1 `CHECK(q == held, "holds while en is low")
      end
    end
    tb_pass();
  end
endmodule
