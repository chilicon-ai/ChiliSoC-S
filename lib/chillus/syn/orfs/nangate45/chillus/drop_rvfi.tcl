# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# ORFS SYNTH_CANONICALIZE_TCL hook (Yosys, after hierarchy -check): make the
# rvfi_* ports of chillus_core internal wires. Nothing else loads them, so the
# chillus_rvfi logic is removed by the following opt_clean / flatten passes,
# as in tools/synth.py.
delete -port chillus_core/rvfi_*
