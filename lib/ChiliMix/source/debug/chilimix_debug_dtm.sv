// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_debug_dtm
//
// RISC-V debug transport module over JTAG (RISC-V Debug Specification 1.0,
// section 6.1), so OpenOCD / GDB find a standard DTM. A basechili_jtag_tap
// (5-bit IR) with:
//   0x01 IDCODE   IDCODE parameter
//   0x10 dtmcs    version 1, abits ABITS, idle IDLE, dmistat; a write of
//                 dmireset or dtmhardreset clears the sticky error (a
//                 request in flight still completes: the DM always answers)
//   0x11 dmi      {address, data, op}: Update-DR with op 1 (read) / 2 (write)
//                 starts a DMI request unless one is in flight or an error is
//                 sticky; Capture-DR returns the last address, the last read
//                 data and op = the sticky error, or 3 (busy) while a request
//                 is in flight
//   other         BYPASS
// Errors (dmistat / op, sticky until dmireset): 3 when Capture-DR or a new
// request (Update-DR) finds a request still in flight, 2 or 3 when the DM
// answers so.
// The DMI side runs on clk: one request at a time crosses from tck through
// a basechili_handshake_sync, the response comes back through another, so
// the debug module needs no knowledge of tck.
//
// Timing    : the TAP and the dmi / dtmcs registers run on tck (tdo on its
//             falling edge; Update-DR acts on the rising edge, see the
//             1149.1 deviation in basechili_jtag_tap); a request reaches dmi_req_valid STAGES clk edges
//             after the Update-DR edge; a response is seen STAGES tck edges
//             after dmi_rsp_valid / accept (so tck must keep running, e.g.
//             IDLE cycles in Run-Test/Idle).
// Invariants: a request starts only on Update-DR of dmi with op 1 / 2, no
//             sticky error and nothing in flight; the error is sticky (it
//             clears only by dmireset or dtmhardreset); in_flight falls only
//             on a response.
// Reset     : rst_n (power-on / debug domain, not the system reset that
//             ndmreset drives) resets both domains, released per clock by
//             basechili_reset_sync; trst_n resets the TAP only.
// Debug     : no request -> u_tap.ir (0x11), dmi_upd, err, busy; stuck busy
//             -> in_flight, u_req.src_accept, u_rsp.dst_valid; wrong data ->
//             rsp_data, dmi_sr.
// -----------------------------------------------------------------------------
module chilimix_debug_dtm #(
  parameter  int          ABITS  = 7,              // DMI address bits
  parameter  logic [31:0] IDCODE = 32'h0000_0001,  // JTAG IDCODE, bit 0 = 1
  parameter  int          IDLE   = 1,              // Run-Test/Idle hint, 0 .. 7
  localparam int          DMI_W  = ABITS + 34      // dmi register bits
) (
  // JTAG
  input  logic             tck,
  input  logic             trst_n,          // async, active-low (tie high if absent)
  input  logic             tms,
  input  logic             tdi,
  output logic             tdo,
  output logic             tdo_en,
  // debug domain
  input  logic             clk,
  input  logic             rst_n,           // async, active-low (power-on, not ndmreset)
  // DMI, clk domain (valid / accept)
  output logic             dmi_req_valid,
  input  logic             dmi_req_accept,
  output logic [ABITS-1:0] dmi_req_addr,
  output logic [31:0]      dmi_req_data,
  output logic [1:0]       dmi_req_op,      // 1 read, 2 write
  input  logic             dmi_rsp_valid,
  output logic             dmi_rsp_accept,
  input  logic [31:0]      dmi_rsp_data,    // read data
  input  logic [1:0]       dmi_rsp_op       // 0 success, 2 failed, 3 busy
);

  localparam logic [4:0] IR_DTMCS = 5'h10;
  localparam logic [4:0] IR_DMI   = 5'h11;
  localparam int         REQ_W    = ABITS + 34;    // {addr, data, op}
  localparam int         RSP_W    = 34;            // {data, op}

  logic             tck_rst_n;       // rst_n released on tck
  logic             clk_rst_n;       // rst_n released on clk
  logic             tap_rst_n;       // tck_rst_n and trst_n
  logic [4:0]       ir;
  logic             capture_dr;
  logic             shift_dr;
  logic             update_dr;
  logic             user_sel;        // ir selects dtmcs or dmi
  logic             user_tdo;        // LSB of the selected register
  logic             sel_dtmcs;
  logic             sel_dmi;
  logic [31:0]      dtmcs_sr;        // dtmcs shift register
  logic [31:0]      dtmcs_sr_d;
  logic [31:0]      dtmcs_cap;       // dtmcs capture value
  logic [DMI_W-1:0] dmi_sr;          // dmi shift register
  logic [DMI_W-1:0] dmi_sr_d;
  logic [DMI_W-1:0] dmi_cap;         // dmi capture value
  logic             dtmcs_upd;       // Update-DR of dtmcs
  logic             dmi_reset;       // dtmcs write with dmireset or dtmhardreset
  logic             dmi_cap_en;      // Capture-DR of dmi
  logic             dmi_upd;         // Update-DR of dmi
  logic             dmi_rw;          // ... with op read or write
  logic             busy;            // a request is in flight or not yet taken
  logic [1:0]       err;             // sticky error (dmistat)
  logic [1:0]       err_d;
  logic [1:0]       cap_op;          // op returned by Capture-DR
  logic             req_go;          // start a request (tck)
  logic             req_accept;      // u_req ready for a request (tck)
  logic [REQ_W-1:0] req_word;        // {addr, data, op}
  logic [REQ_W-1:0] req_out;         // request word on the clk side
  logic             in_flight;       // waiting for the response (tck)
  logic             in_flight_d;
  logic             rsp_valid;       // response arrived (tck)
  logic             rsp_accept;      // take it at once
  logic [RSP_W-1:0] rsp_word;        // {data, op} on the clk side
  logic [RSP_W-1:0] rsp_in;          // {data, op} on the tck side
  logic             rsp_take;        // a response for the request in flight
  logic             rsp_data_en;
  logic [31:0]      rsp_in_data;     // data of the arriving response
  logic [31:0]      rsp_data;        // last read data
  logic             addr_en;
  logic [ABITS-1:0] dmi_sr_addr;     // address field of dmi
  logic [ABITS-1:0] addr_q;          // address of the last request

  // ---- resets
  basechili_reset_sync u_tck_rst (
    .clk         (tck),
    .rst_n_async (rst_n),
    .test_en     (1'b0),
    .rst_n_sync  (tck_rst_n)
  );

  basechili_reset_sync u_clk_rst (
    .clk         (clk),
    .rst_n_async (rst_n),
    .test_en     (1'b0),
    .rst_n_sync  (clk_rst_n)
  );

  assign tap_rst_n = tck_rst_n && trst_n;

  // ---- TAP
  basechili_jtag_tap #(.IR_W(5), .IDCODE(IDCODE), .IDCODE_IR(5'h01)) u_tap (
    .tck        (tck),
    .rst_n      (tap_rst_n),
    .tms        (tms),
    .tdi        (tdi),
    .tdo        (tdo),
    .tdo_en     (tdo_en),
    .ir         (ir),
    .tlr        (),
    .capture_dr (capture_dr),
    .shift_dr   (shift_dr),
    .update_dr  (update_dr),
    .user_sel   (user_sel),
    .user_tdo   (user_tdo)
  );

  assign sel_dtmcs = ir == IR_DTMCS;
  assign sel_dmi   = ir == IR_DMI;
  assign user_sel  = sel_dtmcs || sel_dmi;
  assign user_tdo  = sel_dtmcs ? dtmcs_sr[0] : dmi_sr[0];

  // ---- dtmcs
  assign dtmcs_cap = {11'd0, 3'd0, 2'b00, 1'b0, 3'(IDLE), err, 6'(ABITS), 4'd1};

  always_comb begin
    if (capture_dr && sel_dtmcs)    dtmcs_sr_d = dtmcs_cap;
    else if (shift_dr && sel_dtmcs) dtmcs_sr_d = {tdi, dtmcs_sr[31:1]};
    else                            dtmcs_sr_d = dtmcs_sr;
  end

  basechili_dff #(.WIDTH(32)) u_dtmcs_sr (
    .clk   (tck),
    .rst_n (tck_rst_n),
    .d     (dtmcs_sr_d),
    .q     (dtmcs_sr)
  );

  assign dtmcs_upd  = update_dr && sel_dtmcs;
  assign dmi_reset  = dtmcs_upd && (dtmcs_sr[16] || dtmcs_sr[17]);

  // ---- dmi
  assign busy    = in_flight || !req_accept;
  assign cap_op  = (err != 2'd0) ? err : (busy ? 2'd3 : 2'd0);
  assign dmi_cap = {addr_q, rsp_data, cap_op};

  always_comb begin
    if (capture_dr && sel_dmi)    dmi_sr_d = dmi_cap;
    else if (shift_dr && sel_dmi) dmi_sr_d = {tdi, dmi_sr[DMI_W-1:1]};
    else                          dmi_sr_d = dmi_sr;
  end

  basechili_dff #(.WIDTH(DMI_W)) u_dmi_sr (
    .clk   (tck),
    .rst_n (tck_rst_n),
    .d     (dmi_sr_d),
    .q     (dmi_sr)
  );

  assign dmi_cap_en = capture_dr && sel_dmi;
  assign dmi_upd    = update_dr && sel_dmi;
  assign dmi_rw     = dmi_upd && (dmi_sr[1:0] == 2'd1 || dmi_sr[1:0] == 2'd2);
  assign req_go     = dmi_rw && err == 2'd0 && !busy;
  assign req_word   = dmi_sr;

  // ---- sticky error
  assign rsp_take = rsp_valid && in_flight;

  always_comb begin
    if (dmi_reset)                                           err_d = 2'd0;
    else if (err != 2'd0)                                    err_d = err;
    else if ((dmi_cap_en || dmi_rw) && busy)                 err_d = 2'd3;
    else if (rsp_take && rsp_in[1])                          err_d = rsp_in[1:0];
    else                                                     err_d = err;
  end

  basechili_dff #(.WIDTH(2)) u_err (
    .clk   (tck),
    .rst_n (tck_rst_n),
    .d     (err_d),
    .q     (err)
  );

  // ---- request in flight, response data, last address
  assign in_flight_d = req_go || (in_flight && !rsp_valid);

  basechili_dff #(.WIDTH(1)) u_in_flight (
    .clk   (tck),
    .rst_n (tck_rst_n),
    .d     (in_flight_d),
    .q     (in_flight)
  );

  assign rsp_accept  = 1'b1;
  assign rsp_data_en = rsp_take;
  assign rsp_in_data = rsp_in[RSP_W-1:2];

  basechili_dffe #(.WIDTH(32)) u_rsp_data (
    .clk   (tck),
    .rst_n (tck_rst_n),
    .en    (rsp_data_en),
    .d     (rsp_in_data),
    .q     (rsp_data)
  );

  assign addr_en     = req_go;
  assign dmi_sr_addr = dmi_sr[DMI_W-1:34];

  basechili_dffe #(.WIDTH(ABITS)) u_addr (
    .clk   (tck),
    .rst_n (tck_rst_n),
    .en    (addr_en),
    .d     (dmi_sr_addr),
    .q     (addr_q)
  );

  // ---- clock-domain crossings
  basechili_handshake_sync #(.WIDTH(REQ_W)) u_req (
    .src_clk    (tck),
    .src_rst_n  (tck_rst_n),
    .src_valid  (req_go),
    .src_accept (req_accept),
    .src_data   (req_word),
    .dst_clk    (clk),
    .dst_rst_n  (clk_rst_n),
    .dst_valid  (dmi_req_valid),
    .dst_accept (dmi_req_accept),
    .dst_data   (req_out)
  );

  assign dmi_req_addr = req_out[REQ_W-1:34];
  assign dmi_req_data = req_out[33:2];
  assign dmi_req_op   = req_out[1:0];
  assign rsp_word     = {dmi_rsp_data, dmi_rsp_op};

  basechili_handshake_sync #(.WIDTH(RSP_W)) u_rsp (
    .src_clk    (clk),
    .src_rst_n  (clk_rst_n),
    .src_valid  (dmi_rsp_valid),
    .src_accept (dmi_rsp_accept),
    .src_data   (rsp_word),
    .dst_clk    (tck),
    .dst_rst_n  (tck_rst_n),
    .dst_valid  (rsp_valid),
    .dst_accept (rsp_accept),
    .dst_data   (rsp_in)
  );

endmodule
