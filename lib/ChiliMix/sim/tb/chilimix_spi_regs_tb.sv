// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// Testbench :: chilimix_spi_regs -- random APB4 transfers against a register model
//
// Checked every cycle: field outputs equal the model (reset values, rw bits
// with PSTRB, w1c set by _set inputs and cleared by writing 1, set winning),
// PREADY high, PRDATA of a read, PSLVERR exactly where no block word exists,
// read / write pulses one-hot on the accessed register in ACCESS.
`include "tb_common.svh"
module chilimix_spi_regs_tb;
  localparam int AW = 7, DW = 32, NL = 4, NREG = 16, NBLK = 1;
  localparam int N_CYC = 20000;

  `TB_CLOCK_RESET

  logic PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [AW-1:0] PADDR;
  logic [DW-1:0] PWDATA, PRDATA;
  logic [NL-1:0] PSTRB;
  logic [11:0] sckdiv_div;
  logic sckmode_pha;
  logic sckmode_pol;
  logic [1:0] csid_csid;
  logic csid_wr;
  logic [3:0] csdef_csdef;
  logic csdef_wr;
  logic [1:0] csmode_mode;
  logic csmode_wr;
  logic [7:0] delay0_cssck;
  logic [7:0] delay0_sckcs;
  logic [7:0] delay1_intercs;
  logic [7:0] delay1_interxfr;
  logic [1:0] fmt_proto;
  logic fmt_endian;
  logic fmt_dir;
  logic [3:0] fmt_len;
  logic [7:0] txdata_data;
  logic txdata_full;
  logic txdata_wr;
  logic [7:0] rxdata_data;
  logic rxdata_empty;
  logic rxdata_rd;
  logic [2:0] txmark_txmark;
  logic [2:0] rxmark_rxmark;
  logic fctrl_en;
  logic fctrl_wr;
  logic ffmt_cmd_en;
  logic [2:0] ffmt_addr_len;
  logic [3:0] ffmt_pad_cnt;
  logic [1:0] ffmt_cmd_proto;
  logic [1:0] ffmt_addr_proto;
  logic [1:0] ffmt_data_proto;
  logic [7:0] ffmt_cmd_code;
  logic [7:0] ffmt_pad_code;
  logic ffmt_wr;
  logic ie_txwm;
  logic ie_rxwm;
  logic ip_txwm;
  logic ip_rxwm;

  chilimix_spi_regs dut (.*);

  // register table (absolute byte offsets) and blocks
  localparam logic [AW-1:0] OFFS [NREG] = '{7'h0, 7'h4, 7'h10, 7'h14, 7'h18, 7'h28, 7'h2c, 7'h40, 7'h48, 7'h4c, 7'h50, 7'h54, 7'h60, 7'h64, 7'h70, 7'h74};
  localparam logic [DW-1:0] RW   [NREG] = '{32'hfff, 32'h3, 32'h3, 32'hf, 32'h3, 32'hff00ff, 32'hff00ff, 32'hf000f, 32'h0, 32'h0, 32'h7, 32'h7, 32'h1, 32'hffff3fff, 32'h3, 32'h0};
  localparam logic [DW-1:0] W1C  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] RO   [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h80000000, 32'h800000ff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h3};
  localparam logic [DW-1:0] RST  [NREG] = '{32'h3, 32'h0, 32'h0, 32'hf, 32'h0, 32'h10001, 32'h1, 32'h80000, 32'h0, 32'h0, 32'h1, 32'h0, 32'h1, 32'h30007, 32'h0, 32'h0};
  localparam logic [DW-1:0] WO   [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'hff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam int DIR [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};  // 0 both, 1 reads only, 2 writes only
  localparam int BANK_IDX [NREG] = '{-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};  // register holding the bank field, or -1
  localparam logic [DW-1:0] BANK_MASK [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] BANK_VAL  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam bit HAS_RD [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0};
  localparam bit HAS_WR [NREG] = '{0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0};
  localparam int BLK_BASE  [NBLK] = '{0};
  localparam int BLK_SIZE  [NBLK] = '{128};
  localparam int BLK_WORDS [NBLK] = '{30};

  logic [DW-1:0] model  [NREG];   // expected rw / w1c bits
  logic [DW-1:0] ro_val [NREG];   // read-only values driven this cycle
  logic [DW-1:0] set_rq [NREG];   // w1c set requests this cycle

  // drive the read-only values and w1c set requests of this cycle
  task automatic drive_hw();
    txdata_full = ro_val[8][31:31];
    rxdata_data = ro_val[9][7:0];
    rxdata_empty = ro_val[9][31:31];
    ip_txwm = ro_val[15][0:0];
    ip_rxwm = ro_val[15][1:1];
  endtask

  // stored bits of register i as seen on the field outputs
  function automatic logic [DW-1:0] q_of(int i);
    case (i)
      0: return (DW'(sckdiv_div) << 0);
      1: return (DW'(sckmode_pha) << 0) | (DW'(sckmode_pol) << 1);
      2: return (DW'(csid_csid) << 0);
      3: return (DW'(csdef_csdef) << 0);
      4: return (DW'(csmode_mode) << 0);
      5: return (DW'(delay0_cssck) << 0) | (DW'(delay0_sckcs) << 16);
      6: return (DW'(delay1_intercs) << 0) | (DW'(delay1_interxfr) << 16);
      7: return (DW'(fmt_proto) << 0) | (DW'(fmt_endian) << 2) | (DW'(fmt_dir) << 3) | (DW'(fmt_len) << 16);
      8: return '0;
      9: return '0;
      10: return (DW'(txmark_txmark) << 0);
      11: return (DW'(rxmark_rxmark) << 0);
      12: return (DW'(fctrl_en) << 0);
      13: return (DW'(ffmt_cmd_en) << 0) | (DW'(ffmt_addr_len) << 1) | (DW'(ffmt_pad_cnt) << 4) | (DW'(ffmt_cmd_proto) << 8) | (DW'(ffmt_addr_proto) << 10) | (DW'(ffmt_data_proto) << 12) | (DW'(ffmt_cmd_code) << 16) | (DW'(ffmt_pad_code) << 24);
      14: return (DW'(ie_txwm) << 0) | (DW'(ie_rxwm) << 1);
      15: return '0;
      default: return '0;
    endcase
  endfunction

  // write-only field outputs of register i (PWDATA bits) in place
  function automatic logic [DW-1:0] wo_of(int i);
    case (i)
      8: return (DW'(txdata_data) << 0);
      default: return '0;
    endcase
  endfunction

  function automatic logic pulse_of(int i, bit wr);
    case (i)
      0: return wr ? 1'b0 : 1'b0;
      1: return wr ? 1'b0 : 1'b0;
      2: return wr ? csid_wr : 1'b0;
      3: return wr ? csdef_wr : 1'b0;
      4: return wr ? csmode_wr : 1'b0;
      5: return wr ? 1'b0 : 1'b0;
      6: return wr ? 1'b0 : 1'b0;
      7: return wr ? 1'b0 : 1'b0;
      8: return wr ? txdata_wr : 1'b0;
      9: return wr ? 1'b0 : rxdata_rd;
      10: return wr ? 1'b0 : 1'b0;
      11: return wr ? 1'b0 : 1'b0;
      12: return wr ? fctrl_wr : 1'b0;
      13: return wr ? ffmt_wr : 1'b0;
      14: return wr ? 1'b0 : 1'b0;
      15: return wr ? 1'b0 : 1'b0;
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
