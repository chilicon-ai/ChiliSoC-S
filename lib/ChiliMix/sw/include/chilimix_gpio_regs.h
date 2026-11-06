/* GENERATED FILE - DO NOT EDIT
 * Source: source/gpio/regs/gpio.json
 *
 * ChiliMix gpio: GPIO for up to 32 pins with edge and level interrupts and two IO functions per pin registers.
 * Layout compatible with sifive,gpio0.
 * Offsets are bytes from the IP's base address; registers are 32-bit (uint32_t).
 */
#ifndef CHILIMIX_GPIO_REGS_H
#define CHILIMIX_GPIO_REGS_H

#include <stdint.h>

#define CHILIMIX_GPIO_SPAN 0x80u

/* input_val: Pin values (synchronized; 0 where input_en is 0) */
#define CHILIMIX_GPIO_INPUT_VAL_OFFSET 0x0u
#define CHILIMIX_GPIO_INPUT_VAL_RESET 0x0u
#define CHILIMIX_GPIO_INPUT_VAL_PIN_SHIFT 0
#define CHILIMIX_GPIO_INPUT_VAL_PIN_MASK 0xffffffffu  /* ro */

/* input_en: Input enables */
#define CHILIMIX_GPIO_INPUT_EN_OFFSET 0x4u
#define CHILIMIX_GPIO_INPUT_EN_RESET 0x0u
#define CHILIMIX_GPIO_INPUT_EN_PIN_SHIFT 0
#define CHILIMIX_GPIO_INPUT_EN_PIN_MASK 0xffffffffu  /* rw */

/* output_en: Output enables (pins not under an IO function) */
#define CHILIMIX_GPIO_OUTPUT_EN_OFFSET 0x8u
#define CHILIMIX_GPIO_OUTPUT_EN_RESET 0x0u
#define CHILIMIX_GPIO_OUTPUT_EN_PIN_SHIFT 0
#define CHILIMIX_GPIO_OUTPUT_EN_PIN_MASK 0xffffffffu  /* rw */

/* output_val: Output values (pins not under an IO function) */
#define CHILIMIX_GPIO_OUTPUT_VAL_OFFSET 0xcu
#define CHILIMIX_GPIO_OUTPUT_VAL_RESET 0x0u
#define CHILIMIX_GPIO_OUTPUT_VAL_PIN_SHIFT 0
#define CHILIMIX_GPIO_OUTPUT_VAL_PIN_MASK 0xffffffffu  /* rw */

/* pue: Pull-up enables (pad control) */
#define CHILIMIX_GPIO_PUE_OFFSET 0x10u
#define CHILIMIX_GPIO_PUE_RESET 0x0u
#define CHILIMIX_GPIO_PUE_PIN_SHIFT 0
#define CHILIMIX_GPIO_PUE_PIN_MASK 0xffffffffu  /* rw */

/* ds: Drive strengths (pad control) */
#define CHILIMIX_GPIO_DS_OFFSET 0x14u
#define CHILIMIX_GPIO_DS_RESET 0x0u
#define CHILIMIX_GPIO_DS_PIN_SHIFT 0
#define CHILIMIX_GPIO_DS_PIN_MASK 0xffffffffu  /* rw */

/* rise_ie: Rising-edge interrupt enables */
#define CHILIMIX_GPIO_RISE_IE_OFFSET 0x18u
#define CHILIMIX_GPIO_RISE_IE_RESET 0x0u
#define CHILIMIX_GPIO_RISE_IE_PIN_SHIFT 0
#define CHILIMIX_GPIO_RISE_IE_PIN_MASK 0xffffffffu  /* rw */

/* rise_ip: Rising edges seen */
#define CHILIMIX_GPIO_RISE_IP_OFFSET 0x1cu
#define CHILIMIX_GPIO_RISE_IP_RESET 0x0u
#define CHILIMIX_GPIO_RISE_IP_PIN_SHIFT 0
#define CHILIMIX_GPIO_RISE_IP_PIN_MASK 0xffffffffu  /* w1c */

/* fall_ie: Falling-edge interrupt enables */
#define CHILIMIX_GPIO_FALL_IE_OFFSET 0x20u
#define CHILIMIX_GPIO_FALL_IE_RESET 0x0u
#define CHILIMIX_GPIO_FALL_IE_PIN_SHIFT 0
#define CHILIMIX_GPIO_FALL_IE_PIN_MASK 0xffffffffu  /* rw */

/* fall_ip: Falling edges seen */
#define CHILIMIX_GPIO_FALL_IP_OFFSET 0x24u
#define CHILIMIX_GPIO_FALL_IP_RESET 0x0u
#define CHILIMIX_GPIO_FALL_IP_PIN_SHIFT 0
#define CHILIMIX_GPIO_FALL_IP_PIN_MASK 0xffffffffu  /* w1c */

/* high_ie: High-level interrupt enables */
#define CHILIMIX_GPIO_HIGH_IE_OFFSET 0x28u
#define CHILIMIX_GPIO_HIGH_IE_RESET 0x0u
#define CHILIMIX_GPIO_HIGH_IE_PIN_SHIFT 0
#define CHILIMIX_GPIO_HIGH_IE_PIN_MASK 0xffffffffu  /* rw */

/* high_ip: High levels seen (set again while still high) */
#define CHILIMIX_GPIO_HIGH_IP_OFFSET 0x2cu
#define CHILIMIX_GPIO_HIGH_IP_RESET 0x0u
#define CHILIMIX_GPIO_HIGH_IP_PIN_SHIFT 0
#define CHILIMIX_GPIO_HIGH_IP_PIN_MASK 0xffffffffu  /* w1c */

/* low_ie: Low-level interrupt enables */
#define CHILIMIX_GPIO_LOW_IE_OFFSET 0x30u
#define CHILIMIX_GPIO_LOW_IE_RESET 0x0u
#define CHILIMIX_GPIO_LOW_IE_PIN_SHIFT 0
#define CHILIMIX_GPIO_LOW_IE_PIN_MASK 0xffffffffu  /* rw */

/* low_ip: Low levels seen (set again while still low) */
#define CHILIMIX_GPIO_LOW_IP_OFFSET 0x34u
#define CHILIMIX_GPIO_LOW_IP_RESET 0x0u
#define CHILIMIX_GPIO_LOW_IP_PIN_SHIFT 0
#define CHILIMIX_GPIO_LOW_IP_PIN_MASK 0xffffffffu  /* w1c */

/* iof_en: IO function enables */
#define CHILIMIX_GPIO_IOF_EN_OFFSET 0x38u
#define CHILIMIX_GPIO_IOF_EN_RESET 0x0u
#define CHILIMIX_GPIO_IOF_EN_PIN_SHIFT 0
#define CHILIMIX_GPIO_IOF_EN_PIN_MASK 0xffffffffu  /* rw */

/* iof_sel: IO function select */
#define CHILIMIX_GPIO_IOF_SEL_OFFSET 0x3cu
#define CHILIMIX_GPIO_IOF_SEL_RESET 0x0u
#define CHILIMIX_GPIO_IOF_SEL_PIN_SHIFT 0
#define CHILIMIX_GPIO_IOF_SEL_PIN_MASK 0xffffffffu  /* rw */

/* out_xor: Output inversion (after the IO function mux) */
#define CHILIMIX_GPIO_OUT_XOR_OFFSET 0x40u
#define CHILIMIX_GPIO_OUT_XOR_RESET 0x0u
#define CHILIMIX_GPIO_OUT_XOR_PIN_SHIFT 0
#define CHILIMIX_GPIO_OUT_XOR_PIN_MASK 0xffffffffu  /* rw */

#endif /* CHILIMIX_GPIO_REGS_H */
