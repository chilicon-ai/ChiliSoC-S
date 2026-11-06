// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: basechili_jtag_tap_chk (bound into every basechili_jtag_tap)
//   - five rising edges of tck with tms high end in Test-Logic-Reset
//                                                            (header Invariant)
//   - at most one of Capture / Shift / Update of IR and DR   (header Invariant)
//   - one cycle in Test-Logic-Reset sets ir to IDCODE_IR     (header Invariant)
//   - tdo_en == in Shift-IR or Shift-DR                      (header Invariant)
//   - IDCODE bit 0 is 1                                      (header)
// Implication-free ("a |=> b" as !past_ok || !$past(a) || b), so the
// properties also run in SymbiYosys.
// -----------------------------------------------------------------------------
module basechili_jtag_tap_chk #(
  parameter int              IR_W      = 5,
  parameter logic [31:0]     IDCODE    = 32'h0000_0001,
  parameter logic [IR_W-1:0] IDCODE_IR = IR_W'(1)
) (
  input logic            tck,
  input logic            rst_n,
  input logic            tms,
  input logic            tlr,
  input logic [IR_W-1:0] ir,
  input logic            capture_dr,
  input logic            shift_dr,
  input logic            update_dr,
  input logic            capture_ir,
  input logic            shift_ir,
  input logic            update_ir,
  input logic            tdo_en
);

  logic       past_ok = 1'b0;   // a previous rising edge exists ($past is defined)
  logic [2:0] tms_hi  = 3'd0;   // rising edges with tms high in a row (saturates at 5)
  always @(posedge tck) begin
    past_ok <= 1'b1;
    tms_hi  <= !rst_n ? 3'd5 : !tms ? 3'd0 : (tms_hi == 3'd5) ? 3'd5 : tms_hi + 3'd1;
  end

  jtag_tap_tms_reset: assert property (@(posedge tck) disable iff (!rst_n)
                   tms_hi != 3'd5 || tlr)
    else $error("basechili_jtag_tap: not in Test-Logic-Reset after five tms-high edges");

  jtag_tap_one_phase: assert property (@(posedge tck) disable iff (!rst_n)
                   $onehot0({capture_dr, shift_dr, update_dr, capture_ir, shift_ir, update_ir}))
    else $error("basechili_jtag_tap: more than one Capture / Shift / Update state");

  jtag_tap_tlr_ir: assert property (@(posedge tck) disable iff (!rst_n)
                   !past_ok || !$past(rst_n) || !$past(tlr) || ir == IDCODE_IR)
    else $error("basechili_jtag_tap: ir is not IDCODE_IR after Test-Logic-Reset");

  jtag_tap_tdo_en: assert property (@(posedge tck) disable iff (!rst_n)
                   tdo_en == (shift_ir || shift_dr))
    else $error("basechili_jtag_tap: tdo_en differs from Shift-IR / Shift-DR");

  jtag_tap_idcode_lsb: assert property (@(posedge tck) IDCODE[0])
    else $error("basechili_jtag_tap: IDCODE bit 0 must be 1");

endmodule

bind basechili_jtag_tap basechili_jtag_tap_chk #(.IR_W(IR_W), .IDCODE(IDCODE), .IDCODE_IR(IDCODE_IR)) u_chk (
  .tck        (tck),
  .rst_n      (rst_n),
  .tms        (tms),
  .tlr        (tlr),
  .ir         (ir),
  .capture_dr (capture_dr),
  .shift_dr   (shift_dr),
  .update_dr  (update_dr),
  .capture_ir (capture_ir),
  .shift_ir   (shift_ir),
  .update_ir  (update_ir),
  .tdo_en     (tdo_en)
);
