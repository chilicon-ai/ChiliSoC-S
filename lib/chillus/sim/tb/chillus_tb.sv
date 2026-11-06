// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S sim :: chillus_tb
//
// Simulation top for chillus_core (Verilator --binary --timing). Not RTL: the
// source/ coding rules do not apply here.
//
//   memory : one word array at BASE, shared by fetch and data (stores are
//            visible to later fetches), loaded with $readmemh(+hex).
//   imss   : imss_gnt, then in-order imss_rvalid one
//            or more cycles after the grant; out-of-range fetch returns
//            imss_err.
//            +ifetch_err=<addr> [+ifetch_err_words=<n>, default 1] also
//            fails fetches of the n words from addr (word aligned) inside
//            the memory (data accesses unaffected). TB only: Spike does not
//            see it, so sim/run.py does not use it (sim/tests/fetch_fault.S
//            faults at the end of RAM instead, as Spike does).
//   dmss   : a request is taken at an edge with
//            dmss_req && dmss_gnt (the access happens then: a store writes,
//            a load word is registered); dmss_rvalid follows one or more
//            cycles later with dmss_rdata / dmss_err. A load / store outside
//            the memory and the CLINT gets dmss_err, no effect.
//   clint  : chillus_clint at CLINT_BASE (64 KiB, as Spike's): msip /
//            mtimecmp / mtime; mtime counts every clock; drives irq_timer,
//            irq_software and the core's mtime.
//   irqgen : a store to +irqgen=<addr> (a word in the memory, stored as
//            usual) also sets the interrupt lines from its data: [14:0]
//            irq_fast, [15] irq_external, [31] irq_nmi (levels, 0 after
//            reset). Spike has no such lines, so sim/run.py runs tests that
//            use it without Spike (# run.py: no-spike).
//            [30] arms the debug wake: debug_req rises once core_sleep has
//            been high DEBUG_WAKE cycles and stays high (a halt request
//            held until the DM code clears [30]).
//            [29] drives debug_req (halt request) directly, like the
//            interrupt lines.
//            +debug_req_reset sets [29] from time 0: debug_req is high
//            through reset (halt before the first instruction).
//   priv   : +priv_region=<addr> [+priv_region_words=<n>, default 1024]
//            makes the n words from addr (word aligned) privileged, like a
//            SoC subordinate that checks HPROT[1]: a fetch, load or store
//            there that is not privileged (imss_priv / dmss_priv, AHB
//            i_HPROT[1] / d_HPROT[1] = 0: U-mode, or MPRV with MPP = U)
//            gets an error response (no effect). Spike does not see it, so
//            tests that use it run without Spike (sim/tests/hprot.S). The
//            AHB models also check HPROT[0] (0 fetch, 1 data) and HPROT[3:2]
//            = 0 on every transfer (TB: ERROR hprot).
//   debug  : DM_HALT_ADDR / DM_EXCEPTION_ADDR are DM_ROM / DM_ROM + 8 in the
//            memory; a debug test links its own mini-DM code there (section
//            .dbg_rom, sim/tests/dbg.h; run.py places it).
//   boot   : boot_addr = BASE; hart_id = +hart_id=<hex> (default 0, as
//            Spike's mhartid); fetch_enable high from time 0, or with
//            +fetch_delay=<n> low until n cycles after reset release, then
//            high for one cycle only (the core must start and keep running:
//            it is sticky). Spike boots at once, so tests that use them run
//            without Spike (sim/tests/boot.S).
//   sleep  : test_en = 0; "TB: sleep cycles <n>" counts cycles with
//            core_sleep high (WFI).
//   stalls : +istall=<pct> / +dstall=<pct> randomly withhold imss_gnt /
//            imss_rvalid and dmss_gnt / dmss_rvalid (seed:
//            +verilator+seed+<n>).
//   trace  : one line per rvfi_valid to +trace (format below).
//   console: a store to +console=<addr> (word holding it) appends its byte
//            [7:0] to +console_log=<file> (sim/sw runtime, con_putc).
//   end    : a store of a non-zero word to +tohost ends the test after a few
//            drain cycles (so the store itself retires into the trace):
//            1 = PASS, (n << 1) | 1 = FAIL test n. +max_cycles ends it as
//            TIMEOUT.
//
// Trace line (hex unless noted):
//   order(dec) pc insn trap(dec) rd(dec) rd_wdata mem_addr rmask wmask
//   mem_rdata mem_wdata mode(dec: 3 M, 0 U)
// Result line on stdout: "TB: PASS", "TB: FAIL <n>", "TB: TIMEOUT", or
// "TB: ERROR <reason>", followed by "TB: cycles <n> retired <n>" and
// "TB: sleep cycles <n>".
//
// AHB = 1 (run.py --param AHB=1): the DUT is chillus_ahb (the core behind
// its AHB-Lite I / D bus bridges) and the memory, CLINT, console and tohost
// sit behind two AHB-Lite subordinate models instead of the MSS ones:
//   I bus  : +istall=<pct> random wait states per data phase; a fetch
//            outside the memory gets a two-cycle ERROR response.
//   D bus  : +dstall=<pct> random wait states; a load / store outside the
//            memory and the CLINT gets a two-cycle ERROR response (no
//            effect); a CLINT read waits one cycle (its register is read at
//            the end of the first data-phase cycle), a CLINT write goes in
//            when its data phase completes.
//
// Parameters: forwarded to u_dut (defaults as chillus_core), so a build can
// set them with Verilator -G (sim/run.py --param NAME=VALUE).
// -----------------------------------------------------------------------------
module chillus_tb #(
  parameter bit RF_LATCH  = 1'b1,     // chillus_core RF_LATCH
  parameter int MEM_WORDS = 1 << 18,  // RAM size in words at BASE (1 MiB); run.py --param MEM_WORDS=
  parameter bit AHB       = 1'b0,     // 1: chillus_ahb behind AHB-Lite memory models
  parameter bit DEBUG     = 1'b1,     // chillus_core DEBUG
  parameter int NUM_TRIGGERS = 0,     // chillus_core NUM_TRIGGERS (Spike: --triggers, run.py)
  parameter int PMP_REGIONS  = 4,     // chillus_core PMP_REGIONS (Spike: --pmpregions, run.py)
  parameter int ICACHE_KB    = 0      // chillus_core ICACHE_KB (every address cacheable)
);
  import chillus_dec_pkg::*;

  localparam logic [31:0] BASE       = 32'h8000_0000;  // riscv-tests link address
  localparam logic [31:0] CLINT_BASE = 32'h0200_0000;  // as Spike
  localparam int          DRAIN     = 16;              // cycles after tohost
  localparam int          DEBUG_WAKE = 16;             // sleep cycles before the armed debug_req
  localparam logic [31:0] DM_ROM     = BASE + 32'h1_0000;  // mini-DM halt address (run.py DM_ROM)

  // ---------------------------------------------------------------------------
  // clock, reset, plusargs
  // ---------------------------------------------------------------------------
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic test_en = 1'b0;   // functional mode
  logic [31:0] boot_addr = BASE;
  logic [31:0] hart_id   = '0;      // +hart_id
  logic        fetch_enable = 1'b1; // +fetch_delay: a one-cycle pulse instead
  int          fetch_delay  = -1;   // -1: fetch_enable tied high
  always #5 clk = ~clk;

  string       hex_file;
  string       trace_file;
  logic [31:0] tohost      = '0;      // 0: no tohost detection
  logic [31:0] console     = '0;      // 0: no console
  logic [31:0] irqgen      = '0;      // 0: no interrupt generator
  logic [31:0] irq_gen     = '0;      // interrupt lines set by the program (+irqgen)
  string       console_log;
  int          console_fd  = 0;
  int          max_cycles  = 200000;
  int          istall      = 0;       // percent
  int          dstall      = 0;       // percent
  int          trace_fd    = 0;
  logic [31:0] ifetch_err  = '0;      // first injected fetch-error word address
  int          ifetch_err_words = 0;  // injected fetch-error words (0: none)
  logic [31:0] priv_region = '0;      // first word of the privileged region
  int          priv_region_words = 0; // privileged words (0: none)

  logic [31:0] mem [MEM_WORDS];

  initial begin
    if (!$value$plusargs("hex=%s", hex_file)) begin
      $display("TB: ERROR no +hex=<file>");
      $finish;
    end
    void'($value$plusargs("trace=%s", trace_file));
    void'($value$plusargs("tohost=%h", tohost));
    void'($value$plusargs("console=%h", console));
    void'($value$plusargs("console_log=%s", console_log));
    void'($value$plusargs("irqgen=%h", irqgen));
    void'($value$plusargs("hart_id=%h", hart_id));
    if ($value$plusargs("fetch_delay=%d", fetch_delay)) fetch_enable = 1'b0;
    if ($test$plusargs("debug_req_reset")) irq_gen[29] = 1'b1;
    void'($value$plusargs("max_cycles=%d", max_cycles));
    void'($value$plusargs("istall=%d", istall));
    void'($value$plusargs("dstall=%d", dstall));
    if ($value$plusargs("ifetch_err=%h", ifetch_err)) begin
      ifetch_err[1:0]  = 2'b00;
      ifetch_err_words = 1;
      void'($value$plusargs("ifetch_err_words=%d", ifetch_err_words));
    end
    if ($value$plusargs("priv_region=%h", priv_region)) begin
      priv_region[1:0]  = 2'b00;
      priv_region_words = 1024;
      void'($value$plusargs("priv_region_words=%d", priv_region_words));
    end
    for (int i = 0; i < MEM_WORDS; i++) mem[i] = '0;
    $readmemh(hex_file, mem);
    if (trace_file != "") trace_fd = $fopen(trace_file, "w");
    if (console_log != "") console_fd = $fopen(console_log, "w");
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    if (fetch_delay >= 0) begin
      repeat (fetch_delay) @(posedge clk);
      fetch_enable = 1'b1;
      @(posedge clk);
      fetch_enable = 1'b0;
    end
  end

  function automatic logic in_mem(input logic [31:0] addr);
    return (addr >= BASE) && (((addr - BASE) >> 2) < MEM_WORDS);
  endfunction

  function automatic logic in_clint(input logic [31:0] addr);
    return addr[31:16] == CLINT_BASE[31:16];
  endfunction

  // fetch answered with imss_err: outside the memory, or injected
  function automatic logic fetch_err(input logic [31:0] addr);
    return !in_mem(addr) ||
           (((addr - ifetch_err) >> 2) < 32'(ifetch_err_words) && addr >= ifetch_err);
  endfunction

  // unprivileged access to the privileged region: error response
  function automatic logic priv_err(input logic [31:0] addr, input logic priv);
    return !priv && addr >= priv_region &&
           ((addr - priv_region) >> 2) < 32'(priv_region_words);
  endfunction

  function automatic int widx(input logic [31:0] addr);
    return int'((addr - BASE) >> 2);
  endfunction

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  logic              imss_req;
  logic              imss_gnt;
  logic [XLEN-1:0]   imss_addr;
  logic              imss_priv;          // privileged fetch (HPROT[1])
  logic              imss_rvalid;
  logic [31:0]       imss_rdata;
  logic              imss_err;
  logic              dmss_req;
  logic              dmss_gnt;
  logic              dmss_we;
  logic [XLEN/8-1:0] dmss_be;
  logic [XLEN-1:0]   dmss_addr;
  logic [XLEN-1:0]   dmss_wdata;
  logic              dmss_priv;          // privileged access (HPROT[1])
  logic              dmss_rvalid;
  logic [XLEN-1:0]   dmss_rdata;         // memory or CLINT read word
  logic              dmss_err;
  logic              debug_req;          // armed debug wake (irq_gen[30]) or irq_gen[29]
  logic              debug_mode;
  logic              core_sleep;

  logic              rvfi_valid;
  logic [63:0]       rvfi_order;
  logic [31:0]       rvfi_insn;
  logic              rvfi_trap;
  logic              rvfi_halt;
  logic              rvfi_intr;
  logic [1:0]        rvfi_mode;
  logic [1:0]        rvfi_ixl;
  logic [4:0]        rvfi_rs1_addr;
  logic [4:0]        rvfi_rs2_addr;
  logic [XLEN-1:0]   rvfi_rs1_rdata;
  logic [XLEN-1:0]   rvfi_rs2_rdata;
  logic [4:0]        rvfi_rd_addr;
  logic [XLEN-1:0]   rvfi_rd_wdata;
  logic [XLEN-1:0]   rvfi_pc_rdata;
  logic [XLEN-1:0]   rvfi_pc_wdata;
  logic [XLEN-1:0]   rvfi_mem_addr;
  logic [XLEN/8-1:0] rvfi_mem_rmask;
  logic [XLEN/8-1:0] rvfi_mem_wmask;
  logic [XLEN-1:0]   rvfi_mem_rdata;
  logic [XLEN-1:0]   rvfi_mem_wdata;

  // CLINT side (u_clint below)
  logic              irq_software;
  logic              irq_timer;
  logic              irq_external;    // irq_gen[15]
  logic [14:0]       irq_fast;        // irq_gen[14:0]
  logic              irq_nmi;         // irq_gen[31]
  logic [63:0]       mtime;
  logic              clint_req;       // data request to the CLINT taken this edge
  logic [31:0]       clint_rdata;
  logic              clint_rd_q = 1'b0;   // last data read went to the CLINT
  logic              one = 1'b1;
  logic [31:0]       ram_rdata = '0;  // last data read from memory

  // AHB mode: the bus signals between chillus_ahb and the subordinate models
  logic [31:0] i_HADDR, i_HWDATA, i_HRDATA, d_HADDR, d_HWDATA, d_HRDATA;
  logic [1:0]  i_HTRANS, d_HTRANS;
  logic [2:0]  i_HSIZE, d_HSIZE;
  logic        i_HWRITE, i_HREADY, i_HRESP, d_HWRITE, d_HREADY, d_HRESP;
  logic [3:0]  i_HPROT, d_HPROT;

  if (!AHB) begin : g_mss
    chillus_core #(
      .NUM_TRIGGERS      (NUM_TRIGGERS),
      .PMP_REGIONS       (PMP_REGIONS),
      .ICACHE_KB         (ICACHE_KB),
      .RF_LATCH          (RF_LATCH),
      .DEBUG             (DEBUG),
      .DM_HALT_ADDR      (DM_ROM),
      .DM_EXCEPTION_ADDR (DM_ROM + 32'd8)
    ) u_dut (.*);
  end else begin : g_ahb
    chillus_ahb #(
      .NUM_TRIGGERS      (NUM_TRIGGERS),
      .PMP_REGIONS       (PMP_REGIONS),
      .ICACHE_KB         (ICACHE_KB),
      .RF_LATCH          (RF_LATCH),
      .DEBUG             (DEBUG),
      .DM_HALT_ADDR      (DM_ROM),
      .DM_EXCEPTION_ADDR (DM_ROM + 32'd8)
    ) u_dut (.*);
  end

  assign irq_fast     = irq_gen[14:0];
  assign irq_external = irq_gen[15];
  assign irq_nmi      = irq_gen[31];

  // ---------------------------------------------------------------------------
  // CLINT (timer, software interrupt)
  // ---------------------------------------------------------------------------
  logic        clint_write;   // CLINT port request (driven by the MSS or AHB data model)
  logic [15:0] clint_addr;
  logic [3:0]  clint_strb;
  logic [31:0] clint_wdata;

  chillus_clint u_clint (
    .clk          (clk),
    .rst_n        (rst_n),
    .tick         (one),
    .req_valid    (clint_req),
    .req_write    (clint_write),
    .req_addr     (clint_addr),
    .req_strb     (clint_strb),
    .req_wdata    (clint_wdata),
    .ack_rdata    (clint_rdata),
    .mtime        (mtime),
    .irq_timer    (irq_timer),
    .irq_software (irq_software)
  );

  // ---------------------------------------------------------------------------
  // shared memory-side actions
  // ---------------------------------------------------------------------------
  int   cycles   = 0;
  int   retired  = 0;
  int   drain    = -1;         // >= 0: counting down after tohost
  string result  = "";
  bit    hprot_bad = 1'b0;     // an AHB transfer had a wrong HPROT

  // a store into the memory (in range), with console output and tohost
  task automatic mem_store(input logic [31:0] addr, input logic [31:0] wdata,
                           input logic [3:0] strb);
    logic [31:0] w;
    w = mem[widx(addr)];
    for (int b = 0; b < 4; b++) begin
      if (strb[b]) w[b*8 +: 8] = wdata[b*8 +: 8];
    end
    mem[widx(addr)] <= w;
    if (irqgen != '0 && addr == irqgen) irq_gen <= w;
    if (console != '0 && console_fd != 0 && addr == console && strb[0]) begin
      $fwrite(console_fd, "%c", wdata[7:0]);
    end
    if (tohost != '0 && addr == tohost && w != '0 && drain < 0) begin
      result = (w == 32'd1) ? "PASS" : $sformatf("FAIL %0d", w >> 1);
      drain  = DRAIN;
    end
  endtask

  if (!AHB) begin : g_mss_mem
    logic d_take;     // a data request is granted at this edge

    assign d_take      = rst_n && dmss_req && dmss_gnt;
    assign clint_req   = d_take && in_clint(dmss_addr);
    assign clint_write = dmss_we;
    assign clint_addr  = dmss_addr[15:0];
    assign clint_strb  = dmss_be;
    assign clint_wdata = dmss_wdata;
    assign dmss_rdata  = !dmss_rvalid ? '0 : clint_rd_q ? clint_rdata : ram_rdata;

    // -------------------------------------------------------------------------
    // instruction fetch port
    // -------------------------------------------------------------------------
    logic [31:0] fetch_q [$];    // granted request addresses, oldest first
    logic        fetch_pq [$];   // their imss_priv
    logic        i_gnt_ok = 1'b0;

    assign imss_gnt = i_gnt_ok;

    initial begin
      imss_rvalid = 1'b0;
      imss_rdata  = '0;
      imss_err    = 1'b0;
    end

    always @(posedge clk) begin
      if (imss_rvalid) begin
        void'(fetch_q.pop_front());
        void'(fetch_pq.pop_front());
      end
      if (rst_n && imss_req && imss_gnt) begin
        fetch_q.push_back(imss_addr);
        fetch_pq.push_back(imss_priv);
      end

      i_gnt_ok <= rst_n && ($urandom_range(99) >= istall);
      if (fetch_q.size() > 0 && $urandom_range(99) >= istall) begin
        imss_rvalid <= 1'b1;
        imss_err    <= fetch_err(fetch_q[0]) || priv_err(fetch_q[0], fetch_pq[0]);
        imss_rdata  <= (fetch_err(fetch_q[0]) || priv_err(fetch_q[0], fetch_pq[0])) ? '0 :
                       mem[widx(fetch_q[0])];
      end else begin
        imss_rvalid <= 1'b0;
        imss_err    <= 1'b0;
        imss_rdata  <= '0;
      end
    end

    // -------------------------------------------------------------------------
    // data port: the access happens at the granting edge, the response
    // follows one or more cycles later
    // -------------------------------------------------------------------------
    logic d_gnt_ok = 1'b0;
    logic d_wait   = 1'b0;       // granted, response not yet given
    logic d_err_q  = 1'b0;       // error of the granted access

    assign dmss_gnt = d_gnt_ok;

    initial begin
      dmss_rvalid = 1'b0;
      dmss_err    = 1'b0;
    end

    always @(posedge clk) begin
      logic err;
      logic give;
      err  = d_err_q;
      if (d_take) begin
        err = (!in_mem(dmss_addr) && !in_clint(dmss_addr)) || priv_err(dmss_addr, dmss_priv);
        if (!dmss_we) clint_rd_q <= in_clint(dmss_addr);
        if (in_clint(dmss_addr)) begin
          // u_clint takes it (clint_req)
        end else if (err) begin
          ram_rdata <= '0;                      // bus error: no effect
        end else if (dmss_we) begin
          mem_store(dmss_addr, dmss_wdata, dmss_be);
        end else begin
          ram_rdata <= mem[widx(dmss_addr)];
        end
      end
      give        = (d_take || d_wait) && ($urandom_range(99) >= dstall);
      d_err_q     <= err;
      d_wait      <= (d_take || d_wait) && !give;
      dmss_rvalid <= give;
      dmss_err    <= give && err;
      d_gnt_ok    <= rst_n && ($urandom_range(99) >= dstall);
    end

  end else begin : g_ahb_mem
    // -------------------------------------------------------------------------
    // I bus subordinate: data phase state, random wait states, ERROR outside
    // -------------------------------------------------------------------------
    logic        i_dp = 1'b0;        // a fetch is in its data phase
    logic [31:0] i_dp_addr = '0;
    logic        i_err1 = 1'b0;      // first cycle of an ERROR response

    initial begin
      i_HREADY = 1'b1;
      i_HRESP  = 1'b0;
    end

    assign i_HRDATA = (i_dp && !i_HRESP) ? mem[widx(i_dp_addr)] : '0;

    always @(posedge clk) begin
      if (i_HREADY) begin
        // address phase sampled: the next data phase
        i_dp      <= rst_n && i_HTRANS[1];
        i_dp_addr <= i_HADDR;
        if (rst_n && i_HTRANS[1] && i_HPROT != {2'b00, i_HPROT[1], 1'b0}) hprot_bad = 1'b1;
        if (rst_n && i_HTRANS[1] && (fetch_err(i_HADDR) || priv_err(i_HADDR, i_HPROT[1]))) begin
          i_HREADY <= 1'b0; i_HRESP <= 1'b1; i_err1 <= 1'b1;
        end else begin
          i_HREADY <= !(rst_n && i_HTRANS[1] && $urandom_range(99) < istall);
          i_HRESP  <= 1'b0; i_err1 <= 1'b0;
        end
      end else if (i_err1) begin
        i_HREADY <= 1'b1; i_HRESP <= 1'b1; i_err1 <= 1'b0;   // ERROR, second cycle
      end else begin
        i_HREADY <= $urandom_range(99) >= istall;
      end
    end

    // -------------------------------------------------------------------------
    // D bus subordinate: memory and CLINT, random wait states, ERROR outside
    // -------------------------------------------------------------------------
    logic        d_dp = 1'b0;        // a load / store is in its data phase
    logic [31:0] d_dp_addr = '0;
    logic        d_dp_write = 1'b0;
    logic [2:0]  d_dp_size = '0;
    logic        d_dp_clint = 1'b0;  // ... to the CLINT
    logic        d_err1 = 1'b0;      // first cycle of an ERROR response
    logic        d_clint_rd = 1'b0;  // first cycle of a CLINT read: read it now
    logic [3:0]  d_strb;             // byte lanes of the data-phase access

    initial begin
      d_HREADY = 1'b1;
      d_HRESP  = 1'b0;
    end

    always_comb begin
      d_strb = 4'b0;
      case (d_dp_size)
        3'd0:    d_strb = 4'b0001 << d_dp_addr[1:0];
        3'd1:    d_strb = 4'b0011 << d_dp_addr[1:0];
        default: d_strb = 4'b1111;
      endcase
    end

    assign clint_req   = rst_n && d_dp && d_dp_clint &&
                         (d_dp_write ? d_HREADY : d_clint_rd);
    assign clint_write = d_dp_write;
    assign clint_addr  = d_dp_addr[15:0];
    assign clint_strb  = d_strb;
    assign clint_wdata = d_HWDATA;
    assign d_HRDATA    = (!d_dp || d_dp_write || d_HRESP) ? '0 :
                         d_dp_clint ? clint_rdata : mem[widx(d_dp_addr)];

    always @(posedge clk) begin
      // data phase completes: a store takes effect
      if (d_dp && d_HREADY && d_dp_write && !d_HRESP && !d_dp_clint) begin
        mem_store(d_dp_addr, d_HWDATA, d_strb);
      end
      d_clint_rd <= 1'b0;
      if (d_HREADY) begin
        // address phase sampled: the next data phase
        d_dp       <= rst_n && d_HTRANS[1];
        d_dp_addr  <= d_HADDR;
        d_dp_write <= d_HWRITE;
        d_dp_size  <= d_HSIZE;
        d_dp_clint <= in_clint(d_HADDR);
        if (rst_n && d_HTRANS[1] && d_HPROT != {2'b00, d_HPROT[1], 1'b1}) hprot_bad = 1'b1;
        if (rst_n && d_HTRANS[1] && ((!in_mem(d_HADDR) && !in_clint(d_HADDR)) ||
                                     priv_err(d_HADDR, d_HPROT[1]))) begin
          d_HREADY <= 1'b0; d_HRESP <= 1'b1; d_err1 <= 1'b1;
        end else if (rst_n && d_HTRANS[1] && in_clint(d_HADDR) && !d_HWRITE) begin
          d_HREADY <= 1'b0; d_HRESP <= 1'b0; d_err1 <= 1'b0; d_clint_rd <= 1'b1;
        end else begin
          d_HREADY <= !(rst_n && d_HTRANS[1] && $urandom_range(99) < dstall);
          d_HRESP  <= 1'b0; d_err1 <= 1'b0;
        end
      end else if (d_err1) begin
        d_HREADY <= 1'b1; d_HRESP <= 1'b1; d_err1 <= 1'b0;   // ERROR, second cycle
      end else begin
        d_HREADY <= $urandom_range(99) >= dstall;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // debug wake
  // ---------------------------------------------------------------------------
  int   sleep_run = 0;         // consecutive cycles with core_sleep high
  int   sleep_cycles = 0;
  bit   dbg_wake = 1'b0;       // armed debug wake fired (held until irq_gen[30] clears)

  assign debug_req = dbg_wake || irq_gen[29];

  always @(posedge clk) begin
    sleep_run = core_sleep ? sleep_run + 1 : 0;
    if (!irq_gen[30])                              dbg_wake <= 1'b0;
    else if (core_sleep && sleep_run >= DEBUG_WAKE) dbg_wake <= 1'b1;
  end

  // ---------------------------------------------------------------------------
  // trace, end of test
  // ---------------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst_n) cycles++;
    if (rst_n && core_sleep) sleep_cycles++;
    if (rvfi_valid) begin
      retired++;
      if (trace_fd != 0) begin
        $fwrite(trace_fd, "%0d %08h %08h %0d %0d %08h %08h %h %h %08h %08h %0d\n",
                rvfi_order, rvfi_pc_rdata, rvfi_insn, rvfi_trap, rvfi_rd_addr,
                rvfi_rd_wdata, rvfi_mem_addr, rvfi_mem_rmask, rvfi_mem_wmask,
                rvfi_mem_rdata, rvfi_mem_wdata, rvfi_mode);
      end
    end
    if (drain > 0) begin
      drain--;
    end else if (drain == 0 || cycles >= max_cycles) begin
      if (result == "") result = "TIMEOUT";
      if (hprot_bad) result = "ERROR hprot";
      $display("TB: %s", result);
      $display("TB: cycles %0d retired %0d", cycles, retired);
      $display("TB: sleep cycles %0d", sleep_cycles);
      if (trace_fd != 0) $fclose(trace_fd);
      if (console_fd != 0) $fclose(console_fd);
      $finish;
    end
  end

endmodule
