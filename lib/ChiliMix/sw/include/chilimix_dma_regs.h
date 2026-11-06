/* GENERATED FILE - DO NOT EDIT
 * Source: source/dma/regs/dma.json
 *
 * ChiliMix dma: One channel of the SiFive Platform DMA (sifive,fu540-c000-pdma): Next registers software programs, Exec registers the running transfer; channel i at 0x1000 * i registers.
 * Layout compatible with sifive,fu540-c000-pdma.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_DMA_REGS_H
#define CHILIMIX_DMA_REGS_H

#include <stdint.h>

#define CHILIMIX_DMA_SPAN 0x1000u

/* control: Channel control and status (reads only) */
#define CHILIMIX_DMA_CONTROL_OFFSET 0x0u
#define CHILIMIX_DMA_CONTROL_RESET 0x0u
#define CHILIMIX_DMA_CONTROL_CLAIM_SHIFT 0
#define CHILIMIX_DMA_CONTROL_CLAIM_MASK 0x1u  /* ro */
#define CHILIMIX_DMA_CONTROL_RUN_SHIFT 1
#define CHILIMIX_DMA_CONTROL_RUN_MASK 0x2u  /* ro */
#define CHILIMIX_DMA_CONTROL_DONE_IE_SHIFT 14
#define CHILIMIX_DMA_CONTROL_DONE_IE_MASK 0x4000u  /* ro */
#define CHILIMIX_DMA_CONTROL_ERROR_IE_SHIFT 15
#define CHILIMIX_DMA_CONTROL_ERROR_IE_MASK 0x8000u  /* ro */
#define CHILIMIX_DMA_CONTROL_DONE_SHIFT 30
#define CHILIMIX_DMA_CONTROL_DONE_MASK 0x40000000u  /* ro */
#define CHILIMIX_DMA_CONTROL_ERROR_SHIFT 31
#define CHILIMIX_DMA_CONTROL_ERROR_MASK 0x80000000u  /* ro */

/* control_w: Channel control: claim, start (run 0 to 1) or abort (run 1 to 0), interrupt enables; done and error are cleared by writing 0 (writes only) */
#define CHILIMIX_DMA_CONTROL_W_OFFSET 0x0u
#define CHILIMIX_DMA_CONTROL_W_RESET 0x0u
#define CHILIMIX_DMA_CONTROL_W_CLAIM_SHIFT 0
#define CHILIMIX_DMA_CONTROL_W_CLAIM_MASK 0x1u  /* wo */
#define CHILIMIX_DMA_CONTROL_W_RUN_SHIFT 1
#define CHILIMIX_DMA_CONTROL_W_RUN_MASK 0x2u  /* wo */
#define CHILIMIX_DMA_CONTROL_W_DONE_IE_SHIFT 14
#define CHILIMIX_DMA_CONTROL_W_DONE_IE_MASK 0x4000u  /* wo */
#define CHILIMIX_DMA_CONTROL_W_ERROR_IE_SHIFT 15
#define CHILIMIX_DMA_CONTROL_W_ERROR_IE_MASK 0x8000u  /* wo */
#define CHILIMIX_DMA_CONTROL_W_DONE_SHIFT 30
#define CHILIMIX_DMA_CONTROL_W_DONE_MASK 0x40000000u  /* wo */
#define CHILIMIX_DMA_CONTROL_W_ERROR_SHIFT 31
#define CHILIMIX_DMA_CONTROL_W_ERROR_MASK 0x80000000u  /* wo */

/* next_config: Configuration of the next transfer */
#define CHILIMIX_DMA_NEXT_CONFIG_OFFSET 0x4u
#define CHILIMIX_DMA_NEXT_CONFIG_RESET 0x0u
#define CHILIMIX_DMA_NEXT_CONFIG_REPEAT_SHIFT 2
#define CHILIMIX_DMA_NEXT_CONFIG_REPEAT_MASK 0x4u  /* rw */
#define CHILIMIX_DMA_NEXT_CONFIG_ORDER_SHIFT 3
#define CHILIMIX_DMA_NEXT_CONFIG_ORDER_MASK 0x8u  /* rw */
#define CHILIMIX_DMA_NEXT_CONFIG_WSIZE_SHIFT 24
#define CHILIMIX_DMA_NEXT_CONFIG_WSIZE_MASK 0xf000000u  /* rw */
#define CHILIMIX_DMA_NEXT_CONFIG_RSIZE_SHIFT 28
#define CHILIMIX_DMA_NEXT_CONFIG_RSIZE_MASK 0xf0000000u  /* rw */

/* next_bytes: Bytes to transfer, bits 31:0 (bits 63:32 at 0x0c: a hole, reads 0) */
#define CHILIMIX_DMA_NEXT_BYTES_OFFSET 0x8u
#define CHILIMIX_DMA_NEXT_BYTES_RESET 0x0u
#define CHILIMIX_DMA_NEXT_BYTES_VALUE_SHIFT 0
#define CHILIMIX_DMA_NEXT_BYTES_VALUE_MASK 0xffffffffu  /* rw */

/* next_dst: Destination address, bits 31:0 (bits 63:32 at 0x14: a hole, reads 0) */
#define CHILIMIX_DMA_NEXT_DST_OFFSET 0x10u
#define CHILIMIX_DMA_NEXT_DST_RESET 0x0u
#define CHILIMIX_DMA_NEXT_DST_VALUE_SHIFT 0
#define CHILIMIX_DMA_NEXT_DST_VALUE_MASK 0xffffffffu  /* rw */

/* next_src: Source address, bits 31:0 */
#define CHILIMIX_DMA_NEXT_SRC_OFFSET 0x18u
#define CHILIMIX_DMA_NEXT_SRC_RESET 0x0u
#define CHILIMIX_DMA_NEXT_SRC_VALUE_SHIFT 0
#define CHILIMIX_DMA_NEXT_SRC_VALUE_MASK 0xffffffffu  /* rw */

/* next_src_hi: Source address, bits 63:32: reads 0 (addresses are 32 bits) */
#define CHILIMIX_DMA_NEXT_SRC_HI_OFFSET 0x1cu
#define CHILIMIX_DMA_NEXT_SRC_HI_RESET 0x0u
#define CHILIMIX_DMA_NEXT_SRC_HI_VALUE_SHIFT 0
#define CHILIMIX_DMA_NEXT_SRC_HI_VALUE_MASK 0xffffffffu  /* ro */

/* exec_config: Configuration of the running transfer */
#define CHILIMIX_DMA_EXEC_CONFIG_OFFSET 0x104u
#define CHILIMIX_DMA_EXEC_CONFIG_RESET 0x0u
#define CHILIMIX_DMA_EXEC_CONFIG_REPEAT_SHIFT 2
#define CHILIMIX_DMA_EXEC_CONFIG_REPEAT_MASK 0x4u  /* ro */
#define CHILIMIX_DMA_EXEC_CONFIG_ORDER_SHIFT 3
#define CHILIMIX_DMA_EXEC_CONFIG_ORDER_MASK 0x8u  /* ro */
#define CHILIMIX_DMA_EXEC_CONFIG_WSIZE_SHIFT 24
#define CHILIMIX_DMA_EXEC_CONFIG_WSIZE_MASK 0xf000000u  /* ro */
#define CHILIMIX_DMA_EXEC_CONFIG_RSIZE_SHIFT 28
#define CHILIMIX_DMA_EXEC_CONFIG_RSIZE_MASK 0xf0000000u  /* ro */

/* exec_bytes: Bytes left in the running transfer */
#define CHILIMIX_DMA_EXEC_BYTES_OFFSET 0x108u
#define CHILIMIX_DMA_EXEC_BYTES_RESET 0x0u
#define CHILIMIX_DMA_EXEC_BYTES_VALUE_SHIFT 0
#define CHILIMIX_DMA_EXEC_BYTES_VALUE_MASK 0xffffffffu  /* ro */

/* exec_dst: Next destination address of the running transfer */
#define CHILIMIX_DMA_EXEC_DST_OFFSET 0x110u
#define CHILIMIX_DMA_EXEC_DST_RESET 0x0u
#define CHILIMIX_DMA_EXEC_DST_VALUE_SHIFT 0
#define CHILIMIX_DMA_EXEC_DST_VALUE_MASK 0xffffffffu  /* ro */

/* exec_src: Next source address of the running transfer */
#define CHILIMIX_DMA_EXEC_SRC_OFFSET 0x118u
#define CHILIMIX_DMA_EXEC_SRC_RESET 0x0u
#define CHILIMIX_DMA_EXEC_SRC_VALUE_SHIFT 0
#define CHILIMIX_DMA_EXEC_SRC_VALUE_MASK 0xffffffffu  /* ro */

/* exec_src_hi: Source address, bits 63:32: reads 0 */
#define CHILIMIX_DMA_EXEC_SRC_HI_OFFSET 0x11cu
#define CHILIMIX_DMA_EXEC_SRC_HI_RESET 0x0u
#define CHILIMIX_DMA_EXEC_SRC_HI_VALUE_SHIFT 0
#define CHILIMIX_DMA_EXEC_SRC_HI_VALUE_MASK 0xffffffffu  /* ro */

#endif /* CHILIMIX_DMA_REGS_H */
