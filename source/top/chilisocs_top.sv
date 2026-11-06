// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S :: chilisocs_top
//
// The ChillU-S microcontroller SoC: chillus_ahb (RV32IMC, M and U modes, debug
// mode, two triggers) on the chilisocs_fabric AHB-Lite matrix with a boot
// ROM, two SRAMs, the RISC-V debug unit (JTAG pins), the SPI0 flash window
// (XIP), a DMA engine (third manager of the D bus) and an APB bridge to the
// ChiliMix peripherals: ACLINT (mtime, mtimecmp, msip), PLIC (63 sources:
// UART0, one per GPIO pin and PWM comparator, the watchdog, SPI0, I2C0, two
// per DMA channel), ns16550a UART0, GPIO, timers (three PWMs and a
// watchdog), SPI0 (sifive,spi0 with the XIP read cache), I2C0 (OpenCores
// layout), DMA (sf-pdma layout, N_DMA_CH channels) and the SoC control unit
// (ID, reset sequencing and causes, clock dividers). Memory map and
// interrupt numbers: chilisocs_pkg.
//
//   resets : chilimix_socctl turns por_n / ext_rst_n / a software reset
//            (sysrst key) / a watchdog bite (rst_req, cause req) / the
//            debugger's ndmreset (dbg_rst_req, cause dbg) into two domain
//            resets released in order:
//            DOM_BUS (fabric, memories, peripherals), then DOM_CPU (ChillU-S
//            starts at ROM_BASE). socctl itself runs on por_n, and so does
//            the debug unit (rst_dbg_n: por_n synchronized), so a debugger
//            keeps its session across system resets.
//   mtime  : counts once per clk_div_tick[0] of socctl (clkdiv[0], reset
//            value 2: clk / 2); clk_div[1] is a pin.
//   timers : chilimix_timer, N_PWM PWMs (count clk) and the watchdog (counts
//            mtime ticks, like the FE310 AON watchdog on the RTC clock).
//            PWM k comparator j drives GPIO pin 4k + j as IO function 1
//            (pins below N_GPIO). The core's debug_mode halts every counter;
//            the watchdog's core_sleep is the core asleep or in reset.
//   core   : chillus_ahb (ChillU-S: three stages, req / gnt memory
//            ports, zero-latency AHB bridges), DEBUG = 1 with NUM_TRIGGERS
//            = 2, PMP_REGIONS = 4; boot_addr = ROM_BASE, hart_id = 0, fetch_enable tied 1;
//            ICACHE_KB (default 2) KiB instruction cache for fetches in the
//            XIP window only (ICACHE_BASE / MASK = XIP_BASE / MASK; ROM, SRAM
//            and the DM bypass it); 0 builds none.
//            RF_LATCH (default 1) keeps the register file in latches;
//            0 builds it from flops, for FPGAs (fpga/).
//            irq_fast and irq_nmi tied 0 (every source, the watchdog too,
//            goes through the PLIC); test_en from the pin.
//   debug  : chilimix_debug (JTAG DTM, debug module, system bus access):
//            debug_req to the core, halt / exception entries in the DM
//            memory at DM_BASE + 0x800 / 0x808 (I and D layer of the
//            fabric, behind a one-wait basechili_ahb_wait: the DM's address
//            decode and read mux start from a register, not from the
//            core's address adder), SBA as a third fabric manager sharing
//            the D bus,
//            hart_unavail while the CPU domain is in reset, ndmreset to
//            socctl dbg_rst_req.
//            core_sleep (WFI) is a pin; the core gates its own clock while asleep.
//   SPI0   : chilimix_spi, one chip select on dedicated pins (the FE310
//            QSPI0 pins), quad capable; its flash reads (fctrl.en, on at
//            reset, FE310 default instruction 0x03) serve the XIP window
//            for fetches and loads (an I and D layer of the fabric).
//   I2C0   : chilimix_i2c on dedicated open-drain pins (the pad drives 0
//            while *_oe is high).
//   DMA    : chilimix_dma, N_DMA_CH channels; it reaches everything the D
//            bus reaches (privileged data accesses, HPROT of
//            basechili_ahb_manager).
//   ROM    : basechili_ahb_sram with READ_ONLY = 1 on a basechili_sram_sp;
//            its contents come from the simulation testbench for now (no
//            init file, no ROM macro yet).
//   memories: each ROM / SRAM controller sits behind a basechili_ahb_wait;
//            MEM_WAIT = 0 (default) makes it wires, MEM_WAIT > 0 adds 1 ..
//            MEM_WAIT pseudo-random wait states per transfer (each memory
//            its own LFSR seed), so simulation stresses every manager with
//            bus stalls.
//
// Timing    : as the parts: zero-wait ROM / SRAM accesses (MEM_WAIT = 0) (an I / D clash
//             on ROM or SRAM0 costs a cycle), DM memory accesses (debug
//             mode only) one wait state, APB accesses 4 cycles
//             (basechili_ahb_to_apb); every pin output comes from a register
//             of its IP except the UART modem outputs (16550 MCR bits).
// Invariants: rst_cpu_n is low whenever rst_bus_n is low (domain order);
//             debug_req is low while rst_dbg_n is low;
//             while core_sleep is high both core buses are idle (IDLE
//             HTRANS on I and D); the cycle after wdog_rst_req is high,
//             rst_bus_n is low (a watchdog bite resets the system).
// Debug     : no boot -> u_socctl.rst_n_out, then u_cpu i_HADDR / i_HTRANS
//             (fetch at ROM_BASE) and u_fabric i_HREADY; hung load / store ->
//             u_fabric.u_d_mux dsel, u_apb.state (APB), u_apb_ic PSEL_s;
//             no interrupt -> plic_irq, u_plic eip, u_aclint mtip / msip, the core's
//             mip (u_cpu.u_core.u_csr); no wake from WFI -> core_sleep,
//             the mie / mip bits and u_cpu.u_core.u_ctrl; no watchdog
//             reset -> wdog_rst_req, u_timer.u_wdog (cfg_rsten, elapsed),
//             u_socctl sys_rst_q; no PWM on a pin -> pwm_out, u_gpio
//             iof_en / iof_sel; no JTAG answer -> u_debug.u_dtm, jtag_tdo_en;
//             hart does not halt -> debug_req, cpu_debug_mode, i_HADDR at
//             0x800; SBA stuck -> u_fabric.u_db_arb, sba_HTRANS / sba_HREADY;
//             XIP read stuck -> u_spi0.u_xip.state, u_spi0.u_phy.state, the
//             spi pins; DMA stuck -> u_dma.state, dma_HTRANS / dma_HREADY;
//             no I2C ACK -> i2c_sda_i at the ninth scl, u_i2c0.u_bit.state.
// -----------------------------------------------------------------------------
module chilisocs_top
  import chilisocs_pkg::*;
#(
  parameter logic [31:0] SOC_ID  = 32'h5C05_0700,  // socctl id register (0x5C05 = SoC-S, 0x0700 = 0.7)
  parameter int          ROM_AW  = 10,             // boot ROM word address bits (4 KiB)
  parameter int          SRAM_AW = 14,             // SRAM0 / SRAM1 word address bits (64 KiB each)
  parameter int          N_GPIO  = 16,             // GPIO pins, 1 .. 16 (PLIC sources 2 .. N_GPIO + 1)
  parameter int          MEM_WAIT = 0,             // > 0: pseudo-random 1 .. MEM_WAIT wait states per ROM / SRAM
  parameter int          ICACHE_KB = 2,            // ChillU-S instruction cache for the XIP window: 0 (none), 2 or 4 KiB
  parameter bit          RF_LATCH  = 1'b1          // core register file: latches (ASIC); 0: flops (FPGA)
) (
  input  logic              clk,
  input  logic              por_n,           // power-on reset, async, active-low
  input  logic              ext_rst_n,       // reset pin, async, active-low
  input  logic              test_en,         // scan: domain resets follow por_n / ext_rst_n
  // JTAG (debug)
  input  logic              jtag_tck,
  input  logic              jtag_trst_n,     // async, active-low (tie high if the probe has none)
  input  logic              jtag_tms,
  input  logic              jtag_tdi,
  output logic              jtag_tdo,
  output logic              jtag_tdo_en,     // tdo driven (Shift-DR / Shift-IR)
  // UART0
  input  logic              uart_rxd,        // asynchronous
  output logic              uart_txd,
  // GPIO pads
  input  logic [N_GPIO-1:0] gpio_in,         // asynchronous
  output logic [N_GPIO-1:0] gpio_out,
  output logic [N_GPIO-1:0] gpio_oe,
  output logic [N_GPIO-1:0] gpio_pue,
  output logic [N_GPIO-1:0] gpio_ds,
  // socctl clock dividers
  output logic [1:0]        clk_div,
  // SPI0 (flash)
  output logic              spi_sck,
  output logic              spi_cs,          // chip select, active low
  output logic [3:0]        spi_dq_o,
  output logic [3:0]        spi_dq_oe,
  input  logic [3:0]        spi_dq_i,
  // I2C0 (open drain)
  input  logic              i2c_scl_i,
  input  logic              i2c_sda_i,
  output logic              i2c_scl_oe,      // pull scl low
  output logic              i2c_sda_oe,      // pull sda low
  // status
  output logic              core_sleep       // the hart sleeps in WFI (registered); a board may show it on an LED
);

  // ---- resets
  logic [N_DOM-1:0] rst_dom_n;       // socctl domain resets
  logic             rst_bus_n;       // DOM_BUS
  logic             rst_cpu_n;       // DOM_CPU
  logic [1:0]       clk_div_tick;    // last clk cycle of each clk_div period
  logic             mtime_tick;      // mtime counts this cycle
  logic             rst_dbg_n;       // debug unit: por_n synchronized (survives system resets)
  logic             ndmreset;        // debugger system reset (to socctl dbg_rst_req)

  assign rst_bus_n  = rst_dom_n[DOM_BUS];
  assign rst_cpu_n  = rst_dom_n[DOM_CPU];
  assign mtime_tick = clk_div_tick[0];

  // ---- ChillU-S
  logic [31:0] i_HADDR;              // I manager
  logic [1:0]  i_HTRANS;
  logic        i_HWRITE;
  logic [2:0]  i_HSIZE;
  logic [3:0]  i_HPROT;              // [1] privileged (M-mode) fetch
  logic        i_HREADY;
  logic        i_HRESP;
  logic [31:0] i_HRDATA;
  logic [31:0] d_HADDR;              // D manager
  logic [1:0]  d_HTRANS;
  logic        d_HWRITE;
  logic [2:0]  d_HSIZE;
  logic [31:0] d_HWDATA;
  logic [3:0]  d_HPROT;              // [1] privileged (M-mode, or MPRV) access
  logic        d_HREADY;
  logic        d_HRESP;
  logic [31:0] d_HRDATA;
  logic        msip;                 // ACLINT -> hart
  logic        mtip;
  logic        meip;                 // PLIC context 0 -> hart
  logic [63:0] mtime;
  logic [14:0] no_irq_fast;          // fast local interrupts: unused, all sources go through the PLIC
  logic        no_irq_nmi;           // NMI: unused (the watchdog goes to the PLIC)
  logic        debug_req;            // debug module halt request
  logic        cpu_debug_mode;       // the hart is in debug mode: halts the timers

  logic [31:0] boot_addr;            // first fetch and reset mtvec: the boot ROM
  logic [31:0] hart_id;              // mhartid: the only hart
  logic        fetch_en;             // the core fetches as soon as its reset is released

  assign boot_addr    = ROM_BASE;
  assign hart_id      = '0;
  assign fetch_en     = 1'b1;
  assign no_irq_fast  = '0;
  assign no_irq_nmi   = 1'b0;

  localparam logic [31:0] DM_HALT = DM_BASE + 32'h800;   // debug ROM halt entry
  localparam logic [31:0] DM_EXC  = DM_BASE + 32'h808;   // debug ROM exception entry

  chillus_ahb #(
    .DEBUG             (1'b1),
    .NUM_TRIGGERS      (2),
    .PMP_REGIONS       (4),
    .ICACHE_KB         (ICACHE_KB),
    .RF_LATCH          (RF_LATCH),
    .ICACHE_BASE       (XIP_BASE),
    .ICACHE_MASK       (XIP_MASK),
    .DM_HALT_ADDR      (DM_HALT),
    .DM_EXCEPTION_ADDR (DM_EXC)
  ) u_cpu (
    .clk            (clk),
    .rst_n          (rst_cpu_n),
    .test_en        (test_en),
    .boot_addr      (boot_addr),
    .hart_id        (hart_id),
    .fetch_enable   (fetch_en),
    .i_HADDR        (i_HADDR),
    .i_HTRANS       (i_HTRANS),
    .i_HWRITE       (i_HWRITE),
    .i_HSIZE        (i_HSIZE),
    .i_HWDATA       (),
    .i_HPROT        (i_HPROT),
    .i_HREADY       (i_HREADY),
    .i_HRESP        (i_HRESP),
    .i_HRDATA       (i_HRDATA),
    .d_HADDR        (d_HADDR),
    .d_HTRANS       (d_HTRANS),
    .d_HWRITE       (d_HWRITE),
    .d_HSIZE        (d_HSIZE),
    .d_HWDATA       (d_HWDATA),
    .d_HPROT        (d_HPROT),
    .d_HREADY       (d_HREADY),
    .d_HRESP        (d_HRESP),
    .d_HRDATA       (d_HRDATA),
    .irq_software   (msip),
    .irq_timer      (mtip),
    .irq_external   (meip),
    .irq_fast       (no_irq_fast),
    .irq_nmi        (no_irq_nmi),
    .mtime          (mtime),
    .debug_req      (debug_req),
    .debug_mode     (cpu_debug_mode),
    .core_sleep     (core_sleep),
    .rvfi_valid     (),
    .rvfi_order     (),
    .rvfi_insn      (),
    .rvfi_trap      (),
    .rvfi_halt      (),
    .rvfi_intr      (),
    .rvfi_mode      (),
    .rvfi_ixl       (),
    .rvfi_rs1_addr  (),
    .rvfi_rs2_addr  (),
    .rvfi_rs1_rdata (),
    .rvfi_rs2_rdata (),
    .rvfi_rd_addr   (),
    .rvfi_rd_wdata  (),
    .rvfi_pc_rdata  (),
    .rvfi_pc_wdata  (),
    .rvfi_mem_addr  (),
    .rvfi_mem_rmask (),
    .rvfi_mem_wmask (),
    .rvfi_mem_rdata (),
    .rvfi_mem_wdata ()
  );

  // ---- AHB matrix
  logic        rom_HSEL;             // ROM layer
  logic [31:0] rom_HADDR;
  logic [1:0]  rom_HTRANS;
  logic        rom_HWRITE;
  logic [2:0]  rom_HSIZE;
  logic [31:0] rom_HWDATA;
  logic        rom_HREADY;
  logic        rom_HREADYOUT;
  logic        rom_HRESP;
  logic [31:0] rom_HRDATA;
  logic        sram0_HSEL;           // SRAM0 layer
  logic [31:0] sram0_HADDR;
  logic [1:0]  sram0_HTRANS;
  logic        sram0_HWRITE;
  logic [2:0]  sram0_HSIZE;
  logic [31:0] sram0_HWDATA;
  logic        sram0_HREADY;
  logic        sram0_HREADYOUT;
  logic        sram0_HRESP;
  logic [31:0] sram0_HRDATA;
  logic        sram1_HSEL;           // SRAM1 on the D bus
  logic        sram1_HREADY;
  logic        sram1_HREADYOUT;
  logic        sram1_HRESP;
  logic [31:0] sram1_HRDATA;
  logic        apb_HSEL;             // APB bridge on the D bus
  logic        apb_HREADY;
  logic        apb_HREADYOUT;
  logic        apb_HRESP;
  logic [31:0] apb_HRDATA;
  logic [31:0] b_HADDR;              // the D / SBA bus (SRAM1, APB bridge)
  logic [1:0]  b_HTRANS;
  logic        b_HWRITE;
  logic [2:0]  b_HSIZE;
  logic [3:0]  b_HPROT;
  logic [31:0] b_HWDATA;
  logic [31:0] sba_HADDR;            // debugger system bus access (manager)
  logic [1:0]  sba_HTRANS;
  logic        sba_HWRITE;
  logic [2:0]  sba_HSIZE;
  logic [2:0]  sba_HBURST;
  logic [3:0]  sba_HPROT;
  logic        sba_HMASTLOCK;
  logic [31:0] sba_HWDATA;
  logic        sba_HREADY;
  logic        sba_HRESP;
  logic [31:0] sba_HRDATA;
  logic        dm_HSEL;              // debug module memory layer
  logic [31:0] dm_HADDR;
  logic [1:0]  dm_HTRANS;
  logic        dm_HWRITE;
  logic [2:0]  dm_HSIZE;
  logic [31:0] dm_HWDATA;
  logic        dm_HREADY;
  logic        dm_HREADYOUT;
  logic        dm_HRESP;
  logic [31:0] dm_HRDATA;
  logic        dm_c_HSEL;            // debug module memory port, after u_dm_wait
  logic [31:0] dm_c_HADDR;
  logic [1:0]  dm_c_HTRANS;
  logic        dm_c_HWRITE;
  logic [2:0]  dm_c_HSIZE;
  logic [31:0] dm_c_HWDATA;
  logic        dm_c_HREADY;
  logic        dm_c_HREADYOUT;
  logic        dm_c_HRESP;
  logic [31:0] dm_c_HRDATA;
  logic [31:0] dma_HADDR;            // DMA engine (manager)
  logic [1:0]  dma_HTRANS;
  logic        dma_HWRITE;
  logic [2:0]  dma_HSIZE;
  logic [2:0]  dma_HBURST;
  logic [3:0]  dma_HPROT;
  logic        dma_HMASTLOCK;
  logic [31:0] dma_HWDATA;
  logic        dma_HREADY;
  logic        dma_HRESP;
  logic [31:0] dma_HRDATA;
  logic        xip_HSEL;             // SPI0 flash window layer
  logic [31:0] xip_HADDR;
  logic [1:0]  xip_HTRANS;
  logic        xip_HWRITE;
  logic [2:0]  xip_HSIZE;
  logic [31:0] xip_HWDATA;
  logic        xip_HREADY;
  logic        xip_HREADYOUT;
  logic        xip_HRESP;
  logic [31:0] xip_HRDATA;

  chilisocs_fabric u_fabric (
    .clk             (clk),
    .rst_n           (rst_bus_n),
    .i_HADDR         (i_HADDR),
    .i_HTRANS        (i_HTRANS),
    .i_HWRITE        (i_HWRITE),
    .i_HSIZE         (i_HSIZE),
    .i_HPROT         (i_HPROT),
    .i_HREADY        (i_HREADY),
    .i_HRESP         (i_HRESP),
    .i_HRDATA        (i_HRDATA),
    .d_HADDR         (d_HADDR),
    .d_HTRANS        (d_HTRANS),
    .d_HWRITE        (d_HWRITE),
    .d_HSIZE         (d_HSIZE),
    .d_HWDATA        (d_HWDATA),
    .d_HPROT         (d_HPROT),
    .d_HREADY        (d_HREADY),
    .d_HRESP         (d_HRESP),
    .d_HRDATA        (d_HRDATA),
    .sba_HADDR       (sba_HADDR),
    .sba_HTRANS      (sba_HTRANS),
    .sba_HWRITE      (sba_HWRITE),
    .sba_HSIZE       (sba_HSIZE),
    .sba_HBURST      (sba_HBURST),
    .sba_HPROT       (sba_HPROT),
    .sba_HMASTLOCK   (sba_HMASTLOCK),
    .sba_HWDATA      (sba_HWDATA),
    .sba_HREADY      (sba_HREADY),
    .sba_HRESP       (sba_HRESP),
    .sba_HRDATA      (sba_HRDATA),
    .dma_HADDR       (dma_HADDR),
    .dma_HTRANS      (dma_HTRANS),
    .dma_HWRITE      (dma_HWRITE),
    .dma_HSIZE       (dma_HSIZE),
    .dma_HBURST      (dma_HBURST),
    .dma_HPROT       (dma_HPROT),
    .dma_HMASTLOCK   (dma_HMASTLOCK),
    .dma_HWDATA      (dma_HWDATA),
    .dma_HREADY      (dma_HREADY),
    .dma_HRESP       (dma_HRESP),
    .dma_HRDATA      (dma_HRDATA),
    .b_HADDR         (b_HADDR),
    .b_HTRANS        (b_HTRANS),
    .b_HWRITE        (b_HWRITE),
    .b_HSIZE         (b_HSIZE),
    .b_HPROT         (b_HPROT),
    .b_HWDATA        (b_HWDATA),
    .dm_HSEL         (dm_HSEL),
    .dm_HADDR        (dm_HADDR),
    .dm_HTRANS       (dm_HTRANS),
    .dm_HWRITE       (dm_HWRITE),
    .dm_HSIZE        (dm_HSIZE),
    .dm_HWDATA       (dm_HWDATA),
    .dm_HREADY       (dm_HREADY),
    .dm_HREADYOUT    (dm_HREADYOUT),
    .dm_HRESP        (dm_HRESP),
    .dm_HRDATA       (dm_HRDATA),
    .rom_HSEL        (rom_HSEL),
    .rom_HADDR       (rom_HADDR),
    .rom_HTRANS      (rom_HTRANS),
    .rom_HWRITE      (rom_HWRITE),
    .rom_HSIZE       (rom_HSIZE),
    .rom_HWDATA      (rom_HWDATA),
    .rom_HREADY      (rom_HREADY),
    .rom_HREADYOUT   (rom_HREADYOUT),
    .rom_HRESP       (rom_HRESP),
    .rom_HRDATA      (rom_HRDATA),
    .sram0_HSEL      (sram0_HSEL),
    .sram0_HADDR     (sram0_HADDR),
    .sram0_HTRANS    (sram0_HTRANS),
    .sram0_HWRITE    (sram0_HWRITE),
    .sram0_HSIZE     (sram0_HSIZE),
    .sram0_HWDATA    (sram0_HWDATA),
    .sram0_HREADY    (sram0_HREADY),
    .sram0_HREADYOUT (sram0_HREADYOUT),
    .sram0_HRESP     (sram0_HRESP),
    .sram0_HRDATA    (sram0_HRDATA),
    .xip_HSEL        (xip_HSEL),
    .xip_HADDR       (xip_HADDR),
    .xip_HTRANS      (xip_HTRANS),
    .xip_HWRITE      (xip_HWRITE),
    .xip_HSIZE       (xip_HSIZE),
    .xip_HWDATA      (xip_HWDATA),
    .xip_HREADY      (xip_HREADY),
    .xip_HREADYOUT   (xip_HREADYOUT),
    .xip_HRESP       (xip_HRESP),
    .xip_HRDATA      (xip_HRDATA),
    .sram1_HSEL      (sram1_HSEL),
    .sram1_HREADY    (sram1_HREADY),
    .sram1_HREADYOUT (sram1_HREADYOUT),
    .sram1_HRESP     (sram1_HRESP),
    .sram1_HRDATA    (sram1_HRDATA),
    .apb_HSEL        (apb_HSEL),
    .apb_HREADY      (apb_HREADY),
    .apb_HREADYOUT   (apb_HREADYOUT),
    .apb_HRESP       (apb_HRESP),
    .apb_HRDATA      (apb_HRDATA)
  );

  // ---- memories: AHB SRAM controller + single-port SRAM each
  logic              rom_req;        // ROM port
  logic              rom_we;
  logic [ROM_AW-1:0] rom_addr;
  logic [31:0]       rom_wdata;
  logic [3:0]        rom_be;
  logic [31:0]       rom_rdata;

  logic        rom_c_HSEL;            // ROM controller side of its wait inserter
  logic [31:0] rom_c_HADDR;
  logic [1:0]  rom_c_HTRANS;
  logic        rom_c_HWRITE;
  logic [2:0]  rom_c_HSIZE;
  logic [31:0] rom_c_HWDATA;
  logic        rom_c_HREADY;
  logic        rom_c_HREADYOUT;
  logic        rom_c_HRESP;
  logic [31:0] rom_c_HRDATA;

  basechili_ahb_wait #(.ADDR_W(32), .DATA_W(32), .WAIT(MEM_WAIT), .RANDOM(1'b1), .SEED(16'hACE1)) u_rom_wait (
    .clk         (clk),
    .rst_n       (rst_bus_n),
    .HSEL        (rom_HSEL),
    .HADDR       (rom_HADDR),
    .HTRANS      (rom_HTRANS),
    .HWRITE      (rom_HWRITE),
    .HSIZE       (rom_HSIZE),
    .HWDATA      (rom_HWDATA),
    .HREADY      (rom_HREADY),
    .HREADYOUT   (rom_HREADYOUT),
    .HRESP       (rom_HRESP),
    .HRDATA      (rom_HRDATA),
    .HSEL_s      (rom_c_HSEL),
    .HADDR_s     (rom_c_HADDR),
    .HTRANS_s    (rom_c_HTRANS),
    .HWRITE_s    (rom_c_HWRITE),
    .HSIZE_s     (rom_c_HSIZE),
    .HWDATA_s    (rom_c_HWDATA),
    .HREADY_s    (rom_c_HREADY),
    .HREADYOUT_s (rom_c_HREADYOUT),
    .HRESP_s     (rom_c_HRESP),
    .HRDATA_s    (rom_c_HRDATA)
  );

  basechili_ahb_sram #(.ADDR_W(32), .DATA_W(32), .MEM_AW(ROM_AW), .READ_ONLY(1'b1)) u_rom_ctl (
    .clk       (clk),
    .rst_n     (rst_bus_n),
    .HSEL      (rom_c_HSEL),
    .HADDR     (rom_c_HADDR),
    .HTRANS    (rom_c_HTRANS),
    .HWRITE    (rom_c_HWRITE),
    .HSIZE     (rom_c_HSIZE),
    .HWDATA    (rom_c_HWDATA),
    .HREADY    (rom_c_HREADY),
    .HREADYOUT (rom_c_HREADYOUT),
    .HRESP     (rom_c_HRESP),
    .HRDATA    (rom_c_HRDATA),
    .mem_req   (rom_req),
    .mem_we    (rom_we),
    .mem_addr  (rom_addr),
    .mem_wdata (rom_wdata),
    .mem_be    (rom_be),
    .mem_rdata (rom_rdata)
  );

  basechili_sram_sp #(.WIDTH(32), .DEPTH(2 ** ROM_AW)) u_rom (
    .clk   (clk),
    .req   (rom_req),
    .we    (rom_we),
    .addr  (rom_addr),
    .wdata (rom_wdata),
    .be    (rom_be),
    .rdata (rom_rdata)
  );

  logic               sram0_req;     // SRAM0 port
  logic               sram0_we;
  logic [SRAM_AW-1:0] sram0_addr;
  logic [31:0]        sram0_wdata;
  logic [3:0]         sram0_be;
  logic [31:0]        sram0_rdata;

  logic        sram0_c_HSEL;            // SRAM0 controller side of its wait inserter
  logic [31:0] sram0_c_HADDR;
  logic [1:0]  sram0_c_HTRANS;
  logic        sram0_c_HWRITE;
  logic [2:0]  sram0_c_HSIZE;
  logic [31:0] sram0_c_HWDATA;
  logic        sram0_c_HREADY;
  logic        sram0_c_HREADYOUT;
  logic        sram0_c_HRESP;
  logic [31:0] sram0_c_HRDATA;

  basechili_ahb_wait #(.ADDR_W(32), .DATA_W(32), .WAIT(MEM_WAIT), .RANDOM(1'b1), .SEED(16'h5EED)) u_sram0_wait (
    .clk         (clk),
    .rst_n       (rst_bus_n),
    .HSEL        (sram0_HSEL),
    .HADDR       (sram0_HADDR),
    .HTRANS      (sram0_HTRANS),
    .HWRITE      (sram0_HWRITE),
    .HSIZE       (sram0_HSIZE),
    .HWDATA      (sram0_HWDATA),
    .HREADY      (sram0_HREADY),
    .HREADYOUT   (sram0_HREADYOUT),
    .HRESP       (sram0_HRESP),
    .HRDATA      (sram0_HRDATA),
    .HSEL_s      (sram0_c_HSEL),
    .HADDR_s     (sram0_c_HADDR),
    .HTRANS_s    (sram0_c_HTRANS),
    .HWRITE_s    (sram0_c_HWRITE),
    .HSIZE_s     (sram0_c_HSIZE),
    .HWDATA_s    (sram0_c_HWDATA),
    .HREADY_s    (sram0_c_HREADY),
    .HREADYOUT_s (sram0_c_HREADYOUT),
    .HRESP_s     (sram0_c_HRESP),
    .HRDATA_s    (sram0_c_HRDATA)
  );

  basechili_ahb_sram #(.ADDR_W(32), .DATA_W(32), .MEM_AW(SRAM_AW)) u_sram0_ctl (
    .clk       (clk),
    .rst_n     (rst_bus_n),
    .HSEL      (sram0_c_HSEL),
    .HADDR     (sram0_c_HADDR),
    .HTRANS    (sram0_c_HTRANS),
    .HWRITE    (sram0_c_HWRITE),
    .HSIZE     (sram0_c_HSIZE),
    .HWDATA    (sram0_c_HWDATA),
    .HREADY    (sram0_c_HREADY),
    .HREADYOUT (sram0_c_HREADYOUT),
    .HRESP     (sram0_c_HRESP),
    .HRDATA    (sram0_c_HRDATA),
    .mem_req   (sram0_req),
    .mem_we    (sram0_we),
    .mem_addr  (sram0_addr),
    .mem_wdata (sram0_wdata),
    .mem_be    (sram0_be),
    .mem_rdata (sram0_rdata)
  );

  basechili_sram_sp #(.WIDTH(32), .DEPTH(2 ** SRAM_AW)) u_sram0 (
    .clk   (clk),
    .req   (sram0_req),
    .we    (sram0_we),
    .addr  (sram0_addr),
    .wdata (sram0_wdata),
    .be    (sram0_be),
    .rdata (sram0_rdata)
  );

  logic               sram1_req;     // SRAM1 port
  logic               sram1_we;
  logic [SRAM_AW-1:0] sram1_addr;
  logic [31:0]        sram1_wdata;
  logic [3:0]         sram1_be;
  logic [31:0]        sram1_rdata;

  logic        sram1_c_HSEL;            // SRAM1 controller side of its wait inserter
  logic [31:0] sram1_c_HADDR;
  logic [1:0]  sram1_c_HTRANS;
  logic        sram1_c_HWRITE;
  logic [2:0]  sram1_c_HSIZE;
  logic [31:0] sram1_c_HWDATA;
  logic        sram1_c_HREADY;
  logic        sram1_c_HREADYOUT;
  logic        sram1_c_HRESP;
  logic [31:0] sram1_c_HRDATA;

  basechili_ahb_wait #(.ADDR_W(32), .DATA_W(32), .WAIT(MEM_WAIT), .RANDOM(1'b1), .SEED(16'hBEEF)) u_sram1_wait (
    .clk         (clk),
    .rst_n       (rst_bus_n),
    .HSEL        (sram1_HSEL),
    .HADDR       (b_HADDR),
    .HTRANS      (b_HTRANS),
    .HWRITE      (b_HWRITE),
    .HSIZE       (b_HSIZE),
    .HWDATA      (b_HWDATA),
    .HREADY      (sram1_HREADY),
    .HREADYOUT   (sram1_HREADYOUT),
    .HRESP       (sram1_HRESP),
    .HRDATA      (sram1_HRDATA),
    .HSEL_s      (sram1_c_HSEL),
    .HADDR_s     (sram1_c_HADDR),
    .HTRANS_s    (sram1_c_HTRANS),
    .HWRITE_s    (sram1_c_HWRITE),
    .HSIZE_s     (sram1_c_HSIZE),
    .HWDATA_s    (sram1_c_HWDATA),
    .HREADY_s    (sram1_c_HREADY),
    .HREADYOUT_s (sram1_c_HREADYOUT),
    .HRESP_s     (sram1_c_HRESP),
    .HRDATA_s    (sram1_c_HRDATA)
  );

  basechili_ahb_sram #(.ADDR_W(32), .DATA_W(32), .MEM_AW(SRAM_AW)) u_sram1_ctl (
    .clk       (clk),
    .rst_n     (rst_bus_n),
    .HSEL      (sram1_c_HSEL),
    .HADDR     (sram1_c_HADDR),
    .HTRANS    (sram1_c_HTRANS),
    .HWRITE    (sram1_c_HWRITE),
    .HSIZE     (sram1_c_HSIZE),
    .HWDATA    (sram1_c_HWDATA),
    .HREADY    (sram1_c_HREADY),
    .HREADYOUT (sram1_c_HREADYOUT),
    .HRESP     (sram1_c_HRESP),
    .HRDATA    (sram1_c_HRDATA),
    .mem_req   (sram1_req),
    .mem_we    (sram1_we),
    .mem_addr  (sram1_addr),
    .mem_wdata (sram1_wdata),
    .mem_be    (sram1_be),
    .mem_rdata (sram1_rdata)
  );

  basechili_sram_sp #(.WIDTH(32), .DEPTH(2 ** SRAM_AW)) u_sram1 (
    .clk   (clk),
    .req   (sram1_req),
    .we    (sram1_we),
    .addr  (sram1_addr),
    .wdata (sram1_wdata),
    .be    (sram1_be),
    .rdata (sram1_rdata)
  );

  // ---- APB bridge and interconnect
  localparam int P_CLINT  = 0;       // APB subordinates
  localparam int P_PLIC   = 1;
  localparam int P_SOCCTL = 2;
  localparam int P_GPIO   = 3;
  localparam int P_UART0  = 4;
  localparam int P_TIMER  = 5;
  localparam int P_SPI0   = 6;
  localparam int P_I2C0   = 7;
  localparam int P_DMA    = 8;
  localparam int N_APB    = 9;

  logic [31:0]      PADDR;           // APB bus (shared by the subordinates)
  logic             PSEL;
  logic             PENABLE;
  logic             PWRITE;
  logic [31:0]      PWDATA;
  logic [3:0]       PSTRB;
  logic             PREADY;
  logic [31:0]      PRDATA;
  logic             PSLVERR;
  logic [N_APB-1:0] PSEL_s;          // per subordinate
  logic [N_APB-1:0] PREADY_s;
  logic [N_APB*32-1:0] PRDATA_s;
  logic [N_APB-1:0] PSLVERR_s;


  basechili_ahb_to_apb #(.ADDR_W(32), .DATA_W(32)) u_apb (
    .clk       (clk),
    .rst_n     (rst_bus_n),
    .HSEL      (apb_HSEL),
    .HADDR     (b_HADDR),
    .HTRANS    (b_HTRANS),
    .HWRITE    (b_HWRITE),
    .HSIZE     (b_HSIZE),
    .HPROT     (b_HPROT),
    .HWDATA    (b_HWDATA),
    .HREADY    (apb_HREADY),
    .HREADYOUT (apb_HREADYOUT),
    .HRESP     (apb_HRESP),
    .HRDATA    (apb_HRDATA),
    .PADDR     (PADDR),
    .PSEL      (PSEL),
    .PENABLE   (PENABLE),
    .PWRITE    (PWRITE),
    .PWDATA    (PWDATA),
    .PSTRB     (PSTRB),
    .PPROT     (),
    .PRDATA    (PRDATA),
    .PREADY    (PREADY),
    .PSLVERR   (PSLVERR)
  );

  basechili_apb_interconnect #(
    .ADDR_W (32),
    .DATA_W (32),
    .N      (N_APB),
    .BASE   ({DMA_BASE, I2C0_BASE, SPI0_BASE, TIMER_BASE, UART0_BASE, GPIO_BASE, SOCCTL_BASE,
              PLIC_BASE, CLINT_BASE}),
    .MASK   ({DMA_MASK, I2C0_MASK, SPI0_MASK, TIMER_MASK, UART0_MASK, GPIO_MASK, SOCCTL_MASK,
              PLIC_MASK, CLINT_MASK})
  ) u_apb_ic (
    .PSEL      (PSEL),
    .PADDR     (PADDR),
    .PREADY    (PREADY),
    .PRDATA    (PRDATA),
    .PSLVERR   (PSLVERR),
    .PSEL_s    (PSEL_s),
    .PREADY_s  (PREADY_s),
    .PRDATA_s  (PRDATA_s),
    .PSLVERR_s (PSLVERR_s)
  );

  // ---- ACLINT
  chilimix_aclint u_aclint (
    .clk      (clk),
    .rst_n    (rst_bus_n),
    .PSEL     (PSEL_s[P_CLINT]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (PADDR[15:0]),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (PREADY_s[P_CLINT]),
    .PRDATA   (PRDATA_s[P_CLINT*32 +: 32]),
    .PSLVERR  (PSLVERR_s[P_CLINT]),
    .tick     (mtime_tick),
    .mtime    (mtime),
    .mtip     (mtip),
    .msip     (msip),
    .ssip_set ()                       // no S-mode on ChillU-S
  );

  // ---- PLIC
  logic              uart_irq;       // UART0 interrupt
  logic [N_GPIO-1:0] gpio_irq;       // one per pin
  logic [4*N_PWM-1:0] pwm_irq;       // PWM k comparator j at bit 4k + j
  logic              wdog_irq;       // watchdog ip0
  logic              spi0_irq;       // SPI0 watermarks
  logic              i2c0_irq;       // I2C0 command done / arbitration lost
  logic [2*N_DMA_CH-1:0] dma_irq;    // channel i done at bit 2i, error at 2i + 1
  logic [N_IRQ:1]    plic_irq;       // PLIC sources

  always_comb begin
    plic_irq                         = '0;
    plic_irq[IRQ_UART0]              = uart_irq;
    plic_irq[IRQ_GPIO0 +: N_GPIO]    = gpio_irq;
    plic_irq[IRQ_PWM0 +: 4*N_PWM]    = pwm_irq;
    plic_irq[IRQ_WDOG]               = wdog_irq;
    plic_irq[IRQ_SPI0]               = spi0_irq;
    plic_irq[IRQ_I2C0]               = i2c0_irq;
    plic_irq[IRQ_DMA0 +: 2*N_DMA_CH] = dma_irq;
  end

  chilimix_plic u_plic (
    .clk     (clk),
    .rst_n   (rst_bus_n),
    .PSEL    (PSEL_s[P_PLIC]),
    .PENABLE (PENABLE),
    .PWRITE  (PWRITE),
    .PADDR   (PADDR[21:0]),
    .PWDATA  (PWDATA),
    .PSTRB   (PSTRB),
    .PREADY  (PREADY_s[P_PLIC]),
    .PRDATA  (PRDATA_s[P_PLIC*32 +: 32]),
    .PSLVERR (PSLVERR_s[P_PLIC]),
    .irq     (plic_irq),
    .eip     (meip)
  );

  // ---- SoC control: resets, clock dividers
  logic             wdog_rst_req;    // watchdog bite: system reset request (held until reset)

  chilimix_socctl #(
    .SOC_ID (SOC_ID),
    .N_DOM  (N_DOM),
    .STEP   (16),
    .HOLD   (16)
  ) u_socctl (
    .clk          (clk),
    .por_n        (por_n),
    .ext_rst_n    (ext_rst_n),
    .test_en      (test_en),
    .PSEL         (PSEL_s[P_SOCCTL]),
    .PENABLE      (PENABLE),
    .PWRITE       (PWRITE),
    .PADDR        (PADDR[7:0]),
    .PWDATA       (PWDATA),
    .PSTRB        (PSTRB),
    .PREADY       (PREADY_s[P_SOCCTL]),
    .PRDATA       (PRDATA_s[P_SOCCTL*32 +: 32]),
    .PSLVERR      (PSLVERR_s[P_SOCCTL]),
    .rst_req      (wdog_rst_req),
    .dbg_rst_req  (ndmreset),
    .rst_n_out    (rst_dom_n),
    .hart_rst_n   (),                  // one hart: the CPU domain resets it
    .boot_addr    (),                  // the core boots from ROM_BASE
    .clk_div      (clk_div),
    .clk_div_tick (clk_div_tick)
  );

  // ---- GPIO: IO function 1 = the PWM outputs (PWM k comparator j on pin 4k + j)
  logic [N_GPIO-1:0] iof_none;       // IO function 0 inputs, unused
  logic [4*N_PWM-1:0] pwm_out;       // PWM k comparator j at bit 4k + j
  logic [31:0]       pwm_pin;        // PWM outputs by pin
  logic [31:0]       pwm_pin_oe;     // pins with a PWM output
  logic [N_GPIO-1:0] iof1_out;
  logic [N_GPIO-1:0] iof1_oe;

  always_comb begin
    pwm_pin                  = '0;
    pwm_pin[4*N_PWM-1:0]     = pwm_out;
    pwm_pin_oe               = '0;
    pwm_pin_oe[4*N_PWM-1:0]  = '1;
  end

  assign iof_none = '0;
  assign iof1_out = pwm_pin[N_GPIO-1:0];
  assign iof1_oe  = pwm_pin_oe[N_GPIO-1:0];

  chilimix_gpio #(.N_GPIO(N_GPIO)) u_gpio (
    .clk      (clk),
    .rst_n    (rst_bus_n),
    .PSEL     (PSEL_s[P_GPIO]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (PADDR[6:0]),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (PREADY_s[P_GPIO]),
    .PRDATA   (PRDATA_s[P_GPIO*32 +: 32]),
    .PSLVERR  (PSLVERR_s[P_GPIO]),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe),
    .gpio_pue (gpio_pue),
    .gpio_ds  (gpio_ds),
    .iof0_out (iof_none),
    .iof0_oe  (iof_none),
    .iof1_out (iof1_out),
    .iof1_oe  (iof1_oe),
    .irq      (gpio_irq)
  );

  // ---- UART0 (modem inputs inactive: CTS / DSR / DCD asserted, RI not)
  logic modem_on_n;                  // asserted active-low modem input
  logic modem_off_n;                 // inactive active-low modem input

  assign modem_on_n  = 1'b0;
  assign modem_off_n = 1'b1;

  chilimix_uart u_uart0 (
    .clk     (clk),
    .rst_n   (rst_bus_n),
    .PSEL    (PSEL_s[P_UART0]),
    .PENABLE (PENABLE),
    .PWRITE  (PWRITE),
    .PADDR   (PADDR[4:0]),
    .PWDATA  (PWDATA),
    .PSTRB   (PSTRB),
    .PREADY  (PREADY_s[P_UART0]),
    .PRDATA  (PRDATA_s[P_UART0*32 +: 32]),
    .PSLVERR (PSLVERR_s[P_UART0]),
    .rxd     (uart_rxd),
    .txd     (uart_txd),
    .cts_n   (modem_on_n),
    .dsr_n   (modem_on_n),
    .ri_n    (modem_off_n),
    .dcd_n   (modem_on_n),
    .rts_n   (),
    .dtr_n   (),
    .out1_n  (),
    .out2_n  (),
    .irq     (uart_irq)
  );

  // ---- debug unit: JTAG DTM, debug module, system bus access
  logic hart_unavail;                // the hart is in reset

  assign hart_unavail = !rst_cpu_n;

  basechili_reset_sync u_dbg_rst (
    .clk         (clk),
    .rst_n_async (por_n),
    .test_en     (test_en),
    .rst_n_sync  (rst_dbg_n)
  );

  // the DM memory port takes its address phase from a register (one wait
  // state): the fabric's address decode and the DM's read mux would
  // otherwise hang on the core's address adder
  basechili_ahb_wait #(.ADDR_W(32), .DATA_W(32), .WAIT(1)) u_dm_wait (
    .clk         (clk),
    .rst_n       (rst_bus_n),
    .HSEL        (dm_HSEL),
    .HADDR       (dm_HADDR),
    .HTRANS      (dm_HTRANS),
    .HWRITE      (dm_HWRITE),
    .HSIZE       (dm_HSIZE),
    .HWDATA      (dm_HWDATA),
    .HREADY      (dm_HREADY),
    .HREADYOUT   (dm_HREADYOUT),
    .HRESP       (dm_HRESP),
    .HRDATA      (dm_HRDATA),
    .HSEL_s      (dm_c_HSEL),
    .HADDR_s     (dm_c_HADDR),
    .HTRANS_s    (dm_c_HTRANS),
    .HWRITE_s    (dm_c_HWRITE),
    .HSIZE_s     (dm_c_HSIZE),
    .HWDATA_s    (dm_c_HWDATA),
    .HREADY_s    (dm_c_HREADY),
    .HREADYOUT_s (dm_c_HREADYOUT),
    .HRESP_s     (dm_c_HRESP),
    .HRDATA_s    (dm_c_HRDATA)
  );

  chilimix_debug #(.IDCODE(JTAG_IDCODE)) u_debug (
    .tck           (jtag_tck),
    .trst_n        (jtag_trst_n),
    .tms           (jtag_tms),
    .tdi           (jtag_tdi),
    .tdo           (jtag_tdo),
    .tdo_en        (jtag_tdo_en),
    .clk           (clk),
    .rst_n         (rst_dbg_n),
    .debug_req     (debug_req),
    .hart_unavail  (hart_unavail),
    .ndmreset      (ndmreset),
    .HSEL          (dm_c_HSEL),
    .HADDR         (dm_c_HADDR),
    .HTRANS        (dm_c_HTRANS),
    .HWRITE        (dm_c_HWRITE),
    .HSIZE         (dm_c_HSIZE),
    .HWDATA        (dm_c_HWDATA),
    .HREADY        (dm_c_HREADY),
    .HREADYOUT     (dm_c_HREADYOUT),
    .HRESP         (dm_c_HRESP),
    .HRDATA        (dm_c_HRDATA),
    .sba_HADDR     (sba_HADDR),
    .sba_HTRANS    (sba_HTRANS),
    .sba_HWRITE    (sba_HWRITE),
    .sba_HSIZE     (sba_HSIZE),
    .sba_HBURST    (sba_HBURST),
    .sba_HPROT     (sba_HPROT),
    .sba_HMASTLOCK (sba_HMASTLOCK),
    .sba_HWDATA    (sba_HWDATA),
    .sba_HREADY    (sba_HREADY),
    .sba_HRESP     (sba_HRESP),
    .sba_HRDATA    (sba_HRDATA)
  );

  // ---- timers: N_PWM PWMs and the watchdog
  logic wdog_core_sleep;             // the core is asleep or in reset

  assign wdog_core_sleep = core_sleep || !rst_cpu_n;

  chilimix_timer #(.N_PWM(N_PWM)) u_timer (
    .clk          (clk),
    .rst_n        (rst_bus_n),
    .PSEL         (PSEL_s[P_TIMER]),
    .PENABLE      (PENABLE),
    .PWRITE       (PWRITE),
    .PADDR        (PADDR[10:0]),
    .PWDATA       (PWDATA),
    .PSTRB        (PSTRB),
    .PREADY       (PREADY_s[P_TIMER]),
    .PRDATA       (PRDATA_s[P_TIMER*32 +: 32]),
    .PSLVERR      (PSLVERR_s[P_TIMER]),
    .tick         (mtime_tick),
    .halt         (cpu_debug_mode),
    .core_sleep   (wdog_core_sleep),
    .pwm_out      (pwm_out),
    .pwm_irq      (pwm_irq),
    .wdog_irq     (wdog_irq),
    .wdog_rst_req (wdog_rst_req)
  );

  // ---- SPI0: registers on APB, flash window on the XIP layer
  localparam int XIP_AW = 29;        // window address bits (512 MiB, XIP_MASK)
  logic [XIP_AW-1:0] xip_offset;     // byte address inside the flash window

  assign xip_offset = xip_HADDR[XIP_AW-1:0];

  chilimix_spi #(.N_CS(1), .XIP_AW(XIP_AW), .XIP_LINES(4), .XIP_LINE_B(16)) u_spi0 (
    .clk       (clk),
    .rst_n     (rst_bus_n),
    .PSEL      (PSEL_s[P_SPI0]),
    .PENABLE   (PENABLE),
    .PWRITE    (PWRITE),
    .PADDR     (PADDR[6:0]),
    .PWDATA    (PWDATA),
    .PSTRB     (PSTRB),
    .PREADY    (PREADY_s[P_SPI0]),
    .PRDATA    (PRDATA_s[P_SPI0*32 +: 32]),
    .PSLVERR   (PSLVERR_s[P_SPI0]),
    .HSEL      (xip_HSEL),
    .HADDR     (xip_offset),
    .HTRANS    (xip_HTRANS),
    .HWRITE    (xip_HWRITE),
    .HSIZE     (xip_HSIZE),
    .HWDATA    (xip_HWDATA),
    .HREADY    (xip_HREADY),
    .HREADYOUT (xip_HREADYOUT),
    .HRESP     (xip_HRESP),
    .HRDATA    (xip_HRDATA),
    .sck       (spi_sck),
    .cs        (spi_cs),
    .dq_o      (spi_dq_o),
    .dq_oe     (spi_dq_oe),
    .dq_i      (spi_dq_i),
    .irq       (spi0_irq)
  );

  // ---- I2C0
  chilimix_i2c u_i2c0 (
    .clk     (clk),
    .rst_n   (rst_bus_n),
    .PSEL    (PSEL_s[P_I2C0]),
    .PENABLE (PENABLE),
    .PWRITE  (PWRITE),
    .PADDR   (PADDR[4:0]),
    .PWDATA  (PWDATA),
    .PSTRB   (PSTRB),
    .PREADY  (PREADY_s[P_I2C0]),
    .PRDATA  (PRDATA_s[P_I2C0*32 +: 32]),
    .PSLVERR (PSLVERR_s[P_I2C0]),
    .scl_i   (i2c_scl_i),
    .sda_i   (i2c_sda_i),
    .scl_oe  (i2c_scl_oe),
    .sda_oe  (i2c_sda_oe),
    .irq     (i2c0_irq)
  );

  // ---- DMA: registers on APB, transfers on the D bus
  chilimix_dma #(.N_CH(N_DMA_CH)) u_dma (
    .clk       (clk),
    .rst_n     (rst_bus_n),
    .PSEL      (PSEL_s[P_DMA]),
    .PENABLE   (PENABLE),
    .PWRITE    (PWRITE),
    .PADDR     (PADDR[13:0]),
    .PWDATA    (PWDATA),
    .PSTRB     (PSTRB),
    .PREADY    (PREADY_s[P_DMA]),
    .PRDATA    (PRDATA_s[P_DMA*32 +: 32]),
    .PSLVERR   (PSLVERR_s[P_DMA]),
    .HADDR     (dma_HADDR),
    .HTRANS    (dma_HTRANS),
    .HWRITE    (dma_HWRITE),
    .HSIZE     (dma_HSIZE),
    .HBURST    (dma_HBURST),
    .HPROT     (dma_HPROT),
    .HMASTLOCK (dma_HMASTLOCK),
    .HWDATA    (dma_HWDATA),
    .HREADY    (dma_HREADY),
    .HRESP     (dma_HRESP),
    .HRDATA    (dma_HRDATA),
    .irq       (dma_irq)
  );

endmodule
