# ChiliSoC-S on the Arty A7-100T

`chilisocs_top` runs unchanged on a Digilent Arty A7-100T (XC7A100T-1CSG324C)
inside a board top, `fpga/arty/chilisocs_arty.sv`. The board top carries the
clocking, reset and pads; the build swaps in FPGA versions of two BaseChiliSV
primitives.

| File | What it is |
| --- | --- |
| `arty/chilisocs_arty.sv` | board top: MMCM, LOCKED as `por_n`, pads, JTAG on Pmod JD, `RF_LATCH = 0`, `ICACHE_KB = 4` |
| `arty/chilisocs_arty.xdc` | pins (from Digilent's `Arty-A7-100-Master.xdc`), clocks, configuration |
| `arty/basechili_clock_gate.sv` | FPGA swap: the core's sleep clock gate as a BUFGCE |
| `arty/basechili_sram_sp.sv` | FPGA swap: block RAM with an `INIT_FILE` image (the boot ROM's) |
| `arty/build.tcl` | Vivado non-project batch flow |
| `arty/openocd.cfg` | OpenOCD for the Digilent JTAG-HS2 |
| `lint/unisim.sv` | port models of the Xilinx primitives, for `--lint` only |
| `build.py` | lint, bitstream build, board programs |
| `regress.py` | the regression on the board (JTAG load, UART result) |

## Board mapping

| SoC | Board | Notes |
| --- | --- | --- |
| `clk` | 100 MHz oscillator (E3) through an MMCM | 1000 MHz / `CLKOUT_DIV`; 50 MHz by default |
| `por_n` | MMCM LOCKED | |
| `ext_rst_n` | RESET button (C2) | |
| UART0 | USB UART (FT2232 channel B), A9 in / D10 out | 115200 8N1 with `UART_DIV` 27 at 50 MHz |
| JTAG | Pmod JD pins 1 TMS, 2 TDI, 3 TCK, 4 TDO, 5 GND, 6 VCC | TRST tied high |
| GPIO 0..3 | LD4..LD7 (`led[3:0]`) | lit while the pin is an output driving 1 |
| GPIO 4..7 | slide switches SW0..3 | inputs |
| GPIO 8..11 | buttons BTN0..3 | inputs |
| GPIO 12..15 | Pmod JA pins 1..4 | bidirectional, weak pull-ups |
| SPI0 | the QSPI configuration flash | SCK through STARTUPE2 (CCLK) |
| I2C0 | Arduino header SCL / SDA | the board pull-ups switched on |
| `core_sleep` | RGB LED 0, blue | on while the hart sleeps in WFI |

The board top differs from `chilisocs_top` only as follows:

- The register file is in flops (`RF_LATCH = 0`). The regression runs with this setting too, in the `stress` step of `tools/check.py`.
- The instruction cache is 4 KiB (`ICACHE_KB = 4`; the ASIC top keeps 2). CoreMark's hot code fits in it, so programs that run from the flash come close to SRAM speed; `--icache-kb` builds another size.
- The sleep clock gate is a BUFGCE.
- The ROM holds `sw/boot` in its initial contents, set through a `defparam` on `u_soc.u_rom`.

Every other memory starts at zero.

## One-time setup

1. Install Vivado ML Standard (free, no license key) once per machine for all
   users: run AMD's Unified Installer (Linux self-extracting web installer)
   with `sudo`, choose Vivado, ML Standard, the Artix-7 devices only, location
   `/opt/Xilinx`, no cable drivers (openFPGALoader loads the board).
   `fpga/build.py` takes `$VIVADO`, else `vivado` on PATH, else the newest
   `/opt/Xilinx/<version>/Vivado/bin/vivado`; no `settings64.sh` needed.
2. Install the board tools: `sudo apt install openfpgaloader picocom` (the
   package adds openFPGALoader's udev rules; add the user to `plugdev` and
   `dialout`), and OpenOCD (`tools/install_openocd.sh` builds the pinned
   version the simulation uses; it includes the FTDI driver).
3. Wire the JTAG-HS2's flying leads to Pmod JD's top row by their labels:
   TMS to pin 1, TDI to pin 2, TCK to pin 3, TDO to pin 4, GND to pin 5 and
   VREF to pin 6 (3.3 V).

## Build and load

```sh
python fpga/build.py --lint                 # no Vivado: slang on the board top (part of tools/check.py)
python fpga/build.py                        # fpga/out/arty/chilisocs_arty.bit, reports beside it
openFPGALoader -b arty fpga/out/arty/chilisocs_arty.bit         # into the FPGA (lost at power-off)
openFPGALoader -b arty -f fpga/out/arty/chilisocs_arty.bin      # into the flash (boots at power-on)
```

The build reports land in `fpga/out/arty/`:

- `timing.rpt` holds the WNS that the build checks.
- `utilization.rpt` and `clocks.rpt` cover resources and clocks.
- `vivado.log` is the full log.

For another clock, use `--clkout-div`, for example 13.375 for 74.77 MHz or 10 for 100 MHz.

## Run a program

```sh
picocom -b 115200 /dev/ttyUSB1               # the console (FT2232 channel B)
python fpga/build.py --program hello         # fpga/out/arty/hello/hello.elf, UART_DIV for the clock
openocd -f fpga/arty/openocd.cfg             # in another shell
riscv64-unknown-elf-gdb fpga/out/arty/hello/hello.elf \
  -ex 'target extended-remote :3333' -ex 'monitor reset halt' -ex load -ex continue
```

At reset the ROM jumps to SRAM0. With no program loaded there, the hart traps back into the ROM and loops until the debugger halts it and loads one. Programs print `*** PASS` on the console when they finish, as in simulation. Pass `--clkout-div` to `--program` too when the bitstream runs at another clock.

## Regression on the board

```sh
python fpga/regress.py                       # every program of sim/tests.list the board can run
python fpga/regress.py --bitstream hello     # load the bitstream first (after a power cycle), then hello
python fpga/regress.py coremark --iterations 1500 --timeout 120   # a valid score (>= 10 s at 50 MHz)
```

It builds each program for the board clock, loads it with OpenOCD and waits for `*** PASS` on the UART. Its logs go to `fpga/out/arty/run/`. Under `FPGA` (defined by `--program`), hello accepts the debug and external reset causes next to power-on, and spi expects the board flash's JEDEC ID. A program with a flash part has it written to the flash first (see Flash). `regs` gets a fresh bitstream first, because the power-on scratch registers keep what earlier programs left in them. `SKIP` in the script lists the programs that need the testbench, with the reason for each.

CoreMark counts cycles, so its "Iterations/Sec" is CoreMark/MHz: 1500 iterations take 609 M cycles on the board at 50 MHz, which gives 2.46 CoreMark/MHz (123 CoreMark), with correct operation validated.

## Flash

The board's flash is a Spansion S25FL128S (16 MiB, JEDEC ID 01 20 18), and SPI0 reaches it through the window at `0x2000_0000`. It is laid out like this:

| Offset | Contents |
| --- | --- |
| `0x00_0000` | the bitstream (the FPGA configures from it at power-on) |
| `0x40_0000` | the flash part (`.xip`) of a regress.py program, linked at `0x2040_0000` (`FLASH_OFFSET`) |
| `0x80_0000` | the flash boot image (`BOOT_OFFSET`): magic, segment count, then address, length and words per segment |

The board's boot ROM is `sw/boot/boot.S` built with `FPGA` defined. Unless the debugger caused the reset (`RST_CAUSE.dbg`), it copies the boot image to SRAM and then starts SRAM0. Without an image it starts SRAM0 directly, as in simulation.

```sh
python fpga/regress.py --flash-boot hello    # bitstream + hello into the flash, then boot from it (no debugger)
```

The board then boots that program at every power-on. JTAG loads still work, because OpenOCD's `reset halt` sets `dbg` and the ROM skips the copy.

### Programs that run from the flash

`--xip` links a program with `sw/lib/link_xip.ld`: code and read-only data run in place from the flash, `crt0` copies the writable data's load image from the flash to the SRAMs, and SRAM0 holds only the jump into the flash (the ROM starts every program at SRAM0).

```sh
python fpga/regress.py --xip                 # the regression, every program from the flash
python fpga/regress.py --xip --flash-boot hello   # boots hello at power-on, running from the flash
```

`sim/run.py --xip` runs the same in simulation (a `tools/check.py` step). `XIP_SKIP` in `sim/run.py` lists the tests that cannot run from the flash, with the reason for each. On the Arty, with the board's 4 KiB instruction cache, CoreMark (1500 iterations at 50 MHz) scores 2.37 CoreMark/MHz from the flash and 2.46 from SRAM. With 2 KiB (`--icache-kb 2`) it scores 1.12 from the flash, because its hot code does not fit in the cache.

### QSPI timing

The XDC times the QSPI pins at SPI0's fastest setting, sckdiv 0, where SCK is clk / 2 (25 MHz at 50 MHz). It uses the S25FL128S data sheet values with tV at 6.5 ns, the value for a regulated 3.3 V supply and a 15 pF load, which matches the board. It adds the STARTUPE2 USRCCLKO-to-CCLK delay as the SCK clock's edge shift, because Vivado does not time that delay. The constraint values and their sources are in the XDC. `timing.rpt` covers these paths, and a negative slack fails the build. At 50 MHz, the flash-to-SPI0 read path has 0.22 ns of setup slack.
