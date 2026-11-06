/* GENERATED FILE - DO NOT EDIT
 * Source: source/socctl/regs/socctl.json
 *
 * ChiliMix socctl: SoC control: SoC ID, reset causes, software resets, per-hart resets and boot addresses, clock dividers and scratch registers kept across system resets registers.
 * Layout compatible with chilicon,socctl0.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_SOCCTL_REGS_H
#define CHILIMIX_SOCCTL_REGS_H

#include <stdint.h>

#define CHILIMIX_SOCCTL_SPAN 0x100u

/* id: SoC identification (SOC_ID parameter) */
#define CHILIMIX_SOCCTL_ID_OFFSET 0x0u
#define CHILIMIX_SOCCTL_ID_RESET 0x0u
#define CHILIMIX_SOCCTL_ID_VALUE_SHIFT 0
#define CHILIMIX_SOCCTL_ID_VALUE_MASK 0xffffffffu  /* ro */

/* rst_cause: Causes of the system resets since power-on (cleared only by power-on or by writing 1) */
#define CHILIMIX_SOCCTL_RST_CAUSE_OFFSET 0x4u
#define CHILIMIX_SOCCTL_RST_CAUSE_RESET 0x1u
#define CHILIMIX_SOCCTL_RST_CAUSE_POR_SHIFT 0
#define CHILIMIX_SOCCTL_RST_CAUSE_POR_MASK 0x1u  /* w1c */
#define CHILIMIX_SOCCTL_RST_CAUSE_EXT_SHIFT 1
#define CHILIMIX_SOCCTL_RST_CAUSE_EXT_MASK 0x2u  /* w1c */
#define CHILIMIX_SOCCTL_RST_CAUSE_SW_SHIFT 2
#define CHILIMIX_SOCCTL_RST_CAUSE_SW_MASK 0x4u  /* w1c */
#define CHILIMIX_SOCCTL_RST_CAUSE_REQ_SHIFT 3
#define CHILIMIX_SOCCTL_RST_CAUSE_REQ_MASK 0x8u  /* w1c */
#define CHILIMIX_SOCCTL_RST_CAUSE_DBG_SHIFT 4
#define CHILIMIX_SOCCTL_RST_CAUSE_DBG_MASK 0x10u  /* w1c */

/* sysrst: Software system reset: writing the key 0x52535421 ('RST!') resets every domain */
#define CHILIMIX_SOCCTL_SYSRST_OFFSET 0x8u
#define CHILIMIX_SOCCTL_SYSRST_RESET 0x0u
#define CHILIMIX_SOCCTL_SYSRST_KEY_SHIFT 0
#define CHILIMIX_SOCCTL_SYSRST_KEY_MASK 0xffffffffu  /* wo */

/* rst_hold: Software resets of single domains: holding domain i also holds every later domain; a system reset releases every hold until rst_hold is written again */
#define CHILIMIX_SOCCTL_RST_HOLD_OFFSET 0xcu
#define CHILIMIX_SOCCTL_RST_HOLD_RESET 0x0u
#define CHILIMIX_SOCCTL_RST_HOLD_DOM_SHIFT 0
#define CHILIMIX_SOCCTL_RST_HOLD_DOM_MASK 0xffu  /* rw */

/* rst_status: Reset domain state */
#define CHILIMIX_SOCCTL_RST_STATUS_OFFSET 0x10u
#define CHILIMIX_SOCCTL_RST_STATUS_RESET 0x0u
#define CHILIMIX_SOCCTL_RST_STATUS_DONE_SHIFT 0
#define CHILIMIX_SOCCTL_RST_STATUS_DONE_MASK 0x1u  /* ro */
#define CHILIMIX_SOCCTL_RST_STATUS_DOM_SHIFT 8
#define CHILIMIX_SOCCTL_RST_STATUS_DOM_MASK 0xff00u  /* ro */

/* clkdiv: Clock divider i: clk_div[i] = clk / div (50% duty) */
#define CHILIMIX_SOCCTL_CLKDIV_COUNT 2
#define CHILIMIX_SOCCTL_CLKDIV_OFFSET(i) (0x14u + (i) * 0x4u)
#define CHILIMIX_SOCCTL_CLKDIV_RESET 0x2u
#define CHILIMIX_SOCCTL_CLKDIV_DIV_SHIFT 0
#define CHILIMIX_SOCCTL_CLKDIV_DIV_MASK 0xffffu  /* rw */

/* scratch: Scratch words, kept across system resets (cleared by power-on only) */
#define CHILIMIX_SOCCTL_SCRATCH_COUNT 2
#define CHILIMIX_SOCCTL_SCRATCH_OFFSET(i) (0x1cu + (i) * 0x4u)
#define CHILIMIX_SOCCTL_SCRATCH_RESET 0x0u
#define CHILIMIX_SOCCTL_SCRATCH_VALUE_SHIFT 0
#define CHILIMIX_SOCCTL_SCRATCH_VALUE_MASK 0xffffffffu  /* rw */

/* hart_hold: Hart resets: bit h holds hart h in reset inside the CPU domain; until written after a system reset the holds are the HART_HOLD_RST parameter (secondary harts wait for the boot hart) */
#define CHILIMIX_SOCCTL_HART_HOLD_OFFSET 0x40u
#define CHILIMIX_SOCCTL_HART_HOLD_RESET 0x0u
#define CHILIMIX_SOCCTL_HART_HOLD_HART_SHIFT 0
#define CHILIMIX_SOCCTL_HART_HOLD_HART_MASK 0xffu  /* rw */

/* hart_status: Hart reset state */
#define CHILIMIX_SOCCTL_HART_STATUS_OFFSET 0x44u
#define CHILIMIX_SOCCTL_HART_STATUS_RESET 0x0u
#define CHILIMIX_SOCCTL_HART_STATUS_RUN_SHIFT 0
#define CHILIMIX_SOCCTL_HART_STATUS_RUN_MASK 0xffu  /* ro */

/* boot_lo: Boot address of hart i, bits 31:0 (kept across system resets; 0 in both words: the BOOT_ADDR parameter) */
#define CHILIMIX_SOCCTL_BOOT_LO_COUNT 8  /* at most: elements below the N_HART parameter exist, the others read 0 */
#define CHILIMIX_SOCCTL_BOOT_LO_OFFSET(i) (0x80u + (i) * 0x8u)
#define CHILIMIX_SOCCTL_BOOT_LO_RESET 0x0u
#define CHILIMIX_SOCCTL_BOOT_LO_ADDR_SHIFT 0
#define CHILIMIX_SOCCTL_BOOT_LO_ADDR_MASK 0xffffffffu  /* rw */

/* boot_hi: Boot address of hart i, bits 63:32 */
#define CHILIMIX_SOCCTL_BOOT_HI_COUNT 8  /* at most: elements below the N_HART parameter exist, the others read 0 */
#define CHILIMIX_SOCCTL_BOOT_HI_OFFSET(i) (0x84u + (i) * 0x8u)
#define CHILIMIX_SOCCTL_BOOT_HI_RESET 0x0u
#define CHILIMIX_SOCCTL_BOOT_HI_ADDR_SHIFT 0
#define CHILIMIX_SOCCTL_BOOT_HI_ADDR_MASK 0xffffffffu  /* rw */

#endif /* CHILIMIX_SOCCTL_REGS_H */
