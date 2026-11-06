# ChillU-S

ChillU-S is Chilicon's small RISC-V core: RV32IMC with machine and user mode,
a three-stage in-order pipeline (decode, execute, write-back) behind a
prefetching fetch unit. It is the CPU of [ChiliSoC-S](../../README.md) and is
built from [BaseChiliSV](../BaseChiliSV) units. Its RTL files are listed in
`source/ChillUS/rtl.json`.

## Features

- **ISA:** RV32I, M, C, Zicsr, Zifencei, Zicntr (`cycle`, `time`, `instret`);
  `misa` reads I, M, C, U.
- **Privilege:** machine and user mode (all traps to M), `mcounteren`,
  `mstatus.MPRV` / `TW`. Every bus access carries its privilege.
- **PMP:** up to 4 entries (`PMP_REGIONS`, default 4; 0 removes it), OFF / TOR
  / NA4 / NAPOT, lock, 4-byte grain.
- **Interrupts:** machine software, timer and external, 15 local interrupts
  (`irq_fast`, causes 16-30), a non-maskable interrupt (`irq_nmi`) and vectored
  `mtvec`.
- **Debug:** Sdext debug mode for an external debug module (halt, resume,
  single step, `ebreak`) and Sdtrig execute-address triggers
  (`NUM_TRIGGERS`, default 0).
- **Sleep:** `wfi` drains the pipeline, raises `core_sleep` and stops the
  core clock (one clock gate) until an enabled interrupt, an NMI or
  `debug_req` wakes it.
- **Pipeline:** static branch prediction (JAL and short backward branches
  taken), operand forwarding, a one-cycle low-half multiplier and an
  iterative unit for MULH* and divide.
- **Register file:** in latches (`RF_LATCH = 1`, default) or flops.
- **Memory ports:** separate instruction and data ports (req / gnt, then
  rvalid / rdata / err). `chillus_ahb` wraps the core with AHB-Lite instruction
  and data managers for SoC integration, with no added latency.
- **Instruction cache (optional):** `ICACHE_KB` 0, 2 or 4 (2-way, 16-byte
  lines), for code in slow memory such as a SPI flash.
- **Trace:** an RVFI retirement port for verification.

Not supported: supervisor mode, the A / F / D extensions, hardware
performance counters (the counter CSRs read 0), misaligned loads and
stores in hardware (they trap) and a writable `misa`.

## Using it

Instantiate `chillus_ahb` (AHB-Lite instruction and data managers) or, for
your own bus, `chillus_core` (the req / gnt ports directly). Parameters:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `RF_LATCH` | 1 | register file in latches (0: flops, e.g. for FPGA) |
| `DEBUG` | 1 | Sdext debug mode (0: none) |
| `NUM_TRIGGERS` | 0 | Sdtrig execute-address triggers |
| `PMP_REGIONS` | 4 | PMP entries, 0..4 |
| `ICACHE_KB` | 0 | instruction cache: 0, 2 or 4 KiB |
| `ICACHE_BASE`, `ICACHE_MASK` | 0, 0 | cacheable fetches: `(addr & MASK) == BASE` |
| `DM_HALT_ADDR`, `DM_EXCEPTION_ADDR` | | debug module entry points |

Inputs: `boot_addr` (first instruction, reset `mtvec`), `hart_id`,
`fetch_enable`, the interrupt lines, `debug_req` and `mtime`. Each port's
comment in `source/ChillUS/core/chillus_core.sv` gives its timing.

## Verification

```
python sim/run.py                # the regression (sim/tests/regression.list), against Spike
python sim/run.py coremark       # CoreMark/MHz (--iterations N)
python sim/run.py --istall 40 --dstall 40 --seed 3   # with random memory stalls
python sim/unit.py               # unit testbenches (sim/tb/, sim/unit_tests.json)
python sim/conformance/run_act.py   # riscv-arch-test against the Sail model
```

`sim/run.py` runs each program on the core in Verilator and on Spike, and
compares the core's RVFI trace with Spike's commit log instruction by
instruction: riscv-tests (`rv32ui`, `rv32um`, `rv32uc`, `rv32mi`), ChillU-S's
own sequence tests (hazards, control flow, traps, debug, PMP), random
instruction sequences and CoreMark. Invariant checkers (`sim/checkers/`) are
bound into every build and stop the simulation on a violation.
`run_act.py` runs the RISC-V Architectural Compatibility Tests (riscv-arch-test
3.x through RISCOF) against the Sail formal model.

Tools: Verilator 5, Spike and `riscv64-unknown-elf-gcc` on `PATH`;
riscv-tests in `$RISCV_TESTS` and CoreMark in `$COREMARK`; for conformance,
RISCOF, riscv-arch-test and a sail-riscv binary. The top-level
`tools/setup.sh` installs all of them at the versions tested and writes the
environment file that sets these variables (see the [top-level
README](../../README.md)).

## Synthesis and physical design

`python tools/lint.py` (slang) and `python tools/synth.py` (Yosys with the
slang plugin) check the RTL. `syn/orfs/run.sh chillus` runs the core through
OpenROAD-flow-scripts on its open 45 nm platform, and `syn/orfs/ppa.py`
summarizes a run.

## License

Apache License 2.0, as the rest of this repository: see the top-level
[LICENSE](../../LICENSE).
