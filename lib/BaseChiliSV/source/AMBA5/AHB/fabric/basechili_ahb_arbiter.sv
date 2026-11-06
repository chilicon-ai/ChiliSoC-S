// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_arbiter
//
// N AHB-Lite managers to one AHB-Lite bus (an N:1 layer of a bus matrix).
// Each manager port looks like a subordinate; the bus side is a manager
// (drive it into basechili_ahb_decoder / the subordinates, and take HREADY,
// HRESP from basechili_ahb_mux). HRDATA is shared: wire the bus HRDATA to
// every manager.
//
// One manager owns the bus address phase (HMASTER). Its transfers go through
// with no added latency, so a single active manager runs at full speed. A
// transfer from another manager (or one the bus cannot take yet) is held in
// that manager's port (pend) with its HREADY_m low until the manager owns
// the bus and the held transfer is issued.
//
//   ownership : changes only when the bus HREADY is high, to the round-robin
//               winner (basechili_rr_arbiter) of the managers with a transfer
//               to issue; with none it stays with the last owner (parking).
//               It does not change inside a fixed-length burst (beats_left)
//               or while HMASTLOCK is high.
//   INCR bursts may be split between managers: the first transfer after an
//               owner change is sent as NONSEQ (SEQ) or IDLE (BUSY).
//   data phase: the bus data phase belongs to the manager whose address
//               phase the bus took (dvalid, downer); HWDATA comes from it and
//               only it sees the bus HREADY / HRESP.
//
// Manager m drives HADDR_m[m*ADDR_W +: ADDR_W], HTRANS_m[m*2 +: 2],
// HSIZE_m[m*3 +: 3], HBURST_m[m*3 +: 3], HPROT_m[m*4 +: 4], HWDATA_m[m*DATA_W
// +: DATA_W] and HWRITE_m[m], HMASTLOCK_m[m], and receives HREADY_m[m],
// HRESP_m[m].
//
// Timing    : the bus address phase is combinational from the owner's
//             manager port (or its held copy) and registered state;
//             HREADY_m / HRESP_m / HWDATA are combinational from the bus
//             HREADY / HRESP and registered state. A held transfer waits at
//             least one cycle; changing owner costs one bus cycle.
// Invariants: a manager with a held transfer (pend) is in its data phase
//             (mdp) with HREADY_m low; the bus never shows SEQ / BUSY as the
//             first transfer after an owner change; while beats_left != 0
//             the owner is the data-phase manager (owner == downer), so an
//             owner change always leaves beats_left == 0.
// Debug     : manager stuck (HREADY_m low) -> pend, owner (HMASTER),
//             dvalid / downer and the rr_arbiter req; burst broken ->
//             beats_left and HMASTLOCK; wrong write data -> downer.
// -----------------------------------------------------------------------------
module basechili_ahb_arbiter
  import basechili_ahb_pkg::*;
#(
  parameter  int N      = 2,                          // managers
  parameter  int ADDR_W = 32,                         // HADDR width
  parameter  int DATA_W = 32,                         // data width
  localparam int IDX_W  = (N > 1) ? $clog2(N) : 1,
  localparam int CW     = ADDR_W + 14                 // address / control bits per transfer
) (
  input  logic                clk,
  input  logic                rst_n,                  // async, active-low

  // manager ports
  input  logic [N*ADDR_W-1:0] HADDR_m,
  input  logic [N*2-1:0]      HTRANS_m,
  input  logic [N-1:0]        HWRITE_m,
  input  logic [N*3-1:0]      HSIZE_m,
  input  logic [N*3-1:0]      HBURST_m,
  input  logic [N*4-1:0]      HPROT_m,
  input  logic [N-1:0]        HMASTLOCK_m,
  input  logic [N*DATA_W-1:0] HWDATA_m,
  output logic [N-1:0]        HREADY_m,
  output logic [N-1:0]        HRESP_m,

  // bus (manager side of the decoder / subordinates)
  output logic [ADDR_W-1:0]   HADDR,
  output logic [1:0]          HTRANS,
  output logic                HWRITE,
  output logic [2:0]          HSIZE,
  output logic [2:0]          HBURST,
  output logic [3:0]          HPROT,
  output logic                HMASTLOCK,
  output logic [DATA_W-1:0]   HWDATA,
  output logic [IDX_W-1:0]    HMASTER,                // owner of the address phase
  input  logic                HREADY,                 // bus HREADY
  input  logic                HRESP
);

  logic [N*CW-1:0]  live;         // manager m's address phase, packed
  logic [N*CW-1:0]  held;         // manager m's held transfer
  logic [N-1:0]     pend;         // manager m has a held transfer to issue
  logic [N-1:0]     pend_d;       // next pend
  logic [N-1:0]     mdp;          // manager m is in its data phase
  logic [N-1:0]     mdp_d;        // next mdp
  logic [N-1:0]     live_ok;      // manager m's port may go to the bus now
  logic [N-1:0]     acc;          // manager m's address phase is taken
  logic [N-1:0]     capture;      // ... into its held copy
  logic [N-1:0]     req;          // manager m has a transfer to issue
  logic [IDX_W-1:0] owner;        // address-phase owner
  logic [IDX_W-1:0] owner_d;      // next owner
  logic [N-1:0]     own_oh;       // owner, one-hot
  logic [IDX_W-1:0] gnt_idx;      // its index
  logic             gnt_valid;    // some manager has a transfer to issue
  logic             gnt_accept;   // ownership moves to the winner
  logic             keep;         // ownership must not change
  logic             first;        // no owner transfer taken since the owner changed
  logic             first_d;      // next first
  logic             dvalid;       // a bus data phase is in progress
  logic             dvalid_d;     // next dvalid
  logic [IDX_W-1:0] downer;       // its manager
  logic [N-1:0]     down_oh;      // downer one-hot, zero without a data phase
  logic [N-1:0]     down_raw;     // downer one-hot
  logic [3:0]       beats_left;   // beats left in a fixed-length burst
  logic [3:0]       beats_d;      // next beats_left
  logic [CW-1:0]    own_live;     // the owner's port
  logic [CW-1:0]    own_held;     // the owner's held transfer
  logic [CW-1:0]    bus;          // the transfer on the bus
  logic             own_pend;     // the owner has a held transfer
  logic             own_ok;       // the owner's port may go to the bus
  logic [1:0]       trans_raw;    // HTRANS before the owner-change fix-up

  // ---- manager ports ----------------------------------------------------------
  always_comb begin
    for (int m = 0; m < N; m++) begin
      live[m*CW +: CW] = {HMASTLOCK_m[m], HPROT_m[m*4 +: 4], HBURST_m[m*3 +: 3], HSIZE_m[m*3 +: 3],
                          HWRITE_m[m], HTRANS_m[m*2 +: 2], HADDR_m[m*ADDR_W +: ADDR_W]};
      live_ok[m]  = !mdp[m] || down_oh[m];
      HREADY_m[m] = !mdp[m] || (down_oh[m] && HREADY);
      HRESP_m[m]  = mdp[m] && down_oh[m] && HRESP;
      acc[m]      = HREADY_m[m] && HTRANS_m[m*2+1];
      capture[m]  = acc[m] && !(own_oh[m] && !pend[m] && HREADY);
      pend_d[m]   = capture[m] || (pend[m] && !(own_oh[m] && HREADY));
      mdp_d[m]    = acc[m] || (mdp[m] && !HREADY_m[m]);
      req[m]      = pend[m] || (HTRANS_m[m*2+1] && live_ok[m]);
    end
  end

  for (genvar m = 0; m < N; m++) begin : g_port
    basechili_dffe #(.WIDTH(CW)) u_held (
      .clk   (clk),
      .rst_n (rst_n),
      .en    (capture[m]),
      .d     (live[m*CW +: CW]),
      .q     (held[m*CW +: CW])
    );
  end

  basechili_dff #(.WIDTH(N)) u_pend (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (pend_d),
    .q     (pend)
  );

  basechili_dff #(.WIDTH(N)) u_mdp (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (mdp_d),
    .q     (mdp)
  );

  // ---- bus address phase --------------------------------------------------------
  basechili_decoder #(.N(N)) u_own_dec (
    .in  (owner),
    .out (own_oh)
  );

  basechili_onehot_mux #(.WIDTH(CW), .N(N)) u_own_live (
    .in  (live),
    .sel (own_oh),
    .out (own_live)
  );

  basechili_onehot_mux #(.WIDTH(CW), .N(N)) u_own_held (
    .in  (held),
    .sel (own_oh),
    .out (own_held)
  );

  assign own_pend  = |(pend & own_oh);
  assign own_ok    = |(live_ok & own_oh);
  assign bus       = own_pend ? own_held : own_live;
  assign trans_raw = (own_pend || own_ok) ? bus[ADDR_W +: 2] : HTRANS_IDLE;

  assign HADDR     = bus[0 +: ADDR_W];
  assign HTRANS    = first ? (trans_raw[1] ? HTRANS_NONSEQ : HTRANS_IDLE) : trans_raw;
  assign HWRITE    = bus[ADDR_W + 2];
  assign HSIZE     = bus[ADDR_W + 3 +: 3];
  assign HBURST    = bus[ADDR_W + 6 +: 3];
  assign HPROT     = bus[ADDR_W + 9 +: 4];
  assign HMASTLOCK = bus[ADDR_W + 13];
  assign HMASTER   = owner;

  // ---- ownership ----------------------------------------------------------------
  always_comb begin
    beats_d = beats_left;
    case (HTRANS)
      HTRANS_IDLE:   beats_d = '0;
      HTRANS_NONSEQ: begin
        case (HBURST)
          HBURST_WRAP4,  HBURST_INCR4:  beats_d = 4'd3;
          HBURST_WRAP8,  HBURST_INCR8:  beats_d = 4'd7;
          HBURST_WRAP16, HBURST_INCR16: beats_d = 4'd15;
          default:                      beats_d = '0;
        endcase
      end
      HTRANS_SEQ:    if (beats_left != '0) beats_d = beats_left - 4'd1;
      default:       beats_d = beats_left;   // BUSY
    endcase
  end

  basechili_dffe #(.WIDTH(4)) u_beats (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (beats_d),
    .q     (beats_left)
  );

  basechili_rr_arbiter #(.N(N)) u_rr (
    .clk        (clk),
    .rst_n      (rst_n),
    .req        (req),
    .gnt_accept (gnt_accept),
    .gnt        (),
    .gnt_idx    (gnt_idx),
    .gnt_valid  (gnt_valid)
  );

  assign keep       = (beats_d != '0) || HMASTLOCK;
  assign gnt_accept = HREADY && !keep && gnt_valid;
  assign owner_d    = gnt_accept ? gnt_idx : owner;
  assign first_d    = (owner_d != owner) || (first && !HTRANS[1]);

  basechili_dffe #(.WIDTH(IDX_W)) u_owner (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (owner_d),
    .q     (owner)
  );

  basechili_dffe #(.WIDTH(1), .RESET_VAL(1'b1)) u_first (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (first_d),
    .q     (first)
  );

  // ---- bus data phase -------------------------------------------------------------
  assign dvalid_d = HTRANS[1];

  basechili_dffe #(.WIDTH(1)) u_dvalid (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (dvalid_d),
    .q     (dvalid)
  );

  basechili_dffe #(.WIDTH(IDX_W)) u_downer (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (HREADY),
    .d     (owner),
    .q     (downer)
  );

  basechili_decoder #(.N(N)) u_down_dec (
    .in  (downer),
    .out (down_raw)
  );

  assign down_oh = dvalid ? down_raw : '0;

  basechili_regular_mux #(.WIDTH(DATA_W), .N(N)) u_wdata (
    .in  (HWDATA_m),
    .sel (downer),
    .out (HWDATA)
  );

endmodule
