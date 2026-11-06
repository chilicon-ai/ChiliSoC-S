/* GENERATED FILE - DO NOT EDIT
 * Source: source/aclint/regs/aclint.json
 *
 * ChiliMix aclint: RISC-V ACLINT MSWI, MTIMER and SSWI for up to 8 harts registers.
 * Layout compatible with sifive,clint0 (riscv,clint0); SSWI at +0xC000: riscv,aclint-sswi.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_ACLINT_REGS_H
#define CHILIMIX_ACLINT_REGS_H

#include <stdint.h>

#define CHILIMIX_ACLINT_SPAN 0x10000u

/* msip: Machine software interrupt pending, hart i */
#define CHILIMIX_ACLINT_MSIP_COUNT 8  /* at most: elements below the N_HART parameter exist, the others read 0 */
#define CHILIMIX_ACLINT_MSIP_OFFSET(i) (0x0u + (i) * 0x4u)
#define CHILIMIX_ACLINT_MSIP_RESET 0x0u
#define CHILIMIX_ACLINT_MSIP_PENDING_SHIFT 0
#define CHILIMIX_ACLINT_MSIP_PENDING_MASK 0x1u  /* rw */

/* mtimecmp_lo: mtimecmp bits 31:0, hart i */
#define CHILIMIX_ACLINT_MTIMECMP_LO_COUNT 8  /* at most: elements below the N_HART parameter exist, the others read 0 */
#define CHILIMIX_ACLINT_MTIMECMP_LO_OFFSET(i) (0x4000u + (i) * 0x8u)
#define CHILIMIX_ACLINT_MTIMECMP_LO_RESET 0xffffffffu
#define CHILIMIX_ACLINT_MTIMECMP_LO_VALUE_SHIFT 0
#define CHILIMIX_ACLINT_MTIMECMP_LO_VALUE_MASK 0xffffffffu  /* rw */

/* mtimecmp_hi: mtimecmp bits 63:32, hart i */
#define CHILIMIX_ACLINT_MTIMECMP_HI_COUNT 8  /* at most: elements below the N_HART parameter exist, the others read 0 */
#define CHILIMIX_ACLINT_MTIMECMP_HI_OFFSET(i) (0x4004u + (i) * 0x8u)
#define CHILIMIX_ACLINT_MTIMECMP_HI_RESET 0xffffffffu
#define CHILIMIX_ACLINT_MTIMECMP_HI_VALUE_SHIFT 0
#define CHILIMIX_ACLINT_MTIMECMP_HI_VALUE_MASK 0xffffffffu  /* rw */

/* mtime_lo: mtime bits 31:0 (writable: a write loads the counter) */
#define CHILIMIX_ACLINT_MTIME_LO_OFFSET 0xbff8u
#define CHILIMIX_ACLINT_MTIME_LO_RESET 0x0u
#define CHILIMIX_ACLINT_MTIME_LO_VALUE_SHIFT 0
#define CHILIMIX_ACLINT_MTIME_LO_VALUE_MASK 0xffffffffu  /* ro */

/* mtime_hi: mtime bits 63:32 (writable: a write loads the counter) */
#define CHILIMIX_ACLINT_MTIME_HI_OFFSET 0xbffcu
#define CHILIMIX_ACLINT_MTIME_HI_RESET 0x0u
#define CHILIMIX_ACLINT_MTIME_HI_VALUE_SHIFT 0
#define CHILIMIX_ACLINT_MTIME_HI_VALUE_MASK 0xffffffffu  /* ro */

/* setssip: Supervisor software interrupt of hart i: writing 1 sets the hart's SSIP (reads 0) */
#define CHILIMIX_ACLINT_SETSSIP_COUNT 8  /* at most: elements below the N_HART parameter exist, the others read 0 */
#define CHILIMIX_ACLINT_SETSSIP_OFFSET(i) (0xc000u + (i) * 0x4u)
#define CHILIMIX_ACLINT_SETSSIP_RESET 0x0u
#define CHILIMIX_ACLINT_SETSSIP_SET_SHIFT 0
#define CHILIMIX_ACLINT_SETSSIP_SET_MASK 0x1u  /* wo */

#endif /* CHILIMIX_ACLINT_REGS_H */
