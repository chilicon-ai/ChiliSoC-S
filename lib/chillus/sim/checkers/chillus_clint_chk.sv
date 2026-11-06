// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Chilicon
// -----------------------------------------------------------------------------
// sim checker :: chillus_clint_chk (bound into chillus_clint; the testbench's
// platform CLINT)
//   - irq_timer == (mtime >= mtimecmp) every cycle         (header Invariants)
//   - mtime changes only by +1 (tick, no write) or by a write to 0xBFF8 /
//     0xBFFC (then exactly the written value)              (header Invariants)
//   - irq_software == msip; msip / mtimecmp change only on their writes
//   - a read loads ack_rdata with the addressed register's value before the
//     edge; ack_rdata holds otherwise                       (header)
// -----------------------------------------------------------------------------
module chillus_clint_chk #(
  parameter int XLEN = 32
) (
  input logic            clk,
  input logic            rst_n,
  input logic            tick,
  input logic [63:0]     mtime,
  input logic [63:0]     mtimecmp,
  input logic            mtime_ld,
  input logic [63:0]     mtime_ld_val,
  input logic            msip,
  input logic            msip_en,
  input logic            mtimecmp_lo_en,
  input logic            mtimecmp_hi_en,
  input logic            irq_timer,
  input logic            irq_software,
  input logic            rd_en,
  input logic [XLEN-1:0] rword,
  input logic [XLEN-1:0] ack_rdata
);

  `define CHK(prop, msg) assert property (@(posedge clk) disable iff (!rst_n) prop) else $error msg;

  `CHK(irq_timer == (mtime >= mtimecmp),
       ("chillus_clint: irq_timer == (mtime >= mtimecmp) violated: irq_timer=%b mtime=%h mtimecmp=%h",
        irq_timer, mtime, mtimecmp))
  `CHK(!mtime_ld && tick |=> mtime == $past(mtime) + 64'd1,
       ("chillus_clint: mtime +1 on tick violated: mtime=%h before=%h", mtime, $past(mtime)))
  `CHK(!mtime_ld && !tick |=> $stable(mtime),
       ("chillus_clint: mtime changed without tick / write: mtime=%h before=%h", mtime, $past(mtime)))
  `CHK(mtime_ld |=> mtime == $past(mtime_ld_val),
       ("chillus_clint: mtime after a write != written value: mtime=%h expected=%h", mtime, $past(mtime_ld_val)))
  `CHK(irq_software == msip,
       ("chillus_clint: irq_software == msip violated"))
  `CHK(!msip_en |=> $stable(msip),
       ("chillus_clint: msip changed without a write"))
  `CHK(!mtimecmp_lo_en && !mtimecmp_hi_en |=> $stable(mtimecmp),
       ("chillus_clint: mtimecmp changed without a write: mtimecmp=%h before=%h", mtimecmp, $past(mtimecmp)))
  `CHK(rd_en |=> ack_rdata == $past(rword),
       ("chillus_clint: ack_rdata != register value before the read edge: ack_rdata=%h expected=%h",
        ack_rdata, $past(rword)))
  `CHK(!rd_en |=> $stable(ack_rdata),
       ("chillus_clint: ack_rdata changed without a read"))

  `undef CHK

endmodule

bind chillus_clint chillus_clint_chk #(.XLEN(XLEN)) u_chk (
  .clk            (clk),
  .rst_n          (rst_n),
  .tick           (tick),
  .mtime          (mtime),
  .mtimecmp       (mtimecmp),
  .mtime_ld       (mtime_ld),
  .mtime_ld_val   (mtime_ld_val),
  .msip           (msip),
  .msip_en        (msip_en),
  .mtimecmp_lo_en (mtimecmp_lo_en),
  .mtimecmp_hi_en (mtimecmp_hi_en),
  .irq_timer      (irq_timer),
  .irq_software   (irq_software),
  .rd_en          (rd_en),
  .rword          (rword),
  .ack_rdata      (ack_rdata)
);
