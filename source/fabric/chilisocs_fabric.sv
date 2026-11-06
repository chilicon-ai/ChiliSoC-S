// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S :: chilisocs_fabric
//
// AHB-Lite bus matrix of the SoC: the ChillU-S fetch port (I manager,
// read-only), its data port (D manager), the debug module's system bus
// access (SBA manager) and the DMA engine (DMA manager) to the debug module
// memory, ROM, SRAM0, the SPI0 flash window (XIP), SRAM1 and the APB bridge
// (memory map: chilisocs_pkg).
//
//   I           : DM, ROM, SRAM0, XIP                     else: ERROR (default sub)
//   D, SBA, DMA : DM, ROM, SRAM0, XIP, SRAM1, APB bridge  else: ERROR (default sub)
//
// D, SBA and DMA share one bus (b_*) through a 3:1 basechili_ahb_arbiter
// (manager 0 = D, 1 = SBA, 2 = DMA, round robin): the arbiter parks on its
// last owner, so the core sees no added latency unless the debugger or the
// DMA used the bus since its last access (one bus cycle per owner change).
// DM, ROM, SRAM0 and XIP are reached by I and that bus, each through a 2:1
// arbiter layer (manager 0 = I, 1 = the D bus, round robin). SRAM1 and the
// APB bridge sit on the D bus alone
// (b_* is an output for them). Each manager has its own decoder
// (basechili_ahb_decoder), default subordinate and response mux
// (basechili_ahb_mux), so fetches and data accesses to different
// subordinates run in parallel with no added latency; only an I / D clash on
// ROM, SRAM0 or XIP waits (one bus cycle per owner change).
//
// An arbiter manager port has no HSEL / HREADY: the transfer a manager shows
// it is gated to IDLE unless the decoder selects that layer and the
// manager's bus HREADY is high (the address phase really happens), e.g.
// b_trans_m[S_SRAM0] = b_sel[R_SRAM0] && b_HREADY ? b_HTRANS : IDLE; the
// D bus arbiter's manager ports are gated the same way by their HREADY.
//
// A shared layer has one subordinate: its HSEL is 1 and its HREADY is its
// own HREADYOUT (the layer bus has no other subordinate).
//
// Timing    : combinational paths only (decoders, gating, muxes, the
//             arbiters' held transfers); the registered state is in the
//             muxes (data-phase select), the arbiters and the subordinates.
//             No added wait state for a single manager.
// Invariants: i_sel / b_sel are zero or one-hot; a gated transfer is never
//             NONSEQ while its manager's HREADY is low; the I manager never
//             writes (i_HWRITE low on NONSEQ).
// Debug     : manager stuck (HREADY low) -> its mux data-phase select
//             (u_i_mux / u_b_mux dsel), then the arbiters (u_db_arb and
//             g_layer[s].u_arb pend, HMASTER); wrong data -> the decoder sel
//             of the address phase and the layer's HMASTER; debugger SBA
//             stuck -> u_db_arb pend[1], b_HTRANS; DMA stuck -> u_db_arb
//             pend[2], dma_HREADY; XIP fetch slow -> xip_HREADYOUT (the
//             flash read of a cache line).
// -----------------------------------------------------------------------------
module chilisocs_fabric
  import basechili_ahb_pkg::*;
  import chilisocs_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,          // async, active-low
  // I manager (fetch)
  input  logic [31:0] i_HADDR,
  input  logic [1:0]  i_HTRANS,
  input  logic        i_HWRITE,
  input  logic [2:0]  i_HSIZE,
  input  logic [3:0]  i_HPROT,
  output logic        i_HREADY,
  output logic        i_HRESP,
  output logic [31:0] i_HRDATA,
  // D manager (loads / stores)
  input  logic [31:0] d_HADDR,
  input  logic [1:0]  d_HTRANS,
  input  logic        d_HWRITE,
  input  logic [2:0]  d_HSIZE,
  input  logic [31:0] d_HWDATA,
  input  logic [3:0]  d_HPROT,
  output logic        d_HREADY,
  output logic        d_HRESP,
  output logic [31:0] d_HRDATA,
  // SBA manager (debug module system bus access)
  input  logic [31:0] sba_HADDR,
  input  logic [1:0]  sba_HTRANS,
  input  logic        sba_HWRITE,
  input  logic [2:0]  sba_HSIZE,
  input  logic [2:0]  sba_HBURST,
  input  logic [3:0]  sba_HPROT,
  input  logic        sba_HMASTLOCK,
  input  logic [31:0] sba_HWDATA,
  output logic        sba_HREADY,
  output logic        sba_HRESP,
  output logic [31:0] sba_HRDATA,
  // DMA manager (chilimix_dma)
  input  logic [31:0] dma_HADDR,
  input  logic [1:0]  dma_HTRANS,
  input  logic        dma_HWRITE,
  input  logic [2:0]  dma_HSIZE,
  input  logic [2:0]  dma_HBURST,
  input  logic [3:0]  dma_HPROT,
  input  logic        dma_HMASTLOCK,
  input  logic [31:0] dma_HWDATA,
  output logic        dma_HREADY,
  output logic        dma_HRESP,
  output logic [31:0] dma_HRDATA,
  // the D bus (D / SBA / DMA), for the D-only subordinates
  output logic [31:0] b_HADDR,
  output logic [1:0]  b_HTRANS,
  output logic        b_HWRITE,
  output logic [2:0]  b_HSIZE,
  output logic [3:0]  b_HPROT,
  output logic [31:0] b_HWDATA,
  // debug module memory (I and the D bus)
  output logic        dm_HSEL,
  output logic [31:0] dm_HADDR,
  output logic [1:0]  dm_HTRANS,
  output logic        dm_HWRITE,
  output logic [2:0]  dm_HSIZE,
  output logic [31:0] dm_HWDATA,
  output logic        dm_HREADY,
  input  logic        dm_HREADYOUT,
  input  logic        dm_HRESP,
  input  logic [31:0] dm_HRDATA,
  // ROM (I and D)
  output logic        rom_HSEL,
  output logic [31:0] rom_HADDR,
  output logic [1:0]  rom_HTRANS,
  output logic        rom_HWRITE,
  output logic [2:0]  rom_HSIZE,
  output logic [31:0] rom_HWDATA,
  output logic        rom_HREADY,
  input  logic        rom_HREADYOUT,
  input  logic        rom_HRESP,
  input  logic [31:0] rom_HRDATA,
  // SRAM0 (I and D)
  output logic        sram0_HSEL,
  output logic [31:0] sram0_HADDR,
  output logic [1:0]  sram0_HTRANS,
  output logic        sram0_HWRITE,
  output logic [2:0]  sram0_HSIZE,
  output logic [31:0] sram0_HWDATA,
  output logic        sram0_HREADY,
  input  logic        sram0_HREADYOUT,
  input  logic        sram0_HRESP,
  input  logic [31:0] sram0_HRDATA,
  // SPI0 flash window (I and D, read-only)
  output logic        xip_HSEL,
  output logic [31:0] xip_HADDR,
  output logic [1:0]  xip_HTRANS,
  output logic        xip_HWRITE,
  output logic [2:0]  xip_HSIZE,
  output logic [31:0] xip_HWDATA,
  output logic        xip_HREADY,
  input  logic        xip_HREADYOUT,
  input  logic        xip_HRESP,
  input  logic [31:0] xip_HRDATA,
  // SRAM1 (D bus only)
  output logic        sram1_HSEL,
  output logic        sram1_HREADY,
  input  logic        sram1_HREADYOUT,
  input  logic        sram1_HRESP,
  input  logic [31:0] sram1_HRDATA,
  // APB bridge (D bus only)
  output logic        apb_HSEL,
  output logic        apb_HREADY,
  input  logic        apb_HREADYOUT,
  input  logic        apb_HRESP,
  input  logic [31:0] apb_HRDATA
);

  // decoder regions (I: ROM, SRAM0, DM, XIP; the shared layers come first,
  // at their layer index)
  localparam int R_ROM   = 0;
  localparam int R_SRAM0 = 1;
  localparam int R_DM    = 2;
  localparam int R_XIP   = 3;
  localparam int R_SRAM1 = 4;
  localparam int R_APB0  = 5;   // APB windows: R_APB0 .. R_APB0 + N_APBW - 1
  localparam int N_DREG  = 9;
  localparam logic [N_DREG*32-1:0] D_BASE = {APBW3_BASE, APBW2_BASE, APBW1_BASE, APBW0_BASE,
                                             SRAM1_BASE, XIP_BASE, DM_BASE, SRAM0_BASE, ROM_BASE};
  localparam logic [N_DREG*32-1:0] D_MASK = {APBW3_MASK, APBW2_MASK, APBW1_MASK, APBW0_MASK,
                                             SRAM1_MASK, XIP_MASK, DM_MASK, SRAM0_MASK, ROM_MASK};
  localparam logic [4*32-1:0]      I_BASE = {XIP_BASE, DM_BASE, SRAM0_BASE, ROM_BASE};
  localparam logic [4*32-1:0]      I_MASK = {XIP_MASK, DM_MASK, SRAM0_MASK, ROM_MASK};

  // shared layers (index s) and the response mux inputs of each manager
  localparam int S_ROM   = 0;
  localparam int S_SRAM0 = 1;
  localparam int S_DM    = 2;
  localparam int S_XIP   = 3;
  localparam int N_SH    = 4;
  localparam int N_IMUX  = 5;   // I mux: the shared layers, default
  localparam int N_BMUX  = 7;   // D bus mux: the shared layers, SRAM1, APB, default

  // ---- D bus arbiter: one bus (b_*) for the core's data port, the debugger
  // and the DMA engine
  logic        b_HREADY;             // the bus HREADY (D bus response mux)
  logic        b_HRESP;
  logic [31:0] b_HRDATA;
  logic [5:0]  db_trans_m;           // {DMA, SBA, D} transfers, gated by their HREADY
  logic [2:0]  db_ready_m;           // {DMA, SBA, D} HREADY_m
  logic [2:0]  db_resp_m;
  logic [95:0] db_haddr;             // {DMA, SBA, D}
  logic [2:0]  db_hwrite;
  logic [8:0]  db_hsize;
  logic [8:0]  db_hburst;
  logic [11:0] db_hprot;
  logic [2:0]  db_hmastlock;
  logic [95:0] db_hwdata;
  logic [1:0]  d_trans_g;            // D transfer while its HREADY is high
  logic [1:0]  sba_trans_g;          // SBA transfer while its HREADY is high
  logic [1:0]  dma_trans_g;          // DMA transfer while its HREADY is high

  assign d_trans_g    = d_HREADY ? d_HTRANS : HTRANS_IDLE;
  assign sba_trans_g  = sba_HREADY ? sba_HTRANS : HTRANS_IDLE;
  assign dma_trans_g  = dma_HREADY ? dma_HTRANS : HTRANS_IDLE;
  assign db_trans_m   = {dma_trans_g, sba_trans_g, d_trans_g};
  assign db_haddr     = {dma_HADDR, sba_HADDR, d_HADDR};
  assign db_hwrite    = {dma_HWRITE, sba_HWRITE, d_HWRITE};
  assign db_hsize     = {dma_HSIZE, sba_HSIZE, d_HSIZE};
  assign db_hburst    = {dma_HBURST, sba_HBURST, HBURST_SINGLE};
  assign db_hprot     = {dma_HPROT, sba_HPROT, d_HPROT};
  assign db_hmastlock = {dma_HMASTLOCK, sba_HMASTLOCK, 1'b0};
  assign db_hwdata    = {dma_HWDATA, sba_HWDATA, d_HWDATA};
  assign d_HREADY     = db_ready_m[0];
  assign d_HRESP      = db_resp_m[0];
  assign d_HRDATA     = b_HRDATA;
  assign sba_HREADY   = db_ready_m[1];
  assign sba_HRESP    = db_resp_m[1];
  assign sba_HRDATA   = b_HRDATA;
  assign dma_HREADY   = db_ready_m[2];
  assign dma_HRESP    = db_resp_m[2];
  assign dma_HRDATA   = b_HRDATA;

  basechili_ahb_arbiter #(
    .N      (3),
    .ADDR_W (32),
    .DATA_W (32)
  ) u_db_arb (
    .clk         (clk),
    .rst_n       (rst_n),
    .HADDR_m     (db_haddr),
    .HTRANS_m    (db_trans_m),
    .HWRITE_m    (db_hwrite),
    .HSIZE_m     (db_hsize),
    .HBURST_m    (db_hburst),
    .HPROT_m     (db_hprot),
    .HMASTLOCK_m (db_hmastlock),
    .HWDATA_m    (db_hwdata),
    .HREADY_m    (db_ready_m),
    .HRESP_m     (db_resp_m),
    .HADDR       (b_HADDR),
    .HTRANS      (b_HTRANS),
    .HWRITE      (b_HWRITE),
    .HSIZE       (b_HSIZE),
    .HBURST      (),
    .HPROT       (b_HPROT),
    .HMASTLOCK   (),
    .HWDATA      (b_HWDATA),
    .HMASTER     (),
    .HREADY      (b_HREADY),
    .HRESP       (b_HRESP)
  );

  // ---- decoders
  logic [N_SH-1:0]   i_sel;          // I address phase: ROM, SRAM0, DM, XIP
  logic              i_sel_def;      // I address in no region
  logic [N_DREG-1:0] b_sel;          // D bus address phase regions
  logic              b_sel_def;      // D bus address in no region
  logic              b_sel_apb;      // D bus address in an APB window

  basechili_ahb_decoder #(
    .ADDR_W (32),
    .N      (N_SH),
    .BASE   (I_BASE),
    .MASK   (I_MASK)
  ) u_i_dec (
    .addr        (i_HADDR),
    .sel         (i_sel),
    .sel_default (i_sel_def)
  );

  basechili_ahb_decoder #(
    .ADDR_W (32),
    .N      (N_DREG),
    .BASE   (D_BASE),
    .MASK   (D_MASK)
  ) u_b_dec (
    .addr        (b_HADDR),
    .sel         (b_sel),
    .sel_default (b_sel_def)
  );

  assign b_sel_apb = |b_sel[R_APB0 +: N_APBW];

  // ---- shared layers: arbiter manager ports (I = 0, D bus = 1)
  logic [N_SH*2-1:0]  i_trans_m;     // gated I transfer per layer
  logic [N_SH*2-1:0]  b_trans_m;     // gated D bus transfer per layer
  logic [N_SH-1:0]    i_ready_m;     // layer HREADY_m of I
  logic [N_SH-1:0]    i_resp_m;
  logic [N_SH-1:0]    b_ready_m;     // layer HREADY_m of D bus
  logic [N_SH-1:0]    b_resp_m;
  logic [N_SH*32-1:0] sh_HADDR;      // layer buses
  logic [N_SH*2-1:0]  sh_HTRANS;
  logic [N_SH-1:0]    sh_HWRITE;
  logic [N_SH*3-1:0]  sh_HSIZE;
  logic [N_SH*32-1:0] sh_HWDATA;
  logic [N_SH-1:0]    sh_HREADY;     // the layer subordinate's HREADYOUT
  logic [N_SH-1:0]    sh_HRESP;
  logic [N_SH*32-1:0] sh_HRDATA;

  always_comb begin
    for (int s = 0; s < N_SH; s++) begin
      i_trans_m[s*2 +: 2] = (i_sel[s] && i_HREADY) ? i_HTRANS : HTRANS_IDLE;
      b_trans_m[s*2 +: 2] = (b_sel[s] && b_HREADY) ? b_HTRANS : HTRANS_IDLE;
    end
  end

  // manager port inputs of the arbiters, the same for every layer
  logic [63:0] arb_haddr;            // {D bus, I}
  logic [1:0]  arb_hwrite;
  logic [5:0]  arb_hsize;
  logic [5:0]  arb_hburst;           // SINGLE
  logic [7:0]  arb_hprot;
  logic [1:0]  arb_hmastlock;        // never locked
  logic [63:0] arb_hwdata;           // the I manager never writes

  assign arb_haddr     = {b_HADDR, i_HADDR};
  assign arb_hwrite    = {b_HWRITE, i_HWRITE};
  assign arb_hsize     = {b_HSIZE, i_HSIZE};
  assign arb_hburst    = {HBURST_SINGLE, HBURST_SINGLE};
  assign arb_hprot     = {b_HPROT, i_HPROT};
  assign arb_hmastlock = 2'b00;
  assign arb_hwdata    = {b_HWDATA, 32'h0};

  for (genvar s = 0; s < N_SH; s++) begin : g_layer
    logic [3:0] trans_m;             // {D bus, I} transfers to this layer
    logic [1:0] ready_m;             // {D bus, I} HREADY_m
    logic [1:0] resp_m;              // {D bus, I} HRESP_m

    assign trans_m = {b_trans_m[s*2 +: 2], i_trans_m[s*2 +: 2]};
    assign i_ready_m[s] = ready_m[0];
    assign b_ready_m[s] = ready_m[1];
    assign i_resp_m[s]  = resp_m[0];
    assign b_resp_m[s]  = resp_m[1];

    basechili_ahb_arbiter #(
      .N      (2),
      .ADDR_W (32),
      .DATA_W (32)
    ) u_arb (
      .clk         (clk),
      .rst_n       (rst_n),
      .HADDR_m     (arb_haddr),
      .HTRANS_m    (trans_m),
      .HWRITE_m    (arb_hwrite),
      .HSIZE_m     (arb_hsize),
      .HBURST_m    (arb_hburst),
      .HPROT_m     (arb_hprot),
      .HMASTLOCK_m (arb_hmastlock),
      .HWDATA_m    (arb_hwdata),
      .HREADY_m    (ready_m),
      .HRESP_m     (resp_m),
      .HADDR       (sh_HADDR[s*32 +: 32]),
      .HTRANS      (sh_HTRANS[s*2 +: 2]),
      .HWRITE      (sh_HWRITE[s]),
      .HSIZE       (sh_HSIZE[s*3 +: 3]),
      .HBURST      (),
      .HPROT       (),
      .HMASTLOCK   (),
      .HWDATA      (sh_HWDATA[s*32 +: 32]),
      .HMASTER     (),
      .HREADY      (sh_HREADY[s]),
      .HRESP       (sh_HRESP[s])
    );
  end

  // shared layer subordinates: always selected, HREADY = own HREADYOUT
  assign rom_HSEL      = 1'b1;
  assign rom_HADDR     = sh_HADDR[S_ROM*32 +: 32];
  assign rom_HTRANS    = sh_HTRANS[S_ROM*2 +: 2];
  assign rom_HWRITE    = sh_HWRITE[S_ROM];
  assign rom_HSIZE     = sh_HSIZE[S_ROM*3 +: 3];
  assign rom_HWDATA    = sh_HWDATA[S_ROM*32 +: 32];
  assign rom_HREADY    = rom_HREADYOUT;
  assign sram0_HSEL    = 1'b1;
  assign sram0_HADDR   = sh_HADDR[S_SRAM0*32 +: 32];
  assign sram0_HTRANS  = sh_HTRANS[S_SRAM0*2 +: 2];
  assign sram0_HWRITE  = sh_HWRITE[S_SRAM0];
  assign sram0_HSIZE   = sh_HSIZE[S_SRAM0*3 +: 3];
  assign sram0_HWDATA  = sh_HWDATA[S_SRAM0*32 +: 32];
  assign sram0_HREADY  = sram0_HREADYOUT;
  assign dm_HSEL       = 1'b1;
  assign dm_HADDR      = sh_HADDR[S_DM*32 +: 32];
  assign dm_HTRANS     = sh_HTRANS[S_DM*2 +: 2];
  assign dm_HWRITE     = sh_HWRITE[S_DM];
  assign dm_HSIZE      = sh_HSIZE[S_DM*3 +: 3];
  assign dm_HWDATA     = sh_HWDATA[S_DM*32 +: 32];
  assign dm_HREADY     = dm_HREADYOUT;
  assign xip_HSEL      = 1'b1;
  assign xip_HADDR     = sh_HADDR[S_XIP*32 +: 32];
  assign xip_HTRANS    = sh_HTRANS[S_XIP*2 +: 2];
  assign xip_HWRITE    = sh_HWRITE[S_XIP];
  assign xip_HSIZE     = sh_HSIZE[S_XIP*3 +: 3];
  assign xip_HWDATA    = sh_HWDATA[S_XIP*32 +: 32];
  assign xip_HREADY    = xip_HREADYOUT;
  assign sh_HREADY     = {xip_HREADYOUT, dm_HREADYOUT, sram0_HREADYOUT, rom_HREADYOUT};
  assign sh_HRESP      = {xip_HRESP, dm_HRESP, sram0_HRESP, rom_HRESP};
  assign sh_HRDATA     = {xip_HRDATA, dm_HRDATA, sram0_HRDATA, rom_HRDATA};

  // ---- D-bus-only subordinates
  assign sram1_HSEL   = b_sel[R_SRAM1];
  assign sram1_HREADY = b_HREADY;
  assign apb_HSEL     = b_sel_apb;
  assign apb_HREADY   = b_HREADY;

  // ---- I manager: default subordinate and response mux
  logic              i_def_ready;    // I default subordinate
  logic              i_def_resp;
  logic [31:0]       i_def_rdata;
  logic [N_IMUX-1:0] i_mux_sel;      // I address-phase select per mux input
  logic [N_IMUX-1:0] i_mux_ready;
  logic [N_IMUX-1:0] i_mux_resp;
  logic [N_IMUX*32-1:0] i_mux_rdata;

  basechili_ahb_default_sub #(.DATA_W(32)) u_i_def (
    .clk       (clk),
    .rst_n     (rst_n),
    .HSEL      (i_sel_def),
    .HTRANS    (i_HTRANS),
    .HREADY    (i_HREADY),
    .HREADYOUT (i_def_ready),
    .HRESP     (i_def_resp),
    .HRDATA    (i_def_rdata)
  );

  assign i_mux_sel   = {i_sel_def, i_sel};
  assign i_mux_ready = {i_def_ready, i_ready_m};
  assign i_mux_resp  = {i_def_resp, i_resp_m};
  assign i_mux_rdata = {i_def_rdata, sh_HRDATA};

  basechili_ahb_mux #(.N(N_IMUX), .DATA_W(32)) u_i_mux (
    .clk         (clk),
    .rst_n       (rst_n),
    .sel         (i_mux_sel),
    .HTRANS      (i_HTRANS),
    .HREADYOUT_s (i_mux_ready),
    .HRESP_s     (i_mux_resp),
    .HRDATA_s    (i_mux_rdata),
    .HREADY      (i_HREADY),
    .HRESP       (i_HRESP),
    .HRDATA      (i_HRDATA)
  );

  // ---- D bus: default subordinate and response mux
  logic              b_def_ready;    // D bus default subordinate
  logic              b_def_resp;
  logic [31:0]       b_def_rdata;
  logic [N_BMUX-1:0] b_mux_sel;      // D bus address-phase select per mux input
  logic [N_BMUX-1:0] b_mux_ready;
  logic [N_BMUX-1:0] b_mux_resp;
  logic [N_BMUX*32-1:0] b_mux_rdata;

  basechili_ahb_default_sub #(.DATA_W(32)) u_b_def (
    .clk       (clk),
    .rst_n     (rst_n),
    .HSEL      (b_sel_def),
    .HTRANS    (b_HTRANS),
    .HREADY    (b_HREADY),
    .HREADYOUT (b_def_ready),
    .HRESP     (b_def_resp),
    .HRDATA    (b_def_rdata)
  );

  assign b_mux_sel   = {b_sel_def, b_sel_apb, b_sel[R_SRAM1], b_sel[R_XIP], b_sel[R_DM], b_sel[R_SRAM0],
                        b_sel[R_ROM]};
  assign b_mux_ready = {b_def_ready, apb_HREADYOUT, sram1_HREADYOUT, b_ready_m};
  assign b_mux_resp  = {b_def_resp, apb_HRESP, sram1_HRESP, b_resp_m};
  assign b_mux_rdata = {b_def_rdata, apb_HRDATA, sram1_HRDATA, sh_HRDATA};

  basechili_ahb_mux #(.N(N_BMUX), .DATA_W(32)) u_b_mux (
    .clk         (clk),
    .rst_n       (rst_n),
    .sel         (b_mux_sel),
    .HTRANS      (b_HTRANS),
    .HREADYOUT_s (b_mux_ready),
    .HRESP_s     (b_mux_resp),
    .HRDATA_s    (b_mux_rdata),
    .HREADY      (b_HREADY),
    .HRESP       (b_HRESP),
    .HRDATA      (b_HRDATA)
  );

endmodule
