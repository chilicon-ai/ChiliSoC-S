/*
 * ChillU-S sim :: CoreMark port (core_portme.c)
 *
 * Adapted from coremark/barebones/core_portme.c, Copyright 2018 EEMBC,
 * Apache License 2.0. See core_portme.h.
 *
 * Timing: ticks are clock cycles (cycle CSR). EE_TICKS_PER_SEC assumes a
 * nominal 1 MHz clock, so "seconds" = cycles / 10^6 and iterations per
 * "second" = CoreMark/MHz. A simulation runs far less than the 10 s CoreMark
 * asks for, so the report always contains that one ERROR line; sim/run.py
 * ignores it, checks the CRC lines and computes CoreMark/MHz itself.
 */
#include "coremark.h"
#include "runtime.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

#define EE_TICKS_PER_SEC 1000000

static CORETIMETYPE start_time_val, stop_time_val;

static CORETIMETYPE read_cycle(void)
{
    ee_u32 c;
    __asm__ volatile("csrr %0, cycle" : "=r"(c));
    return c;
}

void start_time(void)
{
    start_time_val = read_cycle();
}

void stop_time(void)
{
    stop_time_val = read_cycle();
}

CORE_TICKS get_time(void)
{
    return (CORE_TICKS)(stop_time_val - start_time_val);
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
}

ee_u32 default_num_contexts = 1;

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *))
        ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
    if (sizeof(ee_u32) != 4)
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    p->portable_id = 1;
}

void portable_fini(core_portable *p)
{
    p->portable_id = 0;
}

int ee_printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int n = con_vprintf(fmt, ap);
    va_end(ap);
    return n;
}
