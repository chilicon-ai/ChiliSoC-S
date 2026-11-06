// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_dma -- sf-pdma style transfers on every channel
// through APB, against an AHB-Lite memory model.
//
// Stimulus: on random channels, transfers as sf-pdma issues them (claim,
// Next config / bytes / dst / src, then claim | run | done_ie | error_ie)
// with random sizes (0 .. 64 bytes) and byte alignments of source and
// destination, so beats of 1, 2 and 4 bytes mix; channels run at the same
// time and interleave; the memory inserts random wait states and answers
// ERROR (two cycles) for a poisoned byte placed in some transfers' source
// or destination; aborts (run 0) at random times; repeat transfers aborted
// after some reloads; an access to a channel past N_CH.
// Checked: after each transfer the destination holds the source bytes for
// the part done (next_bytes - exec_bytes) and its old bytes after it, with
// the guard bytes around it untouched; done at the end, error after a
// poisoned access, neither after an abort that stopped early; exec_bytes 0
// after done; irq[2c] / irq[2c+1] follow done & done_ie / error & error_ie;
// AHB: single NONSEQ transfers with HADDR aligned to HSIZE, at most a word;
// PSLVERR past the last channel; every channel and beat size used.
`include "tb_common.svh"
module chilimix_dma_tb #(
  parameter int N_CH = 1
);
  localparam int N_TR    = 2500;
  localparam int MEM_B   = 1 << 15;   // 32 KiB, aliased over the address space (HADDR[14:0]):
                                      // channel c uses [c*0x2000, +0x2000)
  localparam logic [11:0] CONTROL = 12'h000, NCFG = 12'h004, NBYTES = 12'h008, NDST = 12'h010,
                          NSRC = 12'h018, XBYTES = 12'h108;
  localparam logic [31:0] CLAIM = 32'h1, RUN = 32'h2, DONE_IE = 32'h4000, ERR_IE = 32'h8000,
                          DONE = 32'h4000_0000, ERR = 32'h8000_0000;

  `TB_CLOCK_RESET

  logic              PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [13:0]       PADDR;
  logic [31:0]       PWDATA, PRDATA;
  logic [3:0]        PSTRB;
  logic [31:0]       HADDR, HWDATA, HRDATA;
  logic [1:0]        HTRANS;
  logic              HWRITE, HMASTLOCK, HREADY, HRESP;
  logic [2:0]        HSIZE, HBURST;
  logic [3:0]        HPROT;
  logic [2*N_CH-1:0] irq;

  chilimix_dma #(.N_CH(N_CH)) dut (.*);

  // ---- AHB-Lite memory -------------------------------------------------------------
  logic [7:0]  mem [MEM_B];
  logic        poison [MEM_B];       // an access touching it answers ERROR
  logic        dp_valid, dp_write, dp_err, err2;
  logic [31:0] dp_addr;
  logic [2:0]  dp_size;
  int          dp_wait;
  int          wait_max;
  int          n_size [3];
  int          n_err_resp, n_waits;

  function automatic logic f_err(input logic [31:0] a, input logic [2:0] sz);
    for (int i = 0; i < (1 << sz); i++)
      if (poison[15'(a + i)]) return 1'b1;
    return 1'b0;
  endfunction

  always_comb begin
    HRDATA = '0;
    if (!dp_valid) begin
      HREADY = 1; HRESP = 0;
    end else if (dp_wait > 0) begin
      HREADY = 0; HRESP = 0;
    end else if (dp_err && !err2) begin
      HREADY = 0; HRESP = 1;
    end else begin
      HREADY = 1; HRESP = dp_err;
    end
    if (dp_valid && !dp_write && !dp_err)
      for (int i = 0; i < 4; i++)
        HRDATA[8*i +: 8] = mem[{dp_addr[14:2], 2'(i)}];
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dp_valid <= 0; err2 <= 0;
    end else begin
      if (dp_valid) begin
        if (dp_wait > 0) begin
          dp_wait <= dp_wait - 1; n_waits++;
        end else if (dp_err && !err2) begin
          err2 <= 1;
        end else begin
          if (dp_write && !dp_err)
            for (int i = 0; i < (1 << dp_size); i++)
              mem[15'(dp_addr + i)] <= HWDATA[8*(dp_addr[1:0] + i) +: 8];
          dp_valid <= 0; err2 <= 0;
          if (dp_err) n_err_resp++;
        end
      end
      if (HREADY && HTRANS[1]) begin
        `CHECK(HTRANS == 2'b10 && HBURST == 3'd0 && !HMASTLOCK, "single NONSEQ transfers")
        `CHECK(HSIZE <= 3'd2 && (HADDR & ((32'd1 << HSIZE) - 1)) == 0, "HADDR aligned to HSIZE")
        n_size[HSIZE]++;
        dp_valid <= 1; dp_write <= HWRITE; dp_addr <= HADDR; dp_size <= HSIZE;
        dp_err   <= f_err(HADDR, HSIZE);
        dp_wait  <= (wait_max == 0) ? 0 : $urandom % (wait_max + 1);
        err2     <= 0;
      end
    end
  end

  // ---- APB ------------------------------------------------------------------------
  task automatic apb(input logic w, input logic [13:0] a, input logic [31:0] d, output logic [31:0] q,
                     output logic err);
    PSEL = 1; PENABLE = 0; PWRITE = w; PADDR = a; PWDATA = d; PSTRB = 4'hf;
    @(negedge clk);
    PENABLE = 1;
    #1;
    q = PRDATA; err = PSLVERR;
    `CHECK(PREADY, "APB ready")
    @(negedge clk);
    PSEL = 0; PENABLE = 0;
  endtask

  task automatic wr(input int c, input logic [11:0] a, input logic [31:0] d);
    logic [31:0] q;
    logic        e;
    apb(1'b1, {2'(c), a}, d, q, e);
    `CHECK(!e, "APB write")
  endtask

  task automatic rd(input int c, input logic [11:0] a, output logic [31:0] q);
    logic e;
    apb(1'b0, {2'(c), a}, '0, q, e);
    `CHECK(!e, "APB read")
  endtask

  // ---- per channel state -------------------------------------------------------------
  logic        busy [N_CH];
  logic [31:0] t_src [N_CH], t_dst [N_CH], t_bytes [N_CH], t_ie [N_CH];
  logic        t_poison [N_CH], t_abort [N_CH], t_repeat [N_CH];
  int          t_pos [N_CH];             // the poisoned byte (absolute address)
  logic [7:0]  src_img [N_CH][64];       // source bytes at start
  logic [7:0]  dst_img [N_CH][72];       // destination with 4 guard bytes each side
  int          n_done, n_err, n_abort, n_empty, n_repeat, n_tr_ch [N_CH];

  task automatic start(input int c);
    logic [31:0] base, b, s, d, cfg;
    base = 32'(c) * 32'h2000;
    b = ($urandom % 10 == 0) ? 32'd0 : 32'($urandom % 65);
    s = base + 32'h100 + 32'($urandom % 512);
    d = base + 32'h1000 + 32'($urandom % 512);
    t_repeat[c] = ($urandom % 12 == 0) && b != 0;
    t_poison[c] = ($urandom % 6 == 0) && b != 0 && !t_repeat[c];
    t_abort[c]  = t_repeat[c] || (!t_poison[c] && $urandom % 8 == 0);
    for (int i = 0; i < 64; i++) mem[s + i] = 8'($urandom);
    for (int i = -4; i < 68; i++) mem[d + i] = 8'($urandom);
    for (int i = 0; i < 64; i++) src_img[c][i] = mem[s + i];
    for (int i = 0; i < 72; i++) dst_img[c][i] = mem[d - 4 + i];
    if (t_poison[c]) begin
      t_pos[c] = ($urandom % 2) ? int'(s) + $urandom % int'(b) : int'(d) + $urandom % int'(b);
      poison[t_pos[c]] = 1;
    end
    s = s | ($urandom & 32'hffff_8000);   // the memory aliases: any high bits
    d = d | ($urandom & 32'hffff_8000);
    t_src[c] = s; t_dst[c] = d; t_bytes[c] = b;
    t_ie[c] = ($urandom % 2) ? (DONE_IE | ERR_IE) : 32'd0;
    cfg = {4'd2, 4'd2, 20'd0, 1'b1, t_repeat[c], 2'd0};
    wr(c, CONTROL, CLAIM);
    wr(c, NCFG, cfg); wr(c, NBYTES, b); wr(c, NDST, d); wr(c, NSRC, s);
    wr(c, CONTROL, CLAIM | RUN | t_ie[c]);
    busy[c] = 1;
    n_tr_ch[c]++;
  endtask

  task automatic finish(input int c);
    logic [31:0] q, left, done_b;
    rd(c, CONTROL, q);
    if (q[1]) begin
      if (t_abort[c] && $urandom % 3 == 0) begin
        wr(c, CONTROL, CLAIM | t_ie[c]);     // abort
        t_abort[c] = 0;
        n_abort++;
      end
      return;
    end
    @(negedge clk);
    rd(c, XBYTES, left);
    done_b = t_repeat[c] ? 32'd0 : t_bytes[c] - left;
    if (t_poison[c]) begin
      `CHECK(q[31] && !q[30], "error after a poisoned access")
      n_err++;
      poison[t_pos[c]] = 0;
    end else if (!t_repeat[c] && left == 0) begin
      `CHECK(q[30] && !q[31], "done at the end")
      if (t_bytes[c] == 0) n_empty++; else n_done++;
    end else begin
      `CHECK(!q[31], "no error after an abort")
      if (t_repeat[c]) n_repeat++;
    end
    if (t_ie[c] != 0) begin
      `CHECK(irq[2*c] == q[30] && irq[2*c+1] == q[31], "irq follows done / error")
    end else begin
      `CHECK(irq[2*c] == 0 && irq[2*c+1] == 0, "irq masked")
    end
    // destination: the part done holds the source, the rest and the guards are unchanged
    if (!t_repeat[c]) begin
      for (int i = 0; i < 72; i++) begin
        logic [7:0] e;
        e = (i >= 4 && i - 4 < int'(done_b)) ? src_img[c][i - 4] : dst_img[c][i];
        `CHECK(mem[15'(t_dst[c] - 4 + i)] == e, "destination bytes")
      end
    end else begin
      for (int i = 0; i < 72; i++) begin
        logic [7:0] e;
        e = (i >= 4 && i - 4 < int'(t_bytes[c])) ? src_img[c][i - 4] : dst_img[c][i];
        if (i < 4 || i >= 4 + int'(t_bytes[c])) `CHECK(mem[15'(t_dst[c] - 4 + i)] == e, "guard bytes (repeat)")
      end
    end
    wr(c, CONTROL, (q | t_ie[c]) & ~(DONE | ERR | RUN));
    @(negedge clk);
    `CHECK(irq[2*c] == 0 && irq[2*c+1] == 0, "irq low after clearing")
    if ($urandom % 2) wr(c, CONTROL, '0);
    busy[c] = 0;
  endtask

  initial begin
    logic [31:0] q;
    logic        e;
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    wait_max = 0;
    for (int i = 0; i < MEM_B; i++) begin mem[i] = '0; poison[i] = 0; end
    for (int c = 0; c < N_CH; c++) busy[c] = 0;
    tb_reset();
    if (N_CH < 4) begin
      apb(1'b0, 14'h3000, '0, q, e);
      `CHECK(e, "PSLVERR past the last channel")
    end
    for (int t = 0; t < N_TR * N_CH; t++) begin
      int c;
      c = $urandom % N_CH;
      if (t % 50 == 0) wait_max = $urandom % 4;
      if (busy[c]) finish(c);
      else start(c);
      repeat ($urandom % 40) @(negedge clk);
    end
    for (int c = 0; c < N_CH; c++) begin
      int n = 0;
      t_abort[c] = t_repeat[c];
      while (busy[c] && n < 5000) begin finish(c); n++; end
      `CHECK(!busy[c], "every transfer ends")
    end
    $display("done %0d error %0d abort %0d empty %0d repeat %0d; beats 1/2/4 B: %0d %0d %0d; ERROR responses %0d, wait states %0d",
             n_done, n_err, n_abort, n_empty, n_repeat, n_size[0], n_size[1], n_size[2], n_err_resp, n_waits);
    for (int c = 0; c < N_CH; c++) `CHECK(n_tr_ch[c] > 20, "every channel used")
    `CHECK(n_done > 50 * N_CH && n_err > 5 && n_abort > 5 && n_empty > 5 && n_repeat > 2 &&
           n_size[0] > 100 && n_size[1] > 100 && n_size[2] > 100, "coverage")
    tb_pass();
  end
endmodule
