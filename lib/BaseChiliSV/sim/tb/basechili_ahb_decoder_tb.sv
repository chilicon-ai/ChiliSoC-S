// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_decoder -- the TB derives N non-overlapping
// regions from N and ADDR_W: region i is the top K address bits equal to i
// (codes N .. 2**K-1 decode to no region), and odd regions also need the
// next lower address bit clear (a smaller region, holes go to sel_default).
// Random plus boundary addresses (first / last address of each region and
// its neighbours) are checked against a model.
`include "tb_common.svh"
module basechili_ahb_decoder_tb #(
  parameter  int ADDR_W = 32,
  parameter  int N      = 2,
  localparam int K      = $clog2(N) + 1   // region code bits at the top of addr
);
  logic [ADDR_W-1:0] addr;
  logic [N-1:0]      sel;
  logic              sel_default;

  function automatic logic [N*ADDR_W-1:0] gen(bit want_mask);
    logic [N*ADDR_W-1:0] v = '0;
    for (int i = 0; i < N; i++) begin
      logic [ADDR_W-1:0] b, m;
      b = ADDR_W'(i) << (ADDR_W - K);
      m = ~(ADDR_W'('1) >> K);
      if (i % 2 == 1) m[ADDR_W-K-1] = 1'b1;   // odd: lower half of the code range only
      v[i*ADDR_W +: ADDR_W] = want_mask ? m : b;
    end
    return v;
  endfunction

  localparam logic [N*ADDR_W-1:0] BASE = gen(1'b0);
  localparam logic [N*ADDR_W-1:0] MASK = gen(1'b1);

  basechili_ahb_decoder #(.ADDR_W(ADDR_W), .N(N), .BASE(BASE), .MASK(MASK)) dut (.addr, .sel, .sel_default);

  // independent model: decode the top bits
  function automatic logic [N-1:0] model(logic [ADDR_W-1:0] a);
    int code = int'(a[ADDR_W-1 -: K]);
    if (code >= N) return '0;
    if (code % 2 == 1 && a[ADDR_W-K-1]) return '0;
    return N'(1) << code;
  endfunction

  int n_hit[N+1];   // checks per region, [N] = default

  task automatic check(logic [ADDR_W-1:0] a);
    logic [N-1:0] e;
    addr = a;
    #1 e = model(a);
    `CHECK(sel == e && sel_default == (e == '0),
           $sformatf("addr=%h sel=%b sel_default=%b expected %b", a, sel, sel_default, e))
    for (int i = 0; i < N; i++) if (e[i]) n_hit[i]++;
    if (e == '0) n_hit[N]++;
    #1;
  endtask

  function automatic logic [ADDR_W-1:0] rnd();
    return ADDR_W'({$urandom, $urandom, $urandom, $urandom});   // ADDR_W <= 128
  endfunction

  initial begin
    for (int i = 0; i < N; i++) n_hit[i] = 0;
    n_hit[N] = 0;
    // boundaries of every region and its neighbours
    for (int i = 0; i < N; i++) begin
      logic [ADDR_W-1:0] b = BASE[i*ADDR_W +: ADDR_W];
      logic [ADDR_W-1:0] m = MASK[i*ADDR_W +: ADDR_W];
      logic [ADDR_W-1:0] last = b | ~m;
      check(b); check(last); check(b - 1); check(last + 1);
    end
    check('0); check('1);
    // random: uniform, and biased to the region codes
    for (int t = 0; t < 20000; t++) begin
      logic [ADDR_W-1:0] a = rnd();
      if (t % 2 == 0) a[ADDR_W-1 -: K] = K'($urandom_range(0, (1 << K) - 1));
      check(a);
    end
    for (int i = 0; i <= N; i++)
      `CHECK(n_hit[i] > 0, $sformatf("region %0d never selected", i))
    tb_pass();
  end
endmodule
