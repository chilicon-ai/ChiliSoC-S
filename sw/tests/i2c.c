// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// i2c: I2C0 against the testbench's I2C EEPROM (address 0x50, 256 bytes,
// initial contents 7 * i + 1, it stretches scl now and then), with the
// command sequences of the i2c-ocores driver:
//   1  random read: write the pointer, repeated START, read 4 bytes (ACK,
//      NACK and STOP on the last)
//   2  page write of 6 bytes, then read them back
//   3  an absent address (0x51): NACK, then a STOP alone
//   4  the command-done interrupt through the PLIC (source IRQ_I2C0)
#include "ext_irq.h"
#include "chilimix_i2c_regs.h"

#define I2C(off) REG32(I2C0_BASE, off)
#define DEV 0x50
#define STA CHILIMIX_I2C_CR_STA_MASK
#define STO CHILIMIX_I2C_CR_STO_MASK
#define RD  CHILIMIX_I2C_CR_READ_MASK
#define WR  CHILIMIX_I2C_CR_WRITE_MASK
#define NACK CHILIMIX_I2C_CR_ACK_MASK
#define TIP CHILIMIX_I2C_SR_TIP_MASK
#define RXACK CHILIMIX_I2C_SR_RXACK_MASK

static volatile int n_i2c_irq, n_bad_irq;

static void ext_irq(uint32_t src)
{
  if (src == IRQ_I2C0) {
    I2C(CHILIMIX_I2C_CR_OFFSET) = CHILIMIX_I2C_CR_IACK_MASK;
    n_i2c_irq++;
  } else {
    n_bad_irq++;
  }
}

static uint32_t on_trap(uint32_t mcause, uint32_t mepc, uint32_t *frame)
{
  (void)frame;
  if (ext_irq_trap(mcause))
    return mepc;
  exit(0x400 + (int)(mcause & 0xff));
}

// sr.busy clears when the controller sees the STOP on the (synchronized)
// lines, a few clocks after the command ends: 1 when the bus is free
static int bus_free(void)
{
  for (int t = 0; t < 100; t++)
    if (!(I2C(CHILIMIX_I2C_SR_OFFSET) & CHILIMIX_I2C_SR_BUSY_MASK))
      return 1;
  return 0;
}

// one command; returns sr when it is done
static uint32_t cmd(uint32_t cr)
{
  I2C(CHILIMIX_I2C_CR_OFFSET) = cr;
  uint32_t sr;
  do sr = I2C(CHILIMIX_I2C_SR_OFFSET); while (sr & TIP);
  return sr;
}

// write a byte (with START when sta), 1 when the target acknowledged it
static int put(uint32_t b, uint32_t flags)
{
  I2C(CHILIMIX_I2C_TXR_OFFSET) = b;
  return !(cmd(WR | flags) & RXACK);
}

static uint32_t get(uint32_t flags)
{
  cmd(RD | flags);
  return I2C(CHILIMIX_I2C_RXR_OFFSET);
}

// random read of n bytes at ptr; 0 if a byte was not acknowledged
static int ee_read(uint32_t ptr, uint8_t *d, int n)
{
  if (!put(DEV << 1, STA) || !put(ptr, 0) || !put((DEV << 1) | 1, STA))
    return 0;
  for (int i = 0; i < n; i++)
    d[i] = (uint8_t)get(i == n - 1 ? NACK | STO : 0);
  return 1;
}

int main(void)
{
  trap_hook = on_trap;
  I2C(CHILIMIX_I2C_PRER_LO_OFFSET) = 2;            // bit = 5 * 3 clocks
  I2C(CHILIMIX_I2C_PRER_HI_OFFSET) = 0;
  I2C(CHILIMIX_I2C_CTR_OFFSET) = CHILIMIX_I2C_CTR_EN_MASK;

  // 1: random read of the initial contents
  uint8_t d[8];
  if (!ee_read(0x80, d, 4))
    return 1;
  con_printf("i2c: eeprom[0x80..] %x %x %x %x\n", d[0], d[1], d[2], d[3]);
  for (int i = 0; i < 4; i++)
    if (d[i] != (uint8_t)(7 * (0x80 + i) + 1))
      return 2;
  if (!bus_free())
    return 3;                                      // STOP sent

  // 2: write 6 bytes at 0x10, read them back
  static const uint8_t msg[6] = {0xc4, 0x11, 0x5a, 0x00, 0xff, 0x3e};
  int ok = put(DEV << 1, STA) && put(0x10, 0);
  for (int i = 0; ok && i < 6; i++)
    ok = put(msg[i], i == 5 ? STO : 0);
  if (!ok || !ee_read(0x10, d, 6) || memcmp(d, msg, 6))
    return 4;
  con_printf("i2c: wrote and read back 6 bytes\n");

  // 3: absent address
  int ack = put(0x51 << 1, STA);
  cmd(STO);
  if (ack || !bus_free())
    return 5;

  // 4: interrupt on command done
  I2C(CHILIMIX_I2C_CR_OFFSET) = CHILIMIX_I2C_CR_IACK_MASK;   // the STOP above set iflag
  ext_irq_on(IRQ_I2C0, 1);
  I2C(CHILIMIX_I2C_CTR_OFFSET) = CHILIMIX_I2C_CTR_EN_MASK | CHILIMIX_I2C_CTR_IEN_MASK;
  I2C(CHILIMIX_I2C_TXR_OFFSET) = DEV << 1;
  I2C(CHILIMIX_I2C_CR_OFFSET) = WR | STA;
  for (int t = 0; n_i2c_irq == 0 && t < 10000; t++)
    ;
  uint32_t sr = I2C(CHILIMIX_I2C_SR_OFFSET);       // the handler's iack cleared iflag
  int irq_ack = !(sr & RXACK);
  I2C(CHILIMIX_I2C_CTR_OFFSET) = CHILIMIX_I2C_CTR_EN_MASK;
  cmd(STO);
  ext_irq_off(IRQ_I2C0);
  con_printf("i2c: %d done interrupts, ack %d\n", n_i2c_irq, irq_ack);
  if (n_i2c_irq != 1 || n_bad_irq || !irq_ack || (sr & CHILIMIX_I2C_SR_IFLAG_MASK))
    return 6;
  return 0;
}
