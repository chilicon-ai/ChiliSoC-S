// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_gpio
//
// GPIO for N_GPIO pins (1 .. 32) in the SiFive GPIO layout (sifive,gpio0), so
// existing drivers work. Per pin:
//   input   gpio_in is synchronized (2 flops); input_val = synced & input_en.
//   output  gpio_out = (iof_en ? (iof_sel ? iof1_out : iof0_out)
//                              : output_val) ^ out_xor
//           gpio_oe  =  iof_en ? (iof_sel ? iof1_oe  : iof0_oe)  : output_en
//           gpio_pue / gpio_ds are the pue / ds registers (pad controls).
//   irq     rise_ip / fall_ip latch edges of input_val, high_ip / low_ip its
//           level (set again every cycle the level holds); each is cleared by
//           writing 1, a set in the same cycle wins. irq[i] is the OR of the
//           four ip & ie bits of pin i, registered.
// The IO functions let other IP (UART, SPI, ...) share pins: the integration
// connects their outputs to iof0_* / iof1_* and their inputs to gpio_in.
// Register bits of pins at and above N_GPIO hold what is written but drive
// nothing; their input_val and ip bits read 0.
//
// Timing    : APB reads are combinational (no wait states). input_val shows
//             a pin change 2 cycles later, the ip bits 3 cycles later, irq 4.
//             gpio_out / gpio_oe are combinational from the registers and the
//             iof inputs; gpio_pue / gpio_ds are registers.
// Invariants: irq is the registered OR of the ip & ie bits of each pin.
// Debug     : no interrupt -> in_val, u_edge.rise / fall, u_regs.*_ip_pin and
//             *_ie_pin; pin not driven -> iof_en_pin, output_en_pin; wrong
//             level -> out_xor_pin, iof_sel_pin.
// -----------------------------------------------------------------------------
module chilimix_gpio #(
  parameter int N_GPIO = 32                  // pins, 1 .. 32
) (
  input  logic              clk,
  input  logic              rst_n,           // async, active-low
  // APB4 subordinate (registers)
  input  logic              PSEL,
  input  logic              PENABLE,
  input  logic              PWRITE,
  input  logic [6:0]        PADDR,           // byte address inside the GPIO
  input  logic [31:0]       PWDATA,
  input  logic [3:0]        PSTRB,
  output logic              PREADY,
  output logic [31:0]       PRDATA,
  output logic              PSLVERR,
  // pads
  input  logic [N_GPIO-1:0] gpio_in,         // pin values, asynchronous
  output logic [N_GPIO-1:0] gpio_out,        // pin output values
  output logic [N_GPIO-1:0] gpio_oe,         // pin output enables
  output logic [N_GPIO-1:0] gpio_pue,        // pull-up enables
  output logic [N_GPIO-1:0] gpio_ds,         // drive strengths
  // IO functions (other IP driving the pins)
  input  logic [N_GPIO-1:0] iof0_out,
  input  logic [N_GPIO-1:0] iof0_oe,
  input  logic [N_GPIO-1:0] iof1_out,
  input  logic [N_GPIO-1:0] iof1_oe,
  // interrupts, one per pin, level
  output logic [N_GPIO-1:0] irq
);

  logic [N_GPIO-1:0] pin_sync;      // gpio_in, synchronized
  logic [N_GPIO-1:0] in_val;        // pin_sync gated by input_en
  logic [N_GPIO-1:0] in_rise;       // in_val rose this cycle
  logic [N_GPIO-1:0] in_fall;       // in_val fell this cycle
  logic [N_GPIO-1:0] in_low;        // in_val is 0
  logic [31:0]       input_val;     // in_val, register width
  logic [31:0]       rise_set;      // rise_ip set requests
  logic [31:0]       fall_set;      // fall_ip set requests
  logic [31:0]       low_set;       // low_ip set requests
  logic [31:0]       input_en;
  logic [31:0]       output_en;
  logic [31:0]       output_val;
  logic [31:0]       pue;
  logic [31:0]       ds;
  logic [31:0]       rise_ie, rise_ip;
  logic [31:0]       fall_ie, fall_ip;
  logic [31:0]       high_ie, high_ip;
  logic [31:0]       low_ie, low_ip;
  logic [31:0]       iof_en;
  logic [31:0]       iof_sel;
  logic [31:0]       out_xor;
  logic [31:0]       pend;          // ip & ie, OR of the four kinds
  logic [N_GPIO-1:0] fn_out;        // selected IO function output
  logic [N_GPIO-1:0] fn_oe;         // selected IO function output enable
  logic [N_GPIO-1:0] irq_d;         // next irq

  chilimix_gpio_regs u_regs (
    .clk             (clk),
    .rst_n           (rst_n),
    .PSEL            (PSEL),
    .PENABLE         (PENABLE),
    .PWRITE          (PWRITE),
    .PADDR           (PADDR),
    .PWDATA          (PWDATA),
    .PSTRB           (PSTRB),
    .PREADY          (PREADY),
    .PRDATA          (PRDATA),
    .PSLVERR         (PSLVERR),
    .input_val_pin   (input_val),
    .input_en_pin    (input_en),
    .output_en_pin   (output_en),
    .output_val_pin  (output_val),
    .pue_pin         (pue),
    .ds_pin          (ds),
    .rise_ie_pin     (rise_ie),
    .rise_ip_pin     (rise_ip),
    .rise_ip_pin_set (rise_set),
    .fall_ie_pin     (fall_ie),
    .fall_ip_pin     (fall_ip),
    .fall_ip_pin_set (fall_set),
    .high_ie_pin     (high_ie),
    .high_ip_pin     (high_ip),
    .high_ip_pin_set (input_val),
    .low_ie_pin      (low_ie),
    .low_ip_pin      (low_ip),
    .low_ip_pin_set  (low_set),
    .iof_en_pin      (iof_en),
    .iof_sel_pin     (iof_sel),
    .out_xor_pin     (out_xor)
  );

  // ---- inputs and interrupt events
  basechili_sync #(.WIDTH(N_GPIO)) u_sync (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (gpio_in),
    .q     (pin_sync)
  );

  assign in_val = pin_sync & input_en[N_GPIO-1:0];
  assign in_low = ~in_val;

  basechili_edge_detect #(.WIDTH(N_GPIO)) u_edge (
    .clk      (clk),
    .rst_n    (rst_n),
    .in       (in_val),
    .rise     (in_rise),
    .fall     (in_fall),
    .any_edge ()
  );

  // pins at and above N_GPIO read 0 and never set an ip bit
  assign input_val = 32'(in_val);
  assign rise_set  = 32'(in_rise);
  assign fall_set  = 32'(in_fall);
  assign low_set   = 32'(in_low);

  // ---- interrupts
  assign pend  = (rise_ip & rise_ie) | (fall_ip & fall_ie) | (high_ip & high_ie) | (low_ip & low_ie);
  assign irq_d = pend[N_GPIO-1:0];

  basechili_dff #(.WIDTH(N_GPIO)) u_irq (
    .clk   (clk),
    .rst_n (rst_n),
    .d     (irq_d),
    .q     (irq)
  );

  // ---- outputs
  assign fn_out   = (iof_sel[N_GPIO-1:0] & iof1_out) | (~iof_sel[N_GPIO-1:0] & iof0_out);
  assign fn_oe    = (iof_sel[N_GPIO-1:0] & iof1_oe)  | (~iof_sel[N_GPIO-1:0] & iof0_oe);
  assign gpio_out = ((iof_en[N_GPIO-1:0] & fn_out) | (~iof_en[N_GPIO-1:0] & output_val[N_GPIO-1:0]))
                    ^ out_xor[N_GPIO-1:0];
  assign gpio_oe  = (iof_en[N_GPIO-1:0] & fn_oe) | (~iof_en[N_GPIO-1:0] & output_en[N_GPIO-1:0]);
  assign gpio_pue = pue[N_GPIO-1:0];
  assign gpio_ds  = ds[N_GPIO-1:0];

endmodule
