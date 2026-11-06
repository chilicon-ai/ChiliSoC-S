// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_onehot_check -- the four flags against a bit count:
// zero, every single bit, every pair of bits (N <= 16), then random
// vectors biased to 0, 1 and 2 bits set.
`include "tb_common.svh"
module basechili_onehot_check_tb #(
  parameter int N = 8
);
  logic [N-1:0] in;
  logic         zero, onehot, onehot0, multi;

  basechili_onehot_check #(.N(N)) dut (.in, .zero, .onehot, .onehot0, .multi);

  task automatic check(logic [N-1:0] v);
    int c;
    in = v;
    #1;
    c = $countones(v);
    `CHECK(zero == (c == 0) && onehot == (c == 1) && onehot0 == (c <= 1) && multi == (c >= 2),
           $sformatf("in=%b zero=%b onehot=%b onehot0=%b multi=%b", v, zero, onehot, onehot0, multi))
  endtask

  function automatic logic [N-1:0] rnd();
    logic [N-1:0] v;
    for (int b = 0; b < N; b++) v[b] = 1'($urandom);
    return v;
  endfunction

  initial begin
    check('0);
    check('1);
    for (int i = 0; i < N; i++) begin
      check(N'(1) << i);
      check('0);
    end
    if (N <= 16)
      for (int i = 0; i < N; i++)
        for (int j = i + 1; j < N; j++) check((N'(1) << i) | (N'(1) << j));
    for (int t = 0; t < 20000; t++) begin
      case ($urandom % 4)
        0: check('0);
        1: check(N'(1) << ($urandom % N));
        2: check((N'(1) << ($urandom % N)) | (N'(1) << ($urandom % N)));
        default: check(rnd());
      endcase
    end
    tb_pass();
  end
endmodule
