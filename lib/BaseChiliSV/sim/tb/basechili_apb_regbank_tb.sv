// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: basechili_apb_regbank -- APB reads / writes against a register
// model.
//
// When RESET / RW_MASK / W1C_MASK are left at the TB defaults, every bit gets
// a pseudo-random kind (read / write, W1C or read-only) and reset value
// derived from N and DATA_W, so every register mixes the three kinds.
// Stimulus: APB transfers (SETUP then ACCESS) with random PSTRB, word
// addresses in and out of range, random byte offsets, idle cycles with
// random bus values, random hw_set / hw_rd every cycle.
// Checked every cycle: reg_q against the model (hw_set wins over a W1C
// clear, PSTRB honored, read-only bits 0), PREADY high, PSLVERR only on an
// ACCESS to a word >= N, wr_pulse / rd_pulse one-hot of the accessed word in
// ACCESS only, PRDATA of a read (read-only bits from hw_rd).
`include "tb_common.svh"
module basechili_apb_regbank_tb #(
  parameter  int                  ADDR_W   = 12,
  parameter  int                  DATA_W   = 32,
  parameter  int                  N        = 4,
  parameter  logic [N*DATA_W-1:0] RESET    = tb_bits(3),
  parameter  logic [N*DATA_W-1:0] RW_MASK  = tb_bits(1),
  parameter  logic [N*DATA_W-1:0] W1C_MASK = tb_bits(2),
  localparam int                  N_LANE   = DATA_W / 8,
  localparam int                  OFF_W    = $clog2(N_LANE),
  localparam int                  WORD_W   = ADDR_W - OFF_W
);
  localparam int N_CYC = 20000;

  // kind 1: RW bit (6 in 10), kind 2: W1C bit (3 in 10), else read-only;
  // kind 3: reset value (random bits)
  function automatic logic [N*DATA_W-1:0] tb_bits(int kind);
    logic [N*DATA_W-1:0] v;
    int unsigned h, k;
    v = '0;
    for (int i = 0; i < N * DATA_W; i++) begin
      h = (32'(i) + 32'd7) * 32'd2654435761;
      h = h ^ (h >> 13);
      k = (h >> 8) % 10;
      case (kind)
        1:       v[i] = k < 6;
        2:       v[i] = k >= 6 && k < 9;
        default: v[i] = h[20];
      endcase
    end
    return v;
  endfunction

  `TB_CLOCK_RESET

  logic                PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [ADDR_W-1:0]   PADDR;
  logic [DATA_W-1:0]   PWDATA, PRDATA;
  logic [N_LANE-1:0]   PSTRB;
  logic [N*DATA_W-1:0] reg_q, hw_rd, hw_set;
  logic [N-1:0]        wr_pulse, rd_pulse;

  basechili_apb_regbank #(.ADDR_W(ADDR_W), .DATA_W(DATA_W), .N(N), .RESET(RESET), .RW_MASK(RW_MASK),
                          .W1C_MASK(W1C_MASK)) dut (
    .clk, .rst_n, .PSEL, .PENABLE, .PWRITE, .PADDR, .PWDATA, .PSTRB, .PREADY, .PRDATA, .PSLVERR,
    .reg_q, .hw_rd, .hw_set, .wr_pulse, .rd_pulse);

  // the model assumes RW_MASK and W1C_MASK do not overlap
  localparam logic [N*DATA_W-1:0] RW  = RW_MASK;
  localparam logic [N*DATA_W-1:0] W1C = W1C_MASK;
  localparam logic [N*DATA_W-1:0] STO = RW_MASK | W1C_MASK;    // stored bits

  logic [N*DATA_W-1:0] model;   // expected reg_q

  function automatic logic [DATA_W-1:0] rnd_data();
    logic [DATA_W-1:0] d;
    for (int k = 0; k < DATA_W; k += 32) d = {d, 32'($urandom)};
    return d;
  endfunction

  function automatic logic [N*DATA_W-1:0] rnd_wide();
    logic [N*DATA_W-1:0] d;
    for (int k = 0; k < N * DATA_W; k += 32) d = {d, 32'($urandom)};
    return d;
  endfunction

  // random word address: mostly in range, sometimes just past N, sometimes anywhere
  function automatic logic [WORD_W-1:0] rnd_word();
    case ($urandom % 8)
      0:       return WORD_W'($urandom);
      1:       return WORD_W'(N + $urandom % 2);
      default: return WORD_W'($urandom % N);
    endcase
  endfunction

  int phase;        // 0 idle, 1 SETUP, 2 ACCESS
  int n_wr, n_rd, n_err;

  initial begin
    logic [WORD_W-1:0] word;
    logic              in_range, access;
    logic [N-1:0]      exp_pulse;
    logic [DATA_W-1:0] exp_rd;
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    hw_rd = '0; hw_set = '0;
    phase = 0; n_wr = 0; n_rd = 0; n_err = 0;
    tb_reset();
    model = RESET & STO;
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      // ---- APB manager ----
      case (phase)
        0: if ($urandom % 4 != 0) begin           // start a transfer
             PSEL    = 1; PENABLE = 0;
             PWRITE  = $urandom;
             PADDR   = (ADDR_W'(rnd_word()) << OFF_W) | ADDR_W'($urandom % N_LANE);
             PWDATA  = ($urandom % 8 == 0) ? '1 : ($urandom % 8 == 0) ? '0 : rnd_data();
             PSTRB   = !PWRITE ? '0 : ($urandom % 4 == 0) ? '1 : N_LANE'($urandom);
             phase   = 1;
           end else begin                          // idle, random bus values
             PSEL = 0; PENABLE = $urandom; PWRITE = $urandom;
             PADDR = ADDR_W'($urandom); PWDATA = rnd_data(); PSTRB = N_LANE'($urandom);
           end
        1: begin PENABLE = 1; phase = 2; end
        default: ;
      endcase
      hw_rd  = rnd_wide();
      hw_set = ($urandom % 2) ? rnd_wide() & rnd_wide() & rnd_wide() : '0;
      #1;
      // ---- checks ----
      access    = PSEL && PENABLE;
      word      = PADDR[ADDR_W-1:OFF_W];
      in_range  = int'(word) < N;
      exp_pulse = in_range ? N'(1) << word : '0;
      `CHECK(reg_q == model, $sformatf("reg_q=%h expected %h", reg_q, model))
      `CHECK(PREADY, "PREADY low")
      `CHECK(PSLVERR == (access && !in_range), $sformatf("PSLVERR=%b access=%b word=%0d", PSLVERR, access, word))
      `CHECK(wr_pulse == ((access && PWRITE) ? exp_pulse : '0), $sformatf("wr_pulse=%b word=%0d", wr_pulse, word))
      `CHECK(rd_pulse == ((access && !PWRITE) ? exp_pulse : '0), $sformatf("rd_pulse=%b word=%0d", rd_pulse, word))
      if (access && !PWRITE && in_range) begin
        exp_rd = (model[word*DATA_W +: DATA_W] & STO[word*DATA_W +: DATA_W])
               | (hw_rd[word*DATA_W +: DATA_W] & ~STO[word*DATA_W +: DATA_W]);
        `CHECK(PRDATA == exp_rd, $sformatf("read word %0d: PRDATA=%h expected %h", word, PRDATA, exp_rd))
      end
      if (access) begin
        if (!in_range) n_err++; else if (PWRITE) n_wr++; else n_rd++;
      end
      // ---- model update (bit by bit) ----
      for (int r = 0; r < N; r++)
        for (int b = 0; b < DATA_W; b++) begin
          int  i;
          logic wr;
          i  = r * DATA_W + b;
          wr = access && PWRITE && in_range && int'(word) == r && PSTRB[b / 8];
          if (RW[i]) begin
            if (wr) model[i] = PWDATA[b];
          end else if (W1C[i]) begin
            if (wr && PWDATA[b]) model[i] = 1'b0;
            if (hw_set[i]) model[i] = 1'b1;
          end
        end
      @(negedge clk);
      if (phase == 2) begin                       // ACCESS done (PREADY high)
        phase = 0;
        PSEL = 0; PENABLE = 0;
      end
    end
    `CHECK(n_wr > 0 && n_rd > 0 && n_err > 0, $sformatf("transfers: %0d writes %0d reads %0d errors", n_wr, n_rd, n_err))
    tb_pass();
  end
endmodule
