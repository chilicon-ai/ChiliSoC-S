// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_ahb_to_apb
//
// AHB-Lite subordinate to APB4 manager bridge. Each NONSEQ / SEQ AHB transfer
// becomes one APB transfer: SETUP (PSEL) then ACCESS (PSEL, PENABLE) until
// PREADY. The AHB data phase waits (HREADYOUT low) until the APB transfer
// ends; PSLVERR becomes the two-cycle AHB ERROR. IDLE and BUSY transfers get
// a zero-wait OKAY.
//
//   cycle:     0        1        2         3
//   AHB    : address  wait     wait      HREADYOUT, HRDATA
//   APB    :          SETUP    ACCESS    (PREADY in cycle 2)
//
// PWDATA is HWDATA passed through (the manager holds it while HREADYOUT is
// low). PSTRB comes from HADDR / HSIZE (zero for reads). PPROT: [0]
// privileged = HPROT[1], [1] non-secure = 0, [2] instruction = !HPROT[0].
//
// Timing    : APB outputs, HREADYOUT, HRESP and HRDATA come from registers
//             (PWDATA from HWDATA). An APB transfer with PREADY high in its
//             first ACCESS cycle completes the AHB transfer in 4 cycles from
//             the address phase (2 wait states); a new address phase can
//             overlap the last cycle.
// Invariants: PENABLE only in S_ACCESS; PSEL in S_SETUP and S_ACCESS;
//             HREADYOUT low in S_SETUP, S_ACCESS and S_ERR1; HRESP high only
//             in S_ERR1 and S_ERR2.
// Debug     : bus stuck -> state S_ACCESS with PREADY low (APB subordinate
//             never ready); unexpected ERROR -> PSLVERR in the last ACCESS
//             cycle; wrong data -> rdata_q (u_rdata.q) and PRDATA there.
// -----------------------------------------------------------------------------
module basechili_ahb_to_apb #(
  parameter  int ADDR_W = 32,              // HADDR / PADDR width
  parameter  int DATA_W = 32,              // data width (power of two, >= 16)
  localparam int N_LANE = DATA_W / 8,      // byte lanes
  localparam int OFF_W  = $clog2(N_LANE),  // byte offset bits
  localparam int SIZE_W = $clog2(OFF_W + 1)
) (
  input  logic              clk,
  input  logic              rst_n,         // async, active-low

  // AHB subordinate
  input  logic              HSEL,
  input  logic [ADDR_W-1:0] HADDR,
  input  logic [1:0]        HTRANS,
  input  logic              HWRITE,
  input  logic [2:0]        HSIZE,
  input  logic [3:0]        HPROT,
  input  logic [DATA_W-1:0] HWDATA,
  input  logic              HREADY,
  output logic              HREADYOUT,
  output logic              HRESP,
  output logic [DATA_W-1:0] HRDATA,

  // APB4 manager
  output logic [ADDR_W-1:0] PADDR,
  output logic              PSEL,
  output logic              PENABLE,
  output logic              PWRITE,
  output logic [DATA_W-1:0] PWDATA,
  output logic [N_LANE-1:0] PSTRB,
  output logic [2:0]        PPROT,
  input  logic [DATA_W-1:0] PRDATA,
  input  logic              PREADY,
  input  logic              PSLVERR
);

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,   // no transfer, OKAY
    S_SETUP  = 3'd1,   // APB SETUP (PSEL)
    S_ACCESS = 3'd2,   // APB ACCESS (PSEL, PENABLE) until PREADY
    S_DONE   = 3'd3,   // AHB OKAY with HRDATA
    S_ERR1   = 3'd4,   // AHB ERROR, first cycle (HREADYOUT low)
    S_ERR2   = 3'd5    // AHB ERROR, second cycle
  } state_e;

  logic [2:0]        state_q;     // state register bits
  state_e            state;       // state_q as an enum
  state_e            state_d;     // next state
  logic              addr_fire;   // an AHB transfer is addressed to the bridge
  logic              apb_end;     // the APB transfer ends this cycle
  logic [ADDR_W-1:0] addr_q;      // HADDR of the transfer
  logic              write_q;     // HWRITE of the transfer
  logic [2:0]        size_q;      // HSIZE of the transfer
  logic [3:0]        prot_q;      // HPROT of the transfer
  logic [DATA_W-1:0] rdata_d;     // PRDATA, zero on PSLVERR
  logic [DATA_W-1:0] rdata_q;     // read data for HRDATA
  logic [N_LANE-1:0] strb;        // byte lanes of the transfer
  logic [OFF_W-1:0]  strb_off;    // byte offset of the transfer
  logic [SIZE_W-1:0] strb_size;   // log2 bytes of the transfer

  assign addr_fire = HSEL && HREADY && HTRANS[1] && HREADYOUT;
  assign apb_end   = (state == S_ACCESS) && PREADY;

  always_comb begin
    case (state)
      S_SETUP:  state_d = S_ACCESS;
      S_ACCESS: state_d = !PREADY ? S_ACCESS : (PSLVERR ? S_ERR1 : S_DONE);
      S_ERR1:   state_d = S_ERR2;
      S_IDLE, S_DONE, S_ERR2:
                state_d = addr_fire ? S_SETUP : S_IDLE;
      default:  state_d = S_IDLE;
    endcase
  end

  basechili_dff #(.WIDTH($bits(state_e)), .RESET_VAL(S_IDLE)) u_state (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (state_d),
    .q     (state_q)
  );

  assign state = state_e'(state_q);

  // ---- address phase --------------------------------------------------------
  basechili_dffe #(.WIDTH(ADDR_W)) u_addr (
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

  basechili_dffe #(.WIDTH(4)) u_prot (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (addr_fire),
    .d     (HPROT),
    .q     (prot_q)
  );

  assign strb_off  = addr_q[OFF_W-1:0];
  assign strb_size = size_q[SIZE_W-1:0];

  basechili_byte_strobe #(.DATA_W(DATA_W)) u_strb (
    .offset (strb_off),
    .size   (strb_size),
    .strb   (strb)
  );

  // ---- response ---------------------------------------------------------------
  assign rdata_d = PSLVERR ? '0 : PRDATA;

  basechili_dffe #(.WIDTH(DATA_W)) u_rdata (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (apb_end),
    .d     (rdata_d),
    .q     (rdata_q)
  );

  // ---- outputs ----------------------------------------------------------------
  assign PADDR     = addr_q;
  assign PSEL      = (state == S_SETUP) || (state == S_ACCESS);
  assign PENABLE   = state == S_ACCESS;
  assign PWRITE    = write_q;
  assign PWDATA    = HWDATA;
  assign PSTRB     = write_q ? strb : '0;
  assign PPROT     = {!prot_q[0], 1'b0, prot_q[1]};

  assign HREADYOUT = (state == S_IDLE) || (state == S_DONE) || (state == S_ERR2);
  assign HRESP     = (state == S_ERR1) || (state == S_ERR2);
  assign HRDATA    = rdata_q;

endmodule
