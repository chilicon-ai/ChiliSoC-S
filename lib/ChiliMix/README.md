# ChiliMix

Chilicon's SoC IP library, built on BaseChiliSV: here the IP ChiliSoC-S uses
(listed in `rtl.json`). Register layouts copy the standard ones (ns16550,
SiFive PLIC / CLINT / GPIO / SPI, OpenCores I2C, SiFive PDMA) so existing
drivers work; `doc/regs/` documents every register and `sw/include/` has the C
headers.

```
python tools/lint.py     # slang, every warning
python tools/synth.py    # Yosys + yosys-slang
python tools/sim.py      # the testbenches (sim/tests.json), Verilator
```
