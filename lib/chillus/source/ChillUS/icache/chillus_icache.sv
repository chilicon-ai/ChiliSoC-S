// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_icache
//
// Instruction cache between the IFU and the core's fetch port (IMSS, the
// same protocol on both sides: req / gnt, then one in-order rvalid /
// rdata / err per granted request). SIZE_KB = 0 builds no cache (wires);
// 2 or 4 builds a 2-way set-associative cache of 16-byte lines (64 or 128
// sets) on basechili_sram_sp arrays (an ASIC flow swaps in macros):
//   u_tag[w]  : SETS words of {valid, uok, tag}; uok: filled by an
//               unprivileged fetch (c_priv = 0)
//   u_data[w] : SETS*4 words of 32 bits (one per line word)
//
// A fetch is cacheable when (c_addr & CACHE_MASK) == CACHE_BASE and the core
// is not in debug mode (the debug module's program buffer changes under it).
//   S_RUN    : a cacheable request is granted unless a bypass response is
//              outstanding or a flush is pending (a request granted in the
//              flush cycle belongs to the stream FENCE.I discards), and reads both ways' tag
//              and data at its set (lk_* holds it). Next cycle the tags are
//              compared: a hit returns the word (c_rvalid), a miss starts a
//              refill. An unprivileged fetch hits only a line an
//              unprivileged fetch filled (uok), since the bus may reject
//              unprivileged fetches (imss_priv, AHB HPROT[1]); otherwise it
//              misses and refills that same way with its own privilege. A grant does not depend on the hit, so a second
//              request may be granted in the miss cycle; it waits in lk_*
//              and is looked up again (S_REPLAY) after the refill.
//              An uncacheable request goes straight to the bus (bypass,
//              same latency as without a cache) while no lookup is in
//              flight; its responses pass through (bp_cnt counts them).
//   S_FILL   : the missed line is read from the bus word by word, starting
//              at the missed word and wrapping (at most 2 outstanding),
//              into the victim way (the way holding the tag when only the
//              privilege missed, else an invalid way, else rr). The missed
//              word goes to the core as it arrives. With the last word the
//              victim's tag is written: valid with the new tag, or invalid
//              if a word failed or a flush came (its data was overwritten).
//   S_REPLAY : the request waiting in lk_* reads its set again.
//   S_INIT   : after reset and on flush (FENCE.I) every set's tags are
//              written invalid, one set per cycle (SETS cycles). Bypass
//              requests still run.
// busy (S_FILL) keeps the core awake in WFI until a refill is done.
//
// Timing    : c_gnt is combinational from c_addr (region decode),
//             debug_mode, m_gnt (bypass) and flops, not from flush; m_req / m_addr from
//             c_req / c_addr (bypass) or flops (refill). A hit returns the
//             cycle after the grant (as a zero-wait memory): c_rvalid /
//             c_rdata come from the tag / data SRAM outputs through the tag
//             compare and the way mux. A miss returns the missed word with
//             its bus response, two or more cycles after the grant.
// Invariants: one c_rvalid per granted request, in order; no two valid
//             ways of a set hold the same tag; bp_cnt != 0 only
//             in S_RUN / S_INIT and never with lk_valid; m_req in S_FILL
//             only while fewer than 4 words were requested and fewer than 2
//             are outstanding; a refill writes its tag valid only with no
//             bus error and no flush since the miss, else invalid.
// Debug     : fetch stuck -> state, lk_valid, bp_cnt, flush_pend, req_cnt /
//             rsp_cnt; wrong instruction on a hit -> lk_addr, hit_way, the
//             tag of each way (tag_rd), and the refill that wrote the line
//             (mr_addr, fill_way); stale code after a store -> flush, S_INIT.
// -----------------------------------------------------------------------------
module chillus_icache #(
  parameter  int              ADDR_W     = 32,           // address width in bits
  parameter  int              SIZE_KB    = 0,            // capacity: 0 (no cache), 2 or 4 KiB
  parameter  logic [ADDR_W-1:0] CACHE_BASE = '0,         // cacheable region: (addr & CACHE_MASK) == CACHE_BASE
  parameter  logic [ADDR_W-1:0] CACHE_MASK = '0          // '0: every address is cacheable
) (
  input  logic              clk,
  input  logic              rst_n,         // async, active-low
  input  logic              flush,         // FENCE.I: invalidate every line
  input  logic              debug_mode,    // no caching in debug mode
  output logic              busy,          // a refill is on the bus (WFI waits for it)
  // core side (from the IFU)
  input  logic              c_req,
  output logic              c_gnt,
  input  logic [ADDR_W-1:0] c_addr,        // word-aligned
  input  logic              c_priv,
  output logic              c_rvalid,
  output logic [31:0]       c_rdata,
  output logic              c_err,
  // bus side (the core's imss_* port)
  output logic              m_req,
  input  logic              m_gnt,
  output logic [ADDR_W-1:0] m_addr,
  output logic              m_priv,
  input  logic              m_rvalid,
  input  logic [31:0]       m_rdata,
  input  logic              m_err
);

  if (SIZE_KB == 0) begin : g_none

    assign m_req    = c_req;
    assign m_addr   = c_addr;
    assign m_priv   = c_priv;
    assign c_gnt    = m_gnt;
    assign c_rvalid = m_rvalid;
    assign c_rdata  = m_rdata;
    assign c_err    = m_err;
    assign busy     = 1'b0;

  end else begin : g_cache

    localparam int WAYS   = 2;                              // fixed: round-robin is one bit
    localparam int LINE_W = 4;                              // words per line
    localparam int SETS   = SIZE_KB * 1024 / (WAYS * LINE_W * 4);
    localparam int IDX_W  = $clog2(SETS);
    localparam int TAG_W  = ADDR_W - IDX_W - 4;
    localparam int TE_W   = TAG_W + 2;                      // tag entry: {valid, uok, tag}
    localparam int DAW    = IDX_W + 2;                      // data array word address

    typedef enum logic [1:0] {
      S_INIT   = 2'd0,
      S_RUN    = 2'd1,
      S_FILL   = 2'd2,
      S_REPLAY = 2'd3
    } state_e;

    logic [1:0]        state_q;
    state_e            state;
    state_e            state_d;
    logic              s_init, s_run, s_fill, s_replay;

    // request decode
    logic              cach;            // c_addr is cacheable now
    logic              byp_ok;          // an uncacheable request may go to the bus
    logic              gnt_c;           // a cacheable request may be granted
    logic              fire_c;          // cacheable request granted
    logic              fire_b;          // bypass request granted
    logic [ADDR_W-1:0] c_masked;        // c_addr & CACHE_MASK

    // lookup (the request granted last cycle, or waiting for a replay)
    logic              lk_valid;
    logic              lk_valid_d;
    logic [ADDR_W-3:0] lk_addr;         // word address
    logic              lk_priv;
    logic [ADDR_W-3:0] c_word;          // c_addr word address
    logic [TAG_W-1:0]  lk_tag;
    logic [IDX_W-1:0]  lk_idx;
    logic [1:0]        lk_wrd;

    // tag compare
    logic [WAYS*TE_W-1:0]  tag_rd;      // tag array outputs, way w at w*TE_W
    logic [WAYS*TAG_W-1:0] tags;        // stored tags
    logic [WAYS-1:0]       vld;         // stored valid bits
    logic [WAYS-1:0]       uok;         // stored: filled by an unprivileged fetch
    logic [WAYS-1:0]       match_way;   // valid with the lookup tag (any privilege)
    logic                  match_any;
    logic [WAYS-1:0]       hit_way;     // match_way usable at the lookup's privilege
    logic                  hit_any;
    logic                  hit;         // lookup hit this cycle (S_RUN)
    logic                  miss;        // lookup missed this cycle (S_RUN)
    logic [WAYS*32-1:0]    data_rd;     // data array outputs, way w at w*32
    logic [31:0]           hit_data;    // way mux

    // refill
    logic [ADDR_W-3:0] mr_addr;         // missed word address
    logic              mr_priv;
    logic [TAG_W-1:0]  mr_tag;
    logic [IDX_W-1:0]  mr_idx;
    logic [1:0]        mr_wrd;
    logic              fill_way;        // victim way of the refill
    logic              victim;          // victim chosen in the miss cycle
    logic              rr;              // round-robin way
    logic              rr_d;
    logic              rr_en;
    logic [2:0]        req_cnt;         // refill words requested
    logic [2:0]        req_cnt_d;
    logic [2:0]        rsp_cnt;         // refill words received
    logic [2:0]        rsp_cnt_d;
    logic              cnt_en;
    logic [2:0]        fill_os;         // refill words outstanding
    logic              fill_req;
    logic              fill_rsp;        // refill word received this cycle
    logic              fill_last;       // last refill word received this cycle
    logic              fill_err;        // a refill word failed
    logic              fill_err_d;
    logic              fill_ok;         // write the tag valid with the last word
    logic [1:0]        req_wrd;         // line word of the next refill request
    logic [1:0]        rsp_wrd;         // line word of the arriving refill word
    logic [ADDR_W-1:0] fill_addr;

    // bypass
    logic [1:0]        bp_cnt;          // bypass responses outstanding
    logic              bp_dec;
    logic              bp_rsp;          // a bypass response this cycle
    logic              no_load;
    logic [1:0]        zero2;

    // flush and init
    logic              flush_pend;
    logic              flush_pend_d;
    logic              flush_any;       // flush now or pending
    logic [IDX_W-1:0]  init_cnt;        // set being invalidated
    logic [IDX_W-1:0]  init_cnt_d;
    logic              init_last;

    // arrays
    logic [IDX_W-1:0]  tag_addr;
    logic [WAYS-1:0]   tag_req;
    logic              tag_we;
    logic [TE_W-1:0]   tag_wdata;
    logic [DAW-1:0]    data_addr;
    logic [WAYS-1:0]   data_req;
    logic              data_we;
    logic              rd_run;          // read both ways at c_addr (S_RUN request)
    logic              one;

    assign state    = state_e'(state_q);
    assign s_init   = (state == S_INIT);
    assign s_run    = (state == S_RUN);
    assign s_fill   = (state == S_FILL);
    assign s_replay = (state == S_REPLAY);
    assign one      = 1'b1;

    // -------------------------------------------------------------------------
    // Request side
    // -------------------------------------------------------------------------
    assign c_masked  = c_addr & CACHE_MASK;
    assign cach      = (c_masked == CACHE_BASE) && !debug_mode;
    assign flush_any = flush || flush_pend;
    assign gnt_c     = s_run && (bp_cnt == '0) && !flush_pend;
    assign byp_ok    = (s_run || s_init) && !lk_valid;
    assign c_gnt     = cach ? gnt_c : (byp_ok && m_gnt);
    assign fire_c    = c_req && cach && gnt_c;
    assign fire_b    = c_req && !cach && byp_ok && m_gnt;
    assign c_word    = c_addr[ADDR_W-1:2];

    assign lk_valid_d = s_run ? fire_c : lk_valid;

    basechili_dff u_lk_valid (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (lk_valid_d),
      .q     (lk_valid)
    );

    basechili_dffe #(.WIDTH(ADDR_W - 2)) u_lk_addr (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (fire_c),
      .d     (c_word),
      .q     (lk_addr)
    );

    basechili_dffe #(.WIDTH(1)) u_lk_priv (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (fire_c),
      .d     (c_priv),
      .q     (lk_priv)
    );

    assign lk_tag = lk_addr[ADDR_W-3 -: TAG_W];
    assign lk_idx = lk_addr[IDX_W+1:2];
    assign lk_wrd = lk_addr[1:0];

    // -------------------------------------------------------------------------
    // Lookup
    // -------------------------------------------------------------------------
    for (genvar w = 0; w < WAYS; w++) begin : g_way_view
      assign tags[w*TAG_W +: TAG_W] = tag_rd[w*TE_W +: TAG_W];
      assign uok[w]                 = tag_rd[w*TE_W + TAG_W];
      assign vld[w]                 = tag_rd[w*TE_W + TAG_W + 1];
    end

    basechili_tag_compare #(.TAG_W(TAG_W), .WAYS(WAYS)) u_cmp (
      .tags      (tags),
      .valid     (vld),
      .tag       (lk_tag),
      .hit_way   (match_way),
      .hit       (match_any),
      .hit_idx   (),
      .multi_hit ()
    );

    assign hit_way = lk_priv ? match_way : (match_way & uok);
    assign hit_any = |hit_way;
    assign hit  = s_run && lk_valid && hit_any;
    assign miss = s_run && lk_valid && !hit_any;

    always_comb begin
      hit_data = '0;
      for (int w = 0; w < WAYS; w++) begin
        hit_data = hit_data | (data_rd[w*32 +: 32] & {32{hit_way[w]}});
      end
    end

    // -------------------------------------------------------------------------
    // Refill
    // -------------------------------------------------------------------------
    basechili_dffe #(.WIDTH(ADDR_W - 2)) u_mr_addr (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (miss),
      .d     (lk_addr),
      .q     (mr_addr)
    );

    basechili_dffe #(.WIDTH(1)) u_mr_priv (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (miss),
      .d     (lk_priv),
      .q     (mr_priv)
    );

    assign mr_tag = mr_addr[ADDR_W-3 -: TAG_W];
    assign mr_idx = mr_addr[IDX_W+1:2];
    assign mr_wrd = mr_addr[1:0];

    // victim: the way holding the tag (privilege miss), else an invalid way,
    // else the round-robin way
    assign victim = match_any ? match_way[1] : (!vld[0] ? 1'b0 : (!vld[1] ? 1'b1 : rr));
    assign rr_en  = miss && !match_any && vld[0] && vld[1];
    assign rr_d   = !rr;

    basechili_dffe #(.WIDTH(1)) u_rr (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (rr_en),
      .d     (rr_d),
      .q     (rr)
    );

    basechili_dffe #(.WIDTH(1)) u_fill_way (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (miss),
      .d     (victim),
      .q     (fill_way)
    );

    assign fill_os   = req_cnt - rsp_cnt;
    assign fill_req  = s_fill && (req_cnt != 3'd4) && (fill_os < 3'd2);
    assign fill_rsp  = s_fill && m_rvalid;
    assign fill_last = fill_rsp && (rsp_cnt == 3'd3);
    assign req_wrd   = mr_wrd + req_cnt[1:0];
    assign rsp_wrd   = mr_wrd + rsp_cnt[1:0];
    assign fill_addr = {mr_tag, mr_idx, req_wrd, 2'b00};

    // counters restart with each miss
    assign cnt_en     = miss || s_fill;
    assign req_cnt_d  = miss ? 3'd0 : (req_cnt + 3'(fill_req && m_gnt));
    assign rsp_cnt_d  = miss ? 3'd0 : (rsp_cnt + 3'(fill_rsp));
    assign fill_err_d = !miss && (fill_err || (fill_rsp && m_err));
    assign fill_ok    = !fill_err && !m_err && !flush_any;

    basechili_dffe #(.WIDTH(3)) u_req_cnt (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (cnt_en),
      .d     (req_cnt_d),
      .q     (req_cnt)
    );

    basechili_dffe #(.WIDTH(3)) u_rsp_cnt (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (cnt_en),
      .d     (rsp_cnt_d),
      .q     (rsp_cnt)
    );

    basechili_dffe #(.WIDTH(1)) u_fill_err (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (cnt_en),
      .d     (fill_err_d),
      .q     (fill_err)
    );

    // -------------------------------------------------------------------------
    // Bypass
    // -------------------------------------------------------------------------
    assign bp_rsp  = (bp_cnt != '0) && m_rvalid;
    assign bp_dec  = bp_rsp;
    assign no_load = 1'b0;
    assign zero2   = '0;

    basechili_updown_counter #(.WIDTH(2)) u_bp_cnt (
      .clk      (clk),
      .rst_n    (rst_n),
      .load     (no_load),
      .load_val (zero2),
      .inc      (fire_b),
      .dec      (bp_dec),
      .count    (bp_cnt),
      .count_d  ()
    );

    // -------------------------------------------------------------------------
    // Flush and init
    // -------------------------------------------------------------------------
    assign flush_pend_d = flush_any && !s_init;
    assign init_last    = (init_cnt == IDX_W'(unsigned'(SETS - 1)));
    assign init_cnt_d   = s_init ? (init_cnt + 1'b1) : '0;

    basechili_dff u_flush_pend (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (flush_pend_d),
      .q     (flush_pend)
    );

    basechili_dff #(.WIDTH(IDX_W)) u_init_cnt (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (init_cnt_d),
      .q     (init_cnt)
    );

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------
    always_comb begin
      state_d = state;
      case (state)
        S_INIT:   if (init_last)                state_d = lk_valid ? S_REPLAY : S_RUN;
        S_RUN:    if (miss)                     state_d = S_FILL;
                  else if (flush_any && !lk_valid) state_d = S_INIT;
        S_FILL:   if (fill_last)                state_d = flush_any ? S_INIT : (lk_valid ? S_REPLAY : S_RUN);
        S_REPLAY:                               state_d = S_RUN;
        default:                                state_d = S_INIT;
      endcase
    end

    basechili_dff #(.WIDTH(2)) u_state (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (state_d),
      .q     (state_q)
    );

    // -------------------------------------------------------------------------
    // Arrays
    // -------------------------------------------------------------------------
    // Reads: S_RUN at the request (c_addr), S_REPLAY at lk_addr. Writes: the
    // refill's data words and its tag with the last word (S_FILL), the
    // invalid tags (S_INIT, both ways).
    assign rd_run    = s_run && c_req && cach;
    assign tag_we    = s_init || s_fill;
    assign tag_wdata = s_init ? '0 : {fill_ok, !mr_priv, mr_tag};
    assign tag_addr  = s_init ? init_cnt : (s_fill ? mr_idx : (s_replay ? lk_idx : c_word[IDX_W+1:2]));
    assign data_we   = s_fill;
    assign data_addr = s_fill ? {mr_idx, rsp_wrd} : (s_replay ? {lk_idx, lk_wrd} : c_word[DAW-1:0]);

    for (genvar w = 0; w < WAYS; w++) begin : g_way
      logic way_fill;                   // this way receives the refill

      assign way_fill    = s_fill && (fill_way == 1'(unsigned'(w)));
      assign tag_req[w]  = s_init || rd_run || s_replay || (way_fill && fill_last);
      assign data_req[w] = rd_run || s_replay || (way_fill && fill_rsp);

      basechili_sram_sp #(.WIDTH(TE_W), .DEPTH(SETS), .BYTE_W(TE_W)) u_tag (
        .clk   (clk),
        .req   (tag_req[w]),
        .we    (tag_we),
        .addr  (tag_addr),
        .wdata (tag_wdata),
        .be    (one),
        .rdata (tag_rd[w*TE_W +: TE_W])
      );

      basechili_sram_sp #(.WIDTH(32), .DEPTH(SETS * LINE_W), .BYTE_W(32)) u_data (
        .clk   (clk),
        .req   (data_req[w]),
        .we    (data_we),
        .addr  (data_addr),
        .wdata (m_rdata),
        .be    (one),
        .rdata (data_rd[w*32 +: 32])
      );
    end

    // -------------------------------------------------------------------------
    // Outputs
    // -------------------------------------------------------------------------
    assign c_rvalid = hit || (fill_rsp && (rsp_cnt == '0)) || bp_rsp;
    assign c_rdata  = hit ? hit_data : m_rdata;
    assign c_err    = !hit && m_err;
    assign m_req    = s_fill ? fill_req : (c_req && !cach && byp_ok);
    assign m_addr   = s_fill ? fill_addr : c_addr;
    assign m_priv   = s_fill ? mr_priv : c_priv;
    assign busy     = s_fill;

  end

endmodule
