// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_arbiter -- N AHB-Lite manager BFMs (random
// singles of every size, INCR4/8/16 and WRAP4/8/16 bursts, undefined INCR
// bursts with BUSY, IDLE gaps, locked sequences, IDLE -> NONSEQ while
// waiting, cancelling a burst after an ERROR) through the arbiter into a
// memory-model subordinate with random wait states and two-cycle ERROR
// responses on part of every region. Each manager owns a disjoint address
// region, so read data is checked against a reference memory. Every manager
// transfer must appear on the bus exactly once, in order; the bus is checked
// for AHB burst rules (SEQ / BUSY follow the same manager's burst, a fixed
// burst is never broken, HMASTER changes only after HREADY high, locked
// ownership), write data routing and loose fairness.
`include "tb_common.svh"
module basechili_ahb_arbiter_tb
  import basechili_ahb_pkg::*;
#(
  parameter  int N      = 2,
  parameter  int ADDR_W = 32,
  parameter  int DATA_W = 32,
  localparam int IDX_W  = (N > 1) ? $clog2(N) : 1,
  localparam int NB     = DATA_W / 8,
  localparam int SZ_MAX = $clog2(NB),
  localparam int NP     = 1 << IDX_W   // per-manager TB arrays, a power of two
);
  `TB_CLOCK_RESET

  localparam int NCYC  = 40000;   // random-traffic cycles
  localparam int PHASE = 2500;    // cycles per stimulus phase
  localparam int STUCK = 1000;    // fairness bound: cycles a manager may wait

  // ---- DUT -----------------------------------------------------------------------
  logic [N*ADDR_W-1:0] HADDR_m;
  logic [N*2-1:0]      HTRANS_m;
  logic [N-1:0]        HWRITE_m;
  logic [N*3-1:0]      HSIZE_m;
  logic [N*3-1:0]      HBURST_m;
  logic [N*4-1:0]      HPROT_m;
  logic [N-1:0]        HMASTLOCK_m;
  logic [N*DATA_W-1:0] HWDATA_m;
  logic [N-1:0]        HREADY_m;
  logic [N-1:0]        HRESP_m;
  logic [ADDR_W-1:0]   HADDR;
  logic [1:0]          HTRANS;
  logic                HWRITE;
  logic [2:0]          HSIZE;
  logic [2:0]          HBURST;
  logic [3:0]          HPROT;
  logic                HMASTLOCK;
  logic [DATA_W-1:0]   HWDATA;
  logic [IDX_W-1:0]    HMASTER;
  logic                HREADY;
  logic                HRESP;
  logic [DATA_W-1:0]   HRDATA;    // bus read data, shared by every manager

  basechili_ahb_arbiter #(.N(N), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk, .rst_n, .HADDR_m, .HTRANS_m, .HWRITE_m, .HSIZE_m, .HBURST_m, .HPROT_m,
    .HMASTLOCK_m, .HWDATA_m, .HREADY_m, .HRESP_m, .HADDR, .HTRANS, .HWRITE, .HSIZE,
    .HBURST, .HPROT, .HMASTLOCK, .HWDATA, .HMASTER, .HREADY, .HRESP
  );

  // ---- transfers -----------------------------------------------------------------
  typedef struct {
    logic [1:0]        trans;
    logic [ADDR_W-1:0] addr;
    logic              write;
    logic [2:0]        size;
    logic [2:0]        burst;
    logic [3:0]        prot;
    logic              lock;
    logic [DATA_W-1:0] wdata;
  } beat_t;

  beat_t             plan [NP][$];   // manager m's address phases to show, in order
  beat_t             expq [NP][$];   // manager m's accepted transfers not yet on the bus
  beat_t             mdp  [N];      // manager m's data-phase transfer
  bit                mdp_v[N];      // manager m is in a data phase
  bit                err1 [N];      // manager m saw the first ERROR cycle at the last edge
  bit                waited[N];     // HREADY_m was low at the last edge
  int                stuck[N];      // consecutive cycles with HREADY_m low
  int                ndone[N];      // completed transfers per manager
  logic [7:0]        ref_mem [logic [ADDR_W-1:0]];   // reference memory (manager side)
  logic [7:0]        sub_mem [logic [ADDR_W-1:0]];   // subordinate memory
  logic [ADDR_W-1:0] upool[4];      // upper address bits pool
  bit                draining;      // no new traffic, finish outstanding work
  int                phase;         // stimulus phase
  int                cyc;

  // subordinate data phase
  beat_t sdp;       bit sdp_v;  int sdp_wait;  bit sdp_err;  bit sdp_eph;

  // bus monitor state
  bit                mon_init;
  logic [IDX_W-1:0]  prev_mst;
  bit                prev_rdy;
  bit                lock_hold;     // last taken bus address phase was locked
  bit                open;          // a burst is open on the bus
  logic [IDX_W-1:0]  open_mst;
  logic [ADDR_W-1:0] open_next;     // next address of the open burst
  int                fixed_left;    // beats left of a fixed burst on the bus
  logic [IDX_W-1:0]  fixed_mst;
  int                n_owner_chg, n_conv, n_err, n_busy, n_lock, n_cancel, n_held;

  // ---- helpers -------------------------------------------------------------------
  function automatic logic [7:0] init_byte(logic [ADDR_W-1:0] a);
    return 8'(a) ^ 8'(a >> 8) ^ 8'(a >> 16) ^ 8'(a >> 24) ^ 8'h5a;
  endfunction

  function automatic bit is_err(logic [ADDR_W-1:0] a);
    return a[11:8] == 4'hf;
  endfunction

  function automatic int nbeats(logic [2:0] b);
    case (b)
      HBURST_WRAP4,  HBURST_INCR4:  return 4;
      HBURST_WRAP8,  HBURST_INCR8:  return 8;
      HBURST_WRAP16, HBURST_INCR16: return 16;
      default:                      return 0;
    endcase
  endfunction

  function automatic logic [ADDR_W-1:0] next_addr(logic [ADDR_W-1:0] a, logic [2:0] s, logic [2:0] b);
    logic [ADDR_W-1:0] tot;
    logic [ADDR_W-1:0] n;
    n = a + (ADDR_W'(1) << s);
    if (b == HBURST_WRAP4 || b == HBURST_WRAP8 || b == HBURST_WRAP16) begin
      tot = ADDR_W'(nbeats(b)) << s;
      n = (a & ~(tot - 1)) | (n & (tot - 1));
    end
    return n;
  endfunction

  // byte lanes of a transfer
  function automatic logic [NB-1:0] lanes(logic [ADDR_W-1:0] a, logic [2:0] s);
    logic [NB-1:0] l;
    int lo;
    lo = int'(a % NB) & ~((1 << s) - 1);
    l = '0;
    for (int i = 0; i < (1 << s); i++) l[lo + i] = 1'b1;
    return l;
  endfunction

  function automatic logic [ADDR_W-1:0] word(logic [ADDR_W-1:0] a);
    return a & ~ADDR_W'(NB - 1);
  endfunction

  function automatic logic [7:0] rd_sub(logic [ADDR_W-1:0] a);
    return sub_mem.exists(a) ? sub_mem[a] : init_byte(a);
  endfunction

  function automatic logic [7:0] rd_ref(logic [ADDR_W-1:0] a);
    return ref_mem.exists(a) ? ref_mem[a] : init_byte(a);
  endfunction

  function automatic logic [DATA_W-1:0] rnd_data();
    logic [DATA_W-1:0] d;
    for (int i = 0; i < NB; i += 4) d[i*8 +: 32] = $urandom;
    return d;
  endfunction

  // region of manager m: upper bits from the pool, manager index above the 4 KB offset
  function automatic logic [ADDR_W-1:0] base(int m);
    logic [ADDR_W-1:0] b;
    b = upool[$urandom_range(0, 3)] & ~ADDR_W'(12'hfff);
    if (N > 1) b[12 +: IDX_W] = IDX_W'(m);
    return b;
  endfunction

  function automatic logic [2:0] rnd_size();
    return 3'($urandom_range(0, SZ_MAX));
  endfunction

  // append one burst (or single) to manager m's plan
  task automatic add_burst(int m, logic [2:0] burst, int len, bit lock);
    beat_t b;
    logic [ADDR_W-1:0] a;
    int tot, blk;
    b.size  = rnd_size();
    b.burst = burst;
    b.write = 1'($urandom);
    b.prot  = 4'($urandom);
    b.lock  = lock;
    tot = len << b.size;
    blk = $urandom_range(0, 3);
    if (burst == HBURST_WRAP4 || burst == HBURST_WRAP8 || burst == HBURST_WRAP16 || burst == HBURST_SINGLE)
      a = base(m) | ADDR_W'($urandom_range(0, 4095) & ~((1 << b.size) - 1));
    else
      a = base(m) | ADDR_W'(blk * 1024 + ($urandom_range(0, (1024 - tot) >> b.size) << b.size));
    for (int i = 0; i < len; i++) begin
      if (i > 0 && $urandom_range(0, 7) == 0) begin
        int nb = $urandom_range(1, 2);
        for (int k = 0; k < nb; k++) begin
          b.trans = HTRANS_BUSY;
          b.addr  = a;
          b.wdata = rnd_data();
          plan[m].push_back(b);
        end
      end
      b.trans = (i == 0) ? HTRANS_NONSEQ : HTRANS_SEQ;
      b.addr  = a;
      b.wdata = rnd_data();
      plan[m].push_back(b);
      a = next_addr(a, b.size, burst);
    end
  endtask

  task automatic add_idle(int m, int len, bit lock);
    beat_t b;
    b.trans = HTRANS_IDLE;
    b.addr  = base(m) | ADDR_W'($urandom_range(0, 4095));
    b.write = 1'($urandom);
    b.size  = rnd_size();
    b.burst = 3'($urandom);
    b.prot  = 4'($urandom);
    b.lock  = lock;
    b.wdata = rnd_data();
    for (int i = 0; i < len; i++) plan[m].push_back(b);
  endtask

  task automatic add_any(int m, bit lock);
    int k = $urandom_range(0, 99);
    logic [2:0] fb[6] = '{HBURST_INCR4, HBURST_INCR8, HBURST_INCR16, HBURST_WRAP4, HBURST_WRAP8, HBURST_WRAP16};
    if (k < 40) add_burst(m, HBURST_SINGLE, 1, lock);
    else if (k < 70) begin
      logic [2:0] bb = fb[$urandom_range(0, 5)];
      add_burst(m, bb, nbeats(bb), lock);
    end else add_burst(m, HBURST_INCR, $urandom_range(1, 8), lock);
  endtask

  // a new sequence for manager m
  task automatic gen(int m);
    int k = $urandom_range(0, 99);
    int idle_pct;
    if (draining) begin add_idle(m, 1, 1'b0); return; end
    case (phase)
      2:       idle_pct = (m == 0) ? 0 : 95;    // one active manager at full speed
      3:       idle_pct = 50;                   // sparse traffic, parking
      default: idle_pct = 10;
    endcase
    if (k < idle_pct) add_idle(m, $urandom_range(1, 4), 1'b0);
    else if ($urandom_range(0, 99) < 8) begin
      int n = $urandom_range(1, 3);
      n_lock++;
      for (int i = 0; i < n; i++) add_any(m, 1'b1);
      if ($urandom_range(0, 1) == 1) add_idle(m, 1, 1'b1);
      add_idle(m, 1, 1'b0);
    end else add_any(m, 1'b0);
  endtask

  // ---- drive (after a falling edge) ----------------------------------------------------
  task automatic drive();
    // subordinate
    HRDATA = rnd_data();
    if (!sdp_v) begin
      HREADY = 1'b1; HRESP = 1'b0;
    end else if (sdp_wait > 0) begin
      HREADY = 1'b0; HRESP = 1'b0;
    end else if (sdp_err) begin
      HREADY = sdp_eph; HRESP = 1'b1;
    end else begin
      HREADY = 1'b1; HRESP = 1'b0;
      if (!sdp.write)
        for (int i = 0; i < NB; i++) HRDATA[i*8 +: 8] = rd_sub(word(sdp.addr) + ADDR_W'(i));
    end
    // managers
    for (int m = 0; m < N; m++) begin
      beat_t b;
      if (plan[m].size() == 0) gen(m);
      // after the first ERROR cycle: cancel the rest of the burst
      if (err1[m] && (plan[m][0].trans == HTRANS_SEQ || plan[m][0].trans == HTRANS_BUSY)
          && $urandom_range(0, 3) != 0) begin
        bit lk = plan[m][0].lock;
        while (plan[m].size() > 0 && (plan[m][0].trans == HTRANS_SEQ || plan[m][0].trans == HTRANS_BUSY))
          void'(plan[m].pop_front());
        n_cancel++;
        b.trans = HTRANS_IDLE; b.addr = '0; b.write = 1'b0; b.size = '0; b.burst = '0;
        b.prot = '0; b.lock = lk; b.wdata = '0;
        plan[m].push_front(b);
      end
      // IDLE -> NONSEQ while waiting
      if (waited[m] && !err1[m] && plan[m][0].trans == HTRANS_IDLE && $urandom_range(0, 1) == 1) begin
        void'(plan[m].pop_front());
        if (plan[m].size() == 0) gen(m);
        if (plan[m][0].trans != HTRANS_NONSEQ) begin
          // show a NONSEQ single now, in front of the planned beats
          beat_t s;
          add_burst(m, HBURST_SINGLE, 1, 1'b0);
          s = plan[m][$];
          void'(plan[m].pop_back());
          plan[m].push_front(s);
        end
      end
      b = plan[m][0];
      HADDR_m[m*ADDR_W +: ADDR_W] = b.addr;
      HTRANS_m[m*2 +: 2]          = b.trans;
      HWRITE_m[m]                 = b.write;
      HSIZE_m[m*3 +: 3]           = b.size;
      HBURST_m[m*3 +: 3]          = b.burst;
      HPROT_m[m*4 +: 4]           = b.prot;
      HMASTLOCK_m[m]              = b.lock;
      HWDATA_m[m*DATA_W +: DATA_W] = mdp_v[m] && mdp[m].write ? mdp[m].wdata : rnd_data();
    end
  endtask

  // ---- sample (just before a rising edge) ---------------------------------------------
  task automatic sample();
    // managers
    for (int m = 0; m < N; m++) begin
      if (!mdp_v[m]) begin
        `CHECK(HREADY_m[m] && !HRESP_m[m], $sformatf("m%0d: HREADY_m low / HRESP_m high without a data phase", m))
      end
      stuck[m] = HREADY_m[m] ? 0 : stuck[m] + 1;
      `CHECK(stuck[m] < STUCK, $sformatf("m%0d: waiting for %0d cycles", m, stuck[m]))
      if (HREADY_m[m]) begin
        if (mdp_v[m]) begin
          bit e = is_err(mdp[m].addr);
          logic [NB-1:0] l = lanes(mdp[m].addr, mdp[m].size);
          `CHECK(HRESP_m[m] == e, $sformatf("m%0d: HRESP %0b expected %0b addr %h", m, HRESP_m[m], e, mdp[m].addr))
          if (e) `CHECK(err1[m], $sformatf("m%0d: one-cycle ERROR", m))
          if (!e) begin
            for (int i = 0; i < NB; i++) if (l[i]) begin
              logic [ADDR_W-1:0] a = word(mdp[m].addr) + ADDR_W'(i);
              if (mdp[m].write) ref_mem[a] = mdp[m].wdata[i*8 +: 8];
              else `CHECK(HRDATA[i*8 +: 8] == rd_ref(a),
                          $sformatf("m%0d: read %h lane %0d got %h expected %h", m, mdp[m].addr, i,
                                    HRDATA[i*8 +: 8], rd_ref(a)))
            end
          end
          ndone[m]++;
        end
        mdp_v[m] = plan[m][0].trans[1];
        mdp[m]   = plan[m][0];
        if (mdp_v[m]) begin
          expq[m].push_back(plan[m][0]);
          if (HTRANS_m[m*2 +: 2] != plan[m][0].trans) $error("TB: manager %0d drive mismatch", m);
        end
        void'(plan[m].pop_front());
        err1[m] = 1'b0;
        waited[m] = 1'b0;
      end else begin
        `CHECK(mdp_v[m], $sformatf("m%0d: HREADY_m low without a data phase", m))
        if (HRESP_m[m]) begin
          `CHECK(!err1[m], $sformatf("m%0d: ERROR first cycle twice", m))
          err1[m] = 1'b1;
        end
        waited[m] = 1'b1;
        if (dut.pend[m]) n_held++;
      end
    end

    // bus: ownership
    if (mon_init) begin
      `CHECK(prev_rdy || HMASTER == prev_mst, "HMASTER changed after a cycle with HREADY low")
      `CHECK(!lock_hold || HMASTER == prev_mst, "HMASTER changed after a locked transfer")
      if (HMASTER != prev_mst) n_owner_chg++;
    end
    `CHECK(int'(HMASTER) < N, "HMASTER out of range")
    if (HREADY) begin
      // subordinate data phase completes
      if (sdp_v) begin
        `CHECK(HRESP == sdp_err, "TB subordinate")
        if (sdp.write && !sdp_err) begin
          logic [NB-1:0] l = lanes(sdp.addr, sdp.size);
          for (int i = 0; i < NB; i++) if (l[i]) begin
            `CHECK(HWDATA[i*8 +: 8] == sdp.wdata[i*8 +: 8],
                   $sformatf("HWDATA lane %0d %h expected %h (addr %h)", i, HWDATA[i*8 +: 8], sdp.wdata[i*8 +: 8], sdp.addr))
            sub_mem[word(sdp.addr) + ADDR_W'(i)] = HWDATA[i*8 +: 8];
          end
        end
        if (sdp_err) n_err++;
      end
      // burst rules
      if (fixed_left > 0) begin
        `CHECK(HMASTER == fixed_mst, "fixed-length burst interrupted by another manager")
        if (HTRANS == HTRANS_SEQ) fixed_left--;
        else if (HTRANS != HTRANS_BUSY) begin
          `CHECK(HTRANS == HTRANS_IDLE && HRESP, "fixed-length burst ended early without an ERROR")
          fixed_left = 0;
        end
      end
      if (HTRANS == HTRANS_SEQ || HTRANS == HTRANS_BUSY) begin
        `CHECK(open && open_mst == HMASTER, "SEQ / BUSY on the bus without the same manager's burst")
        `CHECK(HADDR == open_next, $sformatf("burst address %h expected %h", HADDR, open_next))
        if (HTRANS == HTRANS_BUSY) n_busy++;
      end
      if (HTRANS == HTRANS_NONSEQ && nbeats(HBURST) > 0) begin
        fixed_left = nbeats(HBURST) - 1;
        fixed_mst  = HMASTER;
      end
      if (HTRANS[1]) begin
        beat_t r;
        int mm = int'(HMASTER);
        open      = 1'b1;
        open_mst  = HMASTER;
        open_next = next_addr(HADDR, HSIZE, HBURST);
        if (expq[mm].size() == 0) begin
          $error("CHECK failed: bus transfer from m%0d that it did not issue (addr %h)", mm, HADDR);
          sdp_v = 1'b0;
        end else begin
          r = expq[mm].pop_front();
          `CHECK(HADDR == r.addr && HWRITE == r.write && HSIZE == r.size && HBURST == r.burst &&
                 HPROT == r.prot && HMASTLOCK == r.lock,
                 $sformatf("m%0d: bus transfer %h w%0b s%0d b%0d p%h l%0b expected %h w%0b s%0d b%0d p%h l%0b",
                           mm, HADDR, HWRITE, HSIZE, HBURST, HPROT, HMASTLOCK,
                           r.addr, r.write, r.size, r.burst, r.prot, r.lock))
          if (r.trans == HTRANS_NONSEQ) `CHECK(HTRANS == HTRANS_NONSEQ, "NONSEQ shown as SEQ")
          else if (HTRANS == HTRANS_NONSEQ) begin
            `CHECK(r.burst == HBURST_INCR, "fixed-burst SEQ re-issued as NONSEQ")
            n_conv++;
          end
          sdp_v    = 1'b1;
          sdp      = r;
          sdp_wait = (phase == 2 || phase == 0) ? 0 : (($urandom_range(0, 1) == 0) ? 0 : $urandom_range(1, 3));
          sdp_err  = is_err(r.addr);
          sdp_eph  = 1'b0;
        end
      end else begin
        if (HTRANS == HTRANS_IDLE) open = 1'b0;
        sdp_v = 1'b0;
      end
      lock_hold = HMASTLOCK;
    end else begin
      if (sdp_v) begin
        `CHECK(!HRESP || (sdp_err && sdp_wait == 0), "TB subordinate HRESP")
        if (sdp_wait > 0) sdp_wait--;
        else if (sdp_err) sdp_eph = 1'b1;
      end
    end
    prev_mst = HMASTER;
    prev_rdy = HREADY;
    mon_init = 1'b1;
  endtask

  initial begin
    for (int i = 0; i < 4; i++) upool[i] = ADDR_W'({$urandom, $urandom});
    for (int m = 0; m < N; m++) begin
      mdp_v[m] = 0; err1[m] = 0; waited[m] = 0; stuck[m] = 0; ndone[m] = 0;
    end
    sdp_v = 0; mon_init = 0; lock_hold = 0; open = 0; fixed_left = 0; draining = 0; phase = 0;
    n_owner_chg = 0; n_conv = 0; n_err = 0; n_busy = 0; n_lock = 0; n_cancel = 0; n_held = 0;
    HADDR_m = '0; HTRANS_m = '0; HWRITE_m = '0; HSIZE_m = '0; HBURST_m = '0; HPROT_m = '0;
    HMASTLOCK_m = '0; HWDATA_m = '0; HREADY = 1'b1; HRESP = 1'b0; HRDATA = '0;
    tb_reset();
    for (cyc = 0; cyc < NCYC + 400; cyc++) begin
      phase    = (cyc / PHASE) % 4;
      draining = cyc >= NCYC;
      drive();
      #4;
      sample();
      @(negedge clk);
    end
    for (int m = 0; m < N; m++) begin
      `CHECK(expq[m].size() == 0, $sformatf("m%0d: %0d transfers never reached the bus", m, expq[m].size()))
      `CHECK(!mdp_v[m], $sformatf("m%0d: data phase never finished", m))
      `CHECK(ndone[m] > 1000, $sformatf("m%0d: only %0d transfers", m, ndone[m]))
    end
    `CHECK(n_err > 0 && n_busy > 0 && n_lock > 0 && n_cancel > 0, "stimulus coverage")
    if (N > 1) `CHECK(n_owner_chg > 0 && n_conv > 0 && n_held > 0, "stimulus coverage (N > 1)")
    $display("owner changes %0d, SEQ->NONSEQ %0d, held cycles %0d, errors %0d, cancels %0d, BUSY %0d, locks %0d",
             n_owner_chg, n_conv, n_held, n_err, n_cancel, n_busy, n_lock);
    tb_pass();
  end
endmodule
