// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_gpio_regs
//
// GPIO for up to 32 pins with edge and level interrupts and two IO functions per pin register block: an APB4 subordinate (7-bit PADDR, 32-bit data).
// Register layout compatible with sifive,gpio0.
// Built on basechili_apb_regbank (1 bank(s)).
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear):
//   0x0000  input_val    pin[31:0] ro
//   0x0004  input_en     pin[31:0] rw
//   0x0008  output_en    pin[31:0] rw
//   0x000c  output_val   pin[31:0] rw
//   0x0010  pue          pin[31:0] rw
//   0x0014  ds           pin[31:0] rw
//   0x0018  rise_ie      pin[31:0] rw
//   0x001c  rise_ip      pin[31:0] w1c
//   0x0020  fall_ie      pin[31:0] rw
//   0x0024  fall_ip      pin[31:0] w1c
//   0x0028  high_ie      pin[31:0] rw
//   0x002c  high_ip      pin[31:0] w1c
//   0x0030  low_ie       pin[31:0] rw
//   0x0034  low_ip       pin[31:0] w1c
//   0x0038  iof_en       pin[31:0] rw
//   0x003c  iof_sel      pin[31:0] rw
//   0x0040  out_xor      pin[31:0] rw
//
// Words inside a block with no register read 0 and ignore writes; words past
// a block's last register give PSLVERR.
//
// Timing    : as basechili_apb_regbank: no wait states (PREADY high), PRDATA
//             combinational from the APB inputs; field outputs are registered
//             and change the cycle after the write or the _set input.
// Debug     : wrong read value -> u_<block>.reg_q / hw_rd; write lost -> PSTRB
//             and u_<block>.wr_pulse.
// -----------------------------------------------------------------------------
module chilimix_gpio_regs (
  input  logic clk,
  input  logic rst_n,                   // async, active-low
  input  logic PSEL,                    // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [6:0] PADDR,             // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  input  logic [31:0] input_val_pin,    // ro: Pin i input value
  output logic [31:0] input_en_pin,     // rw: Pin i input sampled
  output logic [31:0] output_en_pin,    // rw: Pin i driven
  output logic [31:0] output_val_pin,   // rw: Pin i output value
  output logic [31:0] pue_pin,          // rw: Pin i pull-up on
  output logic [31:0] ds_pin,           // rw: Pin i high drive strength
  output logic [31:0] rise_ie_pin,      // rw: Pin i interrupts on rise_ip
  output logic [31:0] rise_ip_pin,      // w1c: Pin i input_val rose
  input  logic [31:0] rise_ip_pin_set,  // set rise_ip.pin bits
  output logic [31:0] fall_ie_pin,      // rw: Pin i interrupts on fall_ip
  output logic [31:0] fall_ip_pin,      // w1c: Pin i input_val fell
  input  logic [31:0] fall_ip_pin_set,  // set fall_ip.pin bits
  output logic [31:0] high_ie_pin,      // rw: Pin i interrupts on high_ip
  output logic [31:0] high_ip_pin,      // w1c: Pin i input_val was 1
  input  logic [31:0] high_ip_pin_set,  // set high_ip.pin bits
  output logic [31:0] low_ie_pin,       // rw: Pin i interrupts on low_ip
  output logic [31:0] low_ip_pin,       // w1c: Pin i input_val was 0
  input  logic [31:0] low_ip_pin_set,   // set low_ip.pin bits
  output logic [31:0] iof_en_pin,       // rw: Pin i driven by IO function iof_sel
  output logic [31:0] iof_sel_pin,      // rw: Pin i: 0 = IOF0, 1 = IOF1
  output logic [31:0] out_xor_pin       // rw: Pin i output inverted
);

  // ---- block gpio: 17 word(s) at 0x0
  localparam int                N_GPIO = 17;
  localparam logic [543:0] RESET_GPIO = 544'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [543:0] RW_GPIO = 544'hffff_ffff_ffff_ffff_ffff_ffff_0000_0000_ffff_ffff_0000_0000_ffff_ffff_0000_0000_ffff_ffff_0000_0000_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff_0000_0000;
  localparam logic [543:0] W1C_GPIO = 544'h0000_0000_0000_0000_0000_0000_ffff_ffff_0000_0000_ffff_ffff_0000_0000_ffff_ffff_0000_0000_ffff_ffff_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [543:0] gpio_reg_q;    // rw and w1c bit values
  logic [543:0] gpio_hw_rd;    // read-only bit values
  logic [543:0] gpio_hw_set;   // w1c set requests

  assign gpio_hw_rd[31:0] = input_val_pin;  // input_val
  assign gpio_hw_set[31:0] = '0;
  assign gpio_hw_rd[63:32] = '0;  // input_en
  assign gpio_hw_set[63:32] = '0;
  assign gpio_hw_rd[95:64] = '0;  // output_en
  assign gpio_hw_set[95:64] = '0;
  assign gpio_hw_rd[127:96] = '0;  // output_val
  assign gpio_hw_set[127:96] = '0;
  assign gpio_hw_rd[159:128] = '0;  // pue
  assign gpio_hw_set[159:128] = '0;
  assign gpio_hw_rd[191:160] = '0;  // ds
  assign gpio_hw_set[191:160] = '0;
  assign gpio_hw_rd[223:192] = '0;  // rise_ie
  assign gpio_hw_set[223:192] = '0;
  assign gpio_hw_rd[255:224] = '0;  // rise_ip
  assign gpio_hw_set[255:224] = rise_ip_pin_set;
  assign gpio_hw_rd[287:256] = '0;  // fall_ie
  assign gpio_hw_set[287:256] = '0;
  assign gpio_hw_rd[319:288] = '0;  // fall_ip
  assign gpio_hw_set[319:288] = fall_ip_pin_set;
  assign gpio_hw_rd[351:320] = '0;  // high_ie
  assign gpio_hw_set[351:320] = '0;
  assign gpio_hw_rd[383:352] = '0;  // high_ip
  assign gpio_hw_set[383:352] = high_ip_pin_set;
  assign gpio_hw_rd[415:384] = '0;  // low_ie
  assign gpio_hw_set[415:384] = '0;
  assign gpio_hw_rd[447:416] = '0;  // low_ip
  assign gpio_hw_set[447:416] = low_ip_pin_set;
  assign gpio_hw_rd[479:448] = '0;  // iof_en
  assign gpio_hw_set[479:448] = '0;
  assign gpio_hw_rd[511:480] = '0;  // iof_sel
  assign gpio_hw_set[511:480] = '0;
  assign gpio_hw_rd[543:512] = '0;  // out_xor
  assign gpio_hw_set[543:512] = '0;
  assign input_en_pin = gpio_reg_q[63:32];
  assign output_en_pin = gpio_reg_q[95:64];
  assign output_val_pin = gpio_reg_q[127:96];
  assign pue_pin = gpio_reg_q[159:128];
  assign ds_pin = gpio_reg_q[191:160];
  assign rise_ie_pin = gpio_reg_q[223:192];
  assign rise_ip_pin = gpio_reg_q[255:224];
  assign fall_ie_pin = gpio_reg_q[287:256];
  assign fall_ip_pin = gpio_reg_q[319:288];
  assign high_ie_pin = gpio_reg_q[351:320];
  assign high_ip_pin = gpio_reg_q[383:352];
  assign low_ie_pin = gpio_reg_q[415:384];
  assign low_ip_pin = gpio_reg_q[447:416];
  assign iof_en_pin = gpio_reg_q[479:448];
  assign iof_sel_pin = gpio_reg_q[511:480];
  assign out_xor_pin = gpio_reg_q[543:512];

  basechili_apb_regbank #(
    .ADDR_W   (7),
    .DATA_W   (32),
    .N        (N_GPIO),
    .RESET    (RESET_GPIO),
    .RW_MASK  (RW_GPIO),
    .W1C_MASK (W1C_GPIO)
  ) u_gpio (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (PSEL),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (PADDR),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (PREADY),
    .PRDATA   (PRDATA),
    .PSLVERR  (PSLVERR),
    .reg_q    (gpio_reg_q),
    .hw_rd    (gpio_hw_rd),
    .hw_set   (gpio_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

endmodule
