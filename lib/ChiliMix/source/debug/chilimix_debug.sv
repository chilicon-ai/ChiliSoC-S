// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_debug
//
// RISC-V external debug for one RV32 or RV64 hart (XLEN; debug spec 1.0): JTAG pins to the
// debugger (OpenOCD / GDB), an AHB subordinate for the hart and an AHB
// manager for system bus access.
//   u_dtm  chilimix_debug_dtm: JTAG TAP, dtmcs, dmi; DMI crossed to clk
//   u_dm   chilimix_debug_dm: the debug module (halt / resume, abstract
//          commands, program buffer, system bus access)
//   u_mem  basechili_ahb_sram: the DM's 4 KiB memory on AHB (the ROM, flags,
//          command words, program buffer, data) for the hart's instruction
//          and data buses; map it at address 0x0000_0000 (chilimix_debug_pkg)
//   u_sba  basechili_ahb_manager: system bus access, one transfer at a time
//          (8 / 16 / 32-bit, and 64-bit with SB_DATA_W 64), SB_ADDR_W-bit
//          addresses
// The DM memory port is 32 bits wide: a 64-bit hart reaches it through a
// bus downsizer.
// The hart: debug_req to chillu (Sdext) with DM_HALT_ADDR 0x800 and
// DM_EXCEPTION_ADDR 0x808; hart_unavail high while it is in reset; ndmreset
// to the SoC reset controller (resets everything but this unit).
//
// Timing    : see the units; the DM memory answers with no wait states.
// Reset     : rst_n is the debug domain's reset (power-on), not ndmreset or
//             the system reset; trst_n resets the TAP only.
// Debug     : no JTAG answer -> u_dtm (u_tap.ir, tdo_en); DMI errors ->
//             u_dtm.err; the hart does not halt -> debug_req, u_dm.halted
//             and the hart's fetches at 0x800 on HADDR; SBA -> u_dm.sb_state,
//             sba_HADDR / sba_HRESP.
// -----------------------------------------------------------------------------
module chilimix_debug #(
  parameter logic [31:0] IDCODE    = 32'h0000_0001,   // JTAG IDCODE, bit 0 = 1
  parameter int          IDLE      = 1,               // dtmcs.idle hint, 0 .. 7
  parameter int          XLEN      = 32,              // hart register width: 32 or 64
  parameter int          SB_ADDR_W = 32,              // system bus address bits (32 .. 64)
  parameter int          SB_DATA_W = 32               // system bus data bits: 32 or 64
) (
  // JTAG
  input  logic        tck,
  input  logic        trst_n,         // async, active-low (tie high if absent)
  input  logic        tms,
  input  logic        tdi,
  output logic        tdo,
  output logic        tdo_en,
  // debug domain
  input  logic        clk,
  input  logic        rst_n,          // async, active-low (power-on, not ndmreset)
  // hart and SoC
  output logic        debug_req,      // halt request to the hart
  input  logic        hart_unavail,   // the hart is in reset
  output logic        ndmreset,       // reset the system except debug
  // AHB subordinate: the DM memory (4 KiB, at address 0)
  input  logic        HSEL,
  input  logic [31:0] HADDR,
  input  logic [1:0]  HTRANS,
  input  logic        HWRITE,
  input  logic [2:0]  HSIZE,
  input  logic [31:0] HWDATA,
  input  logic        HREADY,
  output logic        HREADYOUT,
  output logic        HRESP,
  output logic [31:0] HRDATA,
  // AHB manager: system bus access
  output logic [SB_ADDR_W-1:0] sba_HADDR,
  output logic [1:0]  sba_HTRANS,
  output logic        sba_HWRITE,
  output logic [2:0]  sba_HSIZE,
  output logic [2:0]  sba_HBURST,
  output logic [3:0]  sba_HPROT,
  output logic        sba_HMASTLOCK,
  output logic [SB_DATA_W-1:0] sba_HWDATA,
  input  logic        sba_HREADY,
  input  logic        sba_HRESP,
  input  logic [SB_DATA_W-1:0] sba_HRDATA
);

  logic        dmi_req_valid;
  logic        dmi_req_accept;
  logic [6:0]  dmi_req_addr;
  logic [31:0] dmi_req_data;
  logic [1:0]  dmi_req_op;
  logic        dmi_rsp_valid;
  logic        dmi_rsp_accept;
  logic [31:0] dmi_rsp_data;
  logic [1:0]  dmi_rsp_op;
  logic        mem_req;
  logic        mem_we;
  logic [9:0]  mem_addr;
  logic [31:0] mem_wdata;
  logic [3:0]  mem_be;
  logic [31:0] mem_rdata;
  logic        sb_req_valid;
  logic        sb_req_accept;
  logic        sb_req_write;
  logic [SB_ADDR_W-1:0] sb_req_addr;
  logic [SB_DATA_W-1:0] sb_req_wdata;
  logic [2:0]  sb_req_size;
  logic        sb_ack_valid;
  logic        sb_ack_accept;
  logic        sb_ack_error;
  logic [SB_DATA_W-1:0] sb_ack_rdata;

  chilimix_debug_dtm #(.ABITS(7), .IDCODE(IDCODE), .IDLE(IDLE)) u_dtm (
    .tck            (tck),
    .trst_n         (trst_n),
    .tms            (tms),
    .tdi            (tdi),
    .tdo            (tdo),
    .tdo_en         (tdo_en),
    .clk            (clk),
    .rst_n          (rst_n),
    .dmi_req_valid  (dmi_req_valid),
    .dmi_req_accept (dmi_req_accept),
    .dmi_req_addr   (dmi_req_addr),
    .dmi_req_data   (dmi_req_data),
    .dmi_req_op     (dmi_req_op),
    .dmi_rsp_valid  (dmi_rsp_valid),
    .dmi_rsp_accept (dmi_rsp_accept),
    .dmi_rsp_data   (dmi_rsp_data),
    .dmi_rsp_op     (dmi_rsp_op)
  );

  chilimix_debug_dm #(.XLEN(XLEN), .SB_ADDR_W(SB_ADDR_W), .SB_DATA_W(SB_DATA_W)) u_dm (
    .clk            (clk),
    .rst_n          (rst_n),
    .dmi_req_valid  (dmi_req_valid),
    .dmi_req_accept (dmi_req_accept),
    .dmi_req_addr   (dmi_req_addr),
    .dmi_req_data   (dmi_req_data),
    .dmi_req_op     (dmi_req_op),
    .dmi_rsp_valid  (dmi_rsp_valid),
    .dmi_rsp_accept (dmi_rsp_accept),
    .dmi_rsp_data   (dmi_rsp_data),
    .dmi_rsp_op     (dmi_rsp_op),
    .debug_req      (debug_req),
    .hart_unavail   (hart_unavail),
    .ndmreset       (ndmreset),
    .mem_req        (mem_req),
    .mem_we         (mem_we),
    .mem_addr       (mem_addr),
    .mem_wdata      (mem_wdata),
    .mem_be         (mem_be),
    .mem_rdata      (mem_rdata),
    .sb_req_valid   (sb_req_valid),
    .sb_req_accept  (sb_req_accept),
    .sb_req_write   (sb_req_write),
    .sb_req_addr    (sb_req_addr),
    .sb_req_wdata   (sb_req_wdata),
    .sb_req_size    (sb_req_size),
    .sb_ack_valid   (sb_ack_valid),
    .sb_ack_accept  (sb_ack_accept),
    .sb_ack_error   (sb_ack_error),
    .sb_ack_rdata   (sb_ack_rdata)
  );

  basechili_ahb_sram #(.ADDR_W(32), .DATA_W(32), .MEM_AW(10)) u_mem (
    .clk       (clk),
    .rst_n     (rst_n),
    .HSEL      (HSEL),
    .HADDR     (HADDR),
    .HTRANS    (HTRANS),
    .HWRITE    (HWRITE),
    .HSIZE     (HSIZE),
    .HWDATA    (HWDATA),
    .HREADY    (HREADY),
    .HREADYOUT (HREADYOUT),
    .HRESP     (HRESP),
    .HRDATA    (HRDATA),
    .mem_req   (mem_req),
    .mem_we    (mem_we),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_be    (mem_be),
    .mem_rdata (mem_rdata)
  );

  basechili_ahb_manager #(.HADDR_W(SB_ADDR_W), .HDATA_W(SB_DATA_W)) u_sba (
    .clk        (clk),
    .rst_n      (rst_n),
    .req_valid  (sb_req_valid),
    .req_write  (sb_req_write),
    .req_addr   (sb_req_addr),
    .req_wdata  (sb_req_wdata),
    .req_size   (sb_req_size),
    .req_accept (sb_req_accept),
    .ack_valid  (sb_ack_valid),
    .ack_error  (sb_ack_error),
    .ack_rdata  (sb_ack_rdata),
    .ack_accept (sb_ack_accept),
    .HADDR      (sba_HADDR),
    .HTRANS     (sba_HTRANS),
    .HWRITE     (sba_HWRITE),
    .HSIZE      (sba_HSIZE),
    .HBURST     (sba_HBURST),
    .HPROT      (sba_HPROT),
    .HMASTLOCK  (sba_HMASTLOCK),
    .HWDATA     (sba_HWDATA),
    .HREADY     (sba_HREADY),
    .HRESP      (sba_HRESP),
    .HRDATA     (sba_HRDATA)
  );

endmodule
