/* GENERATED FILE - DO NOT EDIT
 * Source: source/spi/regs/spi.json
 *
 * ChiliMix spi: SPI controller in the SiFive SPI layout (sifive,spi0): single / dual / quad frames through 8-entry TX and RX FIFOs, and a memory-mapped flash read interface (XIP) registers.
 * Layout compatible with sifive,spi0.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_SPI_REGS_H
#define CHILIMIX_SPI_REGS_H

#include <stdint.h>

#define CHILIMIX_SPI_SPAN 0x80u

/* sckdiv: Serial clock divisor: f_sck = f_clk / (2 * (div + 1)) */
#define CHILIMIX_SPI_SCKDIV_OFFSET 0x0u
#define CHILIMIX_SPI_SCKDIV_RESET 0x3u
#define CHILIMIX_SPI_SCKDIV_DIV_SHIFT 0
#define CHILIMIX_SPI_SCKDIV_DIV_MASK 0xfffu  /* rw */

/* sckmode: Serial clock mode */
#define CHILIMIX_SPI_SCKMODE_OFFSET 0x4u
#define CHILIMIX_SPI_SCKMODE_RESET 0x0u
#define CHILIMIX_SPI_SCKMODE_PHA_SHIFT 0
#define CHILIMIX_SPI_SCKMODE_PHA_MASK 0x1u  /* rw */
#define CHILIMIX_SPI_SCKMODE_POL_SHIFT 1
#define CHILIMIX_SPI_SCKMODE_POL_MASK 0x2u  /* rw */

/* csid: Chip select ID: the cs pin the controller asserts (none for an ID at or above N_CS) */
#define CHILIMIX_SPI_CSID_OFFSET 0x10u
#define CHILIMIX_SPI_CSID_RESET 0x0u
#define CHILIMIX_SPI_CSID_CSID_SHIFT 0
#define CHILIMIX_SPI_CSID_CSID_MASK 0x3u  /* rw */

/* csdef: Chip select default (inactive) levels; an asserted pin is the inverse */
#define CHILIMIX_SPI_CSDEF_OFFSET 0x14u
#define CHILIMIX_SPI_CSDEF_RESET 0xfu
#define CHILIMIX_SPI_CSDEF_CSDEF_SHIFT 0
#define CHILIMIX_SPI_CSDEF_CSDEF_MASK 0xfu  /* rw */

/* csmode: Chip select mode */
#define CHILIMIX_SPI_CSMODE_OFFSET 0x18u
#define CHILIMIX_SPI_CSMODE_RESET 0x0u
#define CHILIMIX_SPI_CSMODE_MODE_SHIFT 0
#define CHILIMIX_SPI_CSMODE_MODE_MASK 0x3u  /* rw */

/* delay0: Chip select delays, in sck periods */
#define CHILIMIX_SPI_DELAY0_OFFSET 0x28u
#define CHILIMIX_SPI_DELAY0_RESET 0x10001u
#define CHILIMIX_SPI_DELAY0_CSSCK_SHIFT 0
#define CHILIMIX_SPI_DELAY0_CSSCK_MASK 0xffu  /* rw */
#define CHILIMIX_SPI_DELAY0_SCKCS_SHIFT 16
#define CHILIMIX_SPI_DELAY0_SCKCS_MASK 0xff0000u  /* rw */

/* delay1: Inter-frame delays, in sck periods */
#define CHILIMIX_SPI_DELAY1_OFFSET 0x2cu
#define CHILIMIX_SPI_DELAY1_RESET 0x1u
#define CHILIMIX_SPI_DELAY1_INTERCS_SHIFT 0
#define CHILIMIX_SPI_DELAY1_INTERCS_MASK 0xffu  /* rw */
#define CHILIMIX_SPI_DELAY1_INTERXFR_SHIFT 16
#define CHILIMIX_SPI_DELAY1_INTERXFR_MASK 0xff0000u  /* rw */

/* fmt: Frame format of FIFO frames */
#define CHILIMIX_SPI_FMT_OFFSET 0x40u
#define CHILIMIX_SPI_FMT_RESET 0x80000u
#define CHILIMIX_SPI_FMT_PROTO_SHIFT 0
#define CHILIMIX_SPI_FMT_PROTO_MASK 0x3u  /* rw */
#define CHILIMIX_SPI_FMT_ENDIAN_SHIFT 2
#define CHILIMIX_SPI_FMT_ENDIAN_MASK 0x4u  /* rw */
#define CHILIMIX_SPI_FMT_DIR_SHIFT 3
#define CHILIMIX_SPI_FMT_DIR_MASK 0x8u  /* rw */
#define CHILIMIX_SPI_FMT_LEN_SHIFT 16
#define CHILIMIX_SPI_FMT_LEN_MASK 0xf0000u  /* rw */

/* txdata: Transmit data: a write pushes a frame (ignored while full) */
#define CHILIMIX_SPI_TXDATA_OFFSET 0x48u
#define CHILIMIX_SPI_TXDATA_RESET 0x0u
#define CHILIMIX_SPI_TXDATA_DATA_SHIFT 0
#define CHILIMIX_SPI_TXDATA_DATA_MASK 0xffu  /* wo */
#define CHILIMIX_SPI_TXDATA_FULL_SHIFT 31
#define CHILIMIX_SPI_TXDATA_FULL_MASK 0x80000000u  /* ro */

/* rxdata: Receive data: a read pops a frame */
#define CHILIMIX_SPI_RXDATA_OFFSET 0x4cu
#define CHILIMIX_SPI_RXDATA_RESET 0x0u
#define CHILIMIX_SPI_RXDATA_DATA_SHIFT 0
#define CHILIMIX_SPI_RXDATA_DATA_MASK 0xffu  /* ro */
#define CHILIMIX_SPI_RXDATA_EMPTY_SHIFT 31
#define CHILIMIX_SPI_RXDATA_EMPTY_MASK 0x80000000u  /* ro */

/* txmark: TX watermark */
#define CHILIMIX_SPI_TXMARK_OFFSET 0x50u
#define CHILIMIX_SPI_TXMARK_RESET 0x1u
#define CHILIMIX_SPI_TXMARK_TXMARK_SHIFT 0
#define CHILIMIX_SPI_TXMARK_TXMARK_MASK 0x7u  /* rw */

/* rxmark: RX watermark */
#define CHILIMIX_SPI_RXMARK_OFFSET 0x54u
#define CHILIMIX_SPI_RXMARK_RESET 0x0u
#define CHILIMIX_SPI_RXMARK_RXMARK_SHIFT 0
#define CHILIMIX_SPI_RXMARK_RXMARK_MASK 0x7u  /* rw */

/* fctrl: Flash interface control: a write also empties the XIP read cache */
#define CHILIMIX_SPI_FCTRL_OFFSET 0x60u
#define CHILIMIX_SPI_FCTRL_RESET 0x1u
#define CHILIMIX_SPI_FCTRL_EN_SHIFT 0
#define CHILIMIX_SPI_FCTRL_EN_MASK 0x1u  /* rw */

/* ffmt: Flash read instruction format: a write also empties the XIP read cache */
#define CHILIMIX_SPI_FFMT_OFFSET 0x64u
#define CHILIMIX_SPI_FFMT_RESET 0x30007u
#define CHILIMIX_SPI_FFMT_CMD_EN_SHIFT 0
#define CHILIMIX_SPI_FFMT_CMD_EN_MASK 0x1u  /* rw */
#define CHILIMIX_SPI_FFMT_ADDR_LEN_SHIFT 1
#define CHILIMIX_SPI_FFMT_ADDR_LEN_MASK 0xeu  /* rw */
#define CHILIMIX_SPI_FFMT_PAD_CNT_SHIFT 4
#define CHILIMIX_SPI_FFMT_PAD_CNT_MASK 0xf0u  /* rw */
#define CHILIMIX_SPI_FFMT_CMD_PROTO_SHIFT 8
#define CHILIMIX_SPI_FFMT_CMD_PROTO_MASK 0x300u  /* rw */
#define CHILIMIX_SPI_FFMT_ADDR_PROTO_SHIFT 10
#define CHILIMIX_SPI_FFMT_ADDR_PROTO_MASK 0xc00u  /* rw */
#define CHILIMIX_SPI_FFMT_DATA_PROTO_SHIFT 12
#define CHILIMIX_SPI_FFMT_DATA_PROTO_MASK 0x3000u  /* rw */
#define CHILIMIX_SPI_FFMT_CMD_CODE_SHIFT 16
#define CHILIMIX_SPI_FFMT_CMD_CODE_MASK 0xff0000u  /* rw */
#define CHILIMIX_SPI_FFMT_PAD_CODE_SHIFT 24
#define CHILIMIX_SPI_FFMT_PAD_CODE_MASK 0xff000000u  /* rw */

/* ie: Interrupt enables */
#define CHILIMIX_SPI_IE_OFFSET 0x70u
#define CHILIMIX_SPI_IE_RESET 0x0u
#define CHILIMIX_SPI_IE_TXWM_SHIFT 0
#define CHILIMIX_SPI_IE_TXWM_MASK 0x1u  /* rw */
#define CHILIMIX_SPI_IE_RXWM_SHIFT 1
#define CHILIMIX_SPI_IE_RXWM_MASK 0x2u  /* rw */

/* ip: Interrupt pending (levels) */
#define CHILIMIX_SPI_IP_OFFSET 0x74u
#define CHILIMIX_SPI_IP_RESET 0x0u
#define CHILIMIX_SPI_IP_TXWM_SHIFT 0
#define CHILIMIX_SPI_IP_TXWM_MASK 0x1u  /* ro */
#define CHILIMIX_SPI_IP_RXWM_SHIFT 1
#define CHILIMIX_SPI_IP_RXWM_MASK 0x2u  /* ro */

#endif /* CHILIMIX_SPI_REGS_H */
