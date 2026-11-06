<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/spi/regs/spi.json -->

# spi registers

SPI controller in the SiFive SPI layout (sifive,spi0): single / dual / quad frames through 8-entry TX and RX FIFOs, and a memory-mapped flash read interface (XIP). APB4, 7-bit address, 32-bit registers, layout compatible with sifive,spi0.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [sckdiv](#sckdiv) | Serial clock divisor: f_sck = f_clk / (2 * (div + 1)) |
| `0x0004` | [sckmode](#sckmode) | Serial clock mode |
| `0x0010` | [csid](#csid) | Chip select ID: the cs pin the controller asserts (none for an ID at or above N_CS) |
| `0x0014` | [csdef](#csdef) | Chip select default (inactive) levels; an asserted pin is the inverse |
| `0x0018` | [csmode](#csmode) | Chip select mode |
| `0x0028` | [delay0](#delay0) | Chip select delays, in sck periods |
| `0x002c` | [delay1](#delay1) | Inter-frame delays, in sck periods |
| `0x0040` | [fmt](#fmt) | Frame format of FIFO frames |
| `0x0048` | [txdata](#txdata) | Transmit data: a write pushes a frame (ignored while full) |
| `0x004c` | [rxdata](#rxdata) | Receive data: a read pops a frame |
| `0x0050` | [txmark](#txmark) | TX watermark |
| `0x0054` | [rxmark](#rxmark) | RX watermark |
| `0x0060` | [fctrl](#fctrl) | Flash interface control: a write also empties the XIP read cache |
| `0x0064` | [ffmt](#ffmt) | Flash read instruction format: a write also empties the XIP read cache |
| `0x0070` | [ie](#ie) | Interrupt enables |
| `0x0074` | [ip](#ip) | Interrupt pending (levels) |

## sckdiv

Offset `0x0000`, reset `0x3`. Serial clock divisor: f_sck = f_clk / (2 * (div + 1))

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 11:0 | div | rw | `0x3` | Divisor |

## sckmode

Offset `0x0004`, reset `0x0`. Serial clock mode

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 1 | pol | rw | `0x0` | Polarity: idle level of sck |
| 0 | pha | rw | `0x0` | Phase: 0 sample on the leading edge, shift on the trailing edge; 1 shift on the leading edge, sample on the trailing edge |

## csid

Offset `0x0010`, reset `0x0`. Chip select ID: the cs pin the controller asserts (none for an ID at or above N_CS) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 1:0 | csid | rw | `0x0` | Chip select index |

## csdef

Offset `0x0014`, reset `0xf`. Chip select default (inactive) levels; an asserted pin is the inverse Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 3:0 | csdef | rw | `0xf` | Inactive level of cs pin i |

## csmode

Offset `0x0018`, reset `0x0`. Chip select mode Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 1:0 | mode | rw | `0x0` | 0 AUTO: assert per frame; 2 HOLD: keep asserted after the first frame until csmode, csid or csdef is written; 3 OFF: never assert (1 acts as AUTO) |

## delay0

Offset `0x0028`, reset `0x10001`. Chip select delays, in sck periods

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 23:16 | sckcs | rw | `0x1` | Last sck edge to cs deassertion |
| 7:0 | cssck | rw | `0x1` | cs assertion to the first sck edge |

## delay1

Offset `0x002c`, reset `0x1`. Inter-frame delays, in sck periods

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 23:16 | interxfr | rw | `0x0` | Delay between frames while cs stays asserted (HOLD) |
| 7:0 | intercs | rw | `0x1` | Minimum cs deasserted time |

## fmt

Offset `0x0040`, reset `0x80000`. Frame format of FIFO frames

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 19:16 | len | rw | `0x8` | Bits per frame, 0 to 8 (above 8 acts as 8) |
| 3 | dir | rw | `0x0` | 0 Rx: received frames go to the RX FIFO (dual / quad: dq pins not driven); 1 Tx: the RX FIFO is not written |
| 2 | endian | rw | `0x0` | 0 MSB first, 1 LSB first |
| 1:0 | proto | rw | `0x0` | 0 single (dq0 out, dq1 in), 1 dual (dq1:0), 2 quad (dq3:0); 3 acts as single |

## txdata

Offset `0x0048`, reset `0x0`. Transmit data: a write pushes a frame (ignored while full) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31 | full | ro | `0x0` | TX FIFO full |
| 7:0 | data | wo | `0x0` | Frame data |

## rxdata

Offset `0x004c`, reset `0x0`. Receive data: a read pops a frame Access pulses: read.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31 | empty | ro | `0x0` | RX FIFO empty: data is not valid |
| 7:0 | data | ro | `0x0` | Received frame (0 when empty) |

## txmark

Offset `0x0050`, reset `0x1`. TX watermark

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 2:0 | txmark | rw | `0x1` | ip.txwm is set while the TX FIFO holds fewer frames |

## rxmark

Offset `0x0054`, reset `0x0`. RX watermark

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 2:0 | rxmark | rw | `0x0` | ip.rxwm is set while the RX FIFO holds more frames |

## fctrl

Offset `0x0060`, reset `0x1`. Flash interface control: a write also empties the XIP read cache Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 0 | en | rw | `0x1` | Memory-mapped flash reads enabled (FIFO frames wait while set) |

## ffmt

Offset `0x0064`, reset `0x30007`. Flash read instruction format: a write also empties the XIP read cache Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:24 | pad_code | rw | `0x0` | Bits driven in the first dummy cycles (e.g. continuous-read mode bits) |
| 23:16 | cmd_code | rw | `0x3` | Command code |
| 13:12 | data_proto | rw | `0x0` | Data protocol |
| 11:10 | addr_proto | rw | `0x0` | Address and dummy protocol |
| 9:8 | cmd_proto | rw | `0x0` | Command protocol (as fmt.proto) |
| 7:4 | pad_cnt | rw | `0x0` | Dummy sck cycles after the address |
| 3:1 | addr_len | rw | `0x3` | Address bytes, 0 to 4 (above 4 acts as 4) |
| 0 | cmd_en | rw | `0x1` | Send the command code |

## ie

Offset `0x0070`, reset `0x0`. Interrupt enables

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 1 | rxwm | rw | `0x0` | RX watermark interrupt |
| 0 | txwm | rw | `0x0` | TX watermark interrupt |

## ip

Offset `0x0074`, reset `0x0`. Interrupt pending (levels)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 1 | rxwm | ro | `0x0` | RX FIFO count above rxmark |
| 0 | txwm | ro | `0x0` | TX FIFO count below txmark |
