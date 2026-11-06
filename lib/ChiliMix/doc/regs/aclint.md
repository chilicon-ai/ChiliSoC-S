<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/aclint/regs/aclint.json -->

# aclint registers

RISC-V ACLINT MSWI, MTIMER and SSWI for up to 8 harts. APB4, 16-bit address, 32-bit registers, layout compatible with sifive,clint0 (riscv,clint0); SSWI at +0xC000: riscv,aclint-sswi.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR. A register array `name[N]` has N elements, element i at the offset shown.

Parameters of the register block; an array sized by one has that many elements present, the others read 0 and ignore writes:

| Parameter | Default | Description |
| --- | --- | --- |
| `N_HART` | 1 | harts present (1 .. 8) |

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000 + 0x4*i` | [msip[8]](#msip) | Machine software interrupt pending, hart i |
| `0x4000 + 0x8*i` | [mtimecmp_lo[8]](#mtimecmp_lo) | mtimecmp bits 31:0, hart i |
| `0x4004 + 0x8*i` | [mtimecmp_hi[8]](#mtimecmp_hi) | mtimecmp bits 63:32, hart i |
| `0xbff8` | [mtime_lo](#mtime_lo) | mtime bits 31:0 (writable: a write loads the counter) |
| `0xbffc` | [mtime_hi](#mtime_hi) | mtime bits 63:32 (writable: a write loads the counter) |
| `0xc000 + 0x4*i` | [setssip[8]](#setssip) | Supervisor software interrupt of hart i: writing 1 sets the hart's SSIP (reads 0) |

## msip

Offset `0x0000 + 0x4*i` for i = 0 to 7 (present: i < `N_HART`), reset `0x0`. Machine software interrupt pending, hart i

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 0 | pending | rw | `0x0` | MSIP: drives the hart's machine software interrupt |

## mtimecmp_lo

Offset `0x4000 + 0x8*i` for i = 0 to 7 (present: i < `N_HART`), reset `0xffffffff`. mtimecmp bits 31:0, hart i

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | rw | `0xffffffff` | Compare value, low word |

## mtimecmp_hi

Offset `0x4004 + 0x8*i` for i = 0 to 7 (present: i < `N_HART`), reset `0xffffffff`. mtimecmp bits 63:32, hart i

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | rw | `0xffffffff` | Compare value, high word |

## mtime_lo

Offset `0xbff8`, reset `0x0`. mtime bits 31:0 (writable: a write loads the counter) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | Time, low word |

## mtime_hi

Offset `0xbffc`, reset `0x0`. mtime bits 63:32 (writable: a write loads the counter) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | Time, high word |

## setssip

Offset `0xc000 + 0x4*i` for i = 0 to 7 (present: i < `N_HART`), reset `0x0`. Supervisor software interrupt of hart i: writing 1 sets the hart's SSIP (reads 0) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 0 | set | wo | `0x0` | Write 1: set the hart's mip.SSIP |
