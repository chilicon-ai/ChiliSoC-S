// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_ahb_subordinate -- the manager / subordinate
// loopback of basechili_ahb_manager_tb.
`include "basechili_ahb_manager_tb.sv"
module basechili_ahb_subordinate_tb #(
  parameter int HDATA_W     = 32,
  parameter int USER_DATA_W = HDATA_W
);
  basechili_ahb_manager_tb #(.HDATA_W(HDATA_W), .USER_DATA_W(USER_DATA_W)) u_loopback ();
endmodule
