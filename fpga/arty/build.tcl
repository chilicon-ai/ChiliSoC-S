# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# ChiliSoC-S on the Arty A7-100T: Vivado non-project batch flow (fpga/build.py runs it).
#   vivado -mode batch -source build.tcl -tclargs <out dir> <part> <top> <xdc> "<generic>=<value> ..."
# Reads <out dir>/files.f (the SoC RTL with the FPGA swaps, then the board top),
# writes the reports and <top>.bit / <top>.bin into <out dir>.

lassign $argv out part top xdc generics
set_part $part
set_param general.maxThreads 4

foreach f [split [string trim [read [open $out/files.f]]] "\n"] {
  read_verilog -sv $f
}
read_xdc $xdc

set gopts {}
foreach g $generics { lappend gopts -generic $g }
synth_design -top $top -part $part {*}$gopts
report_utilization -file $out/utilization_synth.rpt

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -max_paths 10 -file $out/timing.rpt
report_utilization -hierarchical -file $out/utilization.rpt
report_clock_utilization -file $out/clocks.rpt
report_drc -file $out/drc.rpt
report_methodology -file $out/methodology.rpt
write_checkpoint -force $out/$top.dcp

write_bitstream -force -bin_file $out/$top.bit
