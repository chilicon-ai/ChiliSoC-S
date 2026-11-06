// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_default_sub
//
// AHB default subordinate: selected for addresses no other subordinate
// decodes (basechili_ahb_decoder's sel_default). Every NONSEQ / SEQ
// transfer gets the two-cycle ERROR response; IDLE and BUSY get a zero-wait
// OKAY. HRDATA is always zero.
//
// Timing    : HREADYOUT / HRESP are decoded from the state register.
// Invariants: HRESP is high only in S_ERR1 and S_ERR2; HREADYOUT is low only
//             in S_ERR1 (the ERROR response is always two cycles).
// Debug     : unexpected ERROR -> the address decoded to no subordinate:
//             check the decoder regions against HADDR of the transfer.
// -----------------------------------------------------------------------------
module basechili_ahb_default_sub #(
  parameter int DATA_W = 32    // AHB data width
) (
  input  logic              clk,
  input  logic              rst_n,       // async, active-low
  input  logic              HSEL,
  input  logic [1:0]        HTRANS,
  input  logic              HREADY,
  output logic              HREADYOUT,
  output logic              HRESP,
  output logic [DATA_W-1:0] HRDATA
);

  typedef enum logic [1:0] {
    S_IDLE = 2'd0,   // no transfer, OKAY
    S_ERR1 = 2'd1,   // ERROR, first cycle (HREADYOUT low)
    S_ERR2 = 2'd2    // ERROR, second cycle (HREADYOUT high)
  } state_e;

  logic [1:0] state_q;   // state register bits
  state_e     state;     // state_q as an enum (waveforms show names)
  state_e     state_d;   // next state
  logic       take;      // a NONSEQ / SEQ transfer is addressed to us

  assign state = state_e'(state_q);
  assign take  = HSEL && HREADY && HTRANS[1];

  // A transfer is taken in S_IDLE or S_ERR2 (HREADY is high in both).
  always_comb begin
    case (state)
      S_IDLE, S_ERR2: state_d = take ? S_ERR1 : S_IDLE;
      S_ERR1:         state_d = S_ERR2;
      default:        state_d = S_IDLE;
    endcase
  end

  basechili_dff #(.WIDTH($bits(state_e)), .RESET_VAL(S_IDLE)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign HREADYOUT = state != S_ERR1;
  assign HRESP     = state != S_IDLE;
  assign HRDATA    = '0;

endmodule
