// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// Testbench :: chilimix_gpio -- random APB transfers, pin and IO function
// activity against a cycle model of the SiFive GPIO registers, the input
// synchronizer, the interrupt pending bits and the pad outputs.
//
// Stimulus: APB transfers (SETUP then ACCESS) to every register and to the
// unused words past out_xor, random PSTRB and idle cycles; register writes
// biased towards all-ones / all-zeros so pins sit enabled for long runs;
// gpio_in changing on a few pins at a time (edges and held levels); random
// IO function inputs.
// Checked every cycle: PREADY high; in ACCESS, PSLVERR exactly past out_xor
// and the read data; gpio_out / gpio_oe / gpio_pue / gpio_ds from the model
// registers and the iof inputs; after each edge irq (registered OR of
// ip & ie), with the ip bits set by edges / levels of the synchronized,
// input_en-gated pins (a set wins over a write-1 clear).
`include "tb_common.svh"
module chilimix_gpio_tb #(
  parameter int N_GPIO = 32
);
  localparam int N_CYC = 40000;
  localparam int N_REG = 17;               // words 0x00 .. 0x40
  localparam logic [31:0] PINS = 32'((64'd1 << N_GPIO) - 1);

  `TB_CLOCK_RESET

  logic              PSEL, PENABLE, PWRITE, PREADY, PSLVERR;
  logic [6:0]        PADDR;
  logic [31:0]       PWDATA, PRDATA;
  logic [3:0]        PSTRB;
  logic [N_GPIO-1:0] gpio_in, gpio_out, gpio_oe, gpio_pue, gpio_ds;
  logic [N_GPIO-1:0] iof0_out, iof0_oe, iof1_out, iof1_oe, irq;

  chilimix_gpio #(.N_GPIO(N_GPIO)) dut (.*);

  // register word indices
  localparam int R_IN_VAL = 0, R_IN_EN = 1, R_OUT_EN = 2, R_OUT_VAL = 3, R_PUE = 4, R_DS = 5,
                 R_RISE_IE = 6, R_RISE_IP = 7, R_FALL_IE = 8, R_FALL_IP = 9,
                 R_HIGH_IE = 10, R_HIGH_IP = 11, R_LOW_IE = 12, R_LOW_IP = 13,
                 R_IOF_EN = 14, R_IOF_SEL = 15, R_OUT_XOR = 16;

  logic [31:0] m_reg [N_REG];       // model registers (input_val unused: computed)
  logic [31:0] s1, s2;              // model synchronizer stages
  logic [31:0] prev;                // model in_val, one cycle ago
  logic [31:0] m_irq;
  logic [31:0] in_val, nxt_irq, set_rise, set_fall, set_high, set_low, clr, wmask;
  logic [31:0] exp_rd, fn_out, fn_oe, exp_out, exp_oe;
  bit          exp_err, is_ip;
  int          phase, w;
  int          n_irq_rise;          // irq rising edges seen (coverage sanity)

  function automatic logic [31:0] strb_mask(logic [3:0] s);
    return {{8{s[3]}}, {8{s[2]}}, {8{s[1]}}, {8{s[0]}}};
  endfunction

  function automatic logic [31:0] pick_wdata();
    case ($urandom % 5)
      0: return '1;
      1: return '0;
      default: return $urandom;
    endcase
  endfunction

  initial begin
    PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = '0; PWDATA = '0; PSTRB = '0;
    gpio_in = '0; iof0_out = '0; iof0_oe = '0; iof1_out = '0; iof1_oe = '0;
    for (int i = 0; i < N_REG; i++) m_reg[i] = '0;
    s1 = '0; s2 = '0; prev = '0; m_irq = '0; n_irq_rise = 0;
    tb_reset();
    `CHECK(irq == '0 && gpio_oe == '0 && gpio_out == '0, "reset values")
    phase = 0;
    for (int cyc = 0; cyc < N_CYC; cyc++) begin
      // drive after the falling edge
      if ($urandom % 4 == 0) gpio_in = gpio_in ^ N_GPIO'(1 << ($urandom % N_GPIO));
      if ($urandom % 64 == 0) gpio_in = N_GPIO'({$urandom, $urandom});
      if ($urandom % 8 == 0) begin
        iof0_out = N_GPIO'($urandom); iof0_oe = N_GPIO'($urandom);
        iof1_out = N_GPIO'($urandom); iof1_oe = N_GPIO'($urandom);
      end
      if (phase == 2) begin PSEL = 0; PENABLE = 0; phase = 0; end
      else if (phase == 1) begin PENABLE = 1; phase = 2; end
      else if ($urandom % 3 != 0) begin
        PSEL = 1; PENABLE = 0; phase = 1;
        PWRITE = $urandom % 2;
        w = ($urandom % 10 == 0) ? N_REG + $urandom % (32 - N_REG) : $urandom % N_REG;
        PADDR = 7'(w * 4 + $urandom % 4);
        PWDATA = pick_wdata();
        PSTRB = ($urandom % 3 != 0) ? 4'hf : 4'($urandom);
      end else begin
        PWRITE = $urandom % 2; PADDR = 7'($urandom); PWDATA = $urandom; PSTRB = 4'($urandom);
      end
      #1;
      // model view of this cycle
      in_val = s2 & m_reg[R_IN_EN] & PINS;
      w = int'(PADDR[6:2]);
      exp_err = w >= N_REG;
      exp_rd = (w == R_IN_VAL) ? in_val : (w < N_REG) ? m_reg[w] : '0;
      fn_out = (m_reg[R_IOF_SEL] & 32'(iof1_out)) | (~m_reg[R_IOF_SEL] & 32'(iof0_out));
      fn_oe  = (m_reg[R_IOF_SEL] & 32'(iof1_oe))  | (~m_reg[R_IOF_SEL] & 32'(iof0_oe));
      exp_out = ((m_reg[R_IOF_EN] & fn_out) | (~m_reg[R_IOF_EN] & m_reg[R_OUT_VAL])) ^ m_reg[R_OUT_XOR];
      exp_oe  = (m_reg[R_IOF_EN] & fn_oe) | (~m_reg[R_IOF_EN] & m_reg[R_OUT_EN]);
      `CHECK(PREADY, "PREADY high")
      if (phase == 2) begin
        `CHECK(PSLVERR == exp_err, "PSLVERR")
        if (!PWRITE && !exp_err) `CHECK(PRDATA == exp_rd, "read data")
      end
      `CHECK(gpio_out == N_GPIO'(exp_out), "gpio_out")
      `CHECK(gpio_oe == N_GPIO'(exp_oe), "gpio_oe")
      `CHECK(gpio_pue == N_GPIO'(m_reg[R_PUE]), "gpio_pue")
      `CHECK(gpio_ds == N_GPIO'(m_reg[R_DS]), "gpio_ds")
      // next state (values from before the edge)
      nxt_irq = ((m_reg[R_RISE_IP] & m_reg[R_RISE_IE]) | (m_reg[R_FALL_IP] & m_reg[R_FALL_IE]) |
                 (m_reg[R_HIGH_IP] & m_reg[R_HIGH_IE]) | (m_reg[R_LOW_IP] & m_reg[R_LOW_IE])) & PINS;
      set_rise = in_val & ~prev;
      set_fall = ~in_val & prev;
      set_high = in_val;
      set_low  = ~in_val & PINS;
      @(posedge clk);
      if (|(nxt_irq & ~m_irq)) n_irq_rise++;
      m_irq = nxt_irq;
      prev = in_val;
      s2 = s1; s1 = 32'(gpio_in);
      if (phase == 2 && PWRITE && !exp_err) begin
        wmask = strb_mask(PSTRB);
        is_ip = w == R_RISE_IP || w == R_FALL_IP || w == R_HIGH_IP || w == R_LOW_IP;
        if (is_ip) clr = PWDATA & wmask;
        else if (w != R_IN_VAL) m_reg[w] = (m_reg[w] & ~wmask) | (PWDATA & wmask);
      end
      if (!(phase == 2 && PWRITE && !exp_err && is_ip)) clr = '0;
      m_reg[R_RISE_IP] = (m_reg[R_RISE_IP] & ~(w == R_RISE_IP ? clr : '0)) | set_rise;
      m_reg[R_FALL_IP] = (m_reg[R_FALL_IP] & ~(w == R_FALL_IP ? clr : '0)) | set_fall;
      m_reg[R_HIGH_IP] = (m_reg[R_HIGH_IP] & ~(w == R_HIGH_IP ? clr : '0)) | set_high;
      m_reg[R_LOW_IP]  = (m_reg[R_LOW_IP]  & ~(w == R_LOW_IP  ? clr : '0)) | set_low;
      @(negedge clk);
      `CHECK(irq == N_GPIO'(m_irq), "irq")
    end
    `CHECK(n_irq_rise > 20, "irq rarely raised")
    $display("irq raised %0d times", n_irq_rise);
    tb_pass();
  end
endmodule
