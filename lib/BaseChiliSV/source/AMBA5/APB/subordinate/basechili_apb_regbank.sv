// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// BaseChiliSV :: basechili_apb_regbank
//
// APB4 subordinate holding N registers of DATA_W bits, one per word address
// from 0. Each bit is one of three kinds, set per register by parameters:
//
//   RW_MASK  bit 1 : read / write register bit, reset to RESET
//   W1C_MASK bit 1 : status bit: hw_set sets it, writing 1 clears it
//                    (hw_set wins over a clear in the same cycle)
//   neither        : read-only; reads hw_rd, writes are ignored
//   (RW_MASK and W1C_MASK must not overlap.)
//
// Writes honor PSTRB. wr_pulse / rd_pulse mark the register written / read
// this cycle (APB ACCESS phase), for side effects such as popping a FIFO.
// Words at or above N give PSLVERR. PREADY is always high (no wait states).
//
// Register i is at reg_q[i*DATA_W +: DATA_W] (read-only bits read as 0
// there), and likewise in RESET, RW_MASK, W1C_MASK, hw_rd and hw_set.
//
// Timing    : PRDATA, PSLVERR, wr_pulse and rd_pulse are combinational from
//             the APB inputs; reg_q changes the cycle after the write or
//             hw_set.
// Invariants: wr_pulse / rd_pulse are zero or one-hot and only in an ACCESS
//             phase; reg_q bits outside RW_MASK | W1C_MASK are 0.
// Debug     : write lost -> PSTRB, word / in_range and wr_pulse; status bit
//             stuck -> hw_set and the clear (PWDATA bit with wr_pulse).
// -----------------------------------------------------------------------------
module basechili_apb_regbank #(
  parameter  int                  ADDR_W   = 12,                  // PADDR width
  parameter  int                  DATA_W   = 32,                  // register / bus width (8, 16, 32, 64)
  parameter  int                  N        = 4,                   // registers
  parameter  logic [N*DATA_W-1:0] RESET    = '0,                  // reset values (RW and W1C bits)
  parameter  logic [N*DATA_W-1:0] RW_MASK  = '1,                  // read / write bits
  parameter  logic [N*DATA_W-1:0] W1C_MASK = '0,                  // write-one-to-clear status bits
  localparam int                  N_LANE   = DATA_W / 8,          // byte lanes
  localparam int                  OFF_W    = $clog2(N_LANE),      // byte offset bits
  localparam int                  IDX_W    = (N > 1) ? $clog2(N) : 1
) (
  input  logic                clk,
  input  logic                rst_n,        // async, active-low

  // APB4 subordinate
  input  logic                PSEL,
  input  logic                PENABLE,
  input  logic                PWRITE,
  input  logic [ADDR_W-1:0]   PADDR,
  input  logic [DATA_W-1:0]   PWDATA,
  input  logic [N_LANE-1:0]   PSTRB,
  output logic                PREADY,
  output logic [DATA_W-1:0]   PRDATA,
  output logic                PSLVERR,

  // hardware side
  output logic [N*DATA_W-1:0] reg_q,        // RW and W1C bit values
  input  logic [N*DATA_W-1:0] hw_rd,        // values of the read-only bits
  input  logic [N*DATA_W-1:0] hw_set,       // set W1C bits
  output logic [N-1:0]        wr_pulse,     // register i written this cycle
  output logic [N-1:0]        rd_pulse      // register i read this cycle
);

  localparam logic [ADDR_W-OFF_W:0] N_WORDS = (ADDR_W - OFF_W + 1)'(N);   // N, word-address width + 1

  logic                    access;     // APB ACCESS phase
  logic [ADDR_W-OFF_W-1:0] word;       // word address
  logic                    in_range;   // word < N
  logic [IDX_W-1:0]        idx;        // register index
  logic [N-1:0]            sel_raw;    // one-hot of idx
  logic [N-1:0]            sel;        // register idx, when in range
  logic [DATA_W-1:0]       bit_en;     // PSTRB expanded to bits
  logic [N*DATA_W-1:0]     rd_val;     // read value of every register
  logic [DATA_W-1:0]       rd_word;    // read value of register idx

  assign access   = PSEL && PENABLE;
  assign word     = PADDR[ADDR_W-1:OFF_W];
  assign in_range = {1'b0, word} < N_WORDS;
  assign idx      = word[IDX_W-1:0];

  basechili_decoder #(.N(N)) u_sel_dec (
    .in  (idx),
    .out (sel_raw)
  );

  assign sel      = in_range ? sel_raw : '0;

  assign wr_pulse = (access && PWRITE)  ? sel : '0;
  assign rd_pulse = (access && !PWRITE) ? sel : '0;

  always_comb begin
    for (int b = 0; b < DATA_W; b++) bit_en[b] = PSTRB[b / 8];
  end

  // ---- registers ------------------------------------------------------------
  for (genvar i = 0; i < N; i++) begin : g_reg
    localparam logic [DATA_W-1:0] RW  = RW_MASK[i*DATA_W +: DATA_W];
    localparam logic [DATA_W-1:0] W1C = W1C_MASK[i*DATA_W +: DATA_W];
    logic [DATA_W-1:0] q;      // stored bits
    logic [DATA_W-1:0] wr;     // bits written this cycle
    logic [DATA_W-1:0] d;      // next value

    assign wr = wr_pulse[i] ? bit_en : '0;
    assign d  = (RW & ((wr & PWDATA) | (~wr & q)))
              | (W1C & ((q & ~(wr & PWDATA)) | hw_set[i*DATA_W +: DATA_W]));

    basechili_dff #(.WIDTH(DATA_W), .RESET_VAL(RESET[i*DATA_W +: DATA_W] & (RW | W1C))) u_q (
      .clk   (clk),
      .rst_n (rst_n),
      .d     (d),
      .q     (q)
    );

    assign reg_q[i*DATA_W +: DATA_W]  = q;
    assign rd_val[i*DATA_W +: DATA_W] = (q & (RW | W1C)) | (hw_rd[i*DATA_W +: DATA_W] & ~(RW | W1C));
  end

  basechili_onehot_mux #(.WIDTH(DATA_W), .N(N)) u_rd_mux (
    .in  (rd_val),
    .sel (sel),
    .out (rd_word)
  );

  assign PREADY  = 1'b1;
  assign PRDATA  = rd_word;
  assign PSLVERR = access && !in_range;

endmodule
