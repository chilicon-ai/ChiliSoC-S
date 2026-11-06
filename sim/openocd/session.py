# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
"""GDB session against ChiliSoC-S in simulation (GDB Python, run by sim/run.py).

  gdb -batch -ex "set $gdb_port = <n>" -x sim/openocd/session.py <program>.elf

The program is sw/tests/openocd.c, the SRAMs start empty. Every step prints
"gdb check ok: ..." or stops with "gdb check FAILED: ..."; the last line is
"gdb session done: <n> checks". Steps: reset halt at the boot ROM, load the
program over the debug module (program buffer and system bus access),
compare it, software breakpoint, hardware breakpoint, register and memory
access in debug mode, single step, software watchpoint, CSRs, then detach so the
program runs to its end.
"""

import gdb

ROM_BASE = 0x0001_0000
ROM_WORD0 = 0x800002B7          # boot ROM: lui t0, 0x80000
POKE = 0x600DF00D
checks = 0


def ex(cmd: str) -> str:
    out = gdb.execute(cmd, to_string=True)
    for line in out.splitlines():
        print(f"  | {line}")
    return out


def val(expr: str) -> int:
    return int(gdb.parse_and_eval(expr)) & 0xFFFF_FFFF


def check(ok: bool, what: str) -> None:
    global checks
    if not ok:
        print(f"gdb check FAILED: {what}")
        raise gdb.GdbError(what)
    checks += 1
    print(f"gdb check ok: {what}")


def var(name: str) -> str:
    """A program variable as a 32-bit lvalue (the program has no debug info)"""
    return f"*(unsigned int *)&{name}"


def function() -> str:
    """Symbol of the pc (the program has no debug info): function name only"""
    out = gdb.execute("info symbol $pc", to_string=True)
    return out.split()[0] if " in section" in out else "?"


ex("set pagination off")
ex("set confirm off")
ex("set remotetimeout 600")
ex(f"target extended-remote :{val('$gdb_port')}")

ex("monitor reset halt")
ex("maintenance flush register-cache")         # GDB does not know a monitor command reset the hart
check(val("$pc") == ROM_BASE, f"reset halt at the boot ROM (pc {val('$pc'):#x})")

ex("load")
out = ex("compare-sections")
check("MIS-MATCHED" not in out and "matched" in out, "program loaded and compared")

ex("break main")
ex("continue")
check(function() == "main", "software breakpoint at main")
check(val("$sp") >> 16 == 0x8001 or val("$sp") == 0x8002_0000, f"sp {val('$sp'):#x} in SRAM1")

# The 0.12.0 release uses a trigger only if tdata1 already reads type 2 or 6;
# the core's idle triggers read type 15 (disabled, as Spike's), so with it the
# session selects mcontrol6 (execute 0: still off) first. Newer OpenOCD picks
# the type from tinfo (tools/install_openocd.sh).
version = gdb.execute("monitor version", to_string=True).strip()
print(f"  | {version}")
if "0.12.0" in version and "+dev" not in version:
    ex("set $tselect = 0")
    ex("set $tdata1 = 0x60000000")
    check(val("$tdata1") >> 28 == 6, "trigger 0 set to mcontrol6 (OpenOCD 0.12.0)")
ex("hbreak *add3")                               # the entry: a0 still holds the argument
ex(f"set var {var('go')} = 1")
ex("continue")
check(function() == "add3" and val("$a0") == 39, f"hardware breakpoint at add3, a0 {val('$a0')}")
ex(f"set var {var('poked')} = {POKE:#x}")
check(val(var("poked")) == POKE, "variable written in debug mode")

pc = val("$pc")
ex("stepi")
check(val("$pc") in (pc + 2, pc + 4), f"single step {pc:#x} -> {val('$pc'):#x}")
ex("delete")

ex("set can-use-hw-watchpoints 0")             # the core's triggers match execute addresses only
ex(f"watch {var('result')}")
ex("continue")
check(function() == "main" and val(var("result")) == 42, f"watchpoint on result ({val(var('result'))})")
ex("delete")

misa = val("$misa")
check(misa >> 30 == 1 and all(misa >> (ord(c) - ord("A")) & 1 for c in "IMCU"), f"misa {misa:#x}: RV32 I M C U")
check(val("$dcsr") >> 28 == 4, f"dcsr {val('$dcsr'):#x}: external debug 1.0")

for access in ("sysbus", "progbuf"):
    ex(f"monitor riscv set_mem_access {access}")
    check(val(f"*(unsigned int *){ROM_BASE:#x}") == ROM_WORD0, f"boot ROM read with {access}")
    ex(f"set var {var('calls')} = {7 + len(access)}")
    check(val(var("calls")) == 7 + len(access), f"SRAM1 written and read with {access}")
ex(f"set var {var('calls')} = 1")

ex("detach")
print(f"gdb session done: {checks} checks")
