// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_byte_strobe -- exhaustive offset x size.
`include "tb_common.svh"
module basechili_byte_strobe_tb #(
  parameter  int DATA_W = 32,
  localparam int N_LANE = DATA_W / 8,
  localparam int OFF_W  = $clog2(N_LANE),
  localparam int SIZE_W = $clog2(OFF_W + 1)
);
  logic [OFF_W-1:0]  offset;
  logic [SIZE_W-1:0] size;
  logic [N_LANE-1:0] strb, exp_s;

  basechili_byte_strobe #(.DATA_W(DATA_W)) dut (.offset, .size, .strb);

  initial begin
    for (int r = 0; r < 2; r++)
      for (int s = 0; s < 2**SIZE_W; s++)
        for (int o = 0; o < N_LANE; o++) begin
          offset = OFF_W'(o); size = SIZE_W'(s);
          for (int i = 0; i < N_LANE; i++) exp_s[i] = (s <= OFF_W) && (i >= o) && (i < o + (1 << s));
          #1 `CHECK(strb == exp_s, $sformatf("offset=%0d size=%0d strb=%b expected %b", o, s, strb, exp_s))
        end
    tb_pass();
  end
endmodule
