// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// ChiliMix :: chilimix_timer
//
// Timers / PWM and a watchdog in SiFive layouts, behind one APB4 port:
//   0x100 * k   PWM k (k < N_PWM), chilimix_timer_pwm (sifive,pwm0): four
//               16-bit comparators, outputs pwm_out[4k +: 4], interrupts
//               pwm_irq[4k +: 4]
//   0x400       watchdog, chilimix_timer_wdog (SiFive AON wdog): interrupt
//               wdog_irq, reset request wdog_rst_req
// Each device occupies 0x40 bytes; the rest of its 0x100 slot, and slots with
// no device, give PSLVERR. Every device is its own devicetree node at its
// offset, so the standard drivers bind to each one.
// halt freezes every counter (connect the hart's debug-mode signal so a halt
// in the debugger neither moves the PWMs nor fires the watchdog).
//
// Timing    : APB reads are combinational (no wait states); see the PWM and
//             watchdog headers for their outputs.
// Debug     : no response or PSLVERR -> u_apb.PSEL_s and PADDR against the
//             map above; device behavior -> g_pwm[k].u_pwm, u_wdog.
// -----------------------------------------------------------------------------
module chilimix_timer #(
  parameter  int N_PWM = 3,                 // PWM devices, 1 .. 4
  localparam int N_DEV = N_PWM + 1          // PWMs and the watchdog
) (
  input  logic               clk,
  input  logic               rst_n,         // async, active-low
  // APB4 subordinate (registers)
  input  logic               PSEL,
  input  logic               PENABLE,
  input  logic               PWRITE,
  input  logic [10:0]        PADDR,         // byte address inside the timer
  input  logic [31:0]        PWDATA,
  input  logic [3:0]         PSTRB,
  output logic               PREADY,
  output logic [31:0]        PRDATA,
  output logic               PSLVERR,
  // control
  input  logic               tick,          // watchdog count rate
  input  logic               halt,          // freeze every counter (debug)
  input  logic               core_sleep,    // the core is asleep or in reset
  // PWM outputs and interrupts, four per PWM device
  output logic [4*N_PWM-1:0] pwm_out,
  output logic [4*N_PWM-1:0] pwm_irq,
  // watchdog
  output logic               wdog_irq,
  output logic               wdog_rst_req   // to chilimix_socctl rst_req
);

  localparam logic [10:0] DEV_MASK  = 11'h7C0;   // 0x40-byte device windows
  localparam logic [10:0] WDOG_BASE = 11'h400;

  // device d at 0x100 * d (PWMs), the watchdog last at WDOG_BASE
  function automatic logic [N_DEV*11-1:0] dev_base();
    logic [N_DEV*11-1:0] b;
    b = '0;
    for (int d = 0; d < N_PWM; d++) b[d*11 +: 11] = 11'(unsigned'(d) * 32'h100);
    b[N_PWM*11 +: 11] = WDOG_BASE;
    return b;
  endfunction

  localparam logic [N_DEV*11-1:0] BASE = dev_base();
  localparam logic [N_DEV*11-1:0] MASK = {N_DEV{DEV_MASK}};

  logic [N_DEV-1:0]    psel_s;
  logic [N_DEV-1:0]    pready_s;
  logic [N_DEV*32-1:0] prdata_s;
  logic [N_DEV-1:0]    pslverr_s;
  logic [5:0]          dev_addr;   // byte address inside a device

  basechili_apb_interconnect #(
    .ADDR_W (11),
    .DATA_W (32),
    .N      (N_DEV),
    .BASE   (BASE),
    .MASK   (MASK)
  ) u_apb (
    .PSEL      (PSEL),
    .PADDR     (PADDR),
    .PREADY    (PREADY),
    .PRDATA    (PRDATA),
    .PSLVERR   (PSLVERR),
    .PSEL_s    (psel_s),
    .PREADY_s  (pready_s),
    .PRDATA_s  (prdata_s),
    .PSLVERR_s (pslverr_s)
  );

  assign dev_addr = PADDR[5:0];

  for (genvar k = 0; k < N_PWM; k++) begin : g_pwm
    chilimix_timer_pwm u_pwm (
      .clk     (clk),
      .rst_n   (rst_n),
      .PSEL    (psel_s[k]),
      .PENABLE (PENABLE),
      .PWRITE  (PWRITE),
      .PADDR   (dev_addr),
      .PWDATA  (PWDATA),
      .PSTRB   (PSTRB),
      .PREADY  (pready_s[k]),
      .PRDATA  (prdata_s[k*32 +: 32]),
      .PSLVERR (pslverr_s[k]),
      .halt    (halt),
      .out     (pwm_out[k*4 +: 4]),
      .irq     (pwm_irq[k*4 +: 4])
    );
  end

  chilimix_timer_wdog u_wdog (
    .clk        (clk),
    .rst_n      (rst_n),
    .PSEL       (psel_s[N_PWM]),
    .PENABLE    (PENABLE),
    .PWRITE     (PWRITE),
    .PADDR      (dev_addr),
    .PWDATA     (PWDATA),
    .PSTRB      (PSTRB),
    .PREADY     (pready_s[N_PWM]),
    .PRDATA     (prdata_s[N_PWM*32 +: 32]),
    .PSLVERR    (pslverr_s[N_PWM]),
    .tick       (tick),
    .halt       (halt),
    .core_sleep (core_sleep),
    .irq        (wdog_irq),
    .rst_req    (wdog_rst_req)
  );

endmodule
