// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_mux
//
// AHB subordinate-to-manager response mux. The address-phase select (sel,
// usually basechili_ahb_decoder's sel plus sel_default as one more input) is
// registered when HREADY is high and HTRANS is NONSEQ or SEQ, so the data
// phase response comes from the subordinate that took the address. With no
// subordinate in the data phase (after IDLE / BUSY, or after reset) the bus
// sees a zero-wait OKAY.
//
// HREADY is the bus HREADY: it goes to the manager and back to every
// subordinate's HREADY input.
//
// Subordinate i drives HREADYOUT_s[i], HRESP_s[i] and
// HRDATA_s[i*DATA_W +: DATA_W].
//
// Timing    : HREADY / HRESP / HRDATA are combinational from the selected
//             subordinate's outputs and the registered select (dsel).
// Invariants: dsel is zero or one-hot; dsel changes only after a cycle
//             with HREADY high.
// Debug     : response from the wrong subordinate -> dsel (u_dsel.q) and
//             the sel / HTRANS seen in the address phase before it.
// -----------------------------------------------------------------------------
module basechili_ahb_mux #(
  parameter int N      = 2,    // number of subordinates
  parameter int DATA_W = 32    // AHB data width
) (
  input  logic              clk,
  input  logic              rst_n,         // async, active-low
  input  logic [N-1:0]      sel,           // address-phase select, zero or one-hot
  input  logic [1:0]        HTRANS,        // address-phase transfer type
  input  logic [N-1:0]      HREADYOUT_s,
  input  logic [N-1:0]      HRESP_s,
  input  logic [N*DATA_W-1:0] HRDATA_s,
  output logic              HREADY,        // bus HREADY
  output logic              HRESP,
  output logic [DATA_W-1:0] HRDATA
);

  logic [N-1:0] dsel;        // data-phase select, one-hot or zero
  logic [N-1:0] dsel_d;      // select of the transfer that enters the data phase
  logic         active;      // a subordinate is in the data phase
  logic         ready_sel;   // HREADYOUT of the data-phase subordinate
  logic         resp_sel;    // HRESP of the data-phase subordinate

  // A cycle with HREADY high ends the data phase and starts the next one.
  assign dsel_d = HTRANS[1] ? sel : '0;

  basechili_dffe #(.WIDTH(N)) u_dsel (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (dsel_d),
    .q     (dsel)
  );

  basechili_onehot_mux #(.WIDTH(1), .N(N)) u_ready (
    .in  (HREADYOUT_s),
    .sel (dsel),
    .out (ready_sel)
  );

  basechili_onehot_mux #(.WIDTH(1), .N(N)) u_resp (
    .in  (HRESP_s),
    .sel (dsel),
    .out (resp_sel)
  );

  basechili_onehot_mux #(.WIDTH(DATA_W), .N(N)) u_rdata (
    .in  (HRDATA_s),
    .sel (dsel),
    .out (HRDATA)
  );

  assign active = |dsel;
  assign HREADY = active ? ready_sel : 1'b1;
  assign HRESP  = active && resp_sel;

endmodule
