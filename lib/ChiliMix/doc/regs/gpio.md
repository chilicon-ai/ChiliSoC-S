<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/gpio/regs/gpio.json -->

# gpio registers

GPIO for up to 32 pins with edge and level interrupts and two IO functions per pin. APB4, 7-bit address, 32-bit registers, layout compatible with sifive,gpio0.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear. Unused words inside a block read 0; other addresses give PSLVERR.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [input_val](#input_val) | Pin values (synchronized; 0 where input_en is 0) |
| `0x0004` | [input_en](#input_en) | Input enables |
| `0x0008` | [output_en](#output_en) | Output enables (pins not under an IO function) |
| `0x000c` | [output_val](#output_val) | Output values (pins not under an IO function) |
| `0x0010` | [pue](#pue) | Pull-up enables (pad control) |
| `0x0014` | [ds](#ds) | Drive strengths (pad control) |
| `0x0018` | [rise_ie](#rise_ie) | Rising-edge interrupt enables |
| `0x001c` | [rise_ip](#rise_ip) | Rising edges seen |
| `0x0020` | [fall_ie](#fall_ie) | Falling-edge interrupt enables |
| `0x0024` | [fall_ip](#fall_ip) | Falling edges seen |
| `0x0028` | [high_ie](#high_ie) | High-level interrupt enables |
| `0x002c` | [high_ip](#high_ip) | High levels seen (set again while still high) |
| `0x0030` | [low_ie](#low_ie) | Low-level interrupt enables |
| `0x0034` | [low_ip](#low_ip) | Low levels seen (set again while still low) |
| `0x0038` | [iof_en](#iof_en) | IO function enables |
| `0x003c` | [iof_sel](#iof_sel) | IO function select |
| `0x0040` | [out_xor](#out_xor) | Output inversion (after the IO function mux) |

## input_val

Offset `0x0000`, reset `0x0`. Pin values (synchronized; 0 where input_en is 0)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | ro | `0x0` | Pin i input value |

## input_en

Offset `0x0004`, reset `0x0`. Input enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i input sampled |

## output_en

Offset `0x0008`, reset `0x0`. Output enables (pins not under an IO function)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i driven |

## output_val

Offset `0x000c`, reset `0x0`. Output values (pins not under an IO function)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i output value |

## pue

Offset `0x0010`, reset `0x0`. Pull-up enables (pad control)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i pull-up on |

## ds

Offset `0x0014`, reset `0x0`. Drive strengths (pad control)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i high drive strength |

## rise_ie

Offset `0x0018`, reset `0x0`. Rising-edge interrupt enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i interrupts on rise_ip |

## rise_ip

Offset `0x001c`, reset `0x0`. Rising edges seen

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | w1c | `0x0` | Pin i input_val rose |

## fall_ie

Offset `0x0020`, reset `0x0`. Falling-edge interrupt enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i interrupts on fall_ip |

## fall_ip

Offset `0x0024`, reset `0x0`. Falling edges seen

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | w1c | `0x0` | Pin i input_val fell |

## high_ie

Offset `0x0028`, reset `0x0`. High-level interrupt enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i interrupts on high_ip |

## high_ip

Offset `0x002c`, reset `0x0`. High levels seen (set again while still high)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | w1c | `0x0` | Pin i input_val was 1 |

## low_ie

Offset `0x0030`, reset `0x0`. Low-level interrupt enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i interrupts on low_ip |

## low_ip

Offset `0x0034`, reset `0x0`. Low levels seen (set again while still low)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | w1c | `0x0` | Pin i input_val was 0 |

## iof_en

Offset `0x0038`, reset `0x0`. IO function enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i driven by IO function iof_sel |

## iof_sel

Offset `0x003c`, reset `0x0`. IO function select

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i: 0 = IOF0, 1 = IOF1 |

## out_xor

Offset `0x0040`, reset `0x0`. Output inversion (after the IO function mux)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | pin | rw | `0x0` | Pin i output inverted |
