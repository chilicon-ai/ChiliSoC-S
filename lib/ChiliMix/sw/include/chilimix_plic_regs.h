/* GENERATED FILE - DO NOT EDIT
 * Source: source/plic/regs/plic.json
 *
 * ChiliMix plic: RISC-V PLIC for 63 level-triggered sources and up to 16 contexts (hart h: M-mode 2h, S-mode 2h+1) registers.
 * Layout compatible with sifive,plic-1.0.0 (riscv,plic0).
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_PLIC_REGS_H
#define CHILIMIX_PLIC_REGS_H

#include <stdint.h>

#define CHILIMIX_PLIC_SPAN 0x400000u

/* priority: Priority of source i (0: never interrupts); source 0 at offset 0 reads 0 */
#define CHILIMIX_PLIC_PRIORITY_COUNT 63
#define CHILIMIX_PLIC_PRIORITY_FIRST 1
#define CHILIMIX_PLIC_PRIORITY_OFFSET(i) (0x0u + (i) * 0x4u)
#define CHILIMIX_PLIC_PRIORITY_RESET 0x0u
#define CHILIMIX_PLIC_PRIORITY_VALUE_SHIFT 0
#define CHILIMIX_PLIC_PRIORITY_VALUE_MASK 0x7u  /* rw */

/* pending0: Pending bits of sources 1 .. 31 (bit 0: source 0, always 0) */
#define CHILIMIX_PLIC_PENDING0_OFFSET 0x1000u
#define CHILIMIX_PLIC_PENDING0_RESET 0x0u
#define CHILIMIX_PLIC_PENDING0_SRC_SHIFT 1
#define CHILIMIX_PLIC_PENDING0_SRC_MASK 0xfffffffeu  /* ro */

/* pending1: Pending bits of sources 32 .. 63 (bit j: source 32+j) */
#define CHILIMIX_PLIC_PENDING1_OFFSET 0x1004u
#define CHILIMIX_PLIC_PENDING1_RESET 0x0u
#define CHILIMIX_PLIC_PENDING1_SRC_SHIFT 0
#define CHILIMIX_PLIC_PENDING1_SRC_MASK 0xffffffffu  /* ro */

/* enable0: Context i enables of sources 1 .. 31 */
#define CHILIMIX_PLIC_ENABLE0_COUNT 16  /* at most: elements below the N_CTX parameter exist, the others read 0 */
#define CHILIMIX_PLIC_ENABLE0_OFFSET(i) (0x2000u + (i) * 0x80u)
#define CHILIMIX_PLIC_ENABLE0_RESET 0x0u
#define CHILIMIX_PLIC_ENABLE0_SRC_SHIFT 1
#define CHILIMIX_PLIC_ENABLE0_SRC_MASK 0xfffffffeu  /* rw */

/* enable1: Context i enables of sources 32 .. 63 (bit j: source 32+j) */
#define CHILIMIX_PLIC_ENABLE1_COUNT 16  /* at most: elements below the N_CTX parameter exist, the others read 0 */
#define CHILIMIX_PLIC_ENABLE1_OFFSET(i) (0x2004u + (i) * 0x80u)
#define CHILIMIX_PLIC_ENABLE1_RESET 0x0u
#define CHILIMIX_PLIC_ENABLE1_SRC_SHIFT 0
#define CHILIMIX_PLIC_ENABLE1_SRC_MASK 0xffffffffu  /* rw */

/* threshold: Context i priority threshold */
#define CHILIMIX_PLIC_THRESHOLD_COUNT 16  /* at most: elements below the N_CTX parameter exist, the others read 0 */
#define CHILIMIX_PLIC_THRESHOLD_OFFSET(i) (0x200000u + (i) * 0x1000u)
#define CHILIMIX_PLIC_THRESHOLD_RESET 0x0u
#define CHILIMIX_PLIC_THRESHOLD_VALUE_SHIFT 0
#define CHILIMIX_PLIC_THRESHOLD_VALUE_MASK 0x7u  /* rw */

/* claim: Context i claim (read) / complete (write) */
#define CHILIMIX_PLIC_CLAIM_COUNT 16  /* at most: elements below the N_CTX parameter exist, the others read 0 */
#define CHILIMIX_PLIC_CLAIM_OFFSET(i) (0x200004u + (i) * 0x1000u)
#define CHILIMIX_PLIC_CLAIM_RESET 0x0u
#define CHILIMIX_PLIC_CLAIM_ID_SHIFT 0
#define CHILIMIX_PLIC_CLAIM_ID_MASK 0x3fu  /* ro */

#endif /* CHILIMIX_PLIC_REGS_H */
