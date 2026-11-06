# ChiliSoC-S

Chilicon's microcontroller SoC around **ChillU-S** (RV32IMC, M and U modes): the
core from [chillus](lib/chillus) on an AHB-Lite
matrix with a boot ROM, two SRAMs, a SPI flash window (XIP) and a DMA
engine, and an APB bus to the
[ChiliMix](lib/ChiliMix) peripherals (ACLINT, PLIC,
ns16550a UART, GPIO, timers / PWM and watchdog, SPI, I2C, DMA, SoC
control), all built on
[BaseChiliSV](lib/BaseChiliSV). The three are
in `lib/` (ChillU-S in full; of ChiliMix and BaseChiliSV the units the SoC uses). Every unit here is named
`chilisocs_*`;
each part lists its RTL files in `rtl.json`.

## Memory map

| Region | Base | Size | Bus |
| --- | --- | --- | --- |
| Debug module (debugger only; halt entry + `0x800`) | `0x0000_0000` | 4 KiB | I, D |
| Boot ROM (reset) | `0x0001_0000` | 64 KiB window | I, D |
| CLINT (ACLINT) | `0x0200_0000` | 64 KiB | APB |
| DMA (channel i at + `0x1000` i) | `0x0300_0000` | 16 KiB | APB |
| PLIC | `0x0C00_0000` | 4 MiB | APB |
| SoC control | `0x1000_0000` | 4 KiB | APB |
| GPIO | `0x1001_2000` | 4 KiB | APB |
| UART0 | `0x1001_3000` | 4 KiB | APB |
| SPI0 registers | `0x1001_4000` | 4 KiB | APB |
| Timers (PWM k at + `0x100` k, watchdog at + `0x400`) | `0x1001_5000` | 4 KiB | APB |
| I2C0 | `0x1001_6000` | 4 KiB | APB |
| SPI0 flash (XIP, read-only) | `0x2000_0000` | 512 MiB | I, D |
| SRAM0 (code) | `0x8000_0000` | 64 KiB | I, D |
| SRAM1 (data, stack) | `0x8001_0000` | 64 KiB | D |

SiFive FE310 addresses where one exists (DMA: the FU540 PDMA). PLIC
sources (63): 1 = UART0, 2 + i = GPIO pin i (up to 16 pins), 18 + 4k + j =
PWM k comparator j, 30 = watchdog, 31 = SPI0, 32 = I2C0, 33 + 2i / 34 + 2i =
DMA channel i done / error (two channels). PWM k comparator j drives GPIO
pin 4k + j as IO function 1; a watchdog bite resets the system (reset cause
`req`).

SPI0 (`sifive,spi0` layout, quad capable) has its own pins (`spi_*`, one
chip select); at reset its flash interface reads the window with the FE310
default instruction (0x03), and a driver can switch it to fast, dual or
quad reads. Code in the window runs through ChillU-S's 2 KiB
instruction cache (top parameter `ICACHE_KB`: 0, 2 or 4); FENCE.I empties it. I2C0 (OpenCores `i2c-ocores` layout) has open-drain pins
(`i2c_*`: the pad pulls low while `*_oe` is high). The DMA engine
(`sf-pdma` layout) is a third manager of the D bus next to the core's data
port and the debugger, so it reaches everything a load or store does.

The JTAG pins (`jtag_*`) reach the RISC-V debug unit (debug spec 1.0,
OpenOCD `riscv` target, IDCODE `0x05C05001`): halt / resume, abstract
register access, program buffer, system bus access, two hardware triggers;
its ndmreset resets everything but the debug unit (reset cause `dbg`).
The core runs M and U modes with a 4-entry PMP; its bus HPROT[1] (APB PPROT[0]) is low for
U-mode fetches and data accesses (and M-mode data accesses under MPRV). The source of truth is
[chilisocs_pkg](source/pkg/chilisocs_pkg.sv); software uses
[sw/include/chilisocs.h](sw/include/chilisocs.h) and the ChiliMix register
headers (`lib/ChiliMix/sw/include`).

## Setup and checks

```
git clone https://github.com/chilicon-ai/ChiliSoC-S.git
cd ChiliSoC-S
tools/setup.sh                       # installs every tool, about 10 minutes
source ~/chilisocs-tools/env.sh
python tools/check.py
```

`tools/setup.sh` sets up a fresh Ubuntu 24.04 (x86-64) and says what it installs,
where and why: the apt packages (with sudo), the Python packages in a venv, OSS CAD
Suite (Yosys with the slang plugin, Verilator 5), the RISC-V GCC, and Spike,
riscv-tests, CoreMark and the conformance tools at pinned versions, all under
`~/chilisocs-tools` (`--prefix` to change it). `--list` shows the plan without
changing anything; `--with openocd,debug,zephyr` adds the optional extras below.
Rerunning it skips what is already in place.

## Software

`sw/boot` is the boot ROM (jumps to SRAM0), `sw/lib` the C runtime (UART0
console, printf, traps, link script) and `sw/tests` the programs
`python sim/run.py` runs on `chilisocs_top` (list: `sim/tests.list`). A
program ends by printing `*** PASS` or `*** FAIL <code>` on UART0.
`regs` sweeps every ChiliMix register through the core; `openocd` runs a real
OpenOCD and GDB session on the JTAG pins (`sim/openocd`, needs OpenOCD and
a RISC-V `gdb`): GDB loads the program into the empty SRAMs and debugs it.
`tools/install_openocd.sh` builds OpenOCD from a pinned upstream commit
into `~/openocd` (used first); the 0.12.0 release also works.
`sim/openocd/chilisocs.cfg` is also the starting point for a board.
`stress` is seeded random stress (`python sim/run.py stress --seed <n>`):
interrupt storms with nested traps and exceptions inside handlers, U/M
switches with syscalls, DMA copies on both channels and, from the
testbench's debugger, system bus bursts and halts, all at once and every
result checked. `--param MEM_WAIT=<n>` adds 1 .. n random wait states to
every ROM / SRAM transfer (`basechili_ahb_wait`); `tools/check.py` runs the
whole regression that way too, plus more stress seeds.
`python sim/debug/run.py` runs the riscv-tests debug suite (gdbserver.py:
breakpoints, triggers, stepping, memory and register access, privilege
modes, semihosting) on the model, one fresh model per test; it is not part
of `tools/check.py` (it takes tens of minutes). `tools/install_debug_tests.sh`
installs its riscv-tests checkout and the xPack toolchain its CI uses.

## Zephyr

`sw/zephyr` is a Zephyr module with the SoC (`chilisocs`) and the board
`chilisocs_sim` (the Verilator testbench: SRAM0, the SRAM on the instruction
bus, is Zephyr's flash and SRAM1 its RAM, a notional
4 MHz clock, the testbench's GPIO loopback and I2C EEPROM). Every peripheral
uses Zephyr's own driver; the DMA has none. `python sim/zephyr/run.py` runs
twister on a set of samples and kernel, driver and user-mode tests, each on
the model through the board's custom simulator (`west build -t run` does the
same for one app); it is not part of `tools/check.py`. `tools/install_zephyr.sh`
installs Zephyr, its SDK and twister's packages at pinned versions and applies
`sw/zephyr/patches`.

- Code and read-only data must fit SRAM0 (64 KiB) and data SRAM1 (64 KiB),
  so the kernel tests run their ztest user cases in supervisor mode (user
  partitions cost PMP alignment); the user-mode / PMP tests run as they are.
  Twister skips a scenario that does not fit (today `kernel.common`, the
  EEPROM test, `hello_world_user` and two of the three user-mode suites).
  GP-relative addressing is off: with read-only data in SRAM0, linker
  relaxation puts some of it out of `gp`'s reach and links fail.
- Four PMP regions leave no room for Zephyr's per-thread hardware stack
  guard, so the tests leave it off.
- The PLIC follows the spec and ignores a complete of a disabled source.
  Zephyr's PLIC driver completes after the ISR, so a source the ISR disabled
  would stay claimed; `sw/zephyr/patches` fixes the driver (not yet
  upstream).

## Performance

Measured with the flows in this repository, so you can reproduce them:

| | |
|---|---|
| CoreMark/MHz | 2.46 from SRAM, 2.37 from the QSPI flash (4 KiB instruction cache): GCC `-O2`, 1500 iterations on the Arty A7-100T (`sim/run.py coremark` gives 2.44 in simulation) |
| CoreMark/MHz, tuned flags | 3.21: ChillU-S in simulation, GCC `-O3 -funroll-all-loops -finline-limit=600 -falign-jumps=4 -falign-loops=4` |
| ChillU-S area | 43.3 kGE (NAND2-equivalent cell area, timing-clean ORFS run on its open 45 nm platform): default configuration, RV32IMC with 4 PMP regions, no cache |
| ChillU-S clock | over 30% higher than comparable three-stage RV32IMC cores with the same PMP, in less area: same ORFS flow and platform, timing-clean |
| ChiliSoC-S area | 132 kGE of logic with the 2 KiB instruction cache; the memories (SRAM macros) come on top |

## FPGA

The SoC runs on a Digilent Arty A7-100T: `fpga/` has the board top, the
Vivado build, flash boot and the regression on the board (JTAG load, UART
result). See [fpga/README.md](fpga/README.md).

## Contributing

This repository is published from Chilicon's development repositories: `lib/`
holds ChillU-S and the ChiliMix and BaseChiliSV units the SoC uses, a subset of
larger libraries. Issues and pull requests are welcome; accepted changes are
applied upstream and arrive here with the next publish.

## Need a variant?

ChiliSoC-S and its IP are designed with Red Chili, Chilicon's project
intelligence for chip-design teams and their AI agents.
[Request a Pilot](https://chilicon.ai/pilot).

Other peripherals, another memory map, bus or core configuration: Chilicon
builds customized versions of this SoC and its IP. [Contact us](https://chilicon.ai/contact).

## License

Licensed under the Apache License 2.0 (SPDX: `Apache-2.0`): see [LICENSE](LICENSE) and [NOTICE](NOTICE).
