<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/timer/regs/timer_wdog.json -->

# timer_wdog registers

Watchdog in the SiFive AON watchdog layout: a key-unlocked 31-bit counter with a power-of-2 scale, one 16-bit comparator, an interrupt and a reset request. APB4, 6-bit address, 32-bit registers, layout compatible with sifive,wdt.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [cfg](#cfg) | wdogcfg: configuration and interrupt pending (writes need the key) |
| `0x0008` | [count](#count) | wdogcount: the counter (writes need the key and load the strobed bytes) |
| `0x0010` | [s](#s) | wdogs: scaled counter, wdogcount bits wdogscale + 15 .. wdogscale |
| `0x0018` | [feed](#feed) | wdogfeed: writing 0x0D09F00D (with the key) restarts the counter |
| `0x001c` | [key](#key) | wdogkey: writing 0x0051F15E unlocks the next write; any other write locks again |
| `0x0020` | [cmp0](#cmp0) | wdogcmp0: comparator (writes need the key) |

## cfg

Offset `0x0000`, reset `0x0`. wdogcfg: configuration and interrupt pending (writes need the key) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 28 | ip0 | ro | `0x0` | wdogip0: wdogs reached wdogcmp0; drives the interrupt |
| 13 | coreawake | ro | `0x0` | wdogcoreawake: count on every tick while the core is awake |
| 12 | enalways | ro | `0x0` | wdogenalways: count on every tick |
| 9 | zerocmp | ro | `0x0` | wdogzerocmp: wdogcount restarts at 0 once wdogs >= wdogcmp0 |
| 8 | rsten | ro | `0x0` | wdogrsten: a match requests a reset |
| 3:0 | scale | ro | `0x0` | wdogscale: wdogs = wdogcount >> wdogscale |

## count

Offset `0x0008`, reset `0x0`. wdogcount: the counter (writes need the key and load the strobed bytes) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 30:0 | value | ro | `0x0` | Counter |

## s

Offset `0x0010`, reset `0x0`. wdogs: scaled counter, wdogcount bits wdogscale + 15 .. wdogscale

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 15:0 | value | ro | `0x0` | Scaled counter |

## feed

Offset `0x0018`, reset `0x0`. wdogfeed: writing 0x0D09F00D (with the key) restarts the counter Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | wo | `0x0` | Feed value |

## key

Offset `0x001c`, reset `0x0`. wdogkey: writing 0x0051F15E unlocks the next write; any other write locks again Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 0 | unlocked | ro | `0x0` | The next write is allowed |

## cmp0

Offset `0x0020`, reset `0x0`. wdogcmp0: comparator (writes need the key) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 15:0 | value | ro | `0x0` | Compare value (ip0 sets once wdogs >= value) |
