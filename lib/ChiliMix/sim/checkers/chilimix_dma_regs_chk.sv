// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_dma_regs_chk (simulation and formal; bound into every chilimix_dma_regs)
//
// The dma register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_dma_regs_chk (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [11:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic control_claim,
  input logic control_run,
  input logic control_done_ie,
  input logic control_error_ie,
  input logic control_done,
  input logic control_error,
  input logic control_w_claim,
  input logic control_w_run,
  input logic control_w_done_ie,
  input logic control_w_error_ie,
  input logic control_w_done,
  input logic control_w_error,
  input logic control_w_wr,
  input logic next_config_repeat,
  input logic next_config_order,
  input logic [3:0] next_config_wsize,
  input logic [3:0] next_config_rsize,
  input logic [31:0] next_bytes_value,
  input logic [31:0] next_dst_value,
  input logic [31:0] next_src_value,
  input logic [31:0] next_src_hi_value,
  input logic exec_config_repeat,
  input logic exec_config_order,
  input logic [3:0] exec_config_wsize,
  input logic [3:0] exec_config_rsize,
  input logic [31:0] exec_bytes_value,
  input logic [31:0] exec_dst_value,
  input logic [31:0] exec_src_value,
  input logic [31:0] exec_src_hi_value
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [11:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[11:2] == 10'd0 && (!PWRITE);  // control
  assign hit[1] = PADDR[11:2] == 10'd0 && (PWRITE);  // control_w
  assign hit[2] = PADDR[11:2] == 10'd1;  // next_config
  assign hit[3] = PADDR[11:2] == 10'd2;  // next_bytes
  assign hit[4] = PADDR[11:2] == 10'd4;  // next_dst
  assign hit[5] = PADDR[11:2] == 10'd6;  // next_src
  assign hit[6] = PADDR[11:2] == 10'd7;  // next_src_hi
  assign hit[7] = PADDR[11:2] == 10'd65;  // exec_config
  assign hit[8] = PADDR[11:2] == 10'd66;  // exec_bytes
  assign hit[9] = PADDR[11:2] == 10'd68;  // exec_dst
  assign hit[10] = PADDR[11:2] == 10'd70;  // exec_src
  assign hit[11] = PADDR[11:2] == 10'd71;  // exec_src_hi
  assign err = !((PADDR[11:5] == 7'd0 && {1'b0, PADDR[4:2]} < 4'd8) || (PADDR[11:5] == 7'd8 && {1'b0, PADDR[4:2]} < 4'd8));
  assign any_rd = !PWRITE && (hit[0] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_dma_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_dma_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_dma_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // control at 0x0
    p_control_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {control_error, control_done, 14'b0, control_error_ie, control_done_ie, 12'b0, control_run, control_claim})
      else $error("chilimix_dma_regs: control read %h", PRDATA);
    p_control_rd_cov: cover (access && !PWRITE && hit[0]);
    // next_config at 0x4
    p_next_config_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {next_config_rsize, next_config_wsize, 20'b0, next_config_order, next_config_repeat, 2'b0})
      else $error("chilimix_dma_regs: next_config read %h", PRDATA);
    p_next_config_rd_cov: cover (access && !PWRITE && hit[2]);
    // next_bytes at 0x8
    p_next_bytes_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == next_bytes_value)
      else $error("chilimix_dma_regs: next_bytes read %h", PRDATA);
    p_next_bytes_rd_cov: cover (access && !PWRITE && hit[3]);
    // next_dst at 0x10
    p_next_dst_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == next_dst_value)
      else $error("chilimix_dma_regs: next_dst read %h", PRDATA);
    p_next_dst_rd_cov: cover (access && !PWRITE && hit[4]);
    // next_src at 0x18
    p_next_src_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == next_src_value)
      else $error("chilimix_dma_regs: next_src read %h", PRDATA);
    p_next_src_rd_cov: cover (access && !PWRITE && hit[5]);
    // next_src_hi at 0x1c
    p_next_src_hi_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == next_src_hi_value)
      else $error("chilimix_dma_regs: next_src_hi read %h", PRDATA);
    p_next_src_hi_rd_cov: cover (access && !PWRITE && hit[6]);
    // exec_config at 0x104
    p_exec_config_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == {exec_config_rsize, exec_config_wsize, 20'b0, exec_config_order, exec_config_repeat, 2'b0})
      else $error("chilimix_dma_regs: exec_config read %h", PRDATA);
    p_exec_config_rd_cov: cover (access && !PWRITE && hit[7]);
    // exec_bytes at 0x108
    p_exec_bytes_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == exec_bytes_value)
      else $error("chilimix_dma_regs: exec_bytes read %h", PRDATA);
    p_exec_bytes_rd_cov: cover (access && !PWRITE && hit[8]);
    // exec_dst at 0x110
    p_exec_dst_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == exec_dst_value)
      else $error("chilimix_dma_regs: exec_dst read %h", PRDATA);
    p_exec_dst_rd_cov: cover (access && !PWRITE && hit[9]);
    // exec_src at 0x118
    p_exec_src_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == exec_src_value)
      else $error("chilimix_dma_regs: exec_src read %h", PRDATA);
    p_exec_src_rd_cov: cover (access && !PWRITE && hit[10]);
    // exec_src_hi at 0x11c
    p_exec_src_hi_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == exec_src_hi_value)
      else $error("chilimix_dma_regs: exec_src_hi read %h", PRDATA);
    p_exec_src_hi_rd_cov: cover (access && !PWRITE && hit[11]);
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // control_w writes
    p_control_w_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_control_w_wrp: assert (!rst_n || control_w_wr == (access && PWRITE && hit[1]))
      else $error("chilimix_dma_regs: control_w write pulse wrong");
    // next_config writes
    p_next_config_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_next_config_repeat_rst: assert (!past_ok || $past(rst_n) || next_config_repeat == 1'h0)
      else $error("chilimix_dma_regs: next_config.repeat reset value %h", next_config_repeat);
    p_next_config_repeat_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_config_repeat == ($past((access && PWRITE && hit[2])) ? (($past(next_config_repeat) & ~$past(bit_en[2:2])) | ($past(PWDATA[2:2]) & $past(bit_en[2:2]))) : $past(next_config_repeat)))
      else $error("chilimix_dma_regs: next_config.repeat is %h after a write / hold", next_config_repeat);
    p_next_config_order_rst: assert (!past_ok || $past(rst_n) || next_config_order == 1'h0)
      else $error("chilimix_dma_regs: next_config.order reset value %h", next_config_order);
    p_next_config_order_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_config_order == ($past((access && PWRITE && hit[2])) ? (($past(next_config_order) & ~$past(bit_en[3:3])) | ($past(PWDATA[3:3]) & $past(bit_en[3:3]))) : $past(next_config_order)))
      else $error("chilimix_dma_regs: next_config.order is %h after a write / hold", next_config_order);
    p_next_config_wsize_rst: assert (!past_ok || $past(rst_n) || next_config_wsize == 4'h0)
      else $error("chilimix_dma_regs: next_config.wsize reset value %h", next_config_wsize);
    p_next_config_wsize_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_config_wsize == ($past((access && PWRITE && hit[2])) ? (($past(next_config_wsize) & ~$past(bit_en[27:24])) | ($past(PWDATA[27:24]) & $past(bit_en[27:24]))) : $past(next_config_wsize)))
      else $error("chilimix_dma_regs: next_config.wsize is %h after a write / hold", next_config_wsize);
    p_next_config_rsize_rst: assert (!past_ok || $past(rst_n) || next_config_rsize == 4'h0)
      else $error("chilimix_dma_regs: next_config.rsize reset value %h", next_config_rsize);
    p_next_config_rsize_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_config_rsize == ($past((access && PWRITE && hit[2])) ? (($past(next_config_rsize) & ~$past(bit_en[31:28])) | ($past(PWDATA[31:28]) & $past(bit_en[31:28]))) : $past(next_config_rsize)))
      else $error("chilimix_dma_regs: next_config.rsize is %h after a write / hold", next_config_rsize);
    // next_bytes writes
    p_next_bytes_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_next_bytes_value_rst: assert (!past_ok || $past(rst_n) || next_bytes_value == 32'h0000_0000)
      else $error("chilimix_dma_regs: next_bytes.value reset value %h", next_bytes_value);
    p_next_bytes_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_bytes_value == ($past((access && PWRITE && hit[3])) ? (($past(next_bytes_value) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(next_bytes_value)))
      else $error("chilimix_dma_regs: next_bytes.value is %h after a write / hold", next_bytes_value);
    // next_dst writes
    p_next_dst_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_next_dst_value_rst: assert (!past_ok || $past(rst_n) || next_dst_value == 32'h0000_0000)
      else $error("chilimix_dma_regs: next_dst.value reset value %h", next_dst_value);
    p_next_dst_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_dst_value == ($past((access && PWRITE && hit[4])) ? (($past(next_dst_value) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(next_dst_value)))
      else $error("chilimix_dma_regs: next_dst.value is %h after a write / hold", next_dst_value);
    // next_src writes
    p_next_src_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_next_src_value_rst: assert (!past_ok || $past(rst_n) || next_src_value == 32'h0000_0000)
      else $error("chilimix_dma_regs: next_src.value reset value %h", next_src_value);
    p_next_src_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || next_src_value == ($past((access && PWRITE && hit[5])) ? (($past(next_src_value) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(next_src_value)))
      else $error("chilimix_dma_regs: next_src.value is %h after a write / hold", next_src_value);
    // next_src_hi writes
    p_next_src_hi_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    // exec_config writes
    p_exec_config_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    // exec_bytes writes
    p_exec_bytes_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    // exec_dst writes
    p_exec_dst_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    // exec_src writes
    p_exec_src_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    // exec_src_hi writes
    p_exec_src_hi_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
  end

endmodule

bind chilimix_dma_regs chilimix_dma_regs_chk u_chk (.*);
