// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// Testbench :: chilimix_aclint_regs -- random APB4 transfers against a register model
//
// Checked every cycle: field outputs equal the model (reset values, rw bits
// with PSTRB, w1c set by _set inputs and cleared by writing 1, set winning),
// PREADY high, PRDATA of a read, PSLVERR exactly where no block word exists,
// read / write pulses one-hot on the accessed register in ACCESS.
`include "tb_common.svh"
module chilimix_aclint_regs_tb #(
  parameter int N_HART = 1  // harts present (1 .. 8)
);
  localparam int AW = 16, DW = 32, NL = 4, NREG = 34, NBLK = 4;
  localparam int N_CYC = 20000;

  `TB_CLOCK_RESET

  logic PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [AW-1:0] PADDR;
  logic [DW-1:0] PWDATA, PRDATA;
  logic [NL-1:0] PSTRB;
  logic [7:0] msip_pending;
  logic [255:0] mtimecmp_lo_value;
  logic [255:0] mtimecmp_hi_value;
  logic [31:0] mtime_lo_value;
  logic mtime_lo_wr;
  logic [31:0] mtime_hi_value;
  logic mtime_hi_wr;
  logic [7:0] setssip_set;
  logic [7:0] setssip_wr;

  chilimix_aclint_regs #(.N_HART(N_HART)) dut (.*);

  // register table (absolute byte offsets) and blocks
  localparam logic [AW-1:0] OFFS [NREG] = '{16'h0, 16'h4, 16'h8, 16'hc, 16'h10, 16'h14, 16'h18, 16'h1c, 16'h4000, 16'h4004, 16'h4008, 16'h400c, 16'h4010, 16'h4014, 16'h4018, 16'h401c, 16'h4020, 16'h4024, 16'h4028, 16'h402c, 16'h4030, 16'h4034, 16'h4038, 16'h403c, 16'hbff8, 16'hbffc, 16'hc000, 16'hc004, 16'hc008, 16'hc00c, 16'hc010, 16'hc014, 16'hc018, 16'hc01c};
  localparam logic [DW-1:0] RW   [NREG] = '{(N_HART > 0) ? 32'h1 : 32'h0, (N_HART > 1) ? 32'h1 : 32'h0, (N_HART > 2) ? 32'h1 : 32'h0, (N_HART > 3) ? 32'h1 : 32'h0, (N_HART > 4) ? 32'h1 : 32'h0, (N_HART > 5) ? 32'h1 : 32'h0, (N_HART > 6) ? 32'h1 : 32'h0, (N_HART > 7) ? 32'h1 : 32'h0, (N_HART > 0) ? 32'hffffffff : 32'h0, (N_HART > 0) ? 32'hffffffff : 32'h0, (N_HART > 1) ? 32'hffffffff : 32'h0, (N_HART > 1) ? 32'hffffffff : 32'h0, (N_HART > 2) ? 32'hffffffff : 32'h0, (N_HART > 2) ? 32'hffffffff : 32'h0, (N_HART > 3) ? 32'hffffffff : 32'h0, (N_HART > 3) ? 32'hffffffff : 32'h0, (N_HART > 4) ? 32'hffffffff : 32'h0, (N_HART > 4) ? 32'hffffffff : 32'h0, (N_HART > 5) ? 32'hffffffff : 32'h0, (N_HART > 5) ? 32'hffffffff : 32'h0, (N_HART > 6) ? 32'hffffffff : 32'h0, (N_HART > 6) ? 32'hffffffff : 32'h0, (N_HART > 7) ? 32'hffffffff : 32'h0, (N_HART > 7) ? 32'hffffffff : 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] W1C  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] RO   [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'hffffffff, 32'hffffffff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] RST  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, (N_HART > 0) ? 32'hffffffff : 32'h0, (N_HART > 0) ? 32'hffffffff : 32'h0, (N_HART > 1) ? 32'hffffffff : 32'h0, (N_HART > 1) ? 32'hffffffff : 32'h0, (N_HART > 2) ? 32'hffffffff : 32'h0, (N_HART > 2) ? 32'hffffffff : 32'h0, (N_HART > 3) ? 32'hffffffff : 32'h0, (N_HART > 3) ? 32'hffffffff : 32'h0, (N_HART > 4) ? 32'hffffffff : 32'h0, (N_HART > 4) ? 32'hffffffff : 32'h0, (N_HART > 5) ? 32'hffffffff : 32'h0, (N_HART > 5) ? 32'hffffffff : 32'h0, (N_HART > 6) ? 32'hffffffff : 32'h0, (N_HART > 6) ? 32'hffffffff : 32'h0, (N_HART > 7) ? 32'hffffffff : 32'h0, (N_HART > 7) ? 32'hffffffff : 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] WO   [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h1, 32'h1, 32'h1, 32'h1, 32'h1, 32'h1, 32'h1, 32'h1};
  localparam int DIR [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};  // 0 both, 1 reads only, 2 writes only
  localparam int BANK_IDX [NREG] = '{-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};  // register holding the bank field, or -1
  localparam logic [DW-1:0] BANK_MASK [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] BANK_VAL  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam bit HAS_RD [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  localparam bit HAS_WR [NREG] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, (N_HART > 0) ? 1 : 0, (N_HART > 1) ? 1 : 0, (N_HART > 2) ? 1 : 0, (N_HART > 3) ? 1 : 0, (N_HART > 4) ? 1 : 0, (N_HART > 5) ? 1 : 0, (N_HART > 6) ? 1 : 0, (N_HART > 7) ? 1 : 0};
  localparam int BLK_BASE  [NBLK] = '{0, 16384, 49144, 49152};
  localparam int BLK_SIZE  [NBLK] = '{16384, 64, 8, 16384};
  localparam int BLK_WORDS [NBLK] = '{8, 16, 2, 8};
  // driven by the testbench on every element, present or not
  localparam logic [DW-1:0] RO_DRV  [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'hffffffff, 32'hffffffff, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};
  localparam logic [DW-1:0] W1C_DRV [NREG] = '{32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0, 32'h0};

  logic [DW-1:0] model  [NREG];   // expected rw / w1c bits
  logic [DW-1:0] ro_val [NREG];   // read-only values driven this cycle
  logic [DW-1:0] set_rq [NREG];   // w1c set requests this cycle

  // drive the read-only values and w1c set requests of this cycle
  task automatic drive_hw();
    mtime_lo_value = ro_val[24][31:0];
    mtime_hi_value = ro_val[25][31:0];
  endtask

  // stored bits of register i as seen on the field outputs
  function automatic logic [DW-1:0] q_of(int i);
    case (i)
      0: return (DW'(msip_pending[0]) << 0);
      1: return (DW'(msip_pending[1]) << 0);
      2: return (DW'(msip_pending[2]) << 0);
      3: return (DW'(msip_pending[3]) << 0);
      4: return (DW'(msip_pending[4]) << 0);
      5: return (DW'(msip_pending[5]) << 0);
      6: return (DW'(msip_pending[6]) << 0);
      7: return (DW'(msip_pending[7]) << 0);
      8: return (DW'(mtimecmp_lo_value[31:0]) << 0);
      9: return (DW'(mtimecmp_hi_value[31:0]) << 0);
      10: return (DW'(mtimecmp_lo_value[63:32]) << 0);
      11: return (DW'(mtimecmp_hi_value[63:32]) << 0);
      12: return (DW'(mtimecmp_lo_value[95:64]) << 0);
      13: return (DW'(mtimecmp_hi_value[95:64]) << 0);
      14: return (DW'(mtimecmp_lo_value[127:96]) << 0);
      15: return (DW'(mtimecmp_hi_value[127:96]) << 0);
      16: return (DW'(mtimecmp_lo_value[159:128]) << 0);
      17: return (DW'(mtimecmp_hi_value[159:128]) << 0);
      18: return (DW'(mtimecmp_lo_value[191:160]) << 0);
      19: return (DW'(mtimecmp_hi_value[191:160]) << 0);
      20: return (DW'(mtimecmp_lo_value[223:192]) << 0);
      21: return (DW'(mtimecmp_hi_value[223:192]) << 0);
      22: return (DW'(mtimecmp_lo_value[255:224]) << 0);
      23: return (DW'(mtimecmp_hi_value[255:224]) << 0);
      24: return '0;
      25: return '0;
      26: return '0;
      27: return '0;
      28: return '0;
      29: return '0;
      30: return '0;
      31: return '0;
      32: return '0;
      33: return '0;
      default: return '0;
    endcase
  endfunction

  // write-only field outputs of register i (PWDATA bits) in place
  function automatic logic [DW-1:0] wo_of(int i);
    case (i)
      26: return (DW'(setssip_set[0]) << 0);
      27: return (DW'(setssip_set[1]) << 0);
      28: return (DW'(setssip_set[2]) << 0);
      29: return (DW'(setssip_set[3]) << 0);
      30: return (DW'(setssip_set[4]) << 0);
      31: return (DW'(setssip_set[5]) << 0);
      32: return (DW'(setssip_set[6]) << 0);
      33: return (DW'(setssip_set[7]) << 0);
      default: return '0;
    endcase
  endfunction

  function automatic logic pulse_of(int i, bit wr);
    case (i)
      0: return wr ? 1'b0 : 1'b0;
      1: return wr ? 1'b0 : 1'b0;
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
      12: return wr ? 1'b0 : 1'b0;
      13: return wr ? 1'b0 : 1'b0;
      14: return wr ? 1'b0 : 1'b0;
      15: return wr ? 1'b0 : 1'b0;
      16: return wr ? 1'b0 : 1'b0;
      17: return wr ? 1'b0 : 1'b0;
      18: return wr ? 1'b0 : 1'b0;
      19: return wr ? 1'b0 : 1'b0;
      20: return wr ? 1'b0 : 1'b0;
      21: return wr ? 1'b0 : 1'b0;
      22: return wr ? 1'b0 : 1'b0;
      23: return wr ? 1'b0 : 1'b0;
      24: return wr ? mtime_lo_wr : 1'b0;
      25: return wr ? mtime_hi_wr : 1'b0;
      26: return wr ? setssip_wr[0] : 1'b0;
      27: return wr ? setssip_wr[1] : 1'b0;
      28: return wr ? setssip_wr[2] : 1'b0;
      29: return wr ? setssip_wr[3] : 1'b0;
      30: return wr ? setssip_wr[4] : 1'b0;
      31: return wr ? setssip_wr[5] : 1'b0;
      32: return wr ? setssip_wr[6] : 1'b0;
      33: return wr ? setssip_wr[7] : 1'b0;
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
        ro_val[i] = rnd_dw() & RO_DRV[i];
        set_rq[i] = ($urandom % 8 == 0) ? rnd_dw() & W1C_DRV[i] : '0;
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
          exp_rd = (ri >= 0) ? (model[ri] | (ro_val[ri] & RO[ri])) : '0;
          `CHECK(PRDATA == exp_rd, "read data")
        end
      end
      @(posedge clk);
      // model update at the edge: a write, then w1c sets (set wins)
      if (phase == 2 && PWRITE && ri >= 0) begin
        model[ri] = (model[ri] & ~(RW[ri] & strb_mask(PSTRB))) | (PWDATA & RW[ri] & strb_mask(PSTRB));
        model[ri] = model[ri] & ~(PWDATA & W1C[ri] & strb_mask(PSTRB));
      end
      for (int i = 0; i < NREG; i++) model[i] |= set_rq[i] & W1C[i];
      @(negedge clk);
      for (int i = 0; i < NREG; i++) `CHECK(q_of(i) == model[i], "field outputs")
    end
    tb_pass();
  end
endmodule
