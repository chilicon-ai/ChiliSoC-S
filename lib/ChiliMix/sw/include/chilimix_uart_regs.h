/* GENERATED FILE - DO NOT EDIT
 * Source: source/uart/regs/uart.json
 *
 * ChiliMix uart: ns16550a UART: 16-byte FIFOs, 8-bit registers on 32-bit words (reg-shift 2) registers.
 * Layout compatible with ns16550a.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_UART_REGS_H
#define CHILIMIX_UART_REGS_H

#include <stdint.h>

#define CHILIMIX_UART_SPAN 0x20u

/* rbr: Receiver buffer: reading pops the RX FIFO (reads only, lcr.dlab = 0) */
#define CHILIMIX_UART_RBR_OFFSET 0x0u
#define CHILIMIX_UART_RBR_RESET 0x0u
#define CHILIMIX_UART_RBR_DATA_SHIFT 0
#define CHILIMIX_UART_RBR_DATA_MASK 0xffu  /* ro */

/* thr: Transmitter holding: writing pushes the TX FIFO (writes only, lcr.dlab = 0) */
#define CHILIMIX_UART_THR_OFFSET 0x0u
#define CHILIMIX_UART_THR_RESET 0x0u
#define CHILIMIX_UART_THR_DATA_SHIFT 0
#define CHILIMIX_UART_THR_DATA_MASK 0xffu  /* wo */

/* dll: Divisor latch, low byte: baud = clock / (16 * divisor) (lcr.dlab = 1) */
#define CHILIMIX_UART_DLL_OFFSET 0x0u
#define CHILIMIX_UART_DLL_RESET 0x0u
#define CHILIMIX_UART_DLL_VALUE_SHIFT 0
#define CHILIMIX_UART_DLL_VALUE_MASK 0xffu  /* rw */

/* ier: Interrupt enable (lcr.dlab = 0) */
#define CHILIMIX_UART_IER_OFFSET 0x4u
#define CHILIMIX_UART_IER_RESET 0x0u
#define CHILIMIX_UART_IER_ERBFI_SHIFT 0
#define CHILIMIX_UART_IER_ERBFI_MASK 0x1u  /* rw */
#define CHILIMIX_UART_IER_ETBEI_SHIFT 1
#define CHILIMIX_UART_IER_ETBEI_MASK 0x2u  /* rw */
#define CHILIMIX_UART_IER_ELSI_SHIFT 2
#define CHILIMIX_UART_IER_ELSI_MASK 0x4u  /* rw */
#define CHILIMIX_UART_IER_EDSSI_SHIFT 3
#define CHILIMIX_UART_IER_EDSSI_MASK 0x8u  /* rw */

/* dlm: Divisor latch, high byte (lcr.dlab = 1) */
#define CHILIMIX_UART_DLM_OFFSET 0x4u
#define CHILIMIX_UART_DLM_RESET 0x0u
#define CHILIMIX_UART_DLM_VALUE_SHIFT 0
#define CHILIMIX_UART_DLM_VALUE_MASK 0xffu  /* rw */

/* iir: Interrupt identification: reading it clears a THR empty interrupt it reports (reads only) */
#define CHILIMIX_UART_IIR_OFFSET 0x8u
#define CHILIMIX_UART_IIR_RESET 0x0u
#define CHILIMIX_UART_IIR_ID_SHIFT 0
#define CHILIMIX_UART_IIR_ID_MASK 0xfu  /* ro */
#define CHILIMIX_UART_IIR_FIFOS_SHIFT 6
#define CHILIMIX_UART_IIR_FIFOS_MASK 0xc0u  /* ro */

/* fcr: FIFO control (writes only) */
#define CHILIMIX_UART_FCR_OFFSET 0x8u
#define CHILIMIX_UART_FCR_RESET 0x0u
#define CHILIMIX_UART_FCR_ENABLE_SHIFT 0
#define CHILIMIX_UART_FCR_ENABLE_MASK 0x1u  /* rw */
#define CHILIMIX_UART_FCR_RX_RESET_SHIFT 1
#define CHILIMIX_UART_FCR_RX_RESET_MASK 0x2u  /* wo */
#define CHILIMIX_UART_FCR_TX_RESET_SHIFT 2
#define CHILIMIX_UART_FCR_TX_RESET_MASK 0x4u  /* wo */
#define CHILIMIX_UART_FCR_DMA_MODE_SHIFT 3
#define CHILIMIX_UART_FCR_DMA_MODE_MASK 0x8u  /* rw */
#define CHILIMIX_UART_FCR_RX_TRIGGER_SHIFT 6
#define CHILIMIX_UART_FCR_RX_TRIGGER_MASK 0xc0u  /* rw */

/* lcr: Line control */
#define CHILIMIX_UART_LCR_OFFSET 0xcu
#define CHILIMIX_UART_LCR_RESET 0x0u
#define CHILIMIX_UART_LCR_WLS_SHIFT 0
#define CHILIMIX_UART_LCR_WLS_MASK 0x3u  /* rw */
#define CHILIMIX_UART_LCR_STB_SHIFT 2
#define CHILIMIX_UART_LCR_STB_MASK 0x4u  /* rw */
#define CHILIMIX_UART_LCR_PEN_SHIFT 3
#define CHILIMIX_UART_LCR_PEN_MASK 0x8u  /* rw */
#define CHILIMIX_UART_LCR_EPS_SHIFT 4
#define CHILIMIX_UART_LCR_EPS_MASK 0x10u  /* rw */
#define CHILIMIX_UART_LCR_STICK_SHIFT 5
#define CHILIMIX_UART_LCR_STICK_MASK 0x20u  /* rw */
#define CHILIMIX_UART_LCR_BRK_SHIFT 6
#define CHILIMIX_UART_LCR_BRK_MASK 0x40u  /* rw */
#define CHILIMIX_UART_LCR_DLAB_SHIFT 7
#define CHILIMIX_UART_LCR_DLAB_MASK 0x80u  /* rw */

/* mcr: Modem control */
#define CHILIMIX_UART_MCR_OFFSET 0x10u
#define CHILIMIX_UART_MCR_RESET 0x0u
#define CHILIMIX_UART_MCR_DTR_SHIFT 0
#define CHILIMIX_UART_MCR_DTR_MASK 0x1u  /* rw */
#define CHILIMIX_UART_MCR_RTS_SHIFT 1
#define CHILIMIX_UART_MCR_RTS_MASK 0x2u  /* rw */
#define CHILIMIX_UART_MCR_OUT1_SHIFT 2
#define CHILIMIX_UART_MCR_OUT1_MASK 0x4u  /* rw */
#define CHILIMIX_UART_MCR_OUT2_SHIFT 3
#define CHILIMIX_UART_MCR_OUT2_MASK 0x8u  /* rw */
#define CHILIMIX_UART_MCR_LOOP_SHIFT 4
#define CHILIMIX_UART_MCR_LOOP_MASK 0x10u  /* rw */

/* lsr: Line status: reading it clears the error bits 4:1 */
#define CHILIMIX_UART_LSR_OFFSET 0x14u
#define CHILIMIX_UART_LSR_RESET 0x0u
#define CHILIMIX_UART_LSR_DR_SHIFT 0
#define CHILIMIX_UART_LSR_DR_MASK 0x1u  /* ro */
#define CHILIMIX_UART_LSR_OE_SHIFT 1
#define CHILIMIX_UART_LSR_OE_MASK 0x2u  /* ro */
#define CHILIMIX_UART_LSR_PE_SHIFT 2
#define CHILIMIX_UART_LSR_PE_MASK 0x4u  /* ro */
#define CHILIMIX_UART_LSR_FE_SHIFT 3
#define CHILIMIX_UART_LSR_FE_MASK 0x8u  /* ro */
#define CHILIMIX_UART_LSR_BI_SHIFT 4
#define CHILIMIX_UART_LSR_BI_MASK 0x10u  /* ro */
#define CHILIMIX_UART_LSR_THRE_SHIFT 5
#define CHILIMIX_UART_LSR_THRE_MASK 0x20u  /* ro */
#define CHILIMIX_UART_LSR_TEMT_SHIFT 6
#define CHILIMIX_UART_LSR_TEMT_MASK 0x40u  /* ro */
#define CHILIMIX_UART_LSR_RXFE_SHIFT 7
#define CHILIMIX_UART_LSR_RXFE_MASK 0x80u  /* ro */

/* msr: Modem status: reading it clears the delta bits 3:0 */
#define CHILIMIX_UART_MSR_OFFSET 0x18u
#define CHILIMIX_UART_MSR_RESET 0x0u
#define CHILIMIX_UART_MSR_DCTS_SHIFT 0
#define CHILIMIX_UART_MSR_DCTS_MASK 0x1u  /* ro */
#define CHILIMIX_UART_MSR_DDSR_SHIFT 1
#define CHILIMIX_UART_MSR_DDSR_MASK 0x2u  /* ro */
#define CHILIMIX_UART_MSR_TERI_SHIFT 2
#define CHILIMIX_UART_MSR_TERI_MASK 0x4u  /* ro */
#define CHILIMIX_UART_MSR_DDCD_SHIFT 3
#define CHILIMIX_UART_MSR_DDCD_MASK 0x8u  /* ro */
#define CHILIMIX_UART_MSR_CTS_SHIFT 4
#define CHILIMIX_UART_MSR_CTS_MASK 0x10u  /* ro */
#define CHILIMIX_UART_MSR_DSR_SHIFT 5
#define CHILIMIX_UART_MSR_DSR_MASK 0x20u  /* ro */
#define CHILIMIX_UART_MSR_RI_SHIFT 6
#define CHILIMIX_UART_MSR_RI_MASK 0x40u  /* ro */
#define CHILIMIX_UART_MSR_DCD_SHIFT 7
#define CHILIMIX_UART_MSR_DCD_MASK 0x80u  /* ro */

/* scr: Scratch */
#define CHILIMIX_UART_SCR_OFFSET 0x1cu
#define CHILIMIX_UART_SCR_RESET 0x0u
#define CHILIMIX_UART_SCR_VALUE_SHIFT 0
#define CHILIMIX_UART_SCR_VALUE_MASK 0xffu  /* rw */

#endif /* CHILIMIX_UART_REGS_H */
