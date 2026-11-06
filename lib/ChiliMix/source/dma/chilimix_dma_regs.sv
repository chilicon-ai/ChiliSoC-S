// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_dma_regs
//
// One channel of the SiFive Platform DMA (sifive,fu540-c000-pdma): Next registers software programs, Exec registers the running transfer; channel i at 0x1000 * i register block: an APB4 subordinate (12-bit PADDR, 32-bit data).
// Register layout compatible with sifive,fu540-c000-pdma.
// Built on basechili_apb_regbank (2 bank(s)), blocks selected by basechili_apb_interconnect.
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear, wo = write-only, not stored):
//   block next at 0x0, 0x20 bytes
//   0x0000  control      error[31] ro, done[30] ro, error_ie[15] ro, done_ie[14] ro, run[1] ro, claim[0] ro  (reads only)
//   0x0000  control_w    error[31] wo, done[30] wo, error_ie[15] wo, done_ie[14] wo, run[1] wo, claim[0] wo  (writes only)
//   0x0004  next_config  rsize[31:28] rw, wsize[27:24] rw, order[3] rw, repeat[2] rw
//   0x0008  next_bytes   value[31:0] rw
//   0x0010  next_dst     value[31:0] rw
//   0x0018  next_src     value[31:0] rw
//   0x001c  next_src_hi  value[31:0] ro
//   block exec at 0x100, 0x20 bytes
//   0x0104  exec_config  rsize[31:28] ro, wsize[27:24] ro, order[3] ro, repeat[2] ro
//   0x0108  exec_bytes   value[31:0] ro
//   0x0110  exec_dst     value[31:0] ro
//   0x0118  exec_src     value[31:0] ro
//   0x011c  exec_src_hi  value[31:0] ro
//
// Words inside a block with no register read 0 and ignore writes; words past
// a block's last register and addresses outside every block give PSLVERR.
//
// Timing    : as basechili_apb_regbank: no wait states (PREADY high), PRDATA
//             combinational from the APB inputs; field outputs are registered
//             and change the cycle after the write or the _set input.
// Debug     : wrong read value -> u_<block>.reg_q / hw_rd; write lost -> PSTRB
//             and u_<block>.wr_pulse; PSLVERR -> u_apb.PSEL_s.
// -----------------------------------------------------------------------------
module chilimix_dma_regs (
  input  logic clk,
  input  logic rst_n,                     // async, active-low
  input  logic PSEL,                      // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [11:0] PADDR,              // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  input  logic control_claim,             // ro: The channel is in use
  input  logic control_run,               // ro: A transfer runs (hardware clears it at the end, or after an abort)
  input  logic control_done_ie,           // ro: Done interrupt enable
  input  logic control_error_ie,          // ro: Error interrupt enable
  input  logic control_done,              // ro: The transfer finished (cleared by writing 0)
  input  logic control_error,             // ro: A bus error stopped the transfer (cleared by writing 0)
  output logic control_w_claim,           // wo: Claim the channel (cannot be cleared while run is set)
  output logic control_w_run,             // wo: 1 with run clear: copy Next to Exec and start; 0 with run set: stop after the current beat
  output logic control_w_done_ie,         // wo: Done interrupt enable
  output logic control_w_error_ie,        // wo: Error interrupt enable
  output logic control_w_done,            // wo: 0 clears done
  output logic control_w_error,           // wo: 0 clears error
  output logic control_w_wr,              // control_w write this cycle (APB ACCESS)
  output logic next_config_repeat,        // rw: At the end, copy Next to Exec again and keep running
  output logic next_config_order,         // rw: Strict ordering (always the case here: one access at a time)
  output logic [3:0] next_config_wsize,   // rw: log2 of the largest write transaction (stored; accesses are at most one bus word)
  output logic [3:0] next_config_rsize,   // rw: log2 of the largest read transaction (stored; accesses are at most one bus word)
  output logic [31:0] next_bytes_value,   // rw: Byte count
  output logic [31:0] next_dst_value,     // rw: Destination byte address
  output logic [31:0] next_src_value,     // rw: Source byte address
  input  logic [31:0] next_src_hi_value,  // ro: 0
  input  logic exec_config_repeat,        // ro: Repeat
  input  logic exec_config_order,         // ro: Strict ordering
  input  logic [3:0] exec_config_wsize,   // ro: Write transaction size
  input  logic [3:0] exec_config_rsize,   // ro: Read transaction size
  input  logic [31:0] exec_bytes_value,   // ro: Bytes left
  input  logic [31:0] exec_dst_value,     // ro: Destination byte address
  input  logic [31:0] exec_src_value,     // ro: Source byte address
  input  logic [31:0] exec_src_hi_value   // ro: 0
);

  localparam logic [23:0] BLOCK_BASE = 24'h10_0000;
  localparam logic [23:0] BLOCK_MASK = 24'hfe_0fe0;
  logic [1:0]      apb_psel_s;      // PSEL of each block
  logic [1:0]      apb_pready_s;
  logic [63:0] apb_prdata_s;
  logic [1:0]      apb_pslverr_s;

  basechili_apb_interconnect #(
    .ADDR_W (12),
    .DATA_W (32),
    .N      (2),
    .BASE   (BLOCK_BASE),
    .MASK   (BLOCK_MASK)
  ) u_apb (
    .PSEL      (PSEL),
    .PADDR     (PADDR),
    .PREADY    (PREADY),
    .PRDATA    (PRDATA),
    .PSLVERR   (PSLVERR),
    .PSEL_s    (apb_psel_s),
    .PREADY_s  (apb_pready_s),
    .PRDATA_s  (apb_prdata_s),
    .PSLVERR_s (apb_pslverr_s)
  );

  // ---- block next: 8 word(s) at 0x0 (one per register, one empty: offsets are shared)
  localparam int                N_NEXT = 8;
  localparam logic [255:0] RESET_NEXT = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [255:0] RW_NEXT = 256'h0000_0000_0000_0000_ffff_ffff_ffff_ffff_ffff_ffff_ff00_000c_0000_0000_0000_0000;
  localparam logic [255:0] W1C_NEXT = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [255:0] next_reg_q;    // rw and w1c bit values
  logic [255:0] next_hw_rd;    // read-only bit values
  logic [255:0] next_hw_set;   // w1c set requests
  logic [7:0] next_wr_pulse;    // register written this cycle

  logic [2:0] next_word;     // word address inside the block
  logic [3:0] next_slot;     // regbank word of the register selected there
  logic [5:0] next_rb_addr;  // regbank PADDR

  assign next_word = PADDR[4:2];
  assign next_rb_addr = {next_slot, PADDR[1:0]};

  // shared offsets: the register an access selects (by direction and bank field)
  always_comb begin
    next_slot = 4'd8;  // past the last register: PSLVERR
    case (next_word)
      3'd0: next_slot = (!PWRITE) ? 4'd0 : (PWRITE) ? 4'd1 : 4'd7;  // control, control_w
      3'd1: next_slot = 4'd2;  // next_config
      3'd2: next_slot = 4'd3;  // next_bytes
      3'd3: next_slot = 4'd7;  // no register
      3'd4: next_slot = 4'd4;  // next_dst
      3'd5: next_slot = 4'd7;  // no register
      3'd6: next_slot = 4'd5;  // next_src
      default: next_slot = 4'd6;  // next_src_hi
    endcase
  end

  assign next_hw_rd[31:0] = {control_error, control_done, 14'b0, control_error_ie, control_done_ie, 12'b0, control_run, control_claim};  // control
  assign next_hw_set[31:0] = '0;
  assign next_hw_rd[63:32] = '0;  // control_w
  assign next_hw_set[63:32] = '0;
  assign next_hw_rd[95:64] = '0;  // next_config
  assign next_hw_set[95:64] = '0;
  assign next_hw_rd[127:96] = '0;  // next_bytes
  assign next_hw_set[127:96] = '0;
  assign next_hw_rd[159:128] = '0;  // next_dst
  assign next_hw_set[159:128] = '0;
  assign next_hw_rd[191:160] = '0;  // next_src
  assign next_hw_set[191:160] = '0;
  assign next_hw_rd[223:192] = next_src_hi_value;  // next_src_hi
  assign next_hw_set[223:192] = '0;
  assign next_hw_rd[255:224] = '0;  // (no register)
  assign next_hw_set[255:224] = '0;
  assign control_w_claim = PWDATA[0];
  assign control_w_run = PWDATA[1];
  assign control_w_done_ie = PWDATA[14];
  assign control_w_error_ie = PWDATA[15];
  assign control_w_done = PWDATA[30];
  assign control_w_error = PWDATA[31];
  assign control_w_wr = next_wr_pulse[1];
  assign next_config_repeat = next_reg_q[66];
  assign next_config_order = next_reg_q[67];
  assign next_config_wsize = next_reg_q[91:88];
  assign next_config_rsize = next_reg_q[95:92];
  assign next_bytes_value = next_reg_q[127:96];
  assign next_dst_value = next_reg_q[159:128];
  assign next_src_value = next_reg_q[191:160];

  basechili_apb_regbank #(
    .ADDR_W   (6),
    .DATA_W   (32),
    .N        (N_NEXT),
    .RESET    (RESET_NEXT),
    .RW_MASK  (RW_NEXT),
    .W1C_MASK (W1C_NEXT)
  ) u_next (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[0]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (next_rb_addr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[0]),
    .PRDATA   (apb_prdata_s[31:0]),
    .PSLVERR  (apb_pslverr_s[0]),
    .reg_q    (next_reg_q),
    .hw_rd    (next_hw_rd),
    .hw_set   (next_hw_set),
    .wr_pulse (next_wr_pulse),
    .rd_pulse ()
  );

  // ---- block exec: 8 word(s) at 0x100
  localparam int                N_EXEC = 8;
  localparam logic [255:0] RESET_EXEC = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [255:0] RW_EXEC = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [255:0] W1C_EXEC = 256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [255:0] exec_hw_rd;    // read-only bit values
  logic [255:0] exec_hw_set;   // w1c set requests
  logic [4:0] exec_paddr;    // address inside the block

  assign exec_hw_rd[31:0] = '0;  // (no register)
  assign exec_hw_set[31:0] = '0;
  assign exec_hw_rd[63:32] = {exec_config_rsize, exec_config_wsize, 20'b0, exec_config_order, exec_config_repeat, 2'b0};  // exec_config
  assign exec_hw_set[63:32] = '0;
  assign exec_hw_rd[95:64] = exec_bytes_value;  // exec_bytes
  assign exec_hw_set[95:64] = '0;
  assign exec_hw_rd[127:96] = '0;  // (no register)
  assign exec_hw_set[127:96] = '0;
  assign exec_hw_rd[159:128] = exec_dst_value;  // exec_dst
  assign exec_hw_set[159:128] = '0;
  assign exec_hw_rd[191:160] = '0;  // (no register)
  assign exec_hw_set[191:160] = '0;
  assign exec_hw_rd[223:192] = exec_src_value;  // exec_src
  assign exec_hw_set[223:192] = '0;
  assign exec_hw_rd[255:224] = exec_src_hi_value;  // exec_src_hi
  assign exec_hw_set[255:224] = '0;
  assign exec_paddr = PADDR[4:0];

  basechili_apb_regbank #(
    .ADDR_W   (5),
    .DATA_W   (32),
    .N        (N_EXEC),
    .RESET    (RESET_EXEC),
    .RW_MASK  (RW_EXEC),
    .W1C_MASK (W1C_EXEC)
  ) u_exec (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[1]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (exec_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[1]),
    .PRDATA   (apb_prdata_s[63:32]),
    .PSLVERR  (apb_pslverr_s[1]),
    .reg_q    (),
    .hw_rd    (exec_hw_rd),
    .hw_set   (exec_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

endmodule
