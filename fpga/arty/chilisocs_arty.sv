// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliSoC-S FPGA :: chilisocs_arty (Digilent Arty A7-100T board top)
//
// chilisocs_top unchanged (RF_LATCH = 0: register file in flops) with the
// board's clock, reset and pads. Xilinx 7-series primitives are instantiated
// here and only here; fpga/arty/chilisocs_arty.xdc places the ports (pins
// from Digilent's Arty-A7-100-Master.xdc, Rev. D / E).
//
//   clk        : CLK100MHZ (E3) -> MMCME2_BASE (VCO 1000 MHz) -> CLKOUT0
//                (1000 / CLKOUT_DIV MHz, 50 MHz by default) -> BUFG
//   por_n      : the MMCM's LOCKED: the SoC is in reset until the clock is stable
//   ext_rst_n  : the RESET button (ck_rst, active low)
//   UART0      : the FT2232's channel B (uart_txd_in into the FPGA, uart_rxd_out out)
//   JTAG       : Pmod JD (top row): jd[0] TMS, jd[1] TDI, jd[2] TCK (an MRCC
//                pin), jd[3] TDO (driven while jtag_tdo_en, else Z); TRST_N
//                tied high (the 6-pin JTAG-HS2 header has none)
//   GPIO 0..3  : led[3:0] (driven while the pin's output is enabled; read back)
//   GPIO 4..7  : sw[3:0];  GPIO 8..11: btn[3:0];  GPIO 12..15: ja[3:0] (IOBUF)
//   SPI0       : the board's QSPI configuration flash: SCK through STARTUPE2
//                USRCCLKO (the flash clock is the CCLK pin), CS and DQ0..3 pins
//   I2C0       : the Arduino header's SCL / SDA (IOBUF, pulled low while *_oe);
//                scl_pup / sda_pup high switch on the board's pull-ups
//   core_sleep : led0_b (RGB LED 0, blue): the hart sleeps in WFI
//   test_en    : tied 0; clk_div, gpio_pue and gpio_ds have no board use
//   boot ROM   : ROM_INIT, the sw/boot image, through a defparam on u_soc.u_rom
//                (the FPGA basechili_sram_sp's INIT_FILE)
//
// Timing    : clk and jtag_tck (10 MHz in the XDC) are asynchronous clock
//             groups, as in syn/orfs; the pads are asynchronous inputs the
//             IPs synchronize. The core's sleep clock is a BUFGCE
//             (fpga/arty/basechili_clock_gate.sv) driven from clk.
// Invariants: por_n is low while the MMCM is unlocked.
// Debug     : nothing at all -> LOCKED (por_n), the ck_rst level; no console
//             -> uart_rxd_out at 16 * UART_DIV clocks per bit (fpga/README.md);
//             no JTAG -> jd wiring, jtag_tdo_en toggling in Shift-DR.
// -----------------------------------------------------------------------------
module chilisocs_arty #(
  parameter real   CLKOUT_DIV = 20.0,             // MMCM CLKOUT0 divide: 1000 MHz / CLKOUT_DIV (multiple of 0.125)
  parameter int    ICACHE_KB  = 4,                // chilisocs_top ICACHE_KB (the ASIC top keeps 2)
  parameter string ROM_INIT   = ""                // boot ROM image ($readmemh, 32-bit words), set by fpga/build.py
) (
  input  logic       CLK100MHZ,
  input  logic       ck_rst,                      // RESET button, active low
  input  logic       uart_txd_in,                 // from the USB UART
  output logic       uart_rxd_out,                // to the USB UART
  output logic [3:0] led,
  output logic       led0_b,
  input  logic [3:0] sw,
  input  logic [3:0] btn,
  inout  wire  [3:0] ja,
  input  logic       jd_tms,                      // jd[0]
  input  logic       jd_tdi,                      // jd[1]
  input  logic       jd_tck,                      // jd[2]
  output wire        jd_tdo,                      // jd[3]
  output logic       qspi_cs,
  inout  wire  [3:0] qspi_dq,
  inout  wire        ck_scl,
  inout  wire        ck_sda,
  output logic       scl_pup,
  output logic       sda_pup
);
  localparam int N_GPIO = 16;

  // ---- clock and power-on reset
  logic clk;                                      // SoC clock
  logic mmcm_clk;                                 // CLKOUT0 before its BUFG
  logic fb_clk;                                   // MMCM feedback
  logic fb_bufg;                                  // feedback after its BUFG
  logic locked;                                   // MMCM locked: por_n
  logic mmcm_rst;                                 // MMCM reset (never)
  logic mmcm_pwrdwn;                              // MMCM power-down (never)

  assign mmcm_rst    = 1'b0;
  assign mmcm_pwrdwn = 1'b0;

  MMCME2_BASE #(
    .CLKIN1_PERIOD    (10.0),
    .CLKFBOUT_MULT_F  (10.0),
    .DIVCLK_DIVIDE    (1),
    .CLKOUT0_DIVIDE_F (CLKOUT_DIV)
  ) u_mmcm (
    .CLKIN1   (CLK100MHZ),
    .CLKFBIN  (fb_bufg),
    .RST      (mmcm_rst),
    .PWRDWN   (mmcm_pwrdwn),
    .CLKFBOUT (fb_clk),
    .CLKFBOUTB(),
    .CLKOUT0  (mmcm_clk),
    .CLKOUT0B (),
    .CLKOUT1  (),
    .CLKOUT1B (),
    .CLKOUT2  (),
    .CLKOUT2B (),
    .CLKOUT3  (),
    .CLKOUT3B (),
    .CLKOUT4  (),
    .CLKOUT5  (),
    .CLKOUT6  (),
    .LOCKED   (locked)
  );

  BUFG u_fb_bufg  (.I(fb_clk),   .O(fb_bufg));
  BUFG u_clk_bufg (.I(mmcm_clk), .O(clk));

  // ---- SoC
  logic              jtag_tdo;                    // TDO from the debug unit
  logic              jtag_tdo_en;                 // TDO driven
  logic              jtag_tdo_t;                  // OBUFT tristate: TDO released
  logic              jtag_trst_n;                 // no TRST on the probe
  logic              test_en;                     // functional mode
  logic [N_GPIO-1:0] gpio_in;
  logic [N_GPIO-1:0] gpio_out;
  logic [N_GPIO-1:0] gpio_oe;
  logic [N_GPIO-1:0] gpio_t;                      // IOBUF tristate per pin: !gpio_oe
  logic [N_GPIO-1:0] gpio_drv;                    // pin driven high: gpio_out & gpio_oe
  logic              spi_sck;
  logic              spi_cs;
  logic [3:0]        spi_dq_o;
  logic [3:0]        spi_dq_oe;
  logic [3:0]        spi_dq_i;
  logic [3:0]        spi_dq_t;                    // IOBUF tristate per DQ: !spi_dq_oe
  logic              i2c_scl_i;
  logic              i2c_sda_i;
  logic              i2c_scl_oe;
  logic              i2c_sda_oe;
  logic              i2c_scl_t;                   // SCL released: !i2c_scl_oe
  logic              i2c_sda_t;                   // SDA released: !i2c_sda_oe
  logic              i2c_low;                     // the level an open-drain pin drives
  logic              core_sleep;

  assign jtag_trst_n = 1'b1;
  assign test_en     = 1'b0;

  chilisocs_top #(
    .ICACHE_KB (ICACHE_KB),
    .RF_LATCH  (1'b0)
  ) u_soc (
    .clk         (clk),
    .por_n       (locked),
    .ext_rst_n   (ck_rst),
    .test_en     (test_en),
    .jtag_tck    (jd_tck),
    .jtag_trst_n (jtag_trst_n),
    .jtag_tms    (jd_tms),
    .jtag_tdi    (jd_tdi),
    .jtag_tdo    (jtag_tdo),
    .jtag_tdo_en (jtag_tdo_en),
    .uart_rxd    (uart_txd_in),
    .uart_txd    (uart_rxd_out),
    .gpio_in     (gpio_in),
    .gpio_out    (gpio_out),
    .gpio_oe     (gpio_oe),
    .gpio_pue    (),
    .gpio_ds     (),
    .clk_div     (),
    .spi_sck     (spi_sck),
    .spi_cs      (spi_cs),
    .spi_dq_o    (spi_dq_o),
    .spi_dq_oe   (spi_dq_oe),
    .spi_dq_i    (spi_dq_i),
    .i2c_scl_i   (i2c_scl_i),
    .i2c_sda_i   (i2c_sda_i),
    .i2c_scl_oe  (i2c_scl_oe),
    .i2c_sda_oe  (i2c_sda_oe),
    .core_sleep  (core_sleep)
  );

  // the boot ROM's image: INIT_FILE of the FPGA basechili_sram_sp (fpga/arty)
  defparam u_soc.u_rom.INIT_FILE = ROM_INIT;

  // ---- JTAG TDO
  assign jtag_tdo_t = !jtag_tdo_en;

  OBUFT u_tdo (.I(jtag_tdo), .T(jtag_tdo_t), .O(jd_tdo));

  // ---- GPIO: LEDs, switches, buttons, Pmod JA
  assign gpio_t   = ~gpio_oe;
  assign gpio_drv = gpio_out & gpio_oe;
  assign led      = gpio_drv[3:0];
  assign gpio_in[3:0]  = gpio_drv[3:0];
  assign gpio_in[7:4]  = sw;
  assign gpio_in[11:8] = btn;

  for (genvar i = 0; i < 4; i++) begin : g_ja
    IOBUF u_ja (.I(gpio_out[12 + i]), .T(gpio_t[12 + i]), .O(gpio_in[12 + i]), .IO(ja[i]));
  end

  assign led0_b = core_sleep;

  // ---- SPI0: the QSPI configuration flash (SCK is the CCLK pin: STARTUPE2)
  logic startup_low;                              // STARTUPE2 inputs held low
  logic startup_high;                             // STARTUPE2 inputs held high

  assign startup_low  = 1'b0;
  assign startup_high = 1'b1;
  assign spi_dq_t     = ~spi_dq_oe;
  assign qspi_cs      = spi_cs;

  STARTUPE2 #(
    .PROG_USR      ("FALSE"),
    .SIM_CCLK_FREQ (0.0)
  ) u_startup (
    .CFGCLK    (),
    .CFGMCLK   (),
    .EOS       (),
    .PREQ      (),
    .CLK       (startup_low),
    .GSR       (startup_low),
    .GTS       (startup_low),
    .KEYCLEARB (startup_high),
    .PACK      (startup_low),
    .USRCCLKO  (spi_sck),
    .USRCCLKTS (startup_low),
    .USRDONEO  (startup_high),
    .USRDONETS (startup_high)
  );

  for (genvar i = 0; i < 4; i++) begin : g_dq
    IOBUF u_dq (.I(spi_dq_o[i]), .T(spi_dq_t[i]), .O(spi_dq_i[i]), .IO(qspi_dq[i]));
  end

  // ---- I2C0: open drain on the Arduino header, board pull-ups on
  assign i2c_low   = 1'b0;
  assign i2c_scl_t = !i2c_scl_oe;
  assign i2c_sda_t = !i2c_sda_oe;
  assign scl_pup   = 1'b1;
  assign sda_pup   = 1'b1;

  IOBUF u_scl (.I(i2c_low), .T(i2c_scl_t), .O(i2c_scl_i), .IO(ck_scl));
  IOBUF u_sda (.I(i2c_low), .T(i2c_sda_t), .O(i2c_sda_i), .IO(ck_sda));

endmodule
