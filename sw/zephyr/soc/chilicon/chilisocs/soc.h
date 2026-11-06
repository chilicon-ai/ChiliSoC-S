// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
/* ChiliSoC-S :: soc.h -- what Zephyr's SiFive drivers take from the SoC */
#ifndef CHILISOCS_SOC_H
#define CHILISOCS_SOC_H

#include <zephyr/devicetree.h>

/* SPI, I2C and PWM run on the core clock */
#define SIFIVE_PERIPHERAL_CLOCK_FREQUENCY DT_PROP(DT_NODELABEL(coreclk), clock_frequency)

#endif
