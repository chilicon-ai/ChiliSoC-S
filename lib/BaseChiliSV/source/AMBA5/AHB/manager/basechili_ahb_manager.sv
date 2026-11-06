// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_manager
//
// Simple AMBA 5 AHB manager with a valid/accept user interface.
// See doc/valid_accept_handshake.md.
//
// User side
//   Request : user drives req_valid with req_addr/req_write/req_wdata.
//             The request is taken on the cycle where req_valid && req_accept.
//   Response: manager drives ack_valid with ack_rdata/ack_error.
//             The response is consumed on the cycle where ack_valid && ack_accept.
//   One request is in flight at a time.
//
// AHB side
//   USER_DATA_W may be a multiple of HDATA_W. Each request is sent as one
//   incrementing burst of BEATS = USER_DATA_W / HDATA_W full-width beats
//   (SINGLE, INCR4, INCR8, INCR16, or undefined-length INCR otherwise).
//   Beat i carries req_wdata / ack_rdata bits [i*HDATA_W +: HDATA_W].
//   req_addr must be aligned to USER_DATA_W/8 bytes, and USER_DATA_W/8 must
//   not exceed 1024, so a burst never crosses a 1KB boundary.
//   req_size is HSIZE: log2(HDATA_W / 8) for full-width beats (required for
//   bursts); a single-beat request (USER_DATA_W == HDATA_W) may be narrower
//   (byte, halfword, ...), with req_addr aligned to that size. Narrow data
//   travels on its AHB byte lanes (req_wdata / ack_rdata at the lanes of
//   req_addr), as AHB requires.
//   An ERROR response does not cancel the burst; remaining beats complete
//   and ack_error is reported with the response.
//
// Timing
//   req_fire moves S_IDLE -> S_BUSY; the first address phase (NONSEQ) is on
//   the next cycle. When the last data phase completes, state moves to S_ACK
//   and ack_valid rises on the next cycle. req_accept, ack_valid and all AHB
//   outputs are decoded from registers only.
//
// Invariants
//   data_active -> state == S_BUSY
//   addr_cnt <= BEATS
//
// Debug
//   Stuck in S_BUSY: HREADY held low by the subordinate; addr_cnt / data_cnt
//                    show how far the burst got.
//   Stuck in S_ACK : the user never asserts ack_accept.
//   Wrong ack_rdata: rdata_en shows which beat slice is captured each cycle.
//   ack_error set  : an ERROR beat came back; err_beat marks the cycle.
// -----------------------------------------------------------------------------
module basechili_ahb_manager
  import basechili_ahb_pkg::*;
#(
  parameter int         HADDR_W     = 32,             // AHB address width
  parameter int         HDATA_W     = 32,             // AHB data width
  parameter int         USER_DATA_W = HDATA_W,        // user data width, multiple of HDATA_W
  parameter logic [3:0] HPROT_VAL   = HPROT_DEFAULT   // HPROT driven on every transfer
) (
  input  logic                   clk,
  input  logic                   rst_n,               // async, active-low

  // User request
  input  logic                   req_valid,
  input  logic                   req_write,
  input  logic [HADDR_W-1:0]     req_addr,
  input  logic [USER_DATA_W-1:0] req_wdata,
  input  logic [2:0]             req_size,            // HSIZE: full width, or narrower for a single beat
  output logic                   req_accept,

  // User response
  output logic                   ack_valid,
  output logic                   ack_error,
  output logic [USER_DATA_W-1:0] ack_rdata,
  input  logic                   ack_accept,

  // AHB manager
  output logic [HADDR_W-1:0]     HADDR,
  output logic [1:0]             HTRANS,
  output logic                   HWRITE,
  output logic [2:0]             HSIZE,
  output logic [2:0]             HBURST,
  output logic [3:0]             HPROT,
  output logic                   HMASTLOCK,
  output logic [HDATA_W-1:0]     HWDATA,
  input  logic                   HREADY,
  input  logic                   HRESP,
  input  logic [HDATA_W-1:0]     HRDATA
);

  // ---------------------------------------------------------------------------
  // Derived constants
  // ---------------------------------------------------------------------------
  localparam int BEATS  = USER_DATA_W / HDATA_W;
  localparam int BEAT_W = (BEATS > 1) ? $clog2(BEATS) : 1;   // beat index width
  localparam int CNT_W  = $clog2(BEATS + 1);                 // 0..BEATS

  localparam logic [BEAT_W-1:0]  LAST_BEAT = BEAT_W'(BEATS - 1);
  localparam logic [CNT_W-1:0]   ALL_BEATS = CNT_W'(BEATS);
  localparam logic [HADDR_W-1:0] ADDR_INC  = HADDR_W'(HDATA_W / 8);

  localparam logic [2:0] HBURST_VAL = (BEATS == 1)  ? HBURST_SINGLE :
                                      (BEATS == 4)  ? HBURST_INCR4  :
                                      (BEATS == 8)  ? HBURST_INCR8  :
                                      (BEATS == 16) ? HBURST_INCR16 :
                                                      HBURST_INCR;

  // ---------------------------------------------------------------------------
  // Control
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    S_IDLE = 2'd0,   // waiting for a request (req_accept high)
    S_BUSY = 2'd1,   // AHB burst in progress
    S_ACK  = 2'd2    // response held on ack_valid until ack_accept
  } state_e;

  state_e             state;            // current state (enum view of state_q)
  state_e             state_d;          // next state
  logic [1:0]         state_q;          // state register bits
  logic               req_fire;         // request taken this cycle
  logic               addr_active;      // a beat is in the AHB address phase
  logic               addr_done;        // address phase completes this cycle
  logic               data_active;      // a beat is in the AHB data phase
  logic               data_done;        // data phase completes this cycle
  logic               last_done;        // final data phase completes this cycle
  logic               err_beat;         // data phase completes with ERROR
  logic [CNT_W-1:0]   addr_cnt;         // beats issued in address phase
  logic [BEAT_W-1:0]  data_cnt;         // index of beat in data phase
  logic [HADDR_W-1:0] haddr_q;          // HADDR register
  logic [HADDR_W-1:0] haddr_d;
  logic               haddr_en;
  logic               hwrite_q;         // HWRITE register (direction of the request)
  logic [2:0]         hsize_q;          // HSIZE register (size of the request)
  logic               error_q;          // an ERROR beat was seen in this burst
  logic               error_d;
  logic               error_en;

  assign req_fire    = req_valid && (state == S_IDLE);
  assign addr_active = (state == S_BUSY) && (addr_cnt != ALL_BEATS);
  assign addr_done   = addr_active && HREADY;
  assign data_done   = data_active && HREADY;
  assign last_done   = data_done && (data_cnt == LAST_BEAT);
  assign err_beat    = data_done && (HRESP == HRESP_ERROR);

  // Next state
  always_comb begin
    state_d = state;
    case (state)
      S_IDLE:  if (req_valid)  state_d = S_BUSY;
      S_BUSY:  if (last_done)  state_d = S_ACK;
      S_ACK:   if (ack_accept) state_d = S_IDLE;
      default:                 state_d = S_IDLE;
    endcase
  end

  basechili_dff #(.WIDTH($bits(state_e)), .RESET_VAL(S_IDLE)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state = state_e'(state_q);

  // A beat moves into the data phase when its address phase completes
  basechili_dffe #(.WIDTH(1)) u_data_active (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (addr_active),
    .q     (data_active)
  );

  // Address: load on request, increment per accepted address phase
  assign haddr_d  = req_fire ? req_addr : haddr_q + ADDR_INC;
  assign haddr_en = req_fire || addr_done;

  basechili_dffe #(.WIDTH(HADDR_W)) u_haddr (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (haddr_en),
    .d     (haddr_d),
    .q     (haddr_q)
  );

  basechili_dffe #(.WIDTH(1)) u_hwrite (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (req_fire),
    .d     (req_write),
    .q     (hwrite_q)
  );

  basechili_dffe #(.WIDTH(3)) u_hsize (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (req_fire),
    .d     (req_size),
    .q     (hsize_q)
  );

  // Error flag: cleared on request, set by any ERROR beat
  assign error_d  = !req_fire;          // 0 on a new request, 1 on an ERROR beat
  assign error_en = req_fire || err_beat;

  basechili_dffe #(.WIDTH(1)) u_error (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (error_en),
    .d     (error_d),
    .q     (error_q)
  );

  basechili_counter #(.WIDTH(CNT_W)) u_addr_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (req_fire),
    .en    (addr_done),
    .count (addr_cnt)
  );

  basechili_counter #(.WIDTH(BEAT_W)) u_data_cnt (
    .clk   (clk),
    .rst_n (rst_n),
    .clr   (req_fire),
    .en    (data_done),
    .count (data_cnt)
  );

  // ---------------------------------------------------------------------------
  // Write data: latch the wide word, send one beat per data phase
  // ---------------------------------------------------------------------------
  logic [USER_DATA_W-1:0] wdata_q;      // request write data, all beats

  basechili_dffe #(.WIDTH(USER_DATA_W)) u_wdata (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (req_fire),
    .d     (req_wdata),
    .q     (wdata_q)
  );

  basechili_regular_mux #(.WIDTH(HDATA_W), .N(BEATS)) u_wdata_mux (
    .in    (wdata_q),
    .sel   (data_cnt),
    .out   (HWDATA)
  );

  // ---------------------------------------------------------------------------
  // Read data: capture each beat into its slice of the wide word
  // ---------------------------------------------------------------------------
  logic [BEATS-1:0] beat_sel;           // one-hot data_cnt
  logic [BEATS-1:0] rdata_en;           // capture HRDATA into beat slice i

  basechili_decoder #(.N(BEATS)) u_beat_dec (
    .in    (data_cnt),
    .out   (beat_sel)
  );

  assign rdata_en = beat_sel & {BEATS{data_done && !hwrite_q}};

  for (genvar i = 0; i < BEATS; i++) begin : g_rdata
    basechili_dffe #(.WIDTH(HDATA_W)) u_rdata (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (rdata_en[i]),
      .d     (HRDATA),
      .q     (ack_rdata[i*HDATA_W +: HDATA_W])
    );
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  assign req_accept   = (state == S_IDLE);
  assign ack_valid    = (state == S_ACK);
  assign ack_error    = error_q;

  assign HADDR     = haddr_q;
  assign HTRANS    = !addr_active      ? HTRANS_IDLE   :
                     (addr_cnt == '0)  ? HTRANS_NONSEQ :
                                         HTRANS_SEQ;
  assign HWRITE    = hwrite_q;
  assign HSIZE     = hsize_q;
  assign HBURST    = HBURST_VAL;
  assign HPROT     = HPROT_VAL;
  assign HMASTLOCK = 1'b0;

endmodule
