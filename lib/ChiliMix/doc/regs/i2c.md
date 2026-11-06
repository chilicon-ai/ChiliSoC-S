<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/i2c/regs/i2c.json -->

# i2c registers

I2C master in the OpenCores i2c_master layout (sifive,i2c0, as the FU540): 8-bit registers on 32-bit words (reg-shift 2). APB4, 5-bit address, 32-bit registers, layout compatible with sifive,i2c0.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [prer_lo](#prer_lo) | Clock prescale, low byte: prescale = f_clk / (5 * f_scl) - 1; change it only with ctr.en clear |
| `0x0004` | [prer_hi](#prer_hi) | Clock prescale, high byte |
| `0x0008` | [ctr](#ctr) | Control |
| `0x000c` | [rxr](#rxr) | Receive: the last byte read from the bus (reads only) |
| `0x000c` | [txr](#txr) | Transmit: the next byte to write (bit 0 is R/W for an address byte) (writes only) |
| `0x0010` | [sr](#sr) | Status (reads only) |
| `0x0010` | [cr](#cr) | Command (ignored while ctr.en is clear); sta, sto, read and write clear themselves when the command finishes (writes only) |

## prer_lo

Offset `0x0000`, reset `0xff`. Clock prescale, low byte: prescale = f_clk / (5 * f_scl) - 1; change it only with ctr.en clear

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | value | rw | `0xff` | Prescale bits 7:0 |

## prer_hi

Offset `0x0004`, reset `0xff`. Clock prescale, high byte

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | value | rw | `0xff` | Prescale bits 15:8 |

## ctr

Offset `0x0008`, reset `0x0`. Control

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7 | en | rw | `0x0` | Core enable: clear holds the controller idle with both lines released and ignores cr writes |
| 6 | ien | rw | `0x0` | Interrupt enable |

## rxr

Offset `0x000c`, reset `0x0`. Receive: the last byte read from the bus (reads only)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | data | ro | `0x0` | Received byte |

## txr

Offset `0x000c`, reset `0x0`. Transmit: the next byte to write (bit 0 is R/W for an address byte) (writes only)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | data | rw | `0x0` | Byte to send |

## sr

Offset `0x0010`, reset `0x0`. Status (reads only)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7 | rxack | ro | `0x0` | Acknowledge bit of the last byte: 0 ACK, 1 NACK |
| 6 | busy | ro | `0x0` | Bus busy: a START was seen and no STOP since |
| 5 | al | ro | `0x0` | Arbitration lost (cleared by the next cr.sta) |
| 1 | tip | ro | `0x0` | Transfer in progress (a read or write command is running) |
| 0 | iflag | ro | `0x0` | Interrupt flag: a command finished or arbitration was lost (cleared by cr.iack) |

## cr

Offset `0x0010`, reset `0x0`. Command (ignored while ctr.en is clear); sta, sto, read and write clear themselves when the command finishes (writes only) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7 | sta | wo | `0x0` | Generate a (repeated) START (before the byte) |
| 6 | sto | wo | `0x0` | Generate a STOP (after the byte, with read or write) |
| 5 | read | wo | `0x0` | RD: read a byte from the bus into rxr |
| 4 | write | wo | `0x0` | WR: write txr to the bus |
| 3 | ack | wo | `0x0` | Acknowledge to send after a read: 0 ACK, 1 NACK |
| 0 | iack | wo | `0x0` | Write 1: clear the interrupt flag |
