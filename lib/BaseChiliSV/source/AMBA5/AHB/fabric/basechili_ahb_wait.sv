// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_wait
//
// AHB-Lite wait-state inserter between a bus and one subordinate (e.g. a
// zero-wait basechili_ahb_sram): models a slower memory, or stresses the
// managers with bus stalls. Each NONSEQ / SEQ transfer is accepted on the
// bus side, held for w - 1 cycles, then issued downstream as a NONSEQ
// address phase; the downstream data phase (wait states, OKAY or the
// two-cycle ERROR, HRDATA) passes through. The bus sees w more wait states
// than the subordinate inserts: w = WAIT, or with RANDOM a pseudo-random
// 1..WAIT per transfer (basechili_lfsr, stepped once per transfer). WAIT = 0
// is a pass-through (wires). One transfer is in flight at a time, so bursts
// reach the subordinate as single NONSEQ transfers.
//
// Timing    : HREADYOUT / HRESP / HRDATA are combinational from the
//             subordinate's (S_DATA) or from the state register; HREADY_s is
//             HREADYOUT_s (the downstream bus has one subordinate); the
//             downstream address phase comes from registers; HWDATA_s is
//             HWDATA (the downstream data phase lies inside the bus one).
//             WAIT = 0: every output is its matching input, HREADY_s is
//             HREADY.
// Invariants: wait_cnt != 0 exactly in S_WAIT, and wait_cnt < WAIT;
//             the downstream address phase is NONSEQ only in S_ISSUE;
//             HREADYOUT is low only in S_WAIT, S_ISSUE, or S_DATA with
//             HREADYOUT_s low; HRESP is high only in S_DATA.
// Debug     : bus hangs -> state and wait_cnt (stuck in S_ISSUE: the
//             subordinate's HREADYOUT_s is low with no transfer);
//             wrong address or data at the subordinate -> addr_q / ctrl_q at
//             the S_ISSUE cycle against HADDR when accept was high.
// -----------------------------------------------------------------------------
module basechili_ahb_wait #(
  parameter int          ADDR_W = 32,      // AHB address width
  parameter int          DATA_W = 32,      // AHB data width
  parameter int          WAIT   = 1,       // wait states added per transfer (max with RANDOM); 0: wires
  parameter bit          RANDOM = 1'b0,    // 1: pseudo-random 1..WAIT per transfer
  parameter logic [15:0] SEED   = 16'h1    // LFSR reset state (RANDOM), non-zero
) (
  input  logic              clk,
  input  logic              rst_n,         // async, active-low
  // bus side (this module is the subordinate)
  input  logic              HSEL,
  input  logic [ADDR_W-1:0] HADDR,
  input  logic [1:0]        HTRANS,
  input  logic              HWRITE,
  input  logic [2:0]        HSIZE,
  input  logic [DATA_W-1:0] HWDATA,
  input  logic              HREADY,
  output logic              HREADYOUT,
  output logic              HRESP,
  output logic [DATA_W-1:0] HRDATA,
  // subordinate side (this module is the manager)
  output logic              HSEL_s,
  output logic [ADDR_W-1:0] HADDR_s,
  output logic [1:0]        HTRANS_s,
  output logic              HWRITE_s,
  output logic [2:0]        HSIZE_s,
  output logic [DATA_W-1:0] HWDATA_s,
  output logic              HREADY_s,
  input  logic              HREADYOUT_s,
  input  logic              HRESP_s,
  input  logic [DATA_W-1:0] HRDATA_s
);

  localparam int             CNT_W  = (WAIT > 1) ? $clog2(WAIT) : 1;   // wait_cnt width (holds WAIT - 1)
  localparam logic [CNT_W:0] WAIT_C = (CNT_W + 1)'(WAIT);           // WAIT at wait_cnt width + 1
  localparam logic [CNT_W-1:0] ONE  = 1;

  typedef enum logic [1:0] {
    S_IDLE  = 2'd0,   // no transfer
    S_WAIT  = 2'd1,   // transfer accepted, counting wait_cnt down
    S_ISSUE = 2'd2,   // downstream address phase
    S_DATA  = 2'd3    // downstream data phase, passed through
  } state_e;

  logic [1:0]       state_q;    // state register bits
  state_e           state;      // state_q as an enum (waveforms show names)
  logic [CNT_W-1:0] wait_cnt;   // S_WAIT cycles left

  assign HWDATA_s = HWDATA;
  assign HRDATA   = HRDATA_s;

  if (WAIT == 0) begin : g_wire
    assign state_q   = S_IDLE;
    assign wait_cnt  = '0;
    assign HSEL_s    = HSEL;
    assign HADDR_s   = HADDR;
    assign HTRANS_s  = HTRANS;
    assign HWRITE_s  = HWRITE;
    assign HSIZE_s   = HSIZE;
    assign HREADY_s  = HREADY;
    assign HREADYOUT = HREADYOUT_s;
    assign HRESP     = HRESP_s;
  end else begin : g_wait
    state_e           state_d;
    logic             accept;      // a NONSEQ / SEQ transfer is addressed to us
    logic [CNT_W-1:0] extra;       // S_WAIT cycles of the accepted transfer (w - 1)
    logic [CNT_W-1:0] wait_cnt_d;
    logic [3:0]       ctrl_d;      // {HWRITE, HSIZE} captured on accept
    logic [3:0]       ctrl_q;

    assign accept = HSEL && HTRANS[1] && HREADY && (state == S_IDLE || state == S_DATA);

    if (RANDOM) begin : g_rnd
      logic [15:0]      lfsr;        // LFSR state
      logic [15:0]      lfsr_val;    // load value (unused)
      logic             lfsr_load;   // never loads
      logic [CNT_W:0]   rnd;         // raw draw, 0 .. 2**CNT_W - 1

      assign lfsr_load = 1'b0;
      assign lfsr_val  = SEED;
      assign rnd       = {1'b0, lfsr[CNT_W-1:0]};
      // 2**CNT_W < 2 * WAIT, so one subtraction folds rnd into 0 .. WAIT - 1
      assign extra     = (rnd >= WAIT_C) ? CNT_W'(rnd - WAIT_C) : CNT_W'(rnd);

      basechili_lfsr #(.WIDTH(16), .SEED(SEED)) u_lfsr (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (accept),
        .load     (lfsr_load),
        .load_val (lfsr_val),
        .state    (lfsr)
      );
    end else begin : g_fix
      assign extra = CNT_W'(WAIT_C - 1'b1);
    end

    always_comb begin
      state_d    = state;
      wait_cnt_d = '0;
      case (state)
        S_IDLE: if (accept) begin
          state_d    = (extra != '0) ? S_WAIT : S_ISSUE;
          wait_cnt_d = extra;
        end
        S_WAIT: begin
          wait_cnt_d = wait_cnt - ONE;
          if (wait_cnt == ONE) state_d = S_ISSUE;
        end
        S_ISSUE: if (HREADYOUT_s) state_d = S_DATA;
        S_DATA: if (HREADYOUT_s) begin
          if (accept) begin
            state_d    = (extra != '0) ? S_WAIT : S_ISSUE;
            wait_cnt_d = extra;
          end else begin
            state_d = S_IDLE;
          end
        end
        default: state_d = S_IDLE;
      endcase
    end

    assign ctrl_d = {HWRITE, HSIZE};

    basechili_dff #(.WIDTH($bits(state_e)), .RESET_VAL(S_IDLE)) u_state (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (state_d),
      .q     (state_q)
    );

    basechili_dff #(.WIDTH(CNT_W)) u_cnt (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (wait_cnt_d),
      .q     (wait_cnt)
    );

    basechili_dffe #(.WIDTH(ADDR_W)) u_addr (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (accept),
      .d     (HADDR),
      .q     (HADDR_s)
    );

    basechili_dffe #(.WIDTH(4)) u_ctrl (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (accept),
      .d     (ctrl_d),
      .q     (ctrl_q)
    );

    assign HSEL_s    = state == S_ISSUE;
    assign HTRANS_s  = (state == S_ISSUE) ? 2'b10 : 2'b00;   // NONSEQ / IDLE
    assign HWRITE_s  = ctrl_q[3];
    assign HSIZE_s   = ctrl_q[2:0];
    assign HREADY_s  = HREADYOUT_s;
    assign HREADYOUT = (state == S_IDLE) || (state == S_DATA && HREADYOUT_s);
    assign HRESP     = (state == S_DATA) && HRESP_s;
  end

  assign state = state_e'(state_q);

endmodule
