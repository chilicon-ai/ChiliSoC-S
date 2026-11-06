// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// Testbench :: chilimix_dma_regs -- random APB4 transfers against a register model
//
// Checked every cycle: field outputs equal the model (reset values, rw bits
// with PSTRB, w1c set by _set inputs and cleared by writing 1, set winning),
// PREADY high, PRDATA of a read, PSLVERR exactly where no block word exists,
// read / write pulses one-hot on the accessed register in ACCESS.
`include "tb_common.svh"
module chilimix_dma_regs_tb;
  localparam int AW = 12, DW = 32, NL = 4, NREG = 12, NBLK = 2;
  localparam int N_CYC = 20000;

  `TB_CLOCK_RESET

  logic PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [AW-1:0] PADDR;
  logic [DW-1:0] PWDATA, PRDATA;
  logic [NL-1:0] PSTRB;
  logic control_claim;
  logic control_run;
  logic control_done_ie;
  logic control_error_ie;
  logic control_done;
  logic control_error;
  logic control_w_claim;
  logic control_w_run;
  logic control_w_done_ie;
  logic control_w_error_ie;
  logic control_w_done;
  logic control_w_error;
  logic control_w_wr;
  logic next_config_repeat;
  logic next_config_order;
  logic [3:0] next_config_wsize;
  logic [3:0] next_config_rsize;
  logic [31:0] next_bytes_value;
  logic [31:0] next_dst_value;
  logic [31:0] next_src_value;
  logic [31:0] next_src_hi_value;
  logic exec_config_repeat;
  logic exec_config_order;
  logic [3:0] exec_config_wsize;
  logic [3:0] exec_config_rsize;
  logic [31:0] exec_bytes_value;
  logic [31:0] exec_dst_value;
  logic [31:0] exec_src_value;
  logic [31:0] exec_src_hi_value;

  chilimix_dma_regs dut (.*);

  // register table (absolute byte offsets) and blocks
  localparam logic [AW-1:0] OFFS [NREG] = '{12'h0, 12'h0, 12'h4, 12'h8, 12'h10, 12'h18, 12'h1c, 12'h104, 12'h108, 12'h110, 12'h118, 12'h11c};
  localparam logic [DW-1:0] RW   [NREG] = '{32'h0, 32'h0, 32'hff00000c, 32'hffffffff, 32'hffffffff, 32'hffffffff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] W1C  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] RO   [NREG] = '{32'hc000c003, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'hffffffff, 32'hff00000c, 32'hffffffff, 32'hffffffff, 32'hffffffff, 32'hffffffff};
  localparam logic [DW-1:0] RST  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] WO   [NREG] = '{32'h0, 32'hc000c003, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam int DIR [NREG] = '{1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};  // 0 both, 1 reads only, 2 writes only
  localparam int BANK_IDX [NREG] = '{-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};  // register holding the bank field, or -1
  localparam logic [DW-1:0] BANK_MASK [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] BANK_VAL  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam bit HAS_RD [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  localparam bit HAS_WR [NREG] = '{0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  localparam int BLK_BASE  [NBLK] = '{0, 256};
  localparam int BLK_SIZE  [NBLK] = '{32, 32};
  localparam int BLK_WORDS [NBLK] = '{8, 8};

  logic [DW-1:0] model  [NREG];   // expected rw / w1c bits
  logic [DW-1:0] ro_val [NREG];   // read-only values driven this cycle
  logic [DW-1:0] set_rq [NREG];   // w1c set requests this cycle

  // drive the read-only values and w1c set requests of this cycle
  task automatic drive_hw();
    control_claim = ro_val[0][0:0];
    control_run = ro_val[0][1:1];
    control_done_ie = ro_val[0][14:14];
    control_error_ie = ro_val[0][15:15];
    control_done = ro_val[0][30:30];
    control_error = ro_val[0][31:31];
    next_src_hi_value = ro_val[6][31:0];
    exec_config_repeat = ro_val[7][2:2];
    exec_config_order = ro_val[7][3:3];
    exec_config_wsize = ro_val[7][27:24];
    exec_config_rsize = ro_val[7][31:28];
    exec_bytes_value = ro_val[8][31:0];
    exec_dst_value = ro_val[9][31:0];
    exec_src_value = ro_val[10][31:0];
    exec_src_hi_value = ro_val[11][31:0];
  endtask

  // stored bits of register i as seen on the field outputs
  function automatic logic [DW-1:0] q_of(int i);
    case (i)
      0: return '0;
      1: return '0;
      2: return (DW'(next_config_repeat) << 2) | (DW'(next_config_order) << 3) | (DW'(next_config_wsize) << 24) | (DW'(next_config_rsize) << 28);
      3: return (DW'(next_bytes_value) << 0);
      4: return (DW'(next_dst_value) << 0);
      5: return (DW'(next_src_value) << 0);
      6: return '0;
      7: return '0;
      8: return '0;
      9: return '0;
      10: return '0;
      11: return '0;
      default: return '0;
    endcase
  endfunction

  // write-only field outputs of register i (PWDATA bits) in place
  function automatic logic [DW-1:0] wo_of(int i);
    case (i)
      1: return (DW'(control_w_claim) << 0) | (DW'(control_w_run) << 1) | (DW'(control_w_done_ie) << 14) | (DW'(control_w_error_ie) << 15) | (DW'(control_w_done) << 30) | (DW'(control_w_error) << 31);
      default: return '0;
    endcase
  endfunction

  function automatic logic pulse_of(int i, bit wr);
    case (i)
      0: return wr ? 1'b0 : 1'b0;
      1: return wr ? control_w_wr : 1'b0;
      2: return wr ? 1'b0 : 1'b0;
      3: return wr ? 1'b0 : 1'b0;
      4: return wr ? 1'b0 : 1'b0;
      5: return wr ? 1'b0 : 1'b0;
      6: return wr ? 1'b0 : 1'b0;
      7: return wr ? 1'b0 : 1'b0;
      8: return wr ? 1'b0 : 1'b0;
      9: return wr ? 1'b0 : 1'b0;
      10: return wr ? 1'b0 : 1'b0;
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
