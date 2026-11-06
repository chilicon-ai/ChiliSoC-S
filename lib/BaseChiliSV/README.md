# BaseChiliSV

Chilicon's bottom-up, parameterized, synthesizable SystemVerilog module library:
here the units ChiliSoC-S and ChillU-S use (listed in `rtl.json`), each with its
invariant checker (`sim/checkers/`) and self-checking testbench (`sim/tb/`).

```
python tools/lint.py     # slang, every warning
python tools/synth.py    # Yosys + yosys-slang
python tools/sim.py      # the testbenches (sim/tests.json), Verilator
python tools/check.py    # all of the above plus Verilator lint and the RTL rules
```
