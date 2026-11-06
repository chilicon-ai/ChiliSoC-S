// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_subordinate
//
// Simple AMBA 5 AHB subordinate with a valid/accept user interface.
// See doc/valid_accept_handshake.md.
//
// AHB side
//   A NONSEQ/SEQ transfer is registered when HSEL && HREADY. Each beat
//   (including beats of a burst) becomes one user request. IDLE and BUSY
//   transfers get a zero wait state OKAY response.
//
// User side (subordinate initiates, user responds)
//   Request : subordinate drives req_valid with req_addr/req_write/req_size/
//             req_wdata. Taken on the cycle where req_valid && req_accept.
//   Response: user drives ack_valid with ack_rdata/ack_error. Taken on the
//             cycle where ack_valid && ack_accept. ack_accept is already
//             high while req_valid is high, so the response may be given in
//             the same cycle as the request (never before it).
//
// Latency: if the user takes the request and responds in the first data
//   phase cycle, the transfer completes with one wait state. ack_error gives
//   the two-cycle AHB ERROR response, with HRDATA driven to zero.
//
// Timing
//   HREADYOUT is low in S_REQ, S_WAIT and S_ERR, i.e. from the cycle after
//   the address phase until the response is taken (plus the first ERROR
//   cycle). req_valid, ack_accept and HREADYOUT are decoded from the state
//   register only; HRDATA / HRESP come from registers.
//
// Debug
//   HREADYOUT stuck low in S_REQ : the user neither takes the request nor
//                                  responds (req_accept and ack_valid low).
//   HREADYOUT stuck low in S_WAIT: request taken, ack_valid never comes.
//   Unexpected HRESP ERROR       : the user returned ack_error (error_q).
//   Transfer ignored             : addr_valid low (HSEL, HREADY or HTRANS).
// -----------------------------------------------------------------------------
module basechili_ahb_subordinate
  import basechili_ahb_pkg::*;
#(
  parameter int HADDR_W = 32,   // AHB address width
  parameter int HDATA_W = 32    // AHB data width
) (
  input  logic               clk,
  input  logic               rst_n,       // async, active-low

  // AHB subordinate
  input  logic               HSEL,
  input  logic [HADDR_W-1:0] HADDR,
  input  logic [1:0]         HTRANS,
  input  logic               HWRITE,
  input  logic [2:0]         HSIZE,
  input  logic [HDATA_W-1:0] HWDATA,
  input  logic               HREADY,
  output logic               HREADYOUT,
  output logic               HRESP,
  output logic [HDATA_W-1:0] HRDATA,

  // User request
  output logic               req_valid,
  output logic               req_write,
  output logic [HADDR_W-1:0] req_addr,
  output logic [2:0]         req_size,
  output logic [HDATA_W-1:0] req_wdata,
  input  logic               req_accept,

  // User response
  input  logic               ack_valid,
  input  logic               ack_error,
  input  logic [HDATA_W-1:0] ack_rdata,
  output logic               ack_accept
);

  // ---------------------------------------------------------------------------
  // Control
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    S_IDLE = 3'd0,   // no transfer, HREADYOUT high
    S_REQ  = 3'd1,   // data phase, req_valid and ack_accept high
    S_WAIT = 3'd2,   // data phase, request taken, waiting for ack_valid
    S_ERR  = 3'd3,   // ERROR response, first cycle
    S_DONE = 3'd4    // last data phase cycle, HREADYOUT high
  } state_e;

  state_e             state;          // current state (enum view of state_q)
  state_e             state_d;        // next state
  logic [2:0]         state_q;        // state register bits
  logic               addr_valid;     // NONSEQ/SEQ address phase completing
  logic               addr_ready;     // subordinate can register an address phase
  logic               addr_fire;      // address phase registered this cycle
  logic               ack_fire;       // response taken this cycle
  state_e             resp_state;     // state after the response is taken
  logic [HADDR_W-1:0] addr_q;         // registered HADDR of the current transfer
  logic               write_q;        // registered HWRITE
  logic [2:0]         size_q;         // registered HSIZE
  logic [HDATA_W-1:0] rdata_q;        // registered response data (drives HRDATA)
  logic [HDATA_W-1:0] rdata_d;
  logic               error_q;        // registered ack_error (drives HRESP)

  assign addr_valid = HSEL && HREADY &&
                      ((HTRANS == HTRANS_NONSEQ) || (HTRANS == HTRANS_SEQ));
  assign addr_ready = (state == S_IDLE) || (state == S_DONE);
  assign addr_fire  = addr_valid && addr_ready;
  assign ack_fire   = ack_valid && ack_accept;
  assign resp_state = ack_error ? S_ERR : S_DONE;

  // Next state
  always_comb begin
    state_d = state;
    case (state)
      S_IDLE:  if (addr_fire) state_d = S_REQ;
      S_REQ: begin
        if      (ack_valid)  state_d = resp_state;   // request and response together
        else if (req_accept) state_d = S_WAIT;
      end
      S_WAIT:  if (ack_valid) state_d = resp_state;
      S_ERR:                  state_d = S_DONE;
      S_DONE:                 state_d = addr_fire ? S_REQ : S_IDLE;
      default:                state_d = S_IDLE;
    endcase
  end

  basechili_dff #(.WIDTH($bits(state_e)), .RESET_VAL(S_IDLE)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state = state_e'(state_q);

  // ---------------------------------------------------------------------------
  // Address phase registers
  // ---------------------------------------------------------------------------
  basechili_dffe #(.WIDTH(HADDR_W)) u_addr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (addr_fire),
    .d     (HADDR),
    .q     (addr_q)
  );

  basechili_dffe #(.WIDTH(1)) u_write (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (addr_fire),
    .d     (HWRITE),
    .q     (write_q)
  );

  basechili_dffe #(.WIDTH(3)) u_size (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (addr_fire),
    .d     (HSIZE),
    .q     (size_q)
  );

  // ---------------------------------------------------------------------------
  // Response registers (read data forced to zero on ERROR)
  // ---------------------------------------------------------------------------
  assign rdata_d = ack_error ? '0 : ack_rdata;

  basechili_dffe #(.WIDTH(HDATA_W)) u_rdata (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (ack_fire),
    .d     (rdata_d),
    .q     (rdata_q)
  );

  basechili_dffe #(.WIDTH(1)) u_error (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (ack_fire),
    .d     (ack_error),
    .q     (error_q)
  );

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign req_valid  = (state == S_REQ);
  assign req_write  = write_q;
  assign req_addr   = addr_q;
  assign req_size   = size_q;
  assign req_wdata  = HWDATA;           // stable: data phase held by HREADYOUT low
  assign ack_accept = (state == S_REQ) || (state == S_WAIT);

  assign HREADYOUT = addr_ready;
  assign HRESP     = (state == S_ERR) || ((state == S_DONE) && error_q);
  assign HRDATA    = rdata_q;

endmodule
