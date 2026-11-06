<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/socctl/regs/socctl.json -->

# socctl registers

SoC control: SoC ID, reset causes, software resets, per-hart resets and boot addresses, clock dividers and scratch registers kept across system resets. APB4, 8-bit address, 32-bit registers, layout compatible with chilicon,socctl0.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR. A register array `name[N]` has N elements, element i at the offset shown.

Parameters of the register block; an array sized by one has that many elements present, the others read 0 and ignore writes:

| Parameter | Default | Description |
| --- | --- | --- |
| `N_HART` | 1 | harts with a reset and a boot address (1 .. 8) |

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [id](#id) | SoC identification (SOC_ID parameter) |
| `0x0004` | [rst_cause](#rst_cause) | Causes of the system resets since power-on (cleared only by power-on or by writing 1) |
| `0x0008` | [sysrst](#sysrst) | Software system reset: writing the key 0x52535421 ('RST!') resets every domain |
| `0x000c` | [rst_hold](#rst_hold) | Software resets of single domains: holding domain i also holds every later domain; a system reset releases every hold until rst_hold is written again |
| `0x0010` | [rst_status](#rst_status) | Reset domain state |
| `0x0014 + 0x4*i` | [clkdiv[2]](#clkdiv) | Clock divider i: clk_div[i] = clk / div (50% duty) |
| `0x001c + 0x4*i` | [scratch[2]](#scratch) | Scratch words, kept across system resets (cleared by power-on only) |
| `0x0040` | [hart_hold](#hart_hold) | Hart resets: bit h holds hart h in reset inside the CPU domain; until written after a system reset the holds are the HART_HOLD_RST parameter (secondary harts wait for the boot hart) |
| `0x0044` | [hart_status](#hart_status) | Hart reset state |
| `0x0080 + 0x8*i` | [boot_lo[8]](#boot_lo) | Boot address of hart i, bits 31:0 (kept across system resets; 0 in both words: the BOOT_ADDR parameter) |
| `0x0084 + 0x8*i` | [boot_hi[8]](#boot_hi) | Boot address of hart i, bits 63:32 |

## id

Offset `0x0000`, reset `0x0`. SoC identification (SOC_ID parameter)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | SoC ID |

## rst_cause

Offset `0x0004`, reset `0x1`. Causes of the system resets since power-on (cleared only by power-on or by writing 1)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 4 | dbg | w1c | `0x0` | Debugger reset (dbg_rst_req input: the debug module's ndmreset) |
| 3 | req | w1c | `0x0` | Reset request from IP (rst_req input, e.g. a watchdog) |
| 2 | sw | w1c | `0x0` | Software system reset (sysrst write) |
| 1 | ext | w1c | `0x0` | External reset pin |
| 0 | por | w1c | `0x1` | Power-on reset |

## sysrst

Offset `0x0008`, reset `0x0`. Software system reset: writing the key 0x52535421 ('RST!') resets every domain Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | key | wo | `0x0` | Key; other values are ignored |

## rst_hold

Offset `0x000c`, reset `0x0`. Software resets of single domains: holding domain i also holds every later domain; a system reset releases every hold until rst_hold is written again Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | dom | rw | `0x0` | Hold domain i (and every later domain) in reset |

## rst_status

Offset `0x0010`, reset `0x0`. Reset domain state

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 15:8 | dom | ro | `0x0` | Domain i is out of reset |
| 0 | done | ro | `0x0` | The release sequence after the last system reset has finished |

## clkdiv

Offset `0x0014 + 0x4*i` for i = 0 to 1, reset `0x2`. Clock divider i: clk_div[i] = clk / div (50% duty)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 15:0 | div | rw | `0x2` | Divisor (values below 2 act as 2); a new value starts with the next output period |

## scratch

Offset `0x001c + 0x4*i` for i = 0 to 1, reset `0x0`. Scratch words, kept across system resets (cleared by power-on only)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | rw | `0x0` | Software-defined |

## hart_hold

Offset `0x0040`, reset `0x0`. Hart resets: bit h holds hart h in reset inside the CPU domain; until written after a system reset the holds are the HART_HOLD_RST parameter (secondary harts wait for the boot hart) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | hart | rw | `0x0` | Hold hart h in reset (bits at and above N_HART have no effect) |

## hart_status

Offset `0x0044`, reset `0x0`. Hart reset state

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | run | ro | `0x0` | Hart h is out of reset |

## boot_lo

Offset `0x0080 + 0x8*i` for i = 0 to 7 (present: i < `N_HART`), reset `0x0`. Boot address of hart i, bits 31:0 (kept across system resets; 0 in both words: the BOOT_ADDR parameter)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | addr | rw | `0x0` | Boot address, low word |

## boot_hi

Offset `0x0084 + 0x8*i` for i = 0 to 7 (present: i < `N_HART`), reset `0x0`. Boot address of hart i, bits 63:32

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | addr | rw | `0x0` | Boot address, high word |
