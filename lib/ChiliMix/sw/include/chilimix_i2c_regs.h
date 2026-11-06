/* GENERATED FILE - DO NOT EDIT
 * Source: source/i2c/regs/i2c.json
 *
 * ChiliMix i2c: I2C master in the OpenCores i2c_master layout (sifive,i2c0, as the FU540): 8-bit registers on 32-bit words (reg-shift 2) registers.
 * Layout compatible with sifive,i2c0.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_I2C_REGS_H
#define CHILIMIX_I2C_REGS_H

#include <stdint.h>

#define CHILIMIX_I2C_SPAN 0x20u

/* prer_lo: Clock prescale, low byte: prescale = f_clk / (5 * f_scl) - 1; change it only with ctr.en clear */
#define CHILIMIX_I2C_PRER_LO_OFFSET 0x0u
#define CHILIMIX_I2C_PRER_LO_RESET 0xffu
#define CHILIMIX_I2C_PRER_LO_VALUE_SHIFT 0
#define CHILIMIX_I2C_PRER_LO_VALUE_MASK 0xffu  /* rw */

/* prer_hi: Clock prescale, high byte */
#define CHILIMIX_I2C_PRER_HI_OFFSET 0x4u
#define CHILIMIX_I2C_PRER_HI_RESET 0xffu
#define CHILIMIX_I2C_PRER_HI_VALUE_SHIFT 0
#define CHILIMIX_I2C_PRER_HI_VALUE_MASK 0xffu  /* rw */

/* ctr: Control */
#define CHILIMIX_I2C_CTR_OFFSET 0x8u
#define CHILIMIX_I2C_CTR_RESET 0x0u
#define CHILIMIX_I2C_CTR_IEN_SHIFT 6
#define CHILIMIX_I2C_CTR_IEN_MASK 0x40u  /* rw */
#define CHILIMIX_I2C_CTR_EN_SHIFT 7
#define CHILIMIX_I2C_CTR_EN_MASK 0x80u  /* rw */

/* rxr: Receive: the last byte read from the bus (reads only) */
#define CHILIMIX_I2C_RXR_OFFSET 0xcu
#define CHILIMIX_I2C_RXR_RESET 0x0u
#define CHILIMIX_I2C_RXR_DATA_SHIFT 0
#define CHILIMIX_I2C_RXR_DATA_MASK 0xffu  /* ro */

/* txr: Transmit: the next byte to write (bit 0 is R/W for an address byte) (writes only) */
#define CHILIMIX_I2C_TXR_OFFSET 0xcu
#define CHILIMIX_I2C_TXR_RESET 0x0u
#define CHILIMIX_I2C_TXR_DATA_SHIFT 0
#define CHILIMIX_I2C_TXR_DATA_MASK 0xffu  /* rw */

/* sr: Status (reads only) */
#define CHILIMIX_I2C_SR_OFFSET 0x10u
#define CHILIMIX_I2C_SR_RESET 0x0u
#define CHILIMIX_I2C_SR_IFLAG_SHIFT 0
#define CHILIMIX_I2C_SR_IFLAG_MASK 0x1u  /* ro */
#define CHILIMIX_I2C_SR_TIP_SHIFT 1
#define CHILIMIX_I2C_SR_TIP_MASK 0x2u  /* ro */
#define CHILIMIX_I2C_SR_AL_SHIFT 5
#define CHILIMIX_I2C_SR_AL_MASK 0x20u  /* ro */
#define CHILIMIX_I2C_SR_BUSY_SHIFT 6
#define CHILIMIX_I2C_SR_BUSY_MASK 0x40u  /* ro */
#define CHILIMIX_I2C_SR_RXACK_SHIFT 7
#define CHILIMIX_I2C_SR_RXACK_MASK 0x80u  /* ro */

/* cr: Command (ignored while ctr.en is clear); sta, sto, read and write clear themselves when the command finishes (writes only) */
#define CHILIMIX_I2C_CR_OFFSET 0x10u
#define CHILIMIX_I2C_CR_RESET 0x0u
#define CHILIMIX_I2C_CR_IACK_SHIFT 0
#define CHILIMIX_I2C_CR_IACK_MASK 0x1u  /* wo */
#define CHILIMIX_I2C_CR_ACK_SHIFT 3
#define CHILIMIX_I2C_CR_ACK_MASK 0x8u  /* wo */
#define CHILIMIX_I2C_CR_WRITE_SHIFT 4
#define CHILIMIX_I2C_CR_WRITE_MASK 0x10u  /* wo */
#define CHILIMIX_I2C_CR_READ_SHIFT 5
#define CHILIMIX_I2C_CR_READ_MASK 0x20u  /* wo */
#define CHILIMIX_I2C_CR_STO_SHIFT 6
#define CHILIMIX_I2C_CR_STO_MASK 0x40u  /* wo */
#define CHILIMIX_I2C_CR_STA_SHIFT 7
#define CHILIMIX_I2C_CR_STA_MASK 0x80u  /* wo */

#endif /* CHILIMIX_I2C_REGS_H */
