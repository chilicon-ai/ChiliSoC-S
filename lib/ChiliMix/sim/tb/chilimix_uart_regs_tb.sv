// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// Testbench :: chilimix_uart_regs -- random APB4 transfers against a register model
//
// Checked every cycle: field outputs equal the model (reset values, rw bits
// with PSTRB, w1c set by _set inputs and cleared by writing 1, set winning),
// PREADY high, PRDATA of a read, PSLVERR exactly where no block word exists,
// read / write pulses one-hot on the accessed register in ACCESS.
`include "tb_common.svh"
module chilimix_uart_regs_tb;
  localparam int AW = 5, DW = 32, NL = 4, NREG = 12, NBLK = 1;
  localparam int N_CYC = 20000;

  `TB_CLOCK_RESET

  logic PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [AW-1:0] PADDR;
  logic [DW-1:0] PWDATA, PRDATA;
  logic [NL-1:0] PSTRB;
  logic [7:0] rbr_data;
  logic rbr_rd;
  logic [7:0] thr_data;
  logic thr_wr;
  logic [7:0] dll_value;
  logic ier_erbfi;
  logic ier_etbei;
  logic ier_elsi;
  logic ier_edssi;
  logic ier_wr;
  logic [7:0] dlm_value;
  logic [3:0] iir_id;
  logic [1:0] iir_fifos;
  logic iir_rd;
  logic fcr_enable;
  logic fcr_rx_reset;
  logic fcr_tx_reset;
  logic fcr_dma_mode;
  logic [1:0] fcr_rx_trigger;
  logic fcr_wr;
  logic [1:0] lcr_wls;
  logic lcr_stb;
  logic lcr_pen;
  logic lcr_eps;
  logic lcr_stick;
  logic lcr_brk;
  logic lcr_dlab;
  logic mcr_dtr;
  logic mcr_rts;
  logic mcr_out1;
  logic mcr_out2;
  logic mcr_loop;
  logic lsr_dr;
  logic lsr_oe;
  logic lsr_pe;
  logic lsr_fe;
  logic lsr_bi;
  logic lsr_thre;
  logic lsr_temt;
  logic lsr_rxfe;
  logic lsr_rd;
  logic msr_dcts;
  logic msr_ddsr;
  logic msr_teri;
  logic msr_ddcd;
  logic msr_cts;
  logic msr_dsr;
  logic msr_ri;
  logic msr_dcd;
  logic msr_rd;
  logic [7:0] scr_value;

  chilimix_uart_regs dut (.*);

  // register table (absolute byte offsets) and blocks
  localparam logic [AW-1:0] OFFS [NREG] = '{5'h0, 5'h0, 5'h0, 5'h4, 5'h4, 5'h8, 5'h8, 5'hc, 5'h10, 5'h14, 5'h18, 5'h1c};
  localparam logic [DW-1:0] RW   [NREG] = '{32'h0, 32'h0, 32'hff, 32'hf, 32'hff, 32'h0, 32'hc9, 32'hff, 32'h1f, 32'h0, 32'h0, 32'hff};
  localparam logic [DW-1:0] W1C  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] RO   [NREG] = '{32'hff, 32'h0, 32'h0, 32'h0, 32'h0, 32'hcf, 32'h0, 32'h0, 32'h0, 32'hff, 32'hff, 32'h0};
  localparam logic [DW-1:0] RST  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] WO   [NREG] = '{32'h0, 32'hff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h6, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam int DIR [NREG] = '{1, 2, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0};  // 0 both, 1 reads only, 2 writes only
  localparam int BANK_IDX [NREG] = '{7, 7, 7, 7, 7, -1, -1, -1, -1, -1, -1, -1};  // register holding the bank field, or -1
  localparam logic [DW-1:0] BANK_MASK [NREG] = '{32'h80, 32'h80, 32'h80, 32'h80, 32'h80, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] BANK_VAL  [NREG] = '{32'h0, 32'h0, 32'h80, 32'h0, 32'h80, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam bit HAS_RD [NREG] = '{1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0};
  localparam bit HAS_WR [NREG] = '{0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0};
  localparam int BLK_BASE  [NBLK] = '{0};
  localparam int BLK_SIZE  [NBLK] = '{32};
  localparam int BLK_WORDS [NBLK] = '{8};

  logic [DW-1:0] model  [NREG];   // expected rw / w1c bits
  logic [DW-1:0] ro_val [NREG];   // read-only values driven this cycle
  logic [DW-1:0] set_rq [NREG];   // w1c set requests this cycle

  // drive the read-only values and w1c set requests of this cycle
  task automatic drive_hw();
    rbr_data = ro_val[0][7:0];
    iir_id = ro_val[5][3:0];
    iir_fifos = ro_val[5][7:6];
    lsr_dr = ro_val[9][0:0];
    lsr_oe = ro_val[9][1:1];
    lsr_pe = ro_val[9][2:2];
    lsr_fe = ro_val[9][3:3];
    lsr_bi = ro_val[9][4:4];
    lsr_thre = ro_val[9][5:5];
    lsr_temt = ro_val[9][6:6];
    lsr_rxfe = ro_val[9][7:7];
    msr_dcts = ro_val[10][0:0];
    msr_ddsr = ro_val[10][1:1];
    msr_teri = ro_val[10][2:2];
    msr_ddcd = ro_val[10][3:3];
    msr_cts = ro_val[10][4:4];
    msr_dsr = ro_val[10][5:5];
    msr_ri = ro_val[10][6:6];
    msr_dcd = ro_val[10][7:7];
  endtask

  // stored bits of register i as seen on the field outputs
  function automatic logic [DW-1:0] q_of(int i);
    case (i)
      0: return '0;
      1: return '0;
      2: return (DW'(dll_value) << 0);
      3: return (DW'(ier_erbfi) << 0) | (DW'(ier_etbei) << 1) | (DW'(ier_elsi) << 2) | (DW'(ier_edssi) << 3);
      4: return (DW'(dlm_value) << 0);
      5: return '0;
      6: return (DW'(fcr_enable) << 0) | (DW'(fcr_dma_mode) << 3) | (DW'(fcr_rx_trigger) << 6);
      7: return (DW'(lcr_wls) << 0) | (DW'(lcr_stb) << 2) | (DW'(lcr_pen) << 3) | (DW'(lcr_eps) << 4) | (DW'(lcr_stick) << 5) | (DW'(lcr_brk) << 6) | (DW'(lcr_dlab) << 7);
      8: return (DW'(mcr_dtr) << 0) | (DW'(mcr_rts) << 1) | (DW'(mcr_out1) << 2) | (DW'(mcr_out2) << 3) | (DW'(mcr_loop) << 4);
      9: return '0;
      10: return '0;
      11: return (DW'(scr_value) << 0);
      default: return '0;
    endcase
  endfunction

  // write-only field outputs of register i (PWDATA bits) in place
  function automatic logic [DW-1:0] wo_of(int i);
    case (i)
      1: return (DW'(thr_data) << 0);
      6: return (DW'(fcr_rx_reset) << 1) | (DW'(fcr_tx_reset) << 2);
      default: return '0;
    endcase
  endfunction

  function automatic logic pulse_of(int i, bit wr);
    case (i)
      0: return wr ? 1'b0 : rbr_rd;
      1: return wr ? thr_wr : 1'b0;
      2: return wr ? 1'b0 : 1'b0;
      3: return wr ? ier_wr : 1'b0;
      4: return wr ? 1'b0 : 1'b0;
      5: return wr ? 1'b0 : iir_rd;
      6: return wr ? fcr_wr : 1'b0;
      7: return wr ? 1'b0 : 1'b0;
      8: return wr ? 1'b0 : 1'b0;
      9: return wr ? 1'b0 : lsr_rd;
      10: return wr ? 1'b0 : msr_rd;
      11: return wr ? 1'b0 : 1'b0;
      default: return 1'b0;
    endcase
  endfunction

  // register an access selects at addr, or -1; err: no block word there
  function automatic int reg_at(logic [AW-1:0] addr, bit wr, output bit err);
    int word;
    word = int'(addr) & ~(NL - 1);
    err = 1'b1;
    for (int b = 0; b < NBLK; b++)
      if (word >= BLK_BASE[b] && word < BLK_BASE[b] + BLK_SIZE[b])
        err = (word - BLK_BASE[b]) / NL >= BLK_WORDS[b];
    for (int i = 0; i < NREG; i++)
      if (int'(OFFS[i]) == word && DIR[i] != (wr ? 1 : 2)
          && (BANK_IDX[i] < 0 || (model[BANK_IDX[i]] & BANK_MASK[i]) == BANK_VAL[i])) return i;
    return -1;
  endfunction

  function automatic logic [DW-1:0] rnd_dw();
    logic [DW-1:0] d;
    for (int k = 0; k < DW; k += 32) d = {d, 32'($urandom)};
    return d;
  endfunction

  function automatic logic [DW-1:0] strb_mask(logic [NL-1:0] s);
    logic [DW-1:0] mk;
    for (int k = 0; k < NL; k++) mk[k*8 +: 8] = {8{s[k]}};
    return mk;
  endfunction

  int cyc, ri, phase;   // phase 0 idle, 1 SETUP, 2 ACCESS
  bit err;
  logic [DW-1:0] exp_rd;

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    for (int i = 0; i < NREG; i++) begin ro_val[i] = '0; set_rq[i] = '0; model[i] = RST[i]; end
    drive_hw();
    tb_reset();
    for (int i = 0; i < NREG; i++) `CHECK(q_of(i) == RST[i], "reset value")
    phase = 0;
    for (cyc = 0; cyc < N_CYC; cyc++) begin
      // drive after the falling edge
      for (int i = 0; i < NREG; i++) begin
        ro_val[i] = rnd_dw() & RO[i];
        set_rq[i] = ($urandom % 8 == 0) ? rnd_dw() & W1C[i] : '0;
      end
      drive_hw();
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 3 != 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 2;
        PADDR = ($urandom % 5 != 0) ? OFFS[$urandom % NREG] | AW'($urandom % NL) : AW'($urandom);
        PWDATA = rnd_dw();
        PSTRB = ($urandom % 2) ? '1 : NL'($urandom);
        if (!PWRITE) PSTRB = '0;
      end else begin
        PWRITE = $urandom % 2; PADDR = AW'($urandom); PWDATA = rnd_dw(); PSTRB = NL'($urandom);
      end
      #1;
      // combinational checks before the rising edge
      ri = reg_at(PADDR, PWRITE, err);
      `CHECK(PREADY, "PREADY high")
      for (int i = 0; i < NREG; i++) `CHECK(wo_of(i) == (PWDATA & WO[i]), "write-only field outputs")
      for (int i = 0; i < NREG; i++) begin
        `CHECK(pulse_of(i, 1'b1) == (HAS_WR[i] && phase == 2 && PWRITE && ri == i), "write pulse")
        `CHECK(pulse_of(i, 1'b0) == (HAS_RD[i] && phase == 2 && !PWRITE && ri == i), "read pulse")
      end
      if (phase == 2) begin
        `CHECK(PSLVERR == err, "PSLVERR")
        if (!PWRITE && !err) begin
          exp_rd = (ri >= 0) ? (model[ri] | ro_val[ri]) : '0;
          `CHECK(PRDATA == exp_rd, "read data")
        end
      end
      @(posedge clk);
      // model update at the edge: a write, then w1c sets (set wins)
      if (phase == 2 && PWRITE && ri >= 0) begin
        model[ri] = (model[ri] & ~(RW[ri] & strb_mask(PSTRB))) | (PWDATA & RW[ri] & strb_mask(PSTRB));
        model[ri] = model[ri] & ~(PWDATA & W1C[ri] & strb_mask(PSTRB));
      end
      for (int i = 0; i < NREG; i++) model[i] |= set_rq[i];
      @(negedge clk);
      for (int i = 0; i < NREG; i++) `CHECK(q_of(i) == model[i], "field outputs")
    end
    tb_pass();
  end
endmodule
