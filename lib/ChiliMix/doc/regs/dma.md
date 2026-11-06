<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/dma/regs/dma.json -->

# dma registers

One channel of the SiFive Platform DMA (sifive,fu540-c000-pdma): Next registers software programs, Exec registers the running transfer; channel i at 0x1000 * i. APB4, 12-bit address, 32-bit registers, layout compatible with sifive,fu540-c000-pdma.

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear; `wo` write-only, not stored, reads 0. Unused words inside a block read 0; other addresses give PSLVERR.

| Offset | Register | Description |
| --- | --- | --- |
| `0x0000` | [control](#control) | Channel control and status (reads only) |
| `0x0000` | [control_w](#control_w) | Channel control: claim, start (run 0 to 1) or abort (run 1 to 0), interrupt enables; done and error are cleared by writing 0 (writes only) |
| `0x0004` | [next_config](#next_config) | Configuration of the next transfer |
| `0x0008` | [next_bytes](#next_bytes) | Bytes to transfer, bits 31:0 (bits 63:32 at 0x0c: a hole, reads 0) |
| `0x0010` | [next_dst](#next_dst) | Destination address, bits 31:0 (bits 63:32 at 0x14: a hole, reads 0) |
| `0x0018` | [next_src](#next_src) | Source address, bits 31:0 |
| `0x001c` | [next_src_hi](#next_src_hi) | Source address, bits 63:32: reads 0 (addresses are 32 bits) |
| `0x0104` | [exec_config](#exec_config) | Configuration of the running transfer |
| `0x0108` | [exec_bytes](#exec_bytes) | Bytes left in the running transfer |
| `0x0110` | [exec_dst](#exec_dst) | Next destination address of the running transfer |
| `0x0118` | [exec_src](#exec_src) | Next source address of the running transfer |
| `0x011c` | [exec_src_hi](#exec_src_hi) | Source address, bits 63:32: reads 0 |

## control

Offset `0x0000`, reset `0x0`. Channel control and status (reads only)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31 | error | ro | `0x0` | A bus error stopped the transfer (cleared by writing 0) |
| 30 | done | ro | `0x0` | The transfer finished (cleared by writing 0) |
| 15 | error_ie | ro | `0x0` | Error interrupt enable |
| 14 | done_ie | ro | `0x0` | Done interrupt enable |
| 1 | run | ro | `0x0` | A transfer runs (hardware clears it at the end, or after an abort) |
| 0 | claim | ro | `0x0` | The channel is in use |

## control_w

Offset `0x0000`, reset `0x0`. Channel control: claim, start (run 0 to 1) or abort (run 1 to 0), interrupt enables; done and error are cleared by writing 0 (writes only) Access pulses: write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31 | error | wo | `0x0` | 0 clears error |
| 30 | done | wo | `0x0` | 0 clears done |
| 15 | error_ie | wo | `0x0` | Error interrupt enable |
| 14 | done_ie | wo | `0x0` | Done interrupt enable |
| 1 | run | wo | `0x0` | 1 with run clear: copy Next to Exec and start; 0 with run set: stop after the current beat |
| 0 | claim | wo | `0x0` | Claim the channel (cannot be cleared while run is set) |

## next_config

Offset `0x0004`, reset `0x0`. Configuration of the next transfer

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:28 | rsize | rw | `0x0` | log2 of the largest read transaction (stored; accesses are at most one bus word) |
| 27:24 | wsize | rw | `0x0` | log2 of the largest write transaction (stored; accesses are at most one bus word) |
| 3 | order | rw | `0x0` | Strict ordering (always the case here: one access at a time) |
| 2 | repeat | rw | `0x0` | At the end, copy Next to Exec again and keep running |

## next_bytes

Offset `0x0008`, reset `0x0`. Bytes to transfer, bits 31:0 (bits 63:32 at 0x0c: a hole, reads 0)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | rw | `0x0` | Byte count |

## next_dst

Offset `0x0010`, reset `0x0`. Destination address, bits 31:0 (bits 63:32 at 0x14: a hole, reads 0)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | rw | `0x0` | Destination byte address |

## next_src

Offset `0x0018`, reset `0x0`. Source address, bits 31:0

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | rw | `0x0` | Source byte address |

## next_src_hi

Offset `0x001c`, reset `0x0`. Source address, bits 63:32: reads 0 (addresses are 32 bits)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | 0 |

## exec_config

Offset `0x0104`, reset `0x0`. Configuration of the running transfer

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:28 | rsize | ro | `0x0` | Read transaction size |
| 27:24 | wsize | ro | `0x0` | Write transaction size |
| 3 | order | ro | `0x0` | Strict ordering |
| 2 | repeat | ro | `0x0` | Repeat |

## exec_bytes

Offset `0x0108`, reset `0x0`. Bytes left in the running transfer

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | Bytes left |

## exec_dst

Offset `0x0110`, reset `0x0`. Next destination address of the running transfer

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | Destination byte address |

## exec_src

Offset `0x0118`, reset `0x0`. Next source address of the running transfer

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | Source byte address |

## exec_src_hi

Offset `0x011c`, reset `0x0`. Source address, bits 63:32: reads 0

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | value | ro | `0x0` | 0 |
