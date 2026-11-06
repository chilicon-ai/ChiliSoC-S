// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_to_apb -- AHB-Lite manager model in front, APB4
// subordinate model behind.
//
// AHB side: random NONSEQ / SEQ reads and writes of every legal HSIZE
// (aligned) and random HPROT to the bridge, back to back or with IDLE / BUSY
// gaps, and transfers to another subordinate (HSEL low) whose data phase has
// random wait states, so the bridge sees HREADY low while not selected. The
// manager sometimes cancels its next transfer in the first ERROR cycle.
// APB side: random PREADY wait states, occasional PSLVERR, random PRDATA;
// outside ACCESS the responses are random junk.
// Checked: APB SETUP the cycle after the AHB address phase, then ACCESS with
// PADDR / PWRITE / PSTRB / PPROT (and PWDATA of a write) stable until PREADY; PADDR,
// PWRITE, PWDATA = HWDATA, PSTRB from HADDR / HSIZE (0 for reads), PPROT =
// {!HPROT[0], 0, HPROT[1]}; exactly one APB transfer per AHB transfer; AHB
// response OKAY with HRDATA = PRDATA, or the two-cycle ERROR on PSLVERR;
// IDLE / BUSY to the bridge get a zero-wait OKAY.
`include "tb_common.svh"
module basechili_ahb_to_apb_tb #(
  parameter  int ADDR_W = 32,
  parameter  int DATA_W = 32,
  localparam int N_LANE = DATA_W / 8,
  localparam int OFF_W  = $clog2(N_LANE)
);
  localparam int N_XFER = 3000;   // AHB transfers to the bridge

  `TB_CLOCK_RESET

  // AHB
  logic              HSEL, HWRITE, HREADY, HREADYOUT, HRESP;
  logic [ADDR_W-1:0] HADDR;
  logic [1:0]        HTRANS;
  logic [2:0]        HSIZE;
  logic [3:0]        HPROT;
  logic [DATA_W-1:0] HWDATA, HRDATA;
  // APB
  logic [ADDR_W-1:0] PADDR;
  logic              PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [DATA_W-1:0] PWDATA, PRDATA;
  logic [N_LANE-1:0] PSTRB;
  logic [2:0]        PPROT;

  basechili_ahb_to_apb #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk, .rst_n,
    .HSEL, .HADDR, .HTRANS, .HWRITE, .HSIZE, .HPROT, .HWDATA, .HREADY, .HREADYOUT, .HRESP, .HRDATA,
    .PADDR, .PSEL, .PENABLE, .PWRITE, .PWDATA, .PSTRB, .PPROT, .PRDATA, .PREADY, .PSLVERR);

  typedef struct {
    logic [ADDR_W-1:0] addr;
    logic              write;
    logic [2:0]        size;
    logic [3:0]        prot;
    logic [DATA_W-1:0] wdata;
  } xfer_t;
  typedef struct { logic err; logic [DATA_W-1:0] rdata; } resp_t;

  xfer_t apb_q[$];    // AHB transfers waiting for their APB SETUP
  resp_t resp_q[$];   // APB responses waiting for the AHB data phase to end

  function automatic logic [DATA_W-1:0] rnd_data();
    logic [DATA_W-1:0] d;
    for (int k = 0; k < DATA_W; k += 32) d = {d, 32'($urandom)};
    return d;
  endfunction

  function automatic logic [N_LANE-1:0] exp_strb(xfer_t x);
    logic [N_LANE-1:0] s;
    int off;
    off = int'(x.addr) % N_LANE;
    s = '0;
    if (x.write) for (int b = 0; b < (1 << x.size); b++) s[off + b] = 1'b1;
    return s;
  endfunction

  // ---- AHB manager state ----
  int    issued, done, n_err, n_other, n_idle;
  logic  stop;           // all transfers issued: only IDLE from now on
  logic  dp_bridge;      // a bridge NONSEQ / SEQ transfer is in its data phase
  logic  dp_bridge_idle; // an IDLE / BUSY to the bridge is in its data phase
  logic  dp_other;       // another subordinate's transfer is in its data phase
  logic  other_ready;    // that subordinate's HREADYOUT
  logic  err1_seen;      // first ERROR cycle seen in the current data phase
  xfer_t dp;             // the bridge transfer in its data phase
  logic  addr_taken;     // the address phase was taken at the last edge
  logic  expect_setup;   // an APB SETUP must show this cycle
  // ---- APB monitor state ----
  logic              p_sel, p_en, p_end;    // previous cycle PSEL / PENABLE / ACCESS end
  logic [ADDR_W-1:0] p_addr;
  logic              p_write;
  logic [DATA_W-1:0] p_wdata;
  logic [N_LANE-1:0] p_strb;
  logic [2:0]        p_prot;

  // next AHB address phase
  task automatic new_addr();
    int k;
    HADDR  = ADDR_W'(rnd_data());
    HWRITE = $urandom;
    HSIZE  = 3'($urandom % (OFF_W + 1));
    HPROT  = 4'($urandom);
    HADDR  = HADDR & ~ADDR_W'((1 << HSIZE) - 1);   // aligned
    k = $urandom % 16;
    if (stop) begin
      HSEL = $urandom; HTRANS = 2'b00;
    end else if (k < 9) begin                      // to the bridge
      HSEL = 1; HTRANS = ($urandom % 4 == 0) ? 2'b11 : 2'b10;
      issued++;
    end else if (k < 12) begin                     // to another subordinate
      HSEL = 0; HTRANS = ($urandom % 2) ? 2'b11 : 2'b10;
    end else if (k < 14) begin                     // IDLE, selected or not
      HSEL = $urandom; HTRANS = 2'b00;
    end else begin                                 // BUSY to the bridge
      HSEL = 1; HTRANS = 2'b01;
    end
  endtask

  initial begin
    HSEL = 0; HADDR = '0; HTRANS = 2'b00; HWRITE = 0; HSIZE = '0; HPROT = '0; HWDATA = '0; HREADY = 1;
    PREADY = 0; PSLVERR = 0; PRDATA = '0;
    issued = 0; done = 0; n_err = 0; n_other = 0; n_idle = 0; stop = 0;
    dp_bridge = 0; dp_bridge_idle = 0; dp_other = 0; other_ready = 1; err1_seen = 0;
    addr_taken = 1; expect_setup = 0;
    p_sel = 0; p_en = 0; p_end = 0; p_addr = '0; p_write = 0; p_wdata = '0; p_strb = '0; p_prot = '0;
    tb_reset();
    forever begin
      // ================= drive (after the falling edge) =================
      if (addr_taken) begin
        stop = issued >= N_XFER;
        new_addr();
      end else if (dp_bridge && HRESP && !HREADYOUT && ($urandom % 2)) begin
        if (HTRANS[1] && HSEL) issued--;           // cancelled in the first ERROR cycle
        HTRANS = 2'b00;
      end
      if (!(dp_bridge && dp.write)) HWDATA = rnd_data();
      other_ready = !dp_other || ($urandom % 3 == 0);
      // APB subordinate: wait states / errors in ACCESS, junk elsewhere
      if (PSEL && PENABLE) begin
        PREADY  = ($urandom % 3 != 0);
        PSLVERR = PREADY ? ($urandom % 6 == 0) : 1'($urandom);
      end else begin
        PREADY = $urandom; PSLVERR = $urandom;
      end
      PRDATA = rnd_data();
      HREADY = dp_bridge || dp_bridge_idle ? HREADYOUT : dp_other ? other_ready : 1'b1;
      #1;
      // ================= sample (before the rising edge) =================
      // ---- APB protocol ----
      `CHECK(!PENABLE || PSEL, "PENABLE without PSEL")
      `CHECK((PSEL && !PENABLE) == expect_setup, $sformatf("SETUP=%b, expected %b", PSEL && !PENABLE, expect_setup))
      if (p_sel && !p_en) `CHECK(PSEL && PENABLE, "SETUP not followed by ACCESS")
      if (p_sel && p_en && !p_end) `CHECK(PSEL && PENABLE, "ACCESS left before PREADY")
      if (p_end) `CHECK(!(PSEL && PENABLE), "ACCESS continued after PREADY")
      if (PSEL && PENABLE)
        `CHECK(PADDR == p_addr && PWRITE == p_write && (!PWRITE || PWDATA == p_wdata) && PSTRB == p_strb && PPROT == p_prot,
               "APB signals changed between SETUP and the end of ACCESS")
      if (PSEL && !PENABLE) begin
        xfer_t x;
        `CHECK(apb_q.size() == 1, $sformatf("SETUP with %0d AHB transfers waiting", apb_q.size()))
        x = apb_q.pop_front();
        `CHECK(PADDR == x.addr && PWRITE == x.write && PSTRB == exp_strb(x)
               && PPROT == {!x.prot[0], 1'b0, x.prot[1]} && (!x.write || PWDATA == x.wdata),
               $sformatf("SETUP PADDR=%h PWRITE=%b PSTRB=%b PPROT=%b PWDATA=%h, expected %h %b %b prot %b %h",
                         PADDR, PWRITE, PSTRB, PPROT, PWDATA, x.addr, x.write, exp_strb(x), x.prot, x.wdata))
      end
      p_sel = PSEL; p_en = PENABLE; p_end = PSEL && PENABLE && PREADY;
      p_addr = PADDR; p_write = PWRITE; p_wdata = PWDATA; p_strb = PSTRB; p_prot = PPROT;
      if (p_end) begin
        resp_t r;
        r.err = PSLVERR; r.rdata = PRDATA;
        resp_q.push_back(r);
      end
      // ---- AHB data phase ----
      if (dp_bridge) begin
        if (dp.write) `CHECK(HWDATA == PWDATA, "PWDATA is not HWDATA")
        if (!HREADYOUT) begin
          if (HRESP) begin
            `CHECK(!err1_seen, "ERROR first cycle twice")
            err1_seen = 1;
          end
        end else begin
          resp_t r;
          `CHECK(resp_q.size() == 1, $sformatf("AHB transfer ends with %0d APB responses", resp_q.size()))
          r = resp_q.pop_front();
          if (r.err) begin
            `CHECK(HRESP && err1_seen, "PSLVERR without the two-cycle ERROR")
            n_err++;
          end else begin
            `CHECK(!HRESP && !err1_seen, "ERROR without PSLVERR")
            if (!dp.write) `CHECK(HRDATA == r.rdata, $sformatf("HRDATA=%h expected %h", HRDATA, r.rdata))
          end
          done++;
          dp_bridge = 0;
        end
      end else begin
        `CHECK(HREADYOUT && !HRESP, $sformatf("no bridge transfer, HREADYOUT=%b HRESP=%b", HREADYOUT, HRESP))
        `CHECK(apb_q.size() == 0 && resp_q.size() == 0 && !PSEL, "APB activity without an AHB transfer")
        if (dp_bridge_idle) n_idle++;
      end
      dp_bridge_idle = 0;
      if (dp_other && other_ready) dp_other = 0;
      // ---- AHB address phase ----
      addr_taken   = HREADY;
      expect_setup = 0;
      if (HREADY) begin
        if (HSEL && HTRANS[1]) begin
          dp_bridge    = 1;
          err1_seen    = 0;
          dp.addr = HADDR; dp.write = HWRITE; dp.size = HSIZE; dp.prot = HPROT;
          dp.wdata     = rnd_data();
          apb_q.push_back(dp);
          expect_setup = 1;
        end else if (HSEL) dp_bridge_idle = 1;
        else if (HTRANS[1]) begin dp_other = 1; n_other++; end
      end
      @(negedge clk);
      if (dp_bridge && dp.write) HWDATA = dp.wdata;     // data phase write data
      if (stop && !dp_bridge && !dp_other && done == issued) break;
    end
    `CHECK(done == issued, $sformatf("%0d transfers issued, %0d done", issued, done))
    `CHECK(n_err > 0 && n_other > 0 && n_idle > 0, $sformatf("errors %0d, other %0d, idle %0d", n_err, n_other, n_idle))
    tb_pass();
  end

  initial begin
    #(N_XFER * 400);
    `CHECK(1'b0, $sformatf("timeout after %0d transfers", done))
  end
endmodule
