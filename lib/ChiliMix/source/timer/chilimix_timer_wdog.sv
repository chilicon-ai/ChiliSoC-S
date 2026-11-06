// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_timer_wdog
//
// Watchdog in the SiFive AON watchdog layout (FE310 wdog*, Zephyr sifive,wdt),
// so existing drivers work. It behaves like SiFive's WatchdogTimer
// (sifive-blocks mockaon), clocked by clk with tick as the count rate (the
// AON low-frequency clock there), except that registers reset to 0 where
// SiFive leaves them unreset and wdogcmp0 resets to 0xFFFF:
//   key     writing 0x0051F15E (all four bytes) to wdogkey unlocks the next
//           write; any other APB write locks again, whether or not it took
//           effect. Writes to wdogcfg, wdogcount and wdogcmp0 take effect
//           only while unlocked.
//   count   wdogcount (31 bits, wraps) counts ticks while enalways is set, or
//           coreawake is set and core_sleep is low; halt freezes it.
//           s = (count >> scale)[15:0]; elapsed = s >= wdogcmp0.
//   restart count goes to 0 on a feed (0x0D09F00D written to wdogfeed while
//           unlocked, all four bytes) or when zerocmp is set and elapsed.
//   ip0     set by elapsed; cleared only by a wdogcfg write of bit 28 = 0
//           (while unlocked, and not while elapsed). Drives irq.
//   rst_req set by elapsed while rsten is set; held until reset (connect it
//           to chilimix_socctl rst_req).
// Software writes: the strobed bytes of wdogcount load the counter (a write
// wins over a restart and a tick); wdogcfg and wdogcmp0 bytes are written
// byte by byte.
//
// Timing    : APB reads are combinational (no wait states). count, the cfg
//             bits, ip0, unlocked and rst_req are registered; elapsed is
//             combinational from count, so ip0 / rst_req follow one cycle
//             later. irq is ip0.
// Invariants: unlocked falls on every APB write other than a key write;
//             wdogcfg, wdogcount and wdogcmp0 change by a write only while
//             unlocked; rst_req never falls while rst_n is high; irq == ip0.
// Debug     : no reset -> rst_req, cfg_rsten, elapsed, cmp0; writes ignored ->
//             unlocked (u_unlocked.q) and the key write before them; not
//             counting -> tick, halt, core_sleep, cfg_enalways / cfg_coreawake.
// -----------------------------------------------------------------------------
module chilimix_timer_wdog (
  input  logic        clk,
  input  logic        rst_n,       // async, active-low
  // APB4 subordinate (registers)
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [5:0]  PADDR,       // byte address inside the watchdog
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic        PREADY,
  output logic [31:0] PRDATA,
  output logic        PSLVERR,
  // control
  input  logic        tick,        // count rate (e.g. a 32 kHz timebase)
  input  logic        halt,        // freeze the counter (e.g. debug mode)
  input  logic        core_sleep,  // the core is asleep or in reset
  // outputs
  output logic        irq,         // level: ip0
  output logic        rst_req      // reset request, held until reset
);

  localparam logic [31:0] KEY  = 32'h0051_F15E;  // wdogkey unlock value
  localparam logic [31:0] FOOD = 32'h0D09_F00D;  // wdogfeed value

  logic        cfg_wr;            // APB write to wdogcfg
  logic        count_wr;          // APB write to wdogcount
  logic [31:0] feed_value;        // PWDATA of a wdogfeed write
  logic        feed_wr;           // APB write to wdogfeed
  logic        key_wr;            // APB write to wdogkey
  logic        cmp0_wr;           // APB write to wdogcmp0
  logic        apb_wr;            // any APB write to the watchdog
  logic        full_word;         // all four bytes strobed
  logic        unlocked;
  logic        unlocked_en;
  logic        unlocked_d;
  logic        cfg_ok;            // wdogcfg write takes effect
  logic        cfg_lo_en;         // wdogcfg byte 0 written
  logic        cfg_mid_en;        // wdogcfg byte 1 written
  logic [3:0]  cfg_mid_d;         // wdogcfg byte 1 bits 13, 12, 9, 8
  logic [3:0]  cfg_mid;           // {coreawake, enalways, zerocmp, rsten}
  logic [3:0]  cfg_scale;
  logic        cfg_rsten;
  logic        cfg_zerocmp;
  logic        cfg_enalways;
  logic        cfg_coreawake;
  logic        cmp0_ok;           // wdogcmp0 write takes effect
  logic        cmp0_en;
  logic [15:0] cmp0_d;
  logic [15:0] cmp0;              // wdogcmp0
  logic [30:0] count;             // wdogcount
  logic        count_en;          // count up this cycle
  logic        feed;              // valid feed write
  logic        restart;           // count goes to 0
  logic [3:0]  count_strb;        // wdogcount bytes written
  logic        count_load;        // load count (restart or write)
  logic [30:0] count_base;        // count before the write bytes
  logic [30:0] count_load_val;    // restart value with the written bytes
  logic [30:0] count_shr;         // count >> scale
  logic [15:0] s;                 // wdogs
  logic        elapsed;           // wdogs >= wdogcmp0
  logic        ip0;               // wdogip0
  logic        ip0_wr;            // wdogcfg byte 3 written (unlocked)
  logic        ip0_en;
  logic        ip0_d;
  logic        rst_req_d;

  chilimix_timer_wdog_regs u_regs (
    .clk           (clk),
    .rst_n         (rst_n),
    .PSEL          (PSEL),
    .PENABLE       (PENABLE),
    .PWRITE        (PWRITE),
    .PADDR         (PADDR),
    .PWDATA        (PWDATA),
    .PSTRB         (PSTRB),
    .PREADY        (PREADY),
    .PRDATA        (PRDATA),
    .PSLVERR       (PSLVERR),
    .cfg_scale     (cfg_scale),
    .cfg_rsten     (cfg_rsten),
    .cfg_zerocmp   (cfg_zerocmp),
    .cfg_enalways  (cfg_enalways),
    .cfg_coreawake (cfg_coreawake),
    .cfg_ip0       (ip0),
    .cfg_wr        (cfg_wr),
    .count_value   (count),
    .count_wr      (count_wr),
    .s_value       (s),
    .feed_value    (feed_value),
    .feed_wr       (feed_wr),
    .key_unlocked  (unlocked),
    .key_wr        (key_wr),
    .cmp0_value    (cmp0),
    .cmp0_wr       (cmp0_wr)
  );

  // ---- key: a key write unlocks, every other write locks
  assign apb_wr      = PSEL && PENABLE && PWRITE;
  assign full_word   = PSTRB == 4'b1111;
  assign unlocked_en = apb_wr;
  assign unlocked_d  = key_wr && full_word && (PWDATA == KEY);

  basechili_dffe #(.WIDTH(1)) u_unlocked (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (unlocked_en),
    .d     (unlocked_d),
    .q     (unlocked)
  );

  // ---- wdogcfg (bytes 0 and 1; byte 3 is ip0)
  assign cfg_ok     = cfg_wr && unlocked;
  assign cfg_lo_en  = cfg_ok && PSTRB[0];
  assign cfg_mid_en = cfg_ok && PSTRB[1];
  assign cfg_mid_d  = {PWDATA[13], PWDATA[12], PWDATA[9], PWDATA[8]};

  basechili_dffe #(.WIDTH(4)) u_scale (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cfg_lo_en),
    .d     (PWDATA[3:0]),
    .q     (cfg_scale)
  );

  basechili_dffe #(.WIDTH(4)) u_cfg_mid (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cfg_mid_en),
    .d     (cfg_mid_d),
    .q     (cfg_mid)
  );

  assign cfg_rsten     = cfg_mid[0];
  assign cfg_zerocmp   = cfg_mid[1];
  assign cfg_enalways  = cfg_mid[2];
  assign cfg_coreawake = cfg_mid[3];

  // ---- wdogcmp0
  assign cmp0_ok = cmp0_wr && unlocked;
  assign cmp0_en = cmp0_ok && (PSTRB[1:0] != 2'b00);
  assign cmp0_d  = {PSTRB[1] ? PWDATA[15:8] : cmp0[15:8], PSTRB[0] ? PWDATA[7:0] : cmp0[7:0]};

  basechili_dffe #(.WIDTH(16), .RESET_VAL(16'hFFFF)) u_cmp0 (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (cmp0_en),
    .d     (cmp0_d),
    .q     (cmp0)
  );

  // ---- counter
  assign count_shr = count >> cfg_scale;
  assign s         = count_shr[15:0];
  assign elapsed   = s >= cmp0;

  assign count_en = (cfg_enalways || (cfg_coreawake && !core_sleep)) && tick && !halt;
  assign feed     = feed_wr && unlocked && full_word && (feed_value == FOOD);
  assign restart  = feed || (cfg_zerocmp && elapsed);

  assign count_strb = PSTRB & {4{count_wr && unlocked}};
  assign count_load = restart || (count_strb != 4'b0000);
  assign count_base = restart ? 31'd0 : count;

  always_comb begin
    for (int b = 0; b < 31; b++)
      count_load_val[b] = count_strb[b/8] ? PWDATA[b] : count_base[b];
  end

  basechili_updown_counter #(.WIDTH(31)) u_count (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (count_load),
    .load_val (count_load_val),
    .inc      (count_en),
    .dec      (1'b0),
    .count    (count),
    .count_d  ()
  );

  // ---- ip0 and the reset request
  assign ip0_wr = cfg_ok && PSTRB[3];
  assign ip0_en = ip0_wr || elapsed;
  assign ip0_d  = (ip0_wr && PWDATA[28]) || elapsed;

  basechili_dffe #(.WIDTH(1)) u_ip0 (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (ip0_en),
    .d     (ip0_d),
    .q     (ip0)
  );

  assign rst_req_d = rst_req || (cfg_rsten && elapsed);

  basechili_dff #(.WIDTH(1)) u_rst_req (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (rst_req_d),
    .q     (rst_req)
  );

  assign irq = ip0;

endmodule
