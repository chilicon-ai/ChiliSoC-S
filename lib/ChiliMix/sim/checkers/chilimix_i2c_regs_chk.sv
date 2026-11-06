// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_i2c_regs_chk (simulation and formal; bound into every chilimix_i2c_regs)
//
// The i2c register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_i2c_regs_chk (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [4:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [7:0] prer_lo_value,
  input logic [7:0] prer_hi_value,
  input logic ctr_ien,
  input logic ctr_en,
  input logic [7:0] rxr_data,
  input logic [7:0] txr_data,
  input logic sr_iflag,
  input logic sr_tip,
  input logic sr_al,
  input logic sr_busy,
  input logic sr_rxack,
  input logic cr_iack,
  input logic cr_ack,
  input logic cr_write,
  input logic cr_read,
  input logic cr_sto,
  input logic cr_sta,
  input logic cr_wr
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [6:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[4:2] == 3'd0;  // prer_lo
  assign hit[1] = PADDR[4:2] == 3'd1;  // prer_hi
  assign hit[2] = PADDR[4:2] == 3'd2;  // ctr
  assign hit[3] = PADDR[4:2] == 3'd3 && (!PWRITE);  // rxr
  assign hit[4] = PADDR[4:2] == 3'd3 && (PWRITE);  // txr
  assign hit[5] = PADDR[4:2] == 3'd4 && (!PWRITE);  // sr
  assign hit[6] = PADDR[4:2] == 3'd4 && (PWRITE);  // cr
  assign err = !((1'b1 && {1'b0, PADDR[4:2]} < 4'd5));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[5]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_i2c_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_i2c_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_i2c_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // prer_lo at 0x0
    p_prer_lo_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {24'b0, prer_lo_value})
      else $error("chilimix_i2c_regs: prer_lo read %h", PRDATA);
    p_prer_lo_rd_cov: cover (access && !PWRITE && hit[0]);
    // prer_hi at 0x4
    p_prer_hi_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == {24'b0, prer_hi_value})
      else $error("chilimix_i2c_regs: prer_hi read %h", PRDATA);
    p_prer_hi_rd_cov: cover (access && !PWRITE && hit[1]);
    // ctr at 0x8
    p_ctr_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {24'b0, ctr_en, ctr_ien, 6'b0})
      else $error("chilimix_i2c_regs: ctr read %h", PRDATA);
    p_ctr_rd_cov: cover (access && !PWRITE && hit[2]);
    // rxr at 0xc
    p_rxr_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == {24'b0, rxr_data})
      else $error("chilimix_i2c_regs: rxr read %h", PRDATA);
    p_rxr_rd_cov: cover (access && !PWRITE && hit[3]);
    // sr at 0x10
    p_sr_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {24'b0, sr_rxack, sr_busy, sr_al, 3'b0, sr_tip, sr_iflag})
      else $error("chilimix_i2c_regs: sr read %h", PRDATA);
    p_sr_rd_cov: cover (access && !PWRITE && hit[5]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // prer_lo writes
    p_prer_lo_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    p_prer_lo_value_rst: assert (!past_ok || $past(rst_n) || prer_lo_value == 8'hff)
      else $error("chilimix_i2c_regs: prer_lo.value reset value %h", prer_lo_value);
    p_prer_lo_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || prer_lo_value == ($past((access && PWRITE && hit[0])) ? (($past(prer_lo_value) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(prer_lo_value)))
      else $error("chilimix_i2c_regs: prer_lo.value is %h after a write / hold", prer_lo_value);
    // prer_hi writes
    p_prer_hi_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_prer_hi_value_rst: assert (!past_ok || $past(rst_n) || prer_hi_value == 8'hff)
      else $error("chilimix_i2c_regs: prer_hi.value reset value %h", prer_hi_value);
    p_prer_hi_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || prer_hi_value == ($past((access && PWRITE && hit[1])) ? (($past(prer_hi_value) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(prer_hi_value)))
      else $error("chilimix_i2c_regs: prer_hi.value is %h after a write / hold", prer_hi_value);
    // ctr writes
    p_ctr_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_ctr_ien_rst: assert (!past_ok || $past(rst_n) || ctr_ien == 1'h0)
      else $error("chilimix_i2c_regs: ctr.ien reset value %h", ctr_ien);
    p_ctr_ien_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ctr_ien == ($past((access && PWRITE && hit[2])) ? (($past(ctr_ien) & ~$past(bit_en[6:6])) | ($past(PWDATA[6:6]) & $past(bit_en[6:6]))) : $past(ctr_ien)))
      else $error("chilimix_i2c_regs: ctr.ien is %h after a write / hold", ctr_ien);
    p_ctr_en_rst: assert (!past_ok || $past(rst_n) || ctr_en == 1'h0)
      else $error("chilimix_i2c_regs: ctr.en reset value %h", ctr_en);
    p_ctr_en_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ctr_en == ($past((access && PWRITE && hit[2])) ? (($past(ctr_en) & ~$past(bit_en[7:7])) | ($past(PWDATA[7:7]) & $past(bit_en[7:7]))) : $past(ctr_en)))
      else $error("chilimix_i2c_regs: ctr.en is %h after a write / hold", ctr_en);
    // txr writes
    p_txr_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_txr_data_rst: assert (!past_ok || $past(rst_n) || txr_data == 8'h00)
      else $error("chilimix_i2c_regs: txr.data reset value %h", txr_data);
    p_txr_data_wr: assert (!rst_n || !past_ok || !$past(rst_n) || txr_data == ($past((access && PWRITE && hit[4])) ? (($past(txr_data) & ~$past(bit_en[7:0])) | ($past(PWDATA[7:0]) & $past(bit_en[7:0]))) : $past(txr_data)))
      else $error("chilimix_i2c_regs: txr.data is %h after a write / hold", txr_data);
    // cr writes
    p_cr_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_cr_wrp: assert (!rst_n || cr_wr == (access && PWRITE && hit[6]))
      else $error("chilimix_i2c_regs: cr write pulse wrong");
  end

endmodule

bind chilimix_i2c_regs chilimix_i2c_regs_chk u_chk (.*);
