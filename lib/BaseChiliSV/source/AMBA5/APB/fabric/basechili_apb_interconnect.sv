// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_apb_interconnect
//
// One APB4 manager to N APB4 subordinates. PSEL goes to the subordinate whose
// region matches PADDR (basechili_ahb_decoder: (PADDR & MASK[i]) == BASE[i]);
// its PRDATA / PREADY / PSLVERR go back to the manager. PADDR, PENABLE,
// PWRITE, PWDATA, PSTRB and PPROT are shared: wire the manager's signals to
// every subordinate. An address in no region completes at once with
// PSLVERR.
//
// Timing    : combinational (PSEL_s from PSEL / PADDR, responses from the
//             selected subordinate).
// Invariants: PSEL_s is zero or one-hot, and zero when PSEL is low.
// Debug     : no response (PREADY low forever) -> PSEL_s and the selected
//             subordinate's PREADY_s; unexpected PSLVERR -> sel_default.
// -----------------------------------------------------------------------------
module basechili_apb_interconnect #(
  parameter int                  ADDR_W = 32,     // PADDR width
  parameter int                  DATA_W = 32,     // data width
  parameter int                  N      = 2,      // subordinates
  parameter logic [N*ADDR_W-1:0] BASE   = '0,     // region base addresses
  parameter logic [N*ADDR_W-1:0] MASK   = '0      // region address masks
) (
  // manager side
  input  logic                PSEL,
  input  logic [ADDR_W-1:0]   PADDR,
  output logic                PREADY,
  output logic [DATA_W-1:0]   PRDATA,
  output logic                PSLVERR,

  // subordinate side
  output logic [N-1:0]        PSEL_s,
  input  logic [N-1:0]        PREADY_s,
  input  logic [N*DATA_W-1:0] PRDATA_s,
  input  logic [N-1:0]        PSLVERR_s
);

  logic [N-1:0] sel;           // region matching PADDR
  logic         sel_default;   // no region matches
  logic         ready_sel;     // PREADY of the selected subordinate
  logic         err_sel;       // PSLVERR of the selected subordinate

  basechili_ahb_decoder #(.ADDR_W(ADDR_W), .N(N), .BASE(BASE), .MASK(MASK)) u_dec (
    .addr        (PADDR),
    .sel         (sel),
    .sel_default (sel_default)
  );

  assign PSEL_s = PSEL ? sel : '0;

  basechili_onehot_mux #(.WIDTH(1), .N(N)) u_ready (
    .in  (PREADY_s),
    .sel (sel),
    .out (ready_sel)
  );

  basechili_onehot_mux #(.WIDTH(1), .N(N)) u_err (
    .in  (PSLVERR_s),
    .sel (sel),
    .out (err_sel)
  );

  basechili_onehot_mux #(.WIDTH(DATA_W), .N(N)) u_rdata (
    .in  (PRDATA_s),
    .sel (sel),
    .out (PRDATA)
  );

  assign PREADY  = sel_default || ready_sel;
  assign PSLVERR = sel_default || err_sel;

endmodule
