# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Chilicon
# ChillU-S core: single clock. Registered ports (logic-level budget 0 in the
# core's port specification: an output straight
# from a flop, an input straight into one) get a tight core-side budget,
# IO_RULE_PCT of the period is left to the other side; the others (io_relaxed:
# ports with a larger budget) keep a
# 20% budget. io_relaxed must equal them, glob patterns on port names without the bus index. io_dmss_req:
# the data port's request outputs (dmss_req and the bus in its cone: address
# adder, PMP check, store data) leave only clk_dmss_req_pct of the period to
# the other side, so the core keeps 85% for that path;
# whatever the SoC puts behind dmss_req must fit in that 15%.
current_design chillus_core

set clk_name    core_clock
set clk_period  $::env(CLK_PERIOD)
set clk_io_pct  0.2
set io_rule_pct 0.7
set clk_dmss_req_pct 0.15
set io_dmss_req {dmss_req dmss_addr dmss_we dmss_be dmss_wdata}

set io_relaxed {clk rst_n rvfi_* imss_req imss_addr imss_gnt imss_rvalid imss_rdata imss_err dmss_req dmss_addr dmss_we dmss_be dmss_wdata dmss_gnt dmss_rvalid dmss_rdata dmss_err mtime test_en boot_addr hart_id}

create_clock -name $clk_name -period $clk_period [get_ports clk]
set clk_io_name vclk_$clk_name
create_clock -name $clk_io_name -period $clk_period

proc io_pct {port} {
  global io_relaxed io_dmss_req clk_io_pct clk_dmss_req_pct io_rule_pct
  set name [regsub {\[[0-9]+\]$} [get_full_name $port] ""]
  if {[lsearch -exact $io_dmss_req $name] >= 0} {
    return $clk_dmss_req_pct
  }
  foreach pat $io_relaxed {
    if {[string match $pat $name]} { return $clk_io_pct }
  }
  return $io_rule_pct
}

foreach port [all_inputs -no_clocks] {
  set_input_delay [expr {$clk_period * [io_pct $port]}] -clock $clk_io_name $port
}
foreach port [all_outputs] {
  set_output_delay [expr {$clk_period * [io_pct $port]}] -clock $clk_io_name $port
}
