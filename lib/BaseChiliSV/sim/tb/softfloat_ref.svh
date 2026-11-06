// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim/tb/softfloat_ref.svh :: Berkeley SoftFloat reference of the IEEE FP
// testbenches (simulation only): DPI-C imports of sim/tb/softfloat_ref.c,
// which tools/sim.py compiles with SoftFloat (tools/softfloat.py) into a
// testbench that includes this file. Arguments and encodings: see the .c.
// -----------------------------------------------------------------------------
`ifndef BASECHILI_SOFTFLOAT_REF_SVH
`define BASECHILI_SOFTFLOAT_REF_SVH

import "DPI-C" function longint unsigned sf_arith(int fmt, int op, longint unsigned a, longint unsigned b,
                                                 longint unsigned c, int rm, output int flags);
import "DPI-C" function longint unsigned sf_to_int(int fmt, int ityp, longint unsigned a, int rm, output int flags);
import "DPI-C" function longint unsigned sf_from_int(int fmt, int ityp, longint unsigned a, int rm, output int flags);
import "DPI-C" function longint unsigned sf_cvt(int from, int to, longint unsigned a, int rm, output int flags);

`endif
