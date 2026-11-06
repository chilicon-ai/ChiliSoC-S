# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# ChiliSoC-S top in ORFS (OpenROAD-flow-scripts), Nangate45.
# Run with syn/orfs/run.sh, which mounts the repository at /soc and sets
# WORK_HOME (results / logs / reports) to syn/orfs/out/<design>.

export DESIGN_NICKNAME = chilisocs
export DESIGN_NAME     = chilisocs_top
export PLATFORM        = nangate45

SOC_HOME ?= /soc
SOC_CFG  := $(SOC_HOME)/syn/orfs/$(PLATFORM)/$(DESIGN_NICKNAME)

# All RTL, from the four file lists (tools/filelist.py), with the library's
# behavioural basechili_sram_sp swapped for the macro version here (ROM and
# SRAMs as fakeram45_1024x32 banks); slang elaborates only what
# chilisocs_top instantiates.
export VERILOG_FILES      = $(shell python3 $(SOC_HOME)/tools/filelist.py | \
                              sed 's|.*/basechili_sram_sp\.sv$$|$(SOC_CFG)/basechili_sram_sp.sv|')
export SYNTH_HDL_FRONTEND = slang

# chilisocs_top parameters (slang -G, ORFS VERILOG_TOP_PARAMS): the default
# memory sizes (4 KiB ROM, 2 x 64 KiB SRAM: 33 macros) and the 2 KiB instruction
# cache (4 more). Use a separate TAG
# per value: make does not rerun synthesis in an existing WORK_HOME when only
# a parameter changes.
export ROM_AW            ?= 10
export SRAM_AW           ?= 14
export ICACHE_KB         ?= 2
export VERILOG_TOP_PARAMS = ROM_AW $(ROM_AW) SRAM_AW $(SRAM_AW) ICACHE_KB $(ICACHE_KB)

# ROM / SRAM banks, and the instruction cache arrays (ICACHE_KB 2: 256x32
# data and 64x32 tags per way; 4: 2 x 256x32 and 128x32)
FAKERAMS = fakeram45_1024x32 fakeram45_256x32 fakeram45_128x32 fakeram45_64x32
export ADDITIONAL_LEFS = $(foreach m,$(FAKERAMS),$(PLATFORM_DIR)/lef/$(m).lef)
export ADDITIONAL_LIBS = $(foreach m,$(FAKERAMS),$(PLATFORM_DIR)/lib/$(m).lib)

export SDC_FILE = $(SOC_CFG)/constraint.sdc
# Core clock period in ns (constraint.sdc); override: run.sh chilisocs CLK_PERIOD=5.0
export CLK_PERIOD ?= 2.4

export CORE_UTILIZATION       ?= 40
export PLACE_DENSITY_LB_ADDON  = 0.20
export TNS_END_PERCENT         = 100
export MACRO_PLACE_HALO        = 10 10
