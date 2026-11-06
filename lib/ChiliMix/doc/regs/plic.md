<!-- GENERATED FILE - DO NOT EDIT
<!-- Source: source/plic/regs/plic.json -->

# plic registers

RISC-V PLIC for 63 level-triggered sources and up to 16 contexts (hart h: M-mode 2h, S-mode 2h+1). APB4, 22-bit address, 32-bit registers, layout compatible with sifive,plic-1.0.0 (riscv,plic0).

Access: `rw` read / write; `ro` read-only, driven by the IP; `w1c` set by the IP, write 1 to clear. Unused words inside a block read 0; other addresses give PSLVERR. A register array `name[N]` has N elements, element i at the offset shown.

Parameters of the register block; an array sized by one has that many elements present, the others read 0 and ignore writes:

| Parameter | Default | Description |
| --- | --- | --- |
| `N_CTX` | 1 | contexts present (1 .. 16) |

| Offset | Register | Description |
| --- | --- | --- |
| `0x4*i` | [priority[63]](#priority) | Priority of source i (0: never interrupts); source 0 at offset 0 reads 0 |
| `0x1000` | [pending0](#pending0) | Pending bits of sources 1 .. 31 (bit 0: source 0, always 0) |
| `0x1004` | [pending1](#pending1) | Pending bits of sources 32 .. 63 (bit j: source 32+j) |
| `0x2000 + 0x80*i` | [enable0[16]](#enable0) | Context i enables of sources 1 .. 31 |
| `0x2004 + 0x80*i` | [enable1[16]](#enable1) | Context i enables of sources 32 .. 63 (bit j: source 32+j) |
| `0x200000 + 0x1000*i` | [threshold[16]](#threshold) | Context i priority threshold |
| `0x200004 + 0x1000*i` | [claim[16]](#claim) | Context i claim (read) / complete (write) |

## priority

Offset `0x4*i` for i = 1 to 63, reset `0x0`. Priority of source i (0: never interrupts); source 0 at offset 0 reads 0

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 2:0 | value | rw | `0x0` | Priority: 1 lowest, 7 highest |

## pending0

Offset `0x1000`, reset `0x0`. Pending bits of sources 1 .. 31 (bit 0: source 0, always 0)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:1 | src | ro | `0x0` | Source i is pending (gateway forwarded, not yet claimed) |

## pending1

Offset `0x1004`, reset `0x0`. Pending bits of sources 32 .. 63 (bit j: source 32+j)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | src | ro | `0x0` | Source 32+j is pending (gateway forwarded, not yet claimed) |

## enable0

Offset `0x2000 + 0x80*i` for i = 0 to 15 (present: i < `N_CTX`), reset `0x0`. Context i enables of sources 1 .. 31

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:1 | src | rw | `0x0` | Source j may interrupt context i |

## enable1

Offset `0x2004 + 0x80*i` for i = 0 to 15 (present: i < `N_CTX`), reset `0x0`. Context i enables of sources 32 .. 63 (bit j: source 32+j)

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 31:0 | src | rw | `0x0` | Source 32+j may interrupt context i |

## threshold

Offset `0x200000 + 0x1000*i` for i = 0 to 15 (present: i < `N_CTX`), reset `0x0`. Context i priority threshold

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 2:0 | value | rw | `0x0` | Only priorities above it interrupt |

## claim

Offset `0x200004 + 0x1000*i` for i = 0 to 15 (present: i < `N_CTX`), reset `0x0`. Context i claim (read) / complete (write) Access pulses: read, write.

| Bits | Field | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| 5:0 | id | ro | `0x0` | Read: claims and returns the highest-priority pending source enabled for the context (0: none). Write the ID to complete it. |
