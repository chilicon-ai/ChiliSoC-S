<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/timer/regs/timer_pwm.json -->

# timer_pwm registers

PWM / timer with four 16-bit comparators in the SiFive PWM layout: a 31-bit counter, a power-of-2 scaled view pwms and per-comparator interrupts and outputs. APB4, 6-bit address, 32-bit registers, layout compatible with sifive,pwm0.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear. Unused words inside a block read 0; other addresses give PSLVERR. A register array `name[N]` has N elements, element i at the offset shown.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [cfg](#cfg) | pwmcfg: configuration and interrupt pending bits |
| `0x0008` | [count](#count) | pwmcount: the counter (writable: a write loads the strobed bytes) |
| `0x0010` | [s](#s) | pwms: scaled counter, pwmcount bits pwmscale + 15 .. pwmscale |
| `0x0020 + 0x4*i` | [cmp[4]](#cmp) | pwmcmpX: comparator X |

## cfg

Offset `0x0000`, reset `0x0`. pwmcfg: configuration and interrupt pending bits Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:28 | ip | ro | `0x0` | pwmcmpXip (written through the write pulse): comparator X matched; drives interrupt X |
| 27:24 | gang | rw | `0x0` | pwmcmpXgang: output X is low while ip X+1 (mod 4) is set |
| 23:20 | invert | rw | `0x0` | pwminvertX: invert output X |
| 19:16 | center | rw | `0x0` | pwmcmpXcenter: compare the folded pwms (center-aligned) |
| 13 | oneshot | ro | `0x0` | pwmenoneshot (written through the write pulse): count until the next counter restart, then clear |
| 12 | enalways | rw | `0x0` | pwmenalways: count continuously |
| 10 | deglitch | rw | `0x0` | pwmdeglitch: ip bits stay set until the period ends |
| 9 | zerocmp | rw | `0x0` | pwmzerocmp: pwmcount restarts at 0 once pwms >= pwmcmp0 |
| 8 | sticky | rw | `0x0` | pwmsticky: ip bits stay set until written 0 |
| 3:0 | scale | rw | `0x0` | pwmscale: pwms = pwmcount >> pwmscale |

## count

Offset `0x0008`, reset `0x0`. pwmcount: the counter (writable: a write loads the strobed bytes) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 30:0 | value | ro | `0x0` | Counter |

## s

Offset `0x0010`, reset `0x0`. pwms: scaled counter, pwmcount bits pwmscale + 15 .. pwmscale

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 15:0 | value | ro | `0x0` | Scaled counter |

## cmp

Offset `0x0020 + 0x4*i` for i = 0 to 3, reset `0xffff`. pwmcmpX: comparator X

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 15:0 | value | rw | `0xffff` | Compare value (ip X sets while pwms >= value) |
