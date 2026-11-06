// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChillU-S :: chillus_ahb
//
// ChillU-S with AHB-Lite manager ports, for SoC integration: chillus_core
// plus chillus_imss_ahb on the fetch port (I bus, read-only) and
// chillus_dmss_ahb on the data port (D bus). Neither bridge adds latency, so
// a zero-wait subordinate gives the same cycle counts as the core's native
// MSS ports. boot_addr / hart_id / fetch_enable, interrupts, mtime,
// debug_req / debug_mode, core_sleep, test_en
// and the RVFI trace pass straight through. The bridges hold no transfer of
// their own past the core's view (a store waits in the core's wb until its
// data phase completes), so WFI sleeps only with both buses idle.
// Connectivity only: no logic of its own.
//
// Timing    : as the bridges: AHB address-phase outputs are combinational
//             from the core's request ports, HWDATA (D bus) is registered.
// Debug     : fetch stalls -> u_ibus.rd_pending, i_HREADY; load / store
//             problems -> u_dbus (HWDATA at u_dbus.u_wdata, u_dbus.pending),
//             d_HREADY / d_HRESP;
//             core internals under u_core.
// -----------------------------------------------------------------------------
module chillus_ahb
  import chillus_dec_pkg::*;
#(
  parameter bit              RF_LATCH    = 1'b1,  // register file storage: latches (0: flops)
  parameter bit              DEBUG       = 1'b1,  // Sdext debug mode (0: none)
  parameter int              NUM_TRIGGERS = 0,    // Sdtrig execute triggers (0: none)
  parameter int              PMP_REGIONS  = 4,    // PMP entries, 0..4 (0: no PMP)
  parameter int              ICACHE_KB    = 0,    // instruction cache KiB: 0 (none), 2 or 4
  parameter logic [XLEN-1:0] ICACHE_BASE  = '0,   // cacheable fetches: (addr & ICACHE_MASK) == ICACHE_BASE
  parameter logic [XLEN-1:0] ICACHE_MASK  = '0,   // 0: every address cacheable
  parameter logic [XLEN-1:0] DM_HALT_ADDR      = 32'h1A11_0800,   // Debug Module halt address
  parameter logic [XLEN-1:0] DM_EXCEPTION_ADDR = 32'h1A11_0808    // Debug Module exception address
) (
  input  logic              clk,
  input  logic              rst_n,          // async, active-low
  input  logic              test_en,        // scan / test: open the clock gates; 0 in functional mode
  // boot
  input  logic [XLEN-1:0]   boot_addr,      // first instruction and reset mtvec (static)
  input  logic [XLEN-1:0]   hart_id,        // mhartid (static)
  input  logic              fetch_enable,   // start fetching (sticky); tie 1 to boot at once
  // I bus: AHB-Lite manager (instruction fetch)
  output logic [XLEN-1:0]   i_HADDR,
  output logic [1:0]        i_HTRANS,
  output logic              i_HWRITE,
  output logic [2:0]        i_HSIZE,
  output logic [31:0]       i_HWDATA,
  output logic [3:0]        i_HPROT,        // opcode fetch; [1] privileged (M-mode)
  input  logic              i_HREADY,
  input  logic              i_HRESP,
  input  logic [31:0]       i_HRDATA,
  // D bus: AHB-Lite manager (loads / stores)
  output logic [XLEN-1:0]   d_HADDR,
  output logic [1:0]        d_HTRANS,
  output logic              d_HWRITE,
  output logic [2:0]        d_HSIZE,
  output logic [XLEN-1:0]   d_HWDATA,
  output logic [3:0]        d_HPROT,        // data access; [1] privileged (M-mode, or MPRV)
  input  logic              d_HREADY,
  input  logic              d_HRESP,
  input  logic [XLEN-1:0]   d_HRDATA,
  // interrupts and timer (ACLINT / PLIC)
  input  logic              irq_software,   // msip
  input  logic              irq_timer,      // mtip
  input  logic              irq_external,   // PLIC context 0
  input  logic [14:0]       irq_fast,       // local interrupts (mcause 16 + i)
  input  logic              irq_nmi,        // non-maskable interrupt (mcause 31)
  input  logic [63:0]       mtime,          // for the time / timeh CSRs
  // debug and sleep
  input  logic              debug_req,      // halt request (Debug Module), also wakes from WFI; tie 0 if unused
  output logic              debug_mode,     // the hart is in debug mode (registered)
  output logic              core_sleep,     // the core sleeps in WFI (registered)
  // RVFI trace (simulation / formal; unconnected in silicon)
  output logic               rvfi_valid,
  output logic [63:0]        rvfi_order,
  output logic [31:0]        rvfi_insn,
  output logic               rvfi_trap,
  output logic               rvfi_halt,
  output logic               rvfi_intr,
  output logic [1:0]         rvfi_mode,
  output logic [1:0]         rvfi_ixl,
  output logic [4:0]         rvfi_rs1_addr,
  output logic [4:0]         rvfi_rs2_addr,
  output logic [XLEN-1:0]    rvfi_rs1_rdata,
  output logic [XLEN-1:0]    rvfi_rs2_rdata,
  output logic [4:0]         rvfi_rd_addr,
  output logic [XLEN-1:0]    rvfi_rd_wdata,
  output logic [XLEN-1:0]    rvfi_pc_rdata,
  output logic [XLEN-1:0]    rvfi_pc_wdata,
  output logic [XLEN-1:0]    rvfi_mem_addr,
  output logic [XLEN/8-1:0]  rvfi_mem_rmask,
  output logic [XLEN/8-1:0]  rvfi_mem_wmask,
  output logic [XLEN-1:0]    rvfi_mem_rdata,
  output logic [XLEN-1:0]    rvfi_mem_wdata
);

  logic              imss_req;
  logic              imss_gnt;
  logic [XLEN-1:0]   imss_addr;
  logic              imss_priv;
  logic              imss_rvalid;
  logic [31:0]       imss_rdata;
  logic              imss_err;
  logic              dmss_req;
  logic              dmss_gnt;
  logic              dmss_we;
  logic [XLEN/8-1:0] dmss_be;
  logic [XLEN-1:0]   dmss_addr;
  logic [XLEN-1:0]   dmss_wdata;
  logic              dmss_priv;
  logic              dmss_rvalid;
  logic [XLEN-1:0]   dmss_rdata;
  logic              dmss_err;

  chillus_core #(
    .RF_LATCH    (RF_LATCH),
    .DEBUG       (DEBUG),
    .NUM_TRIGGERS (NUM_TRIGGERS),
    .PMP_REGIONS  (PMP_REGIONS),
    .ICACHE_KB    (ICACHE_KB),
    .ICACHE_BASE  (ICACHE_BASE),
    .ICACHE_MASK  (ICACHE_MASK),
    .DM_HALT_ADDR      (DM_HALT_ADDR),
    .DM_EXCEPTION_ADDR (DM_EXCEPTION_ADDR)
  ) u_core (
    .clk             (clk),
    .rst_n           (rst_n),
    .test_en         (test_en),
    .boot_addr       (boot_addr),
    .hart_id         (hart_id),
    .fetch_enable    (fetch_enable),
    .imss_req        (imss_req),
    .imss_gnt        (imss_gnt),
    .imss_addr       (imss_addr),
    .imss_priv       (imss_priv),
    .imss_rvalid     (imss_rvalid),
    .imss_rdata      (imss_rdata),
    .imss_err        (imss_err),
    .dmss_req        (dmss_req),
    .dmss_gnt        (dmss_gnt),
    .dmss_we         (dmss_we),
    .dmss_be         (dmss_be),
    .dmss_addr       (dmss_addr),
    .dmss_wdata      (dmss_wdata),
    .dmss_priv       (dmss_priv),
    .dmss_rvalid     (dmss_rvalid),
    .dmss_rdata      (dmss_rdata),
    .dmss_err        (dmss_err),
    .irq_software    (irq_software),
    .irq_timer       (irq_timer),
    .irq_external    (irq_external),
    .irq_fast        (irq_fast),
    .irq_nmi         (irq_nmi),
    .mtime           (mtime),
    .debug_req       (debug_req),
    .debug_mode      (debug_mode),
    .core_sleep      (core_sleep),
    .rvfi_valid      (rvfi_valid),
    .rvfi_order      (rvfi_order),
    .rvfi_insn       (rvfi_insn),
    .rvfi_trap       (rvfi_trap),
    .rvfi_halt       (rvfi_halt),
    .rvfi_intr       (rvfi_intr),
    .rvfi_mode       (rvfi_mode),
    .rvfi_ixl        (rvfi_ixl),
    .rvfi_rs1_addr   (rvfi_rs1_addr),
    .rvfi_rs2_addr   (rvfi_rs2_addr),
    .rvfi_rs1_rdata  (rvfi_rs1_rdata),
    .rvfi_rs2_rdata  (rvfi_rs2_rdata),
    .rvfi_rd_addr    (rvfi_rd_addr),
    .rvfi_rd_wdata   (rvfi_rd_wdata),
    .rvfi_pc_rdata   (rvfi_pc_rdata),
    .rvfi_pc_wdata   (rvfi_pc_wdata),
    .rvfi_mem_addr   (rvfi_mem_addr),
    .rvfi_mem_rmask  (rvfi_mem_rmask),
    .rvfi_mem_wmask  (rvfi_mem_wmask),
    .rvfi_mem_rdata  (rvfi_mem_rdata),
    .rvfi_mem_wdata  (rvfi_mem_wdata)
  );

  chillus_imss_ahb #(.ADDR_W(XLEN)) u_ibus (
    .clk            (clk),
    .rst_n          (rst_n),
    .mss_req        (imss_req),
    .mss_gnt        (imss_gnt),
    .mss_addr       (imss_addr),
    .mss_priv       (imss_priv),
    .mss_rvalid     (imss_rvalid),
    .mss_rdata      (imss_rdata),
    .mss_err        (imss_err),
    .HADDR          (i_HADDR),
    .HTRANS         (i_HTRANS),
    .HWRITE         (i_HWRITE),
    .HSIZE          (i_HSIZE),
    .HWDATA         (i_HWDATA),
    .HPROT          (i_HPROT),
    .HREADY         (i_HREADY),
    .HRESP          (i_HRESP),
    .HRDATA         (i_HRDATA)
  );

  chillus_dmss_ahb #(.ADDR_W(XLEN), .DATA_W(XLEN)) u_dbus (
    .clk           (clk),
    .rst_n         (rst_n),
    .mss_req       (dmss_req),
    .mss_gnt       (dmss_gnt),
    .mss_we        (dmss_we),
    .mss_addr      (dmss_addr),
    .mss_be        (dmss_be),
    .mss_wdata     (dmss_wdata),
    .mss_priv      (dmss_priv),
    .mss_rvalid    (dmss_rvalid),
    .mss_rdata     (dmss_rdata),
    .mss_err       (dmss_err),
    .HADDR         (d_HADDR),
    .HTRANS        (d_HTRANS),
    .HWRITE        (d_HWRITE),
    .HSIZE         (d_HSIZE),
    .HWDATA        (d_HWDATA),
    .HPROT         (d_HPROT),
    .HREADY        (d_HREADY),
    .HRESP         (d_HRESP),
    .HRDATA        (d_HRDATA)
  );

endmodule
