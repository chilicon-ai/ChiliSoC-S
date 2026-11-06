// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_socctl
//
// SoC control unit: SoC ID, reset sequencing with reset causes and software
// resets, per-hart resets and boot addresses, two clock dividers and two
// scratch words.
//
// Reset domains: the unit itself runs in the power-on domain (por_n,
// synchronized by u_por_sync), so its registers survive every other reset.
// The system reset (por_n, the ext_rst_n pin, or a software / IP request)
// drives basechili_reset_ctrl, which releases N_DOM domain resets
// rst_n_out[0 .. N_DOM-1] in index order, STEP cycles apart (e.g. 0 fabric,
// 1 peripherals, 2 core). rst_hold.dom[i] holds domain i and every later
// domain in reset (so the release order holds whatever software writes); a
// system reset (ext_rst_n or a request) releases every hold until rst_hold is
// written again, so a hold of the domain carrying the path to these
// registers cannot lock the SoC until power-on.
//   system reset request: a write of KEY to sysrst with all byte strobes,
//   rst_req (a pulse from IP such as a watchdog) or dbg_rst_req (the debug
//   module's ndmreset, a level); each holds the system reset for HOLD
//   cycles after the last request cycle.
//   rst_cause: por is set by power-on (reset value), ext while the
//   synchronized ext_rst_n is low, sw / req / dbg by the requests; each is
//   cleared by writing 1.
// Harts: N_HART harts sit in the last domain (the CPU domain, N_DOM-1).
// hart_rst_n[h] is that domain's reset, also held while hart_hold bit h is
// set (registered: hart_hold_q). Until hart_hold is written after power-on
// or a system reset, the holds are HART_HOLD_RST (by default every hart but
// hart 0: secondary harts wait until the boot hart has set their boot
// address and releases them). boot_addr[h] is boot_hi / boot_lo[h], or
// BOOT_ADDR while both words are 0; the boot addresses are kept across
// system resets.
// Clock dividers: clk_div[i] = clk / clkdiv[i].div with 50% duty, and
// clk_div_tick[i] the matching one-cycle enable (basechili_clock_div).
//
// Timing    : APB reads are combinational (no wait states). rst_n_out
//             asserts asynchronously with por_n / ext_rst_n, and one cycle
//             after a request (from sys_rst_q); release follows the
//             basechili_reset_ctrl sequence.
// Invariants: sys_rst_q is high for exactly HOLD cycles after a request
//             (longer if requests repeat); a domain out of reset implies
//             sys_rst_q low; outside test mode domain i out of reset implies
//             every domain j < i out of reset; hold_arm is low after a
//             system reset until rst_hold is written; outside test mode a
//             hart out of reset implies the CPU domain out of reset;
//             hart_arm is low after a system reset until hart_hold is
//             written.
// Debug     : no reset on a write -> sysrst_wr, key_hit, PSTRB; a domain
//             stuck in reset -> rst_hold, hold_arm, u_rst.step, sys_rst_q (u_sys_rst); a hart
//             stuck in reset -> hart_hold_q, hart_arm, hart_hold; wrong cause
//             -> ext_sync, rst_req, u_regs rst_cause_*.
// -----------------------------------------------------------------------------
module chilimix_socctl #(
  parameter logic [31:0] SOC_ID = 32'h0,   // read from the id register
  parameter int          N_DOM  = 3,       // reset domains, 1 .. 8
  parameter int          STEP   = 16,      // cycles between domain releases, >= 1
  parameter int          HOLD   = 16,      // system reset cycles per request, 2 .. 256
  parameter int          N_HART = 1,       // harts in the CPU domain (the last one), 1 .. 8
  parameter logic [7:0]  HART_HOLD_RST = 8'hFE,   // harts held after a system reset until hart_hold is written
  parameter logic [63:0] BOOT_ADDR = 64'h0        // boot address while a hart's boot_lo / boot_hi are 0
) (
  input  logic             clk,
  input  logic             por_n,           // power-on reset, async, active-low
  input  logic             ext_rst_n,       // external reset pin, async, active-low
  input  logic             test_en,         // scan: rst_n_out follow por_n / ext_rst_n
  // APB4 subordinate (registers)
  input  logic             PSEL,
  input  logic             PENABLE,
  input  logic             PWRITE,
  input  logic [7:0]       PADDR,           // byte address inside the unit
  input  logic [31:0]      PWDATA,
  input  logic [3:0]       PSTRB,
  output logic             PREADY,
  output logic [31:0]      PRDATA,
  output logic             PSLVERR,
  // resets
  input  logic             rst_req,         // system reset request (pulse, synchronous)
  input  logic             dbg_rst_req,     // debugger system reset (ndmreset, level, synchronous)
  output logic [N_DOM-1:0] rst_n_out,       // domain resets, active-low
  output logic [N_HART-1:0]   hart_rst_n,   // hart resets, active-low (the CPU domain and hart_hold)
  output logic [N_HART*64-1:0] boot_addr,   // boot address of hart h at [h*64 +: 64]
  // clocks
  output logic [1:0]       clk_div,         // divided clocks
  output logic [1:0]       clk_div_tick     // last clk cycle of each clk_div period
);

  localparam logic [31:0] KEY    = 32'h5253_5421;          // 'RST!'

  logic              rst_n;          // power-on domain reset (synchronized por_n)
  logic              ext_sync;       // ext_rst_n, synchronized (1 = inactive)
  logic              ext_seen;       // ext_rst_n low
  logic [31:0]       sysrst_key;     // sysrst write data
  logic              sysrst_wr;      // sysrst written this cycle
  logic              key_hit;        // a full-word write of KEY
  logic              sys_go;         // start (or restart) a system reset
  logic              sys_rst_q;      // software / IP system reset active
  logic              sys_rst_n;      // every system reset source, active-low
  logic [7:0]        rst_hold;       // rst_hold.dom
  logic              hold_wr;        // rst_hold written this cycle
  logic              hold_clr;       // a system reset releases the holds
  logic              hold_arm;       // rst_hold is in force (written since the last system reset)
  logic              hold_arm_d;
  logic [N_DOM-1:0]  hold_dom;       // domains held: rst_hold, cascaded upward, while armed
  logic [7:0]        dom_up;         // domains out of reset, register width
  logic              rst_done;       // release sequence finished
  logic [31:0]       clkdiv;         // two 16-bit divisors
  logic              tie0;           // constant 0 (por cause has no set input)
  logic [7:0]        hart_hold;      // hart_hold.hart
  logic              hart_hold_wr;   // hart_hold written this cycle
  logic              hart_arm;       // hart_hold is in force (written since the last system reset)
  logic              hart_arm_d;
  logic [N_HART-1:0] hart_hold_q;    // harts held in reset (registered: glitch-free)
  logic [N_HART-1:0] hart_hold_d;
  logic [7:0]        hart_run;       // harts out of reset, register width
  logic [255:0]      boot_lo;        // boot_lo[h].addr at [h*32 +: 32]
  logic [255:0]      boot_hi;

  // ---- power-on domain
  basechili_reset_sync u_por_sync (
    .clk         (clk),
    .rst_n_async (por_n),
    .test_en     (test_en),
    .rst_n_sync  (rst_n)
  );

  basechili_sync #(.WIDTH(1), .RESET_VAL(1'b1)) u_ext_sync (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (ext_rst_n),
    .q     (ext_sync)
  );

  assign ext_seen = !ext_sync;
  assign tie0     = 1'b0;

  chilimix_socctl_regs #(.N_HART(N_HART)) u_regs (
    .clk               (clk),
    .rst_n             (rst_n),
    .PSEL              (PSEL),
    .PENABLE           (PENABLE),
    .PWRITE            (PWRITE),
    .PADDR             (PADDR),
    .PWDATA            (PWDATA),
    .PSTRB             (PSTRB),
    .PREADY            (PREADY),
    .PRDATA            (PRDATA),
    .PSLVERR           (PSLVERR),
    .id_value          (SOC_ID),
    .rst_cause_por     (),
    .rst_cause_por_set (tie0),
    .rst_cause_ext     (),
    .rst_cause_ext_set (ext_seen),
    .rst_cause_sw      (),
    .rst_cause_sw_set  (key_hit),
    .rst_cause_req     (),
    .rst_cause_req_set (rst_req),
    .rst_cause_dbg     (),
    .rst_cause_dbg_set (dbg_rst_req),
    .sysrst_key        (sysrst_key),
    .sysrst_wr         (sysrst_wr),
    .rst_hold_dom      (rst_hold),
    .rst_hold_wr       (hold_wr),
    .rst_status_done   (rst_done),
    .rst_status_dom    (dom_up),
    .clkdiv_div        (clkdiv),
    .scratch_value     (),
    .hart_hold_hart    (hart_hold),
    .hart_hold_wr      (hart_hold_wr),
    .hart_status_run   (hart_run),
    .boot_lo_addr      (boot_lo),
    .boot_hi_addr      (boot_hi)
  );

  // ---- system reset requests: held for HOLD cycles (retriggerable)
  assign key_hit = sysrst_wr && (sysrst_key == KEY) && (&PSTRB);
  assign sys_go  = key_hit || rst_req || dbg_rst_req;

  basechili_pulse_stretch #(.CYCLES(HOLD)) u_sys_rst (
    .clk   (clk),
    .rst_n (rst_n),
    .in    (sys_go),
    .out   (sys_rst_q)
  );

  // ---- domain resets
  assign sys_rst_n = por_n && ext_rst_n && !sys_rst_q;
  assign hold_clr   = sys_rst_q || ext_seen;
  assign hold_arm_d = !hold_clr && (hold_wr || hold_arm);

  basechili_dff #(.WIDTH(1)) u_hold_arm (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (hold_arm_d),
    .q     (hold_arm)
  );

  always_comb begin
    hold_dom[0] = hold_arm && rst_hold[0];
    for (int i = 1; i < N_DOM; i++)
      hold_dom[i] = hold_dom[i-1] || (hold_arm && rst_hold[i]);
  end

  basechili_reset_ctrl #(.N(N_DOM), .STEP(STEP)) u_rst (
    .clk         (clk),
    .rst_n_async (sys_rst_n),
    .test_en     (test_en),
    .sw_rst      (hold_dom),
    .rst_n_out   (rst_n_out),
    .done        (rst_done)
  );

  assign dom_up = 8'(rst_n_out);

  // ---- hart resets and boot addresses
  assign hart_arm_d  = !hold_clr && (hart_hold_wr || hart_arm);
  assign hart_hold_d = hart_arm ? hart_hold[N_HART-1:0] : HART_HOLD_RST[N_HART-1:0];

  basechili_dff #(.WIDTH(1 + N_HART), .RESET_VAL({1'b0, HART_HOLD_RST[N_HART-1:0]})) u_hart_hold (
    .clk   (clk),
    .rst_n (rst_n),
    .d     ({hart_arm_d, hart_hold_d}),
    .q     ({hart_arm, hart_hold_q})
  );

  for (genvar h = 0; h < N_HART; h++) begin : g_hart
    logic [63:0] boot;   // boot_hi / boot_lo of hart h
    assign hart_rst_n[h] = rst_n_out[N_DOM-1] && (test_en || !hart_hold_q[h]);
    assign boot          = {boot_hi[h*32 +: 32], boot_lo[h*32 +: 32]};
    assign boot_addr[h*64 +: 64] = (boot == '0) ? BOOT_ADDR : boot;
  end

  assign hart_run = 8'(hart_rst_n);

  // ---- clock dividers
  for (genvar i = 0; i < 2; i++) begin : g_div
    basechili_clock_div #(.W(16)) u_div (
      .clk     (clk),
      .rst_n   (rst_n),
      .div     (clkdiv[i*16 +: 16]),
      .clk_out (clk_div[i]),
      .tick    (clk_div_tick[i])
    );
  end

endmodule
