// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim testbench :: chillus_icache_tb (run by sim/unit.py)
//
// Self-checking: an IFU-like requester (requests held until granted, some
// withdrawn as a redirect may, at most 2 outstanding) against a bus memory
// model with random grant stalls, random response latency (1..LAT_MAX, in
// order) and bus errors on some words and on unprivileged fetches of a
// privileged region (0x4000 .. 0x4fff, as the bus may reject by HPROT). Every response is compared with the
// memory word (and error) of its request, in grant order. Phases change
// the code under the cache (new memory version) with nothing outstanding,
// then pulse flush (FENCE.I); debug_mode toggles now and then (uncached).
// Addresses span 64 KiB so lines conflict; the cacheable region is
// CACHE_BASE / CACHE_MASK. Prints TB PASS with the hit / miss counts.
// -----------------------------------------------------------------------------
module chillus_icache_tb #(
  parameter int          SIZE_KB    = 2,
  parameter logic [31:0] CACHE_BASE = 32'h0000_0000,
  parameter logic [31:0] CACHE_MASK = 32'h0000_8000,  // upper 32 KiB of each 64 KiB uncached
  parameter int          GNT_PCT    = 70,             // bus grant probability
  parameter int          LAT_MAX    = 4,              // bus response latency 1..LAT_MAX
  parameter int          N_REQ      = 200000,
  parameter int          SEED       = 1
);

  logic        clk = 1'b0;
  logic        rst_n;
  logic        flush;
  logic        debug_mode;
  logic        busy;         // refill running (WFI would wait)
  logic        c_req, c_gnt, c_priv, c_rvalid, c_err;
  logic [31:0] c_addr, c_rdata;
  logic        m_req, m_gnt, m_priv, m_rvalid, m_err;
  logic [31:0] m_addr, m_rdata;

  chillus_icache #(
    .ADDR_W     (32),
    .SIZE_KB    (SIZE_KB),
    .CACHE_BASE (CACHE_BASE),
    .CACHE_MASK (CACHE_MASK)
  ) u_dut (.*);

  always #5 clk = !clk;

  int unsigned version;   // memory contents version (changed between phases)

  function automatic logic [31:0] mem_word(input logic [31:0] a, input int unsigned v);
    logic [31:0] x;
    x = a ^ (v * 32'h9E37_79B9);
    x = x ^ (x >> 15);
    x = x * 32'h2C1B_3C6D;
    return x ^ (x >> 12);
  endfunction

  function automatic logic mem_err(input logic [31:0] a, input logic priv);
    return ((a[13:2] % 12'd193) == 12'd7) || (!priv && a[15:12] == 4'h4);
  endfunction

  // ---------------------------------------------------------------------------
  // Bus memory model
  // ---------------------------------------------------------------------------
  logic [31:0] bq_addr[$];   // granted, waiting for their response
  logic        bq_priv[$];
  int          bq_due[$];    // cycle each response may come
  int          cyc = 0;

  logic m_gnt_r;             // random grant, drawn each cycle
  always_ff @(negedge clk) m_gnt_r <= ($urandom % 100) < GNT_PCT;
  assign m_gnt = rst_n && m_gnt_r;

  always_ff @(posedge clk) begin
    cyc      <= cyc + 1;
    m_rvalid <= 1'b0;
    m_rdata  <= 'x;
    m_err    <= 1'bx;
    if (rst_n) begin
      if (bq_addr.size() > 0 && cyc >= bq_due[0]) begin
        m_rvalid <= 1'b1;
        m_rdata  <= mem_word(bq_addr[0], version);
        m_err    <= mem_err(bq_addr[0], bq_priv[0]);
        void'(bq_addr.pop_front());
        void'(bq_priv.pop_front());
        void'(bq_due.pop_front());
      end
      if (m_req && m_gnt) begin
        bq_addr.push_back(m_addr);
        bq_priv.push_back(m_priv);
        bq_due.push_back(cyc + 1 + int'($urandom % LAT_MAX));
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Requester (IFU-like)
  // ---------------------------------------------------------------------------
  logic [31:0] exp_addr[$];  // granted, waiting for their response
  logic        exp_priv[$];
  int          os;           // granted, response not yet received
  int          n_req = 0, n_rsp = 0, n_err_seen = 0;
  logic [31:0] next_addr;
  logic        quiesce;      // stop requesting (phase change)

  function automatic logic [31:0] pick_addr(input logic [31:0] prev);
    int r;
    r = int'($urandom % 100);
    if (r < 75) return prev + 32'd4;                              // sequential
    if (r < 90) return {16'h0, prev[15:6] + 10'($urandom % 5) - 10'd2, 6'h0} | {26'h0, 4'($urandom), 2'b0};  // nearby jump
    return {16'h0, 14'($urandom), 2'b00};                         // anywhere in 64 KiB
  endfunction

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      c_req     <= 1'b0;
      c_addr    <= '0;
      next_addr <= '0;
      os        <= 0;
    end else begin
      // responses
      if (c_rvalid) begin
        if (exp_addr.size() == 0) $fatal(1, "TB FAIL: response without a request");
        if (c_err !== mem_err(exp_addr[0], exp_priv[0]))
          $fatal(1, "TB FAIL: addr %h priv %b err %b, expected %b", exp_addr[0], exp_priv[0], c_err,
                 mem_err(exp_addr[0], exp_priv[0]));
        if (!c_err && c_rdata !== mem_word(exp_addr[0], version))
          $fatal(1, "TB FAIL: addr %h data %h, expected %h (version %0d)",
                 exp_addr[0], c_rdata, mem_word(exp_addr[0], version), version);
        n_err_seen <= n_err_seen + int'(c_err);
        void'(exp_addr.pop_front());
        void'(exp_priv.pop_front());
        n_rsp <= n_rsp + 1;
      end
      os <= os + int'(c_req && c_gnt) - int'(c_rvalid);
      // requests: hold until granted, or withdraw now and then (redirect)
      if (c_req && c_gnt) begin
        exp_addr.push_back(c_addr);
        exp_priv.push_back(c_priv);
        n_req     <= n_req + 1;
        next_addr <= pick_addr(c_addr);
      end
      if ((c_req && c_gnt) || !c_req || ($urandom % 100) < 5) begin
        c_req  <= !quiesce && (os + int'(c_req && c_gnt) - int'(c_rvalid) < 2) && (($urandom % 100) < 85);
        c_addr <= (c_req && c_gnt) ? pick_addr(c_addr)
                                   : ((($urandom % 100) < 50) ? next_addr : pick_addr(next_addr));
      end
    end
  end

  // privilege: changes only with a new request (as on a redirect), mostly M
  always_ff @(posedge clk) if (!c_req || c_gnt) c_priv <= ($urandom % 100) < 80;

  // ---------------------------------------------------------------------------
  // Phases: run, quiesce, change memory, flush; debug_mode now and then
  // ---------------------------------------------------------------------------
  initial begin
    void'($urandom(SEED));
    version    = 0;
    quiesce    = 1'b0;
    flush      = 1'b0;
    debug_mode = 1'b0;
    rst_n      = 1'b0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    while (n_req < N_REQ) begin
      repeat (2000 + ($urandom % 6000)) @(negedge clk);
      quiesce = 1'b1;
      while (os != 0 || c_req) @(negedge clk);
      if (($urandom % 4) == 0) begin
        debug_mode = !debug_mode;
      end else begin
        version = version + 1;            // code changed under the cache
        flush   = 1'b1;
        @(negedge clk);
        flush   = 1'b0;
      end
      quiesce = 1'b0;
    end
    quiesce = 1'b1;
    while (os != 0 || c_req) @(negedge clk);
    if (n_rsp != n_req) $fatal(1, "TB FAIL: %0d requests, %0d responses", n_req, n_rsp);
    if (n_err_seen == 0) $fatal(1, "TB FAIL: no bus error exercised");
    $display("TB PASS: %0d fetches, %0d errors, %0d versions", n_req, n_err_seen, version);
    $finish;
  end

  initial begin
    #(64'd2_000_000_000);
    $fatal(1, "TB FAIL: timeout");
  end

endmodule
