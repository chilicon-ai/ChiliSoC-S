// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim/tb/axi4_tb.svh :: AXI4 traffic models for the fabric testbenches
// (simulation only)
//
//   axi4_tb_mgr  random manager: write / read bursts (FIXED / INCR / WRAP,
//                every size, random WSTRB), W beats possibly before their AW,
//                VALID gaps, B / R stalls. Addresses fall in region r
//                (r << REG_W) inside a block of this manager
//                ((IDX + k * NM) << BLK_W), r in 0..NR-1, or unmapped (region
//                NR, random upper address bits, up to 256 beats: DECERR
//                expected, RDATA 0). Memory responses: axi4_tb_resp(ID), or
//                per word axi4_tb_word_resp (RESP_MODE 1, B the worst beat),
//                or as an AHB bridge answers (RESP_MODE 3: SLVERR on those
//                words, RDATA not checked then, B the worst strobed beat).
//                Reads and writes in flight never share a word. Checks every B / R in issue order: ID, RESP,
//                RLAST, RDATA against its reference memory.
//   axi4_tb_sub  subordinate memory: AW / W / AR accepted independently with
//                random READY (W beats before their AW, up to 32 buffered),
//                B and R in order with random VALID gaps; R starts after a
//                random delay. Returns the AxID it received, and
//                axi4_tb_resp(ID) as BRESP / RRESP.
//   axil_tb_sub  AXI4-Lite subordinate memory, responses axi4_tb_word_resp.
//   axil_tb_mgr  random AXI4-Lite manager: AW and W offered apart or
//                together, reads in parallel, B / R stalls; addresses in
//                region r (r << REG_W), r in 0..NR-1, or unmapped (region NR,
//                random upper bits: DECERR, RDATA 0). A read and a write in
//                flight never share a word. Checks B / R in order against
//                axi4_tb_word_resp and its reference memory.
//
// All start from axi4_tb_init (a hash of each byte address, the same at
// every data width), and drive after a falling edge, sample #1 later
// (tb_common.svh convention).
// -----------------------------------------------------------------------------
`ifndef BASECHILI_AXI4_TB_SVH
`define BASECHILI_AXI4_TB_SVH
`include "tb_common.svh"

// initial content of memory word w of nb bytes: byte a of memory holds a hash
// of a, so models of different data widths agree
function automatic logic [1023:0] axi4_tb_init(longint w, int nb);
  logic [1023:0] v;
  v = '0;
  for (int k = 0; k < nb; k++) begin
    logic [31:0] h;
    h = 32'(w * nb + k) * 32'h9E37_79B1;
    v[k*8 +: 8] = h[31:24] ^ h[15:8];
  end
  return v;
endfunction

// response of a memory subordinate to ID id: its low RID_B (<= 2) bits, which
// are the manager's own ID bits at every fabric level
function automatic logic [1:0] axi4_tb_resp(longint id, int rid_b);
  return 2'(id & ((longint'(1) << rid_b) - 1));
endfunction

// response of an AXI4-Lite memory to a word (RESP_MODE 1 of axi4_tb_mgr)
function automatic logic [1:0] axi4_tb_word_resp(longint w);
  if (w % 13 == 5) return 2'b10;   // SLVERR
  if (w % 29 == 7) return 2'b11;   // DECERR
  return 2'b00;
endfunction

// byte address of beat n of a burst (AXI A3.4.1)
function automatic longint axi4_tb_beat(longint start, int size, int len, int burst, int n);
  longint nb, bl, aligned, wb, a;
  nb = longint'(1) << size;
  bl = len + 1;
  if (burst == 0 || n == 0) return start;
  aligned = (start / nb) * nb;
  wb = (start / (nb * bl)) * (nb * bl);
  a = aligned + n * nb;
  if (burst == 2 && a >= wb + nb * bl) a = a - nb * bl;
  return a;
endfunction

module axi4_tb_mgr #(
  parameter  int ID_W   = 4,
  parameter  int ADDR_W = 32,
  parameter  int DATA_W = 64,
  parameter  int IDX    = 0,      // manager index: blocks IDX + k * NM of every region
  parameter  int NM     = 1,      // managers sharing the regions
  parameter  int NR     = 2,      // mapped regions
  parameter  int REG_W  = 16,     // log2 region size in bytes
  parameter  int BLK_W  = 10,     // log2 block size in bytes
  parameter  int P_ERR  = 10,     // percent of bursts to the unmapped region NR
  parameter  int P_IDLE = 30,     // percent of cycles without a new burst
  parameter  bit WIDE   = 0,      // also mapped bursts get random bits above the regions and up to 256 beats
  parameter  int RESP_MODE = 0,   // mapped responses: 0 axi4_tb_resp(ID); 1 per beat
                                  // axi4_tb_word_resp(word), B the worst of the burst; 2 OKAY;
                                  // 3 SLVERR where mode 1 errs, B the worst beat with strobes
  parameter  bit ALL_LANES = 1,   // RDATA checked on every lane (0: only the beat's active lanes)
  parameter  int ID_SET = 0,      // > 0: IDs drawn from ID_SET random values fixed at start
  localparam int RID_B  = (ID_W < 2) ? ID_W : 2,
  localparam int N_LANE = DATA_W / 8,
  localparam int OFF_W  = $clog2(N_LANE)
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              drain,    // stop starting bursts
  output logic              done,     // drained: nothing in flight
  output int                n_b,      // B received
  output int                n_r,      // reads completed
  output int                n_err,    // DECERR responses checked
  output logic [ID_W-1:0]   AWID,
  output logic [ADDR_W-1:0] AWADDR,
  output logic [7:0]        AWLEN,
  output logic [2:0]        AWSIZE,
  output logic [1:0]        AWBURST,
  output logic              AWLOCK,
  output logic [3:0]        AWCACHE,
  output logic [2:0]        AWPROT,
  output logic [3:0]        AWQOS,
  output logic              AWVALID,
  input  logic              AWREADY,
  output logic [DATA_W-1:0] WDATA,
  output logic [N_LANE-1:0] WSTRB,
  output logic              WLAST,
  output logic              WVALID,
  input  logic              WREADY,
  input  logic [ID_W-1:0]   BID,
  input  logic [1:0]        BRESP,
  input  logic              BVALID,
  output logic              BREADY,
  output logic [ID_W-1:0]   ARID,
  output logic [ADDR_W-1:0] ARADDR,
  output logic [7:0]        ARLEN,
  output logic [2:0]        ARSIZE,
  output logic [1:0]        ARBURST,
  output logic              ARLOCK,
  output logic [3:0]        ARCACHE,
  output logic [2:0]        ARPROT,
  output logic [3:0]        ARQOS,
  output logic              ARVALID,
  input  logic              ARREADY,
  input  logic [ID_W-1:0]   RID,
  input  logic [DATA_W-1:0] RDATA,
  input  logic [1:0]        RRESP,
  input  logic              RLAST,
  input  logic              RVALID,
  output logic              RREADY
);
  typedef struct {
    logic [ID_W-1:0] id;
    longint          addr [];   // beat byte addresses
    int              size, len, burst;
    bit              err;       // unmapped region
    logic [3:0]      attr;      // AxCACHE / AxQOS seed
  } burst_t;

  logic [DATA_W-1:0] ref_mem [longint];   // words written so far (others: axi4_tb_init)
  int                wr_hold [longint];   // write bursts in flight on the word
  int                rd_hold [longint];   // read bursts in flight on the word
  burst_t            awq[$];              // AW to send
  burst_t            wq[$];               // W beats to send (front on W)
  burst_t            bq[$];               // B expected in order
  burst_t            arq[$];              // AR to send
  burst_t            rq[$];               // R expected in order
  int                w_beat, r_beat;
  bit                aw_fire, w_fire, ar_fire;
  int                n_type [3];
  logic [ID_W-1:0]   id_pool [ID_SET > 0 ? ID_SET : 1];
  logic [1:0]        w_worst;             // RESP_MODE 3: worst strobed beat of the W burst so far
  logic [1:0]        b_ahb[$];            // RESP_MODE 3: B expected per W burst, in order

  function automatic longint word(longint a);
    return a >> OFF_W;
  endfunction

  function automatic logic [DATA_W-1:0] mem(longint w);
    if (ref_mem.exists(w)) return ref_mem[w];
    return DATA_W'(axi4_tb_init(w, N_LANE));
  endfunction

  function automatic logic [DATA_W-1:0] rnd_data();
    logic [DATA_W-1:0] v;
    for (int i = 0; i < DATA_W; i += 32) v[i +: 32] = $urandom;
    return v;
  endfunction

  function automatic burst_t new_burst();
    burst_t b;
    longint nb, bl, blk, start, base;
    int     nblk;
    b.id    = (ID_SET > 0) ? id_pool[$urandom % ID_SET] : ID_W'($urandom);
    b.burst = $urandom % 3;
    b.size  = $urandom_range(0, OFF_W);
    b.err   = ($urandom % 100) < P_ERR;
    b.attr  = 4'($urandom);
    if (b.burst == 2) b.len = (2 << ($urandom % 4)) - 1;
    else b.len = ($urandom % 10 == 0) ? $urandom_range(16, 63) : $urandom % 16;
    if ((b.err || WIDE) && $urandom % 4 == 0) begin b.burst = 1; b.size = 0; b.len = $urandom_range(64, 255); end
    nb    = longint'(1) << b.size;
    bl    = b.len + 1;
    blk   = longint'(1) << BLK_W;
    start = ($urandom % 3 != 0) ? longint'($urandom % 8) * nb * bl : longint'($urandom);
    start = start % blk;
    if (b.burst != 1) start = start - (start % nb);
    if (b.burst == 0 && ($urandom % 2)) start = start + ($urandom % nb);
    if (b.burst == 1 && start + nb * bl > blk) start = 0;
    nblk = (1 << (REG_W - BLK_W)) / NM;
    base = (longint'(b.err ? NR : $urandom % NR) << REG_W) + (longint'(IDX + NM * ($urandom % nblk)) << BLK_W);
    if ((b.err || WIDE) && $urandom % 2) base = base | ((longint'({$urandom, $urandom}) >> (REG_W + 2)) << (REG_W + 2));
    if (ADDR_W < 64) base = base & ((longint'(1) << ADDR_W) - 1);
    b.addr = new[b.len + 1];
    for (int n = 0; n <= b.len; n++) b.addr[n] = base + axi4_tb_beat(start, b.size, b.len, b.burst, n);
    return b;
  endfunction

  function automatic bit free_of(burst_t b, bit for_write);
    if (b.err) return 1;
    foreach (b.addr[n]) begin
      longint w;
      w = word(b.addr[n]);
      if (for_write ? (rd_hold.exists(w) && rd_hold[w] != 0) : (wr_hold.exists(w) && wr_hold[w] != 0)) return 0;
    end
    return 1;
  endfunction

  task automatic hold(burst_t b, bit write, int d);
    if (b.err) return;
    foreach (b.addr[n]) begin
      longint w;
      w = word(b.addr[n]);
      if (write) wr_hold[w] = (wr_hold.exists(w) ? wr_hold[w] : 0) + d;
      else       rd_hold[w] = (rd_hold.exists(w) ? rd_hold[w] : 0) + d;
    end
  endtask

  // active byte lanes of beat n: from its address (an unaligned first beat
  // starts there) to the end of its 2^size container
  function automatic logic [N_LANE-1:0] lanes(burst_t b, int n);
    int lo, hi;
    logic [N_LANE-1:0] m;
    lo = int'(b.addr[n] % N_LANE);
    hi = lo - (lo % (1 << b.size)) + (1 << b.size);
    m  = '0;
    for (int l = lo; l < hi; l++) m[l] = 1'b1;
    return m;
  endfunction

  // expected response: of beat n, or of the whole burst (n < 0: the worst beat)
  function automatic logic [1:0] exp_resp(burst_t b, int n);
    logic [1:0] r;
    if (b.err) return 2'b11;
    if (RESP_MODE == 0) return axi4_tb_resp(b.id, RID_B);
    if (RESP_MODE == 2) return 2'b00;
    if (RESP_MODE == 3) return (axi4_tb_word_resp(word(b.addr[n])) != 2'b00) ? 2'b10 : 2'b00;
    if (n >= 0) return axi4_tb_word_resp(word(b.addr[n]));
    r = 2'b00;
    foreach (b.addr[k]) if (axi4_tb_word_resp(word(b.addr[k])) > r) r = axi4_tb_word_resp(word(b.addr[k]));
    return r;
  endfunction

  function automatic bit idle();
    return awq.size() == 0 && wq.size() == 0 && bq.size() == 0 && arq.size() == 0 && rq.size() == 0;
  endfunction

  initial begin
    AWVALID = 0; WVALID = 0; ARVALID = 0; BREADY = 0; RREADY = 0;
    AWID = '0; AWADDR = '0; AWLEN = '0; AWSIZE = '0; AWBURST = '0; AWLOCK = 0; AWCACHE = '0; AWPROT = '0; AWQOS = '0;
    ARID = '0; ARADDR = '0; ARLEN = '0; ARSIZE = '0; ARBURST = '0; ARLOCK = 0; ARCACHE = '0; ARPROT = '0; ARQOS = '0;
    WDATA = '0; WSTRB = '0; WLAST = 0;
    w_beat = 0; r_beat = 0; n_b = 0; n_r = 0; n_err = 0; done = 0;
    foreach (id_pool[k]) id_pool[k] = ID_W'({$urandom, $urandom});
    aw_fire = 0; w_fire = 0; ar_fire = 0; w_worst = 2'b00;
    @(posedge rst_n);
    @(negedge clk);
    forever begin
      burst_t b;
      // new bursts
      if (!drain && ($urandom % 100) >= P_IDLE) begin
        b = new_burst();
        if ($urandom % 2) begin
          if (bq.size() < 10 && free_of(b, 1)) begin
            hold(b, 1, 1);
            awq.push_back(b); wq.push_back(b); bq.push_back(b);
          end
        end else if (rq.size() < 10 && free_of(b, 0)) begin
          hold(b, 0, 1);
          arq.push_back(b); rq.push_back(b);
          if (!b.err) n_type[b.burst]++;
        end
      end
      // AW
      if (!AWVALID || aw_fire) begin
        AWVALID = (awq.size() > 0) && ($urandom % 4 != 0);
        if (AWVALID) begin
          b = awq.pop_front();
          AWID = b.id; AWADDR = ADDR_W'(b.addr[0]); AWLEN = 8'(b.len); AWSIZE = 3'(b.size);
          AWBURST = 2'(b.burst); AWLOCK = b.attr[0]; AWCACHE = b.attr; AWPROT = b.attr[3:1]; AWQOS = ~b.attr;
        end
      end
      // W: may run ahead of AW (the front of wq need not have its AW out)
      if (!WVALID || w_fire) begin
        WVALID = (wq.size() > 0) && ($urandom % 4 != 0);
        if (WVALID) begin
          WDATA = rnd_data();
          WSTRB = lanes(wq[0], w_beat) & (($urandom % 3 != 0) ? '1 : N_LANE'($urandom));
          WLAST = (w_beat == wq[0].len);
        end
      end
      // AR
      if (!ARVALID || ar_fire) begin
        ARVALID = (arq.size() > 0) && ($urandom % 4 != 0);
        if (ARVALID) begin
          b = arq.pop_front();
          ARID = b.id; ARADDR = ADDR_W'(b.addr[0]); ARLEN = 8'(b.len); ARSIZE = 3'(b.size);
          ARBURST = 2'(b.burst); ARLOCK = b.attr[1]; ARCACHE = ~b.attr; ARPROT = b.attr[2:0]; ARQOS = b.attr;
        end
      end
      BREADY = ($urandom % 4 != 0);
      RREADY = ($urandom % 4 != 0);
      #1;
      aw_fire = AWVALID && AWREADY;
      w_fire  = WVALID && WREADY;
      ar_fire = ARVALID && ARREADY;
      if (w_fire) begin
        if (!wq[0].err) begin
          longint w;
          logic [DATA_W-1:0] v;
          w = word(wq[0].addr[w_beat]);
          v = mem(w);
          for (int l = 0; l < N_LANE; l++) if (WSTRB[l]) v[8*l +: 8] = WDATA[8*l +: 8];
          ref_mem[w] = v;
        end
        if (WSTRB != '0 && exp_resp(wq[0], w_beat) != 2'b00) w_worst = 2'b10;
        if (WLAST) begin b_ahb.push_back(w_worst); w_worst = 2'b00; void'(wq.pop_front()); w_beat = 0; end else w_beat++;
      end
      if (BVALID && BREADY) begin
        `CHECK(bq.size() > 0, $sformatf("mgr %0d: B with no write", IDX))
        if (bq.size() > 0) begin
          `CHECK(wq.size() < bq.size(), $sformatf("mgr %0d: B before the last W beat", IDX))
          `CHECK(BID == bq[0].id && BRESP == ((RESP_MODE == 3 && !bq[0].err) ? b_ahb[0] : exp_resp(bq[0], -1)),
                 $sformatf("mgr %0d: BID %h BRESP %b, expected %h", IDX, BID, BRESP, bq[0].id))
          if (bq[0].err) n_err++;
          hold(bq[0], 1, -1);
          void'(bq.pop_front());
          void'(b_ahb.pop_front());
          n_b++;
        end
      end
      if (RVALID && RREADY) begin
        `CHECK(rq.size() > 0, $sformatf("mgr %0d: R with no read", IDX))
        if (rq.size() > 0) begin
          logic [DATA_W-1:0] exp, cmp;   // expected data, lanes compared
          exp = rq[0].err ? '0 : mem(word(rq[0].addr[r_beat]));
          cmp = '1;
          if (!ALL_LANES) for (int l = 0; l < N_LANE; l++) cmp[8*l +: 8] = {8{lanes(rq[0], r_beat)[l]}};
          if (RESP_MODE == 3 && exp_resp(rq[0], r_beat) != 2'b00) cmp = '0;
          `CHECK(RID == rq[0].id && RRESP == exp_resp(rq[0], r_beat),
                 $sformatf("mgr %0d: RID %h RRESP %b, expected %h", IDX, RID, RRESP, rq[0].id))
          `CHECK((RDATA & cmp) == (exp & cmp), $sformatf("mgr %0d: R beat %0d addr %h: %h expected %h", IDX, r_beat,
                 rq[0].addr[r_beat], RDATA, exp))
          `CHECK(RLAST == (r_beat == rq[0].len), $sformatf("mgr %0d: RLAST at beat %0d of %0d", IDX, r_beat, rq[0].len + 1))
          if (r_beat == rq[0].len) begin
            if (rq[0].err) n_err++;
            hold(rq[0], 0, -1); void'(rq.pop_front()); r_beat = 0; n_r++;
          end else r_beat++;
        end
      end
      done = drain && idle() && !AWVALID && !WVALID && !ARVALID;
      @(negedge clk);
    end
  end
endmodule

module axi4_tb_sub #(
  parameter  int ID_W   = 4,
  parameter  int ADDR_W = 32,
  parameter  int DATA_W = 64,
  parameter  int P_STALL = 25,    // percent of cycles a READY is low
  parameter  int RID_B  = 2,      // ID bits that select the response (the managers' ID_W, at most 2)
  localparam int N_LANE = DATA_W / 8,
  localparam int OFF_W  = $clog2(N_LANE)
) (
  input  logic              clk,
  input  logic              rst_n,
  output int                n_w_early,   // W beats taken with no AW queued
  output int                n_aw_late,   // AWs taken after their whole W burst
  output int                n_wr,        // write bursts done
  output int                n_rd,        // read bursts done
  input  logic [ID_W-1:0]   AWID,
  input  logic [ADDR_W-1:0] AWADDR,
  input  logic [7:0]        AWLEN,
  input  logic [2:0]        AWSIZE,
  input  logic [1:0]        AWBURST,
  input  logic              AWVALID,
  output logic              AWREADY,
  input  logic [DATA_W-1:0] WDATA,
  input  logic [N_LANE-1:0] WSTRB,
  input  logic              WLAST,
  input  logic              WVALID,
  output logic              WREADY,
  output logic [ID_W-1:0]   BID,
  output logic [1:0]        BRESP,
  output logic              BVALID,
  input  logic              BREADY,
  input  logic [ID_W-1:0]   ARID,
  input  logic [ADDR_W-1:0] ARADDR,
  input  logic [7:0]        ARLEN,
  input  logic [2:0]        ARSIZE,
  input  logic [1:0]        ARBURST,
  input  logic              ARVALID,
  output logic              ARREADY,
  output logic [ID_W-1:0]   RID,
  output logic [DATA_W-1:0] RDATA,
  output logic [1:0]        RRESP,
  output logic              RLAST,
  output logic              RVALID,
  input  logic              RREADY
);
  typedef struct {
    logic [ID_W-1:0] id;
    longint          start;
    int              size, len, burst;
  } cmd_t;
  typedef struct {
    logic [DATA_W-1:0] data;
    logic [N_LANE-1:0] strb;
    bit                last;
  } wbeat_t;

  logic [DATA_W-1:0] mem [longint];
  cmd_t              awq[$], arq[$];
  wbeat_t            wbuf[$];
  logic [ID_W-1:0]   bq[$];
  int                w_beat, r_beat, r_wait;
  bit                b_fire, r_fire;

  function automatic logic [DATA_W-1:0] rd(longint w);
    if (mem.exists(w)) return mem[w];
    return DATA_W'(axi4_tb_init(w, N_LANE));
  endfunction

  initial begin
    AWREADY = 0; WREADY = 0; ARREADY = 0; BVALID = 0; RVALID = 0;
    BID = '0; BRESP = '0; RID = '0; RDATA = '0; RRESP = '0; RLAST = 0;
    w_beat = 0; r_beat = 0; r_wait = 0; b_fire = 0; r_fire = 0; n_w_early = 0; n_aw_late = 0; n_wr = 0; n_rd = 0;
    @(posedge rst_n);
    @(negedge clk);
    forever begin
      // apply buffered W beats to the oldest AW
      while (awq.size() > 0 && wbuf.size() > 0) begin
        longint w;
        logic [DATA_W-1:0] v;
        w = axi4_tb_beat(awq[0].start, awq[0].size, awq[0].len, awq[0].burst, w_beat) >> OFF_W;
        v = rd(w);
        for (int l = 0; l < N_LANE; l++) if (wbuf[0].strb[l]) v[8*l +: 8] = wbuf[0].data[8*l +: 8];
        mem[w] = v;
        if (wbuf[0].last != (w_beat == awq[0].len)) $error("sub: WLAST at beat %0d of %0d", w_beat, awq[0].len + 1);
        if (wbuf[0].last) begin bq.push_back(awq[0].id); void'(awq.pop_front()); w_beat = 0; end
        else w_beat++;
        void'(wbuf.pop_front());
      end
      // B
      if (!BVALID || b_fire) begin
        BVALID = (bq.size() > 0) && ($urandom % 100 >= P_STALL);
        if (BVALID) begin BID = bq[0]; BRESP = axi4_tb_resp(longint'(bq[0]), RID_B); end
      end
      // R
      if (!RVALID || r_fire) begin
        RVALID = (arq.size() > 0) && (r_wait == 0) && ($urandom % 100 >= P_STALL);
        if (RVALID) begin
          RID   = arq[0].id;
          RDATA = rd(axi4_tb_beat(arq[0].start, arq[0].size, arq[0].len, arq[0].burst, r_beat) >> OFF_W);
          RRESP = axi4_tb_resp(longint'(arq[0].id), RID_B);
          RLAST = (r_beat == arq[0].len);
        end
      end
      if (r_wait > 0) r_wait--;
      // long AWREADY-low stretches with W open let whole bursts pass before their AW
      AWREADY = ($urandom % 100 >= ((($time / 2000) % 4 == 0) ? 95 : P_STALL));
      WREADY  = (wbuf.size() < 32) && ($urandom % 100 >= P_STALL);
      ARREADY = (arq.size() < 4) && ($urandom % 100 >= P_STALL);
      #1;
      b_fire = BVALID && BREADY;
      r_fire = RVALID && RREADY;
      if (b_fire) begin void'(bq.pop_front()); n_wr++; end
      if (r_fire) begin
        if (RLAST) begin void'(arq.pop_front()); n_rd++; r_beat = 0; r_wait = $urandom % 3; end
        else r_beat++;
      end
      if (WVALID && WREADY) begin
        wbeat_t wb;
        if (awq.size() == 0) n_w_early++;
        wb.data = WDATA; wb.strb = WSTRB; wb.last = WLAST;
        wbuf.push_back(wb);
      end
      if (AWVALID && AWREADY) begin
        cmd_t c;
        if (awq.size() == 0 && wbuf.size() > 0 && wbuf[$].last) n_aw_late++;
        c.id = AWID; c.start = longint'(AWADDR); c.size = AWSIZE; c.len = AWLEN; c.burst = AWBURST;
        awq.push_back(c);
      end
      if (ARVALID && ARREADY) begin
        cmd_t c;
        c.id = ARID; c.start = longint'(ARADDR); c.size = ARSIZE; c.len = ARLEN; c.burst = ARBURST;
        arq.push_back(c);
      end
      @(negedge clk);
    end
  end
endmodule

// AXI4-Lite subordinate memory: AW / W / AR accepted independently with
// random READY (W before AW, up to 8 buffered), B and R in order with random
// VALID gaps, responses axi4_tb_word_resp(word); the memory is written
// whatever the response.
module axil_tb_sub #(
  parameter  int ADDR_W  = 32,
  parameter  int DATA_W  = 64,
  parameter  int P_STALL = 25,
  localparam int N_LANE  = DATA_W / 8,
  localparam int OFF_W   = $clog2(N_LANE)
) (
  input  logic              clk,
  input  logic              rst_n,
  output int                n_wr,      // writes done
  output int                n_rd,      // reads done
  input  logic [ADDR_W-1:0] AWADDR,
  input  logic              AWVALID,
  output logic              AWREADY,
  input  logic [DATA_W-1:0] WDATA,
  input  logic [N_LANE-1:0] WSTRB,
  input  logic              WVALID,
  output logic              WREADY,
  output logic [1:0]        BRESP,
  output logic              BVALID,
  input  logic              BREADY,
  input  logic [ADDR_W-1:0] ARADDR,
  input  logic              ARVALID,
  output logic              ARREADY,
  output logic [DATA_W-1:0] RDATA,
  output logic [1:0]        RRESP,
  output logic              RVALID,
  input  logic              RREADY
);
  logic [DATA_W-1:0] mem [longint];
  longint            awq[$], arq[$];
  logic [DATA_W-1:0] wdq[$];
  logic [N_LANE-1:0] wsq[$];
  logic [1:0]        bq[$];
  bit                b_fire, r_fire;

  function automatic logic [DATA_W-1:0] rd(longint w);
    if (mem.exists(w)) return mem[w];
    return DATA_W'(axi4_tb_init(w, N_LANE));
  endfunction

  initial begin
    AWREADY = 0; WREADY = 0; ARREADY = 0; BVALID = 0; RVALID = 0; BRESP = '0; RDATA = '0; RRESP = '0;
    n_wr = 0; n_rd = 0; b_fire = 0; r_fire = 0;
    @(posedge rst_n);
    @(negedge clk);
    forever begin
      while (awq.size() > 0 && wdq.size() > 0) begin
        longint w;
        logic [DATA_W-1:0] v;
        w = awq.pop_front() >> OFF_W;
        v = rd(w);
        for (int l = 0; l < N_LANE; l++) if (wsq[0][l]) v[8*l +: 8] = wdq[0][8*l +: 8];
        mem[w] = v;
        void'(wdq.pop_front()); void'(wsq.pop_front());
        bq.push_back(axi4_tb_word_resp(w));
      end
      if (!BVALID || b_fire) begin
        BVALID = (bq.size() > 0) && ($urandom % 100 >= P_STALL);
        if (BVALID) BRESP = bq[0];
      end
      if (!RVALID || r_fire) begin
        RVALID = (arq.size() > 0) && ($urandom % 100 >= P_STALL);
        if (RVALID) begin RDATA = rd(arq[0] >> OFF_W); RRESP = axi4_tb_word_resp(arq[0] >> OFF_W); end
      end
      AWREADY = (awq.size() < 8) && ($urandom % 100 >= P_STALL);
      WREADY  = (wdq.size() < 8) && ($urandom % 100 >= P_STALL);
      ARREADY = (arq.size() < 8) && ($urandom % 100 >= P_STALL);
      #1;
      b_fire = BVALID && BREADY;
      r_fire = RVALID && RREADY;
      if (b_fire) begin void'(bq.pop_front()); n_wr++; end
      if (r_fire) begin void'(arq.pop_front()); n_rd++; end
      if (AWVALID && AWREADY) awq.push_back(longint'(AWADDR));
      if (WVALID && WREADY) begin wdq.push_back(WDATA); wsq.push_back(WSTRB); end
      if (ARVALID && ARREADY) arq.push_back(longint'(ARADDR));
      @(negedge clk);
    end
  end
endmodule


// random AXI4-Lite manager (see the header)
module axil_tb_mgr #(
  parameter  int ADDR_W = 32,
  parameter  int DATA_W = 32,
  parameter  int NR     = 1,      // mapped regions
  parameter  int REG_W  = 12,     // log2 region size in bytes
  parameter  int P_ERR  = 10,     // percent of transfers to the unmapped region NR
  parameter  int P_IDLE = 20,     // percent of cycles without offering a new transfer
  parameter  bit WIDE   = 0,      // mapped addresses get one of 4 random patterns above REG_W
  localparam int N_LANE = DATA_W / 8,
  localparam int OFF_W  = $clog2(N_LANE)
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              drain,     // stop starting transfers
  output logic              done,      // drained: nothing in flight
  output int                n_b,       // B checked
  output int                n_r,       // R checked
  output int                n_err,     // DECERR (unmapped) checked
  output logic [ADDR_W-1:0] AWADDR,
  output logic [2:0]        AWPROT,
  output logic              AWVALID,
  input  logic              AWREADY,
  output logic [DATA_W-1:0] WDATA,
  output logic [N_LANE-1:0] WSTRB,
  output logic              WVALID,
  input  logic              WREADY,
  input  logic [1:0]        BRESP,
  input  logic              BVALID,
  output logic              BREADY,
  output logic [ADDR_W-1:0] ARADDR,
  output logic [2:0]        ARPROT,
  output logic              ARVALID,
  input  logic              ARREADY,
  input  logic [DATA_W-1:0] RDATA,
  input  logic [1:0]        RRESP,
  input  logic              RVALID,
  output logic              RREADY
);
  typedef struct { longint word; bit err; } xfer_t;
  logic [DATA_W-1:0] ref_mem [longint];
  int                wr_hold [longint];   // writes offered or in flight on the word
  int                rd_hold [longint];   // reads offered or in flight on the word
  xfer_t             bq[$], rq[$];        // B / R expected in order
  xfer_t             wcur, rcur;          // the write / read being offered
  bit                w_on, aw_done, w_done, r_on;
  bit                aw_fire, w_fire, ar_fire;
  longint            hi_pool [4];         // WIDE: upper address patterns

  function automatic logic [DATA_W-1:0] mem(longint w);
    if (ref_mem.exists(w)) return ref_mem[w];
    return DATA_W'(axi4_tb_init(w, N_LANE));
  endfunction
  function automatic logic [DATA_W-1:0] rnd_data();
    logic [DATA_W-1:0] v;
    for (int i = 0; i < DATA_W; i += 32) v[i +: 32] = $urandom;
    return v;
  endfunction
  // a random address: region r, or unmapped with random upper bits
  function automatic longint new_addr(output bit err);
    longint a;
    err = ($urandom % 100) < P_ERR;
    a = (longint'(err ? NR : $urandom % NR) << REG_W) + longint'(($urandom % 24) * N_LANE + $urandom % N_LANE);
    if (err && $urandom % 2) a = a | ((longint'({$urandom, $urandom}) >> (REG_W + 2)) << (REG_W + 2));
    if (WIDE && !err) a = a | ((hi_pool[$urandom % 4] >> (REG_W + 2)) << (REG_W + 2));
    if (ADDR_W < 64) a = a & ((longint'(1) << ADDR_W) - 1);
    return a;
  endfunction
  function automatic int held(int h [longint], longint w);
    return h.exists(w) ? h[w] : 0;
  endfunction

  initial begin
    AWVALID = 0; WVALID = 0; ARVALID = 0; BREADY = 0; RREADY = 0;
    AWADDR = '0; AWPROT = '0; WDATA = '0; WSTRB = '0; ARADDR = '0; ARPROT = '0;
    n_b = 0; n_r = 0; n_err = 0; done = 0; w_on = 0; r_on = 0; aw_done = 0; w_done = 0;
    aw_fire = 0; w_fire = 0; ar_fire = 0;
    foreach (hi_pool[k]) hi_pool[k] = longint'({$urandom, $urandom});
    @(posedge rst_n);
    @(negedge clk);
    forever begin
      // a new write / read when the last one is fully offered
      if (!w_on && !drain && bq.size() < 4 && ($urandom % 100) >= P_IDLE) begin
        bit err; longint a;
        a = new_addr(err);
        wcur = '{a >> OFF_W, err};
        if (err || held(rd_hold, wcur.word) == 0) begin
          w_on = 1; aw_done = 0; w_done = 0;
          if (!err) wr_hold[wcur.word] = held(wr_hold, wcur.word) + 1;
          AWADDR = ADDR_W'(a); AWPROT = 3'($urandom); WDATA = rnd_data();
          WSTRB = ($urandom % 3 == 0) ? N_LANE'({$urandom, $urandom, $urandom, $urandom}) : '1;
        end
      end
      if (!r_on && !drain && rq.size() < 4 && ($urandom % 100) >= P_IDLE) begin
        bit err; longint a;
        a = new_addr(err);
        rcur = '{a >> OFF_W, err};
        if (err || held(wr_hold, rcur.word) == 0) begin
          r_on = 1;
          if (!err) rd_hold[rcur.word] = held(rd_hold, rcur.word) + 1;
          ARADDR = ADDR_W'(a); ARPROT = 3'($urandom);
        end
      end
      AWVALID = w_on && !aw_done && (AWVALID || $urandom % 3 != 0);
      WVALID  = w_on && !w_done && (WVALID || $urandom % 3 != 0);
      ARVALID = r_on && (ARVALID || $urandom % 3 != 0);
      BREADY  = ($urandom % 4 != 0);
      RREADY  = ($urandom % 4 != 0);
      #1;
      aw_fire = AWVALID && AWREADY;
      w_fire  = WVALID && WREADY;
      ar_fire = ARVALID && ARREADY;
      if (aw_fire) aw_done = 1;
      if (w_fire) w_done = 1;
      if (w_on && aw_done && w_done) begin
        if (!wcur.err) begin
          logic [DATA_W-1:0] v;
          v = mem(wcur.word);
          for (int l = 0; l < N_LANE; l++) if (WSTRB[l]) v[8*l +: 8] = WDATA[8*l +: 8];
          ref_mem[wcur.word] = v;
        end
        bq.push_back(wcur); w_on = 0;
      end
      if (ar_fire) begin rq.push_back(rcur); r_on = 0; end
      if (BVALID && BREADY) begin
        `CHECK(bq.size() > 0, "axil_tb_mgr: B with no write")
        if (bq.size() > 0) begin
          `CHECK(BRESP == (bq[0].err ? 2'b11 : axi4_tb_word_resp(bq[0].word)), $sformatf("axil_tb_mgr: BRESP %b word %h", BRESP, bq[0].word))
          if (bq[0].err) n_err++; else wr_hold[bq[0].word]--;
          void'(bq.pop_front()); n_b++;
        end
      end
      if (RVALID && RREADY) begin
        `CHECK(rq.size() > 0, "axil_tb_mgr: R with no read")
        if (rq.size() > 0) begin
          `CHECK(RRESP == (rq[0].err ? 2'b11 : axi4_tb_word_resp(rq[0].word)) && RDATA == (rq[0].err ? '0 : mem(rq[0].word)),
                 $sformatf("axil_tb_mgr: R %h %b word %h, expected %h", RDATA, RRESP, rq[0].word, mem(rq[0].word)))
          if (rq[0].err) n_err++; else rd_hold[rq[0].word]--;
          void'(rq.pop_front()); n_r++;
        end
      end
      done = drain && !w_on && !r_on && bq.size() == 0 && rq.size() == 0;
      @(negedge clk);
    end
  end
endmodule

`endif
