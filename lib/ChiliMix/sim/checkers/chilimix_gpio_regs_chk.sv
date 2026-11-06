// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_gpio_regs_chk (simulation and formal; bound into every chilimix_gpio_regs)
//
// The gpio register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_gpio_regs_chk (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [6:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [31:0] input_val_pin,
  input logic [31:0] input_en_pin,
  input logic [31:0] output_en_pin,
  input logic [31:0] output_val_pin,
  input logic [31:0] pue_pin,
  input logic [31:0] ds_pin,
  input logic [31:0] rise_ie_pin,
  input logic [31:0] rise_ip_pin,
  input logic [31:0] rise_ip_pin_set,
  input logic [31:0] fall_ie_pin,
  input logic [31:0] fall_ip_pin,
  input logic [31:0] fall_ip_pin_set,
  input logic [31:0] high_ie_pin,
  input logic [31:0] high_ip_pin,
  input logic [31:0] high_ip_pin_set,
  input logic [31:0] low_ie_pin,
  input logic [31:0] low_ip_pin,
  input logic [31:0] low_ip_pin_set,
  input logic [31:0] iof_en_pin,
  input logic [31:0] iof_sel_pin,
  input logic [31:0] out_xor_pin
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [16:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[6:2] == 5'd0;  // input_val
  assign hit[1] = PADDR[6:2] == 5'd1;  // input_en
  assign hit[2] = PADDR[6:2] == 5'd2;  // output_en
  assign hit[3] = PADDR[6:2] == 5'd3;  // output_val
  assign hit[4] = PADDR[6:2] == 5'd4;  // pue
  assign hit[5] = PADDR[6:2] == 5'd5;  // ds
  assign hit[6] = PADDR[6:2] == 5'd6;  // rise_ie
  assign hit[7] = PADDR[6:2] == 5'd7;  // rise_ip
  assign hit[8] = PADDR[6:2] == 5'd8;  // fall_ie
  assign hit[9] = PADDR[6:2] == 5'd9;  // fall_ip
  assign hit[10] = PADDR[6:2] == 5'd10;  // high_ie
  assign hit[11] = PADDR[6:2] == 5'd11;  // high_ip
  assign hit[12] = PADDR[6:2] == 5'd12;  // low_ie
  assign hit[13] = PADDR[6:2] == 5'd13;  // low_ip
  assign hit[14] = PADDR[6:2] == 5'd14;  // iof_en
  assign hit[15] = PADDR[6:2] == 5'd15;  // iof_sel
  assign hit[16] = PADDR[6:2] == 5'd16;  // out_xor
  assign err = !((1'b1 && {1'b0, PADDR[6:2]} < 6'd17));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11] || hit[12] || hit[13] || hit[14] || hit[15] || hit[16]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_gpio_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_gpio_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_gpio_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // input_val at 0x0
    p_input_val_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == input_val_pin)
      else $error("chilimix_gpio_regs: input_val read %h", PRDATA);
    p_input_val_rd_cov: cover (access && !PWRITE && hit[0]);
    // input_en at 0x4
    p_input_en_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == input_en_pin)
      else $error("chilimix_gpio_regs: input_en read %h", PRDATA);
    p_input_en_rd_cov: cover (access && !PWRITE && hit[1]);
    // output_en at 0x8
    p_output_en_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == output_en_pin)
      else $error("chilimix_gpio_regs: output_en read %h", PRDATA);
    p_output_en_rd_cov: cover (access && !PWRITE && hit[2]);
    // output_val at 0xc
    p_output_val_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == output_val_pin)
      else $error("chilimix_gpio_regs: output_val read %h", PRDATA);
    p_output_val_rd_cov: cover (access && !PWRITE && hit[3]);
    // pue at 0x10
    p_pue_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == pue_pin)
      else $error("chilimix_gpio_regs: pue read %h", PRDATA);
    p_pue_rd_cov: cover (access && !PWRITE && hit[4]);
    // ds at 0x14
    p_ds_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == ds_pin)
      else $error("chilimix_gpio_regs: ds read %h", PRDATA);
    p_ds_rd_cov: cover (access && !PWRITE && hit[5]);
    // rise_ie at 0x18
    p_rise_ie_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == rise_ie_pin)
      else $error("chilimix_gpio_regs: rise_ie read %h", PRDATA);
    p_rise_ie_rd_cov: cover (access && !PWRITE && hit[6]);
    // rise_ip at 0x1c
    p_rise_ip_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == rise_ip_pin)
      else $error("chilimix_gpio_regs: rise_ip read %h", PRDATA);
    p_rise_ip_rd_cov: cover (access && !PWRITE && hit[7]);
    // fall_ie at 0x20
    p_fall_ie_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == fall_ie_pin)
      else $error("chilimix_gpio_regs: fall_ie read %h", PRDATA);
    p_fall_ie_rd_cov: cover (access && !PWRITE && hit[8]);
    // fall_ip at 0x24
    p_fall_ip_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == fall_ip_pin)
      else $error("chilimix_gpio_regs: fall_ip read %h", PRDATA);
    p_fall_ip_rd_cov: cover (access && !PWRITE && hit[9]);
    // high_ie at 0x28
    p_high_ie_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == high_ie_pin)
      else $error("chilimix_gpio_regs: high_ie read %h", PRDATA);
    p_high_ie_rd_cov: cover (access && !PWRITE && hit[10]);
    // high_ip at 0x2c
    p_high_ip_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == high_ip_pin)
      else $error("chilimix_gpio_regs: high_ip read %h", PRDATA);
    p_high_ip_rd_cov: cover (access && !PWRITE && hit[11]);
    // low_ie at 0x30
    p_low_ie_rd: assert (!(access && !PWRITE && hit[12]) || PRDATA == low_ie_pin)
      else $error("chilimix_gpio_regs: low_ie read %h", PRDATA);
    p_low_ie_rd_cov: cover (access && !PWRITE && hit[12]);
    // low_ip at 0x34
    p_low_ip_rd: assert (!(access && !PWRITE && hit[13]) || PRDATA == low_ip_pin)
      else $error("chilimix_gpio_regs: low_ip read %h", PRDATA);
    p_low_ip_rd_cov: cover (access && !PWRITE && hit[13]);
    // iof_en at 0x38
    p_iof_en_rd: assert (!(access && !PWRITE && hit[14]) || PRDATA == iof_en_pin)
      else $error("chilimix_gpio_regs: iof_en read %h", PRDATA);
    p_iof_en_rd_cov: cover (access && !PWRITE && hit[14]);
    // iof_sel at 0x3c
    p_iof_sel_rd: assert (!(access && !PWRITE && hit[15]) || PRDATA == iof_sel_pin)
      else $error("chilimix_gpio_regs: iof_sel read %h", PRDATA);
    p_iof_sel_rd_cov: cover (access && !PWRITE && hit[15]);
    // out_xor at 0x40
    p_out_xor_rd: assert (!(access && !PWRITE && hit[16]) || PRDATA == out_xor_pin)
      else $error("chilimix_gpio_regs: out_xor read %h", PRDATA);
    p_out_xor_rd_cov: cover (access && !PWRITE && hit[16]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // input_val writes
    p_input_val_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    // input_en writes
    p_input_en_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_input_en_pin_rst: assert (!past_ok || $past(rst_n) || input_en_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: input_en.pin reset value %h", input_en_pin);
    p_input_en_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || input_en_pin == ($past((access && PWRITE && hit[1])) ? (($past(input_en_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(input_en_pin)))
      else $error("chilimix_gpio_regs: input_en.pin is %h after a write / hold", input_en_pin);
    // output_en writes
    p_output_en_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_output_en_pin_rst: assert (!past_ok || $past(rst_n) || output_en_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: output_en.pin reset value %h", output_en_pin);
    p_output_en_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || output_en_pin == ($past((access && PWRITE && hit[2])) ? (($past(output_en_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(output_en_pin)))
      else $error("chilimix_gpio_regs: output_en.pin is %h after a write / hold", output_en_pin);
    // output_val writes
    p_output_val_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_output_val_pin_rst: assert (!past_ok || $past(rst_n) || output_val_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: output_val.pin reset value %h", output_val_pin);
    p_output_val_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || output_val_pin == ($past((access && PWRITE && hit[3])) ? (($past(output_val_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(output_val_pin)))
      else $error("chilimix_gpio_regs: output_val.pin is %h after a write / hold", output_val_pin);
    // pue writes
    p_pue_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_pue_pin_rst: assert (!past_ok || $past(rst_n) || pue_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: pue.pin reset value %h", pue_pin);
    p_pue_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || pue_pin == ($past((access && PWRITE && hit[4])) ? (($past(pue_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(pue_pin)))
      else $error("chilimix_gpio_regs: pue.pin is %h after a write / hold", pue_pin);
    // ds writes
    p_ds_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_ds_pin_rst: assert (!past_ok || $past(rst_n) || ds_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: ds.pin reset value %h", ds_pin);
    p_ds_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || ds_pin == ($past((access && PWRITE && hit[5])) ? (($past(ds_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(ds_pin)))
      else $error("chilimix_gpio_regs: ds.pin is %h after a write / hold", ds_pin);
    // rise_ie writes
    p_rise_ie_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_rise_ie_pin_rst: assert (!past_ok || $past(rst_n) || rise_ie_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: rise_ie.pin reset value %h", rise_ie_pin);
    p_rise_ie_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || rise_ie_pin == ($past((access && PWRITE && hit[6])) ? (($past(rise_ie_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(rise_ie_pin)))
      else $error("chilimix_gpio_regs: rise_ie.pin is %h after a write / hold", rise_ie_pin);
    // rise_ip writes
    p_rise_ip_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    p_rise_ip_pin_rst: assert (!past_ok || $past(rst_n) || rise_ip_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: rise_ip.pin reset value %h", rise_ip_pin);
    p_rise_ip_pin_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || rise_ip_pin == (($past(rise_ip_pin) & ~($past((access && PWRITE && hit[7])) ? ($past(PWDATA[31:0]) & $past(bit_en[31:0])) : '0)) | $past(rise_ip_pin_set)))
      else $error("chilimix_gpio_regs: rise_ip.pin is %h after a clear / set", rise_ip_pin);
    // fall_ie writes
    p_fall_ie_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    p_fall_ie_pin_rst: assert (!past_ok || $past(rst_n) || fall_ie_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: fall_ie.pin reset value %h", fall_ie_pin);
    p_fall_ie_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || fall_ie_pin == ($past((access && PWRITE && hit[8])) ? (($past(fall_ie_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(fall_ie_pin)))
      else $error("chilimix_gpio_regs: fall_ie.pin is %h after a write / hold", fall_ie_pin);
    // fall_ip writes
    p_fall_ip_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    p_fall_ip_pin_rst: assert (!past_ok || $past(rst_n) || fall_ip_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: fall_ip.pin reset value %h", fall_ip_pin);
    p_fall_ip_pin_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || fall_ip_pin == (($past(fall_ip_pin) & ~($past((access && PWRITE && hit[9])) ? ($past(PWDATA[31:0]) & $past(bit_en[31:0])) : '0)) | $past(fall_ip_pin_set)))
      else $error("chilimix_gpio_regs: fall_ip.pin is %h after a clear / set", fall_ip_pin);
    // high_ie writes
    p_high_ie_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    p_high_ie_pin_rst: assert (!past_ok || $past(rst_n) || high_ie_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: high_ie.pin reset value %h", high_ie_pin);
    p_high_ie_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || high_ie_pin == ($past((access && PWRITE && hit[10])) ? (($past(high_ie_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(high_ie_pin)))
      else $error("chilimix_gpio_regs: high_ie.pin is %h after a write / hold", high_ie_pin);
    // high_ip writes
    p_high_ip_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
    p_high_ip_pin_rst: assert (!past_ok || $past(rst_n) || high_ip_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: high_ip.pin reset value %h", high_ip_pin);
    p_high_ip_pin_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || high_ip_pin == (($past(high_ip_pin) & ~($past((access && PWRITE && hit[11])) ? ($past(PWDATA[31:0]) & $past(bit_en[31:0])) : '0)) | $past(high_ip_pin_set)))
      else $error("chilimix_gpio_regs: high_ip.pin is %h after a clear / set", high_ip_pin);
    // low_ie writes
    p_low_ie_wr_cov: cover (rst_n && (access && PWRITE && hit[12]));
    p_low_ie_pin_rst: assert (!past_ok || $past(rst_n) || low_ie_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: low_ie.pin reset value %h", low_ie_pin);
    p_low_ie_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || low_ie_pin == ($past((access && PWRITE && hit[12])) ? (($past(low_ie_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(low_ie_pin)))
      else $error("chilimix_gpio_regs: low_ie.pin is %h after a write / hold", low_ie_pin);
    // low_ip writes
    p_low_ip_wr_cov: cover (rst_n && (access && PWRITE && hit[13]));
    p_low_ip_pin_rst: assert (!past_ok || $past(rst_n) || low_ip_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: low_ip.pin reset value %h", low_ip_pin);
    p_low_ip_pin_w1c: assert (!rst_n || !past_ok || !$past(rst_n) || low_ip_pin == (($past(low_ip_pin) & ~($past((access && PWRITE && hit[13])) ? ($past(PWDATA[31:0]) & $past(bit_en[31:0])) : '0)) | $past(low_ip_pin_set)))
      else $error("chilimix_gpio_regs: low_ip.pin is %h after a clear / set", low_ip_pin);
    // iof_en writes
    p_iof_en_wr_cov: cover (rst_n && (access && PWRITE && hit[14]));
    p_iof_en_pin_rst: assert (!past_ok || $past(rst_n) || iof_en_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: iof_en.pin reset value %h", iof_en_pin);
    p_iof_en_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || iof_en_pin == ($past((access && PWRITE && hit[14])) ? (($past(iof_en_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(iof_en_pin)))
      else $error("chilimix_gpio_regs: iof_en.pin is %h after a write / hold", iof_en_pin);
    // iof_sel writes
    p_iof_sel_wr_cov: cover (rst_n && (access && PWRITE && hit[15]));
    p_iof_sel_pin_rst: assert (!past_ok || $past(rst_n) || iof_sel_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: iof_sel.pin reset value %h", iof_sel_pin);
    p_iof_sel_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || iof_sel_pin == ($past((access && PWRITE && hit[15])) ? (($past(iof_sel_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(iof_sel_pin)))
      else $error("chilimix_gpio_regs: iof_sel.pin is %h after a write / hold", iof_sel_pin);
    // out_xor writes
    p_out_xor_wr_cov: cover (rst_n && (access && PWRITE && hit[16]));
    p_out_xor_pin_rst: assert (!past_ok || $past(rst_n) || out_xor_pin == 32'h0000_0000)
      else $error("chilimix_gpio_regs: out_xor.pin reset value %h", out_xor_pin);
    p_out_xor_pin_wr: assert (!rst_n || !past_ok || !$past(rst_n) || out_xor_pin == ($past((access && PWRITE && hit[16])) ? (($past(out_xor_pin) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(out_xor_pin)))
      else $error("chilimix_gpio_regs: out_xor.pin is %h after a write / hold", out_xor_pin);
  end

endmodule

bind chilimix_gpio_regs chilimix_gpio_regs_chk u_chk (.*);
