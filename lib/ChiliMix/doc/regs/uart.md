<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/uart/regs/uart.json -->

# uart registers

ns16550a UART: 16-byte FIFOs, 8-bit registers on 32-bit words (reg-shift 2). APB4, 5-bit address, 32-bit registers, layout compatible with ns16550a.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [rbr](#rbr) | Receiver buffer: reading pops the RX FIFO (reads only, lcr.dlab = 0) |
| `0x0000` | [thr](#thr) | Transmitter holding: writing pushes the TX FIFO (writes only, lcr.dlab = 0) |
| `0x0000` | [dll](#dll) | Divisor latch, low byte: baud = clock / (16 * divisor) (lcr.dlab = 1) |
| `0x0004` | [ier](#ier) | Interrupt enable (lcr.dlab = 0) |
| `0x0004` | [dlm](#dlm) | Divisor latch, high byte (lcr.dlab = 1) |
| `0x0008` | [iir](#iir) | Interrupt identification: reading it clears a THR empty interrupt it reports (reads only) |
| `0x0008` | [fcr](#fcr) | FIFO control (writes only) |
| `0x000c` | [lcr](#lcr) | Line control |
| `0x0010` | [mcr](#mcr) | Modem control |
| `0x0014` | [lsr](#lsr) | Line status: reading it clears the error bits 4:1 |
| `0x0018` | [msr](#msr) | Modem status: reading it clears the delta bits 3:0 |
| `0x001c` | [scr](#scr) | Scratch |

## rbr

Offset `0x0000`, reset `0x0`. Receiver buffer: reading pops the RX FIFO (reads only, lcr.dlab = 0) Access pulses: read.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | data | ro | `0x0` | Received character (head of the RX FIFO) |

## thr

Offset `0x0000`, reset `0x0`. Transmitter holding: writing pushes the TX FIFO (writes only, lcr.dlab = 0) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | data | wo | `0x0` | Character to send |

## dll

Offset `0x0000`, reset `0x0`. Divisor latch, low byte: baud = clock / (16 * divisor) (lcr.dlab = 1)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | value | rw | `0x0` | Divisor bits 7:0 |

## ier

Offset `0x0004`, reset `0x0`. Interrupt enable (lcr.dlab = 0) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 3 | edssi | rw | `0x0` | Modem status |
| 2 | elsi | rw | `0x0` | Receiver line status (overrun, parity, framing, break) |
| 1 | etbei | rw | `0x0` | Transmitter holding register empty |
| 0 | erbfi | rw | `0x0` | Received data available and character timeout |

## dlm

Offset `0x0004`, reset `0x0`. Divisor latch, high byte (lcr.dlab = 1)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | value | rw | `0x0` | Divisor bits 15:8 |

## iir

Offset `0x0008`, reset `0x0`. Interrupt identification: reading it clears a THR empty interrupt it reports (reads only) Access pulses: read.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:6 | fifos | ro | `0x0` | 0x3 when the FIFOs are enabled |
| 3:0 | id | ro | `0x0` | 0x1 none, 0x6 line status, 0x4 data available, 0xc character timeout, 0x2 THR empty, 0x0 modem status |

## fcr

Offset `0x0008`, reset `0x0`. FIFO control (writes only) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:6 | rx_trigger | rw | `0x0` | RX FIFO interrupt level: 1, 4, 8 or 14 characters |
| 3 | dma_mode | rw | `0x0` | DMA mode select (stored, no effect: no DMA handshake pins) |
| 2 | tx_reset | wo | `0x0` | Write 1: clear the TX FIFO |
| 1 | rx_reset | wo | `0x0` | Write 1: clear the RX FIFO |
| 0 | enable | rw | `0x0` | FIFOs enabled (else one-character buffers); changing it clears both FIFOs |

## lcr

Offset `0x000c`, reset `0x0`. Line control

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7 | dlab | rw | `0x0` | Divisor latch access: offsets 0x0 and 0x4 select DLL and DLM |
| 6 | brk | rw | `0x0` | Break control: hold the TX line low |
| 5 | stick | rw | `0x0` | Stick parity: the parity bit is the inverse of eps |
| 4 | eps | rw | `0x0` | Even parity select |
| 3 | pen | rw | `0x0` | Parity enable |
| 2 | stb | rw | `0x0` | Stop bits: 0 one; 1 two (1.5 with 5-bit words) |
| 1:0 | wls | rw | `0x0` | Word length: 5 + wls bits |

## mcr

Offset `0x0010`, reset `0x0`. Modem control

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 4 | loop | rw | `0x0` | Loopback: TX feeds RX, modem outputs feed modem inputs |
| 3 | out2 | rw | `0x0` | User output 2 (DCD in loopback) |
| 2 | out1 | rw | `0x0` | User output 1 (RI in loopback) |
| 1 | rts | rw | `0x0` | Request to send (rts_n output low) |
| 0 | dtr | rw | `0x0` | Data terminal ready (dtr_n output low) |

## lsr

Offset `0x0014`, reset `0x0`. Line status: reading it clears the error bits 4:1 Access pulses: read.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7 | rxfe | ro | `0x0` | A character in the RX FIFO has a parity, framing or break error |
| 6 | temt | ro | `0x0` | Transmitter empty: TX FIFO and shift register idle |
| 5 | thre | ro | `0x0` | TX FIFO (holding register) empty |
| 4 | bi | ro | `0x0` | Break: the character at the head was a break |
| 3 | fe | ro | `0x0` | Framing error (stop bit 0) of the character at the head |
| 2 | pe | ro | `0x0` | Parity error of the character at the head of the RX FIFO |
| 1 | oe | ro | `0x0` | Overrun: a character arrived with the RX FIFO full and was lost |
| 0 | dr | ro | `0x0` | Data ready: the RX FIFO is not empty |

## msr

Offset `0x0018`, reset `0x0`. Modem status: reading it clears the delta bits 3:0 Access pulses: read.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7 | dcd | ro | `0x0` | Data carrier detect (dcd_n low) |
| 6 | ri | ro | `0x0` | Ring indicator (ri_n low) |
| 5 | dsr | ro | `0x0` | Data set ready (dsr_n low) |
| 4 | cts | ro | `0x0` | Clear to send (cts_n low) |
| 3 | ddcd | ro | `0x0` | DCD changed |
| 2 | teri | ro | `0x0` | RI went inactive |
| 1 | ddsr | ro | `0x0` | DSR changed |
| 0 | dcts | ro | `0x0` | CTS changed |

## scr

Offset `0x001c`, reset `0x0`. Scratch

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 7:0 | value | rw | `0x0` | Software scratch byte |
