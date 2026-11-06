# ChiliSoC-S on the Digilent Arty A7-100T (XC7A100T-1CSG324C): chilisocs_arty.
# Pins from Digilent's Arty-A7-100-Master.xdc (Rev. D / E,
# github.com/Digilent/digilent-xdc); every bank is 3.3 V (LVCMOS33).

# ---- configuration: 3.3 V banks, the QSPI flash holds the bitstream (x4)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# ---- 100 MHz oscillator; clk is the MMCM's output (derived by Vivado)
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -name sys_clk -period 10.000 [get_ports CLK100MHZ]

# ---- RESET button (ck_rst, active low): ext_rst_n, synchronized in socctl
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports ck_rst]

# ---- USB UART (FT2232 channel B): the console
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports uart_txd_in]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports uart_rxd_out]

# ---- LEDs (GPIO 0..3) and RGB LED 0 blue (core_sleep)
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports led0_b]

# ---- slide switches (GPIO 4..7) and buttons (GPIO 8..11)
set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN C9  IOSTANDARD LVCMOS33 } [get_ports {btn[1]}]
set_property -dict { PACKAGE_PIN B9  IOSTANDARD LVCMOS33 } [get_ports {btn[2]}]
set_property -dict { PACKAGE_PIN B8  IOSTANDARD LVCMOS33 } [get_ports {btn[3]}]

# ---- Pmod JA top row (GPIO 12..15), weak pull-ups for open pins
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {ja[0]}]
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {ja[1]}]
set_property -dict { PACKAGE_PIN A11 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {ja[2]}]
set_property -dict { PACKAGE_PIN D12 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {ja[3]}]

# ---- JTAG on Pmod JD top row (Digilent JTAG-HS2 flying leads by label):
# pin 1 TMS, pin 2 TDI, pin 3 TCK (F4, an MRCC pin), pin 4 TDO, pin 5 GND, pin 6 VCC (HS2 VREF)
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports jd_tms]
set_property -dict { PACKAGE_PIN D3 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports jd_tdi]
set_property -dict { PACKAGE_PIN F4 IOSTANDARD LVCMOS33 PULLDOWN TRUE } [get_ports jd_tck]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 } [get_ports jd_tdo]
create_clock -name jtag_tck -period 100.000 [get_ports jd_tck]

# ---- QSPI configuration flash (SCK is CCLK, driven through STARTUPE2)
set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports qspi_cs]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {qspi_dq[0]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {qspi_dq[1]}]
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports {qspi_dq[2]}]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports {qspi_dq[3]}]

# ---- I2C on the Arduino header, with the board's switchable pull-ups
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports ck_scl]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports ck_sda]
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports scl_pup]
set_property -dict { PACKAGE_PIN A13 IOSTANDARD LVCMOS33 } [get_ports sda_pup]

# ---- timing: clk and jtag_tck are asynchronous (crossed inside chilimix_debug,
# as in syn/orfs/nangate45/chilisocs/constraint.sdc)
set_clock_groups -asynchronous \
  -group [get_clocks -of_objects [get_pins u_mmcm/CLKOUT0]] \
  -group [get_clocks jtag_tck]

# Pads are asynchronous to clk (two-flop synchronizers in the IPs; the LEDs,
# UART and I2C timing is set by the IPs' own clocking), so no I/O delays:
# false paths keep them out of the clk timing report. JTAG runs at a few MHz
# (TDO changes on the falling TCK edge).
set_false_path -from [get_ports {ck_rst jd_tms jd_tdi uart_txd_in sw[*] btn[*] ja[*] ck_scl ck_sda}]
set_false_path -to   [get_ports {jd_tdo uart_rxd_out led[*] led0_b ja[*] ck_scl ck_sda scl_pup sda_pup}]

# ---- QSPI flash (SPI0, the board's S25FL128S) at SPI0's fastest setting,
# sckdiv 0: SCK = clk / 2 from a flop of chilimix_spi_phy, through STARTUPE2
# to the CCLK pin. Mode 0: SPI0 changes dq / cs with the falling SCK edge and
# samples dq_i on the clk edge that raises SCK; the flash samples on the
# rising edge and drives dq after the falling one. A slower sckdiv only adds
# margin. qspi_sck is SCK at the CCLK pin: its waveform follows clk, the
# route to USRCCLKO is timed, and the edge shift adds the STARTUPE2 USRCCLKO
# to CCLK delay, which Vivado does not time (DS181: 0.5 .. 6.7 ns at -2;
# 7.5 ns max taken for this -1 part), plus 0.2 ns of board: 0.7 .. 7.7 ns.
# The clock carries the 7.7 ns maximum; the checks for which the minimum is
# worse (output setup, input hold) get the 7.0 ns difference in their delays.
# S25FL128S data sheet (S25FL128S_256S_00 rev. 08, SDR AC characteristics):
# tSU 2, tHD 2, tCSS 3, tCSH 3, tHO 2 min and tV 6.5 max (ns). tV 6.5 is the
# value for a regulated VCC of 3.0 .. 3.6 V and CL = 15 pF (note 4). It
# applies here because the Arty powers the flash from its regulated 3.3 V rail
# and the dq lines carry only the flash and one FPGA pin. 0.2 ns of board on
# dq / cs.
create_generated_clock -name qspi_sck -source [get_pins u_mmcm/CLKOUT0] -edges {1 3 5} \
  -edge_shift {7.7 7.7 7.7} [get_pins u_startup/USRCCLKO]
set_output_delay -clock qspi_sck -max  9.2 [get_ports {qspi_dq[*]}]
set_output_delay -clock qspi_sck -min -2.0 [get_ports {qspi_dq[*]}]
set_output_delay -clock qspi_sck -max 10.2 [get_ports qspi_cs]
set_output_delay -clock qspi_sck -min -3.0 [get_ports qspi_cs]
set_input_delay  -clock qspi_sck -clock_fall -max  6.7 [get_ports {qspi_dq[*]}]
set_input_delay  -clock qspi_sck -clock_fall -min -5.0 [get_ports {qspi_dq[*]}]
# dq / cs change with the falling SCK edge, from the clk edge one period
# before the clk edge of the rising SCK edge the flash samples on: setup from
# that earlier clk edge (the edge shift would pair it with the same one), and
# hold against the rising edge before the next change
set_multicycle_path -setup -start 2 -from [get_clocks -of_objects [get_pins u_mmcm/CLKOUT0]] -to [get_clocks qspi_sck]
set_multicycle_path -hold  -start 1 -from [get_clocks -of_objects [get_pins u_mmcm/CLKOUT0]] -to [get_clocks qspi_sck]
