// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// ChiliMix :: chilimix_plic_regs
//
// RISC-V PLIC for 63 level-triggered sources and up to 16 contexts (hart h: M-mode 2h, S-mode 2h+1) register block: an APB4 subordinate (22-bit PADDR, 32-bit data).
// Register layout compatible with sifive,plic-1.0.0 (riscv,plic0).
// Built on basechili_apb_regbank (4 bank(s)), blocks selected by basechili_apb_interconnect.
//
// Register map (byte offsets; access per field: rw, ro = driven by the IP,
// w1c = set by the IP, write 1 to clear):
//   block prio at 0x0, 0x100 bytes
//   0x0004 + 0x4*i  priority[63] value[2:0] rw
//   block pend at 0x1000, 0x8 bytes
//   0x1000  pending0     src[31:1] ro
//   0x1004  pending1     src[31:0] ro
//   block en at 0x2000, 0x800 bytes
//   0x2000 + 0x80*i  enable0[16]  src[31:1] rw  (i < N_CTX present)
//   0x2004 + 0x80*i  enable1[16]  src[31:0] rw  (i < N_CTX present)
//   block context at 0x200000, 0x10000 bytes
//   0x200000 + 0x1000*i  threshold[16] value[2:0] rw  (i < N_CTX present)
//   0x200004 + 0x1000*i  claim[16]    id[5:0] ro  (i < N_CTX present)
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
module chilimix_plic_regs #(
  parameter int N_CTX = 1  // contexts present (1 .. 16)
) (
  input  logic clk,
  input  logic rst_n,                   // async, active-low
  input  logic PSEL,                    // APB4 subordinate
  input  logic PENABLE,
  input  logic PWRITE,
  input  logic [21:0] PADDR,            // byte address inside the IP
  input  logic [31:0] PWDATA,
  input  logic [3:0] PSTRB,
  output logic PREADY,
  output logic [31:0] PRDATA,
  output logic PSLVERR,
  output logic [188:0] priority_value,  // rw: Priority: 1 lowest, 7 highest x63
  input  logic [30:0] pending0_src,     // ro: Source i is pending (gateway forwarded, not yet claimed)
  input  logic [31:0] pending1_src,     // ro: Source 32+j is pending (gateway forwarded, not yet claimed)
  output logic [495:0] enable0_src,     // rw: Source j may interrupt context i x16
  output logic [511:0] enable1_src,     // rw: Source 32+j may interrupt context i x16
  output logic [47:0] threshold_value,  // rw: Only priorities above it interrupt x16
  input  logic [95:0] claim_id,         // ro: Read: claims and returns the highest-priority pending source enabled for the context (0: none) x16
  output logic [15:0] claim_rd,         // claim read this cycle (APB ACCESS)
  output logic [15:0] claim_wr          // claim write this cycle (APB ACCESS)
);

  localparam logic [87:0] BLOCK_BASE = 88'h80_0000_0200_0004_0000_0000;
  localparam logic [87:0] BLOCK_MASK = 88'hfc_0003_ff80_0fff_fe3f_ff00;
  logic [3:0]      apb_psel_s;      // PSEL of each block
  logic [3:0]      apb_pready_s;
  logic [127:0] apb_prdata_s;
  logic [3:0]      apb_pslverr_s;

  basechili_apb_interconnect #(
    .ADDR_W (22),
    .DATA_W (32),
    .N      (4),
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

  // ---- block prio: 64 word(s) at 0x0
  localparam int                N_PRIO = 64;
  localparam logic [2047:0] RESET_PRIO = 2048'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  localparam logic [2047:0] RW_PRIO = 2048'h0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0007_0000_0000;
  localparam logic [2047:0] W1C_PRIO = 2048'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
  logic [2047:0] prio_reg_q;    // rw and w1c bit values
  logic [2047:0] prio_hw_rd;    // read-only bit values
  logic [2047:0] prio_hw_set;   // w1c set requests
  logic [7:0] prio_paddr;    // address inside the block

  assign prio_hw_rd[31:0] = '0;  // (no register)
  assign prio_hw_set[31:0] = '0;
  assign prio_hw_rd[63:32] = '0;  // priority[0]
  assign prio_hw_set[63:32] = '0;
  assign prio_hw_rd[95:64] = '0;  // priority[1]
  assign prio_hw_set[95:64] = '0;
  assign prio_hw_rd[127:96] = '0;  // priority[2]
  assign prio_hw_set[127:96] = '0;
  assign prio_hw_rd[159:128] = '0;  // priority[3]
  assign prio_hw_set[159:128] = '0;
  assign prio_hw_rd[191:160] = '0;  // priority[4]
  assign prio_hw_set[191:160] = '0;
  assign prio_hw_rd[223:192] = '0;  // priority[5]
  assign prio_hw_set[223:192] = '0;
  assign prio_hw_rd[255:224] = '0;  // priority[6]
  assign prio_hw_set[255:224] = '0;
  assign prio_hw_rd[287:256] = '0;  // priority[7]
  assign prio_hw_set[287:256] = '0;
  assign prio_hw_rd[319:288] = '0;  // priority[8]
  assign prio_hw_set[319:288] = '0;
  assign prio_hw_rd[351:320] = '0;  // priority[9]
  assign prio_hw_set[351:320] = '0;
  assign prio_hw_rd[383:352] = '0;  // priority[10]
  assign prio_hw_set[383:352] = '0;
  assign prio_hw_rd[415:384] = '0;  // priority[11]
  assign prio_hw_set[415:384] = '0;
  assign prio_hw_rd[447:416] = '0;  // priority[12]
  assign prio_hw_set[447:416] = '0;
  assign prio_hw_rd[479:448] = '0;  // priority[13]
  assign prio_hw_set[479:448] = '0;
  assign prio_hw_rd[511:480] = '0;  // priority[14]
  assign prio_hw_set[511:480] = '0;
  assign prio_hw_rd[543:512] = '0;  // priority[15]
  assign prio_hw_set[543:512] = '0;
  assign prio_hw_rd[575:544] = '0;  // priority[16]
  assign prio_hw_set[575:544] = '0;
  assign prio_hw_rd[607:576] = '0;  // priority[17]
  assign prio_hw_set[607:576] = '0;
  assign prio_hw_rd[639:608] = '0;  // priority[18]
  assign prio_hw_set[639:608] = '0;
  assign prio_hw_rd[671:640] = '0;  // priority[19]
  assign prio_hw_set[671:640] = '0;
  assign prio_hw_rd[703:672] = '0;  // priority[20]
  assign prio_hw_set[703:672] = '0;
  assign prio_hw_rd[735:704] = '0;  // priority[21]
  assign prio_hw_set[735:704] = '0;
  assign prio_hw_rd[767:736] = '0;  // priority[22]
  assign prio_hw_set[767:736] = '0;
  assign prio_hw_rd[799:768] = '0;  // priority[23]
  assign prio_hw_set[799:768] = '0;
  assign prio_hw_rd[831:800] = '0;  // priority[24]
  assign prio_hw_set[831:800] = '0;
  assign prio_hw_rd[863:832] = '0;  // priority[25]
  assign prio_hw_set[863:832] = '0;
  assign prio_hw_rd[895:864] = '0;  // priority[26]
  assign prio_hw_set[895:864] = '0;
  assign prio_hw_rd[927:896] = '0;  // priority[27]
  assign prio_hw_set[927:896] = '0;
  assign prio_hw_rd[959:928] = '0;  // priority[28]
  assign prio_hw_set[959:928] = '0;
  assign prio_hw_rd[991:960] = '0;  // priority[29]
  assign prio_hw_set[991:960] = '0;
  assign prio_hw_rd[1023:992] = '0;  // priority[30]
  assign prio_hw_set[1023:992] = '0;
  assign prio_hw_rd[1055:1024] = '0;  // priority[31]
  assign prio_hw_set[1055:1024] = '0;
  assign prio_hw_rd[1087:1056] = '0;  // priority[32]
  assign prio_hw_set[1087:1056] = '0;
  assign prio_hw_rd[1119:1088] = '0;  // priority[33]
  assign prio_hw_set[1119:1088] = '0;
  assign prio_hw_rd[1151:1120] = '0;  // priority[34]
  assign prio_hw_set[1151:1120] = '0;
  assign prio_hw_rd[1183:1152] = '0;  // priority[35]
  assign prio_hw_set[1183:1152] = '0;
  assign prio_hw_rd[1215:1184] = '0;  // priority[36]
  assign prio_hw_set[1215:1184] = '0;
  assign prio_hw_rd[1247:1216] = '0;  // priority[37]
  assign prio_hw_set[1247:1216] = '0;
  assign prio_hw_rd[1279:1248] = '0;  // priority[38]
  assign prio_hw_set[1279:1248] = '0;
  assign prio_hw_rd[1311:1280] = '0;  // priority[39]
  assign prio_hw_set[1311:1280] = '0;
  assign prio_hw_rd[1343:1312] = '0;  // priority[40]
  assign prio_hw_set[1343:1312] = '0;
  assign prio_hw_rd[1375:1344] = '0;  // priority[41]
  assign prio_hw_set[1375:1344] = '0;
  assign prio_hw_rd[1407:1376] = '0;  // priority[42]
  assign prio_hw_set[1407:1376] = '0;
  assign prio_hw_rd[1439:1408] = '0;  // priority[43]
  assign prio_hw_set[1439:1408] = '0;
  assign prio_hw_rd[1471:1440] = '0;  // priority[44]
  assign prio_hw_set[1471:1440] = '0;
  assign prio_hw_rd[1503:1472] = '0;  // priority[45]
  assign prio_hw_set[1503:1472] = '0;
  assign prio_hw_rd[1535:1504] = '0;  // priority[46]
  assign prio_hw_set[1535:1504] = '0;
  assign prio_hw_rd[1567:1536] = '0;  // priority[47]
  assign prio_hw_set[1567:1536] = '0;
  assign prio_hw_rd[1599:1568] = '0;  // priority[48]
  assign prio_hw_set[1599:1568] = '0;
  assign prio_hw_rd[1631:1600] = '0;  // priority[49]
  assign prio_hw_set[1631:1600] = '0;
  assign prio_hw_rd[1663:1632] = '0;  // priority[50]
  assign prio_hw_set[1663:1632] = '0;
  assign prio_hw_rd[1695:1664] = '0;  // priority[51]
  assign prio_hw_set[1695:1664] = '0;
  assign prio_hw_rd[1727:1696] = '0;  // priority[52]
  assign prio_hw_set[1727:1696] = '0;
  assign prio_hw_rd[1759:1728] = '0;  // priority[53]
  assign prio_hw_set[1759:1728] = '0;
  assign prio_hw_rd[1791:1760] = '0;  // priority[54]
  assign prio_hw_set[1791:1760] = '0;
  assign prio_hw_rd[1823:1792] = '0;  // priority[55]
  assign prio_hw_set[1823:1792] = '0;
  assign prio_hw_rd[1855:1824] = '0;  // priority[56]
  assign prio_hw_set[1855:1824] = '0;
  assign prio_hw_rd[1887:1856] = '0;  // priority[57]
  assign prio_hw_set[1887:1856] = '0;
  assign prio_hw_rd[1919:1888] = '0;  // priority[58]
  assign prio_hw_set[1919:1888] = '0;
  assign prio_hw_rd[1951:1920] = '0;  // priority[59]
  assign prio_hw_set[1951:1920] = '0;
  assign prio_hw_rd[1983:1952] = '0;  // priority[60]
  assign prio_hw_set[1983:1952] = '0;
  assign prio_hw_rd[2015:1984] = '0;  // priority[61]
  assign prio_hw_set[2015:1984] = '0;
  assign prio_hw_rd[2047:2016] = '0;  // priority[62]
  assign prio_hw_set[2047:2016] = '0;
  assign prio_paddr = PADDR[7:0];
  assign priority_value[2:0] = prio_reg_q[34:32];
  assign priority_value[5:3] = prio_reg_q[66:64];
  assign priority_value[8:6] = prio_reg_q[98:96];
  assign priority_value[11:9] = prio_reg_q[130:128];
  assign priority_value[14:12] = prio_reg_q[162:160];
  assign priority_value[17:15] = prio_reg_q[194:192];
  assign priority_value[20:18] = prio_reg_q[226:224];
  assign priority_value[23:21] = prio_reg_q[258:256];
  assign priority_value[26:24] = prio_reg_q[290:288];
  assign priority_value[29:27] = prio_reg_q[322:320];
  assign priority_value[32:30] = prio_reg_q[354:352];
  assign priority_value[35:33] = prio_reg_q[386:384];
  assign priority_value[38:36] = prio_reg_q[418:416];
  assign priority_value[41:39] = prio_reg_q[450:448];
  assign priority_value[44:42] = prio_reg_q[482:480];
  assign priority_value[47:45] = prio_reg_q[514:512];
  assign priority_value[50:48] = prio_reg_q[546:544];
  assign priority_value[53:51] = prio_reg_q[578:576];
  assign priority_value[56:54] = prio_reg_q[610:608];
  assign priority_value[59:57] = prio_reg_q[642:640];
  assign priority_value[62:60] = prio_reg_q[674:672];
  assign priority_value[65:63] = prio_reg_q[706:704];
  assign priority_value[68:66] = prio_reg_q[738:736];
  assign priority_value[71:69] = prio_reg_q[770:768];
  assign priority_value[74:72] = prio_reg_q[802:800];
  assign priority_value[77:75] = prio_reg_q[834:832];
  assign priority_value[80:78] = prio_reg_q[866:864];
  assign priority_value[83:81] = prio_reg_q[898:896];
  assign priority_value[86:84] = prio_reg_q[930:928];
  assign priority_value[89:87] = prio_reg_q[962:960];
  assign priority_value[92:90] = prio_reg_q[994:992];
  assign priority_value[95:93] = prio_reg_q[1026:1024];
  assign priority_value[98:96] = prio_reg_q[1058:1056];
  assign priority_value[101:99] = prio_reg_q[1090:1088];
  assign priority_value[104:102] = prio_reg_q[1122:1120];
  assign priority_value[107:105] = prio_reg_q[1154:1152];
  assign priority_value[110:108] = prio_reg_q[1186:1184];
  assign priority_value[113:111] = prio_reg_q[1218:1216];
  assign priority_value[116:114] = prio_reg_q[1250:1248];
  assign priority_value[119:117] = prio_reg_q[1282:1280];
  assign priority_value[122:120] = prio_reg_q[1314:1312];
  assign priority_value[125:123] = prio_reg_q[1346:1344];
  assign priority_value[128:126] = prio_reg_q[1378:1376];
  assign priority_value[131:129] = prio_reg_q[1410:1408];
  assign priority_value[134:132] = prio_reg_q[1442:1440];
  assign priority_value[137:135] = prio_reg_q[1474:1472];
  assign priority_value[140:138] = prio_reg_q[1506:1504];
  assign priority_value[143:141] = prio_reg_q[1538:1536];
  assign priority_value[146:144] = prio_reg_q[1570:1568];
  assign priority_value[149:147] = prio_reg_q[1602:1600];
  assign priority_value[152:150] = prio_reg_q[1634:1632];
  assign priority_value[155:153] = prio_reg_q[1666:1664];
  assign priority_value[158:156] = prio_reg_q[1698:1696];
  assign priority_value[161:159] = prio_reg_q[1730:1728];
  assign priority_value[164:162] = prio_reg_q[1762:1760];
  assign priority_value[167:165] = prio_reg_q[1794:1792];
  assign priority_value[170:168] = prio_reg_q[1826:1824];
  assign priority_value[173:171] = prio_reg_q[1858:1856];
  assign priority_value[176:174] = prio_reg_q[1890:1888];
  assign priority_value[179:177] = prio_reg_q[1922:1920];
  assign priority_value[182:180] = prio_reg_q[1954:1952];
  assign priority_value[185:183] = prio_reg_q[1986:1984];
  assign priority_value[188:186] = prio_reg_q[2018:2016];

  basechili_apb_regbank #(
    .ADDR_W   (8),
    .DATA_W   (32),
    .N        (N_PRIO),
    .RESET    (RESET_PRIO),
    .RW_MASK  (RW_PRIO),
    .W1C_MASK (W1C_PRIO)
  ) u_prio (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[0]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (prio_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[0]),
    .PRDATA   (apb_prdata_s[31:0]),
    .PSLVERR  (apb_pslverr_s[0]),
    .reg_q    (prio_reg_q),
    .hw_rd    (prio_hw_rd),
    .hw_set   (prio_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

  // ---- block pend: 2 word(s) at 0x1000
  localparam int                N_PEND = 2;
  localparam logic [63:0] RESET_PEND = 64'h0000_0000_0000_0000;
  localparam logic [63:0] RW_PEND = 64'h0000_0000_0000_0000;
  localparam logic [63:0] W1C_PEND = 64'h0000_0000_0000_0000;
  logic [63:0] pend_hw_rd;    // read-only bit values
  logic [63:0] pend_hw_set;   // w1c set requests
  logic [2:0] pend_paddr;    // address inside the block

  assign pend_hw_rd[31:0] = {pending0_src, 1'b0};  // pending0
  assign pend_hw_set[31:0] = '0;
  assign pend_hw_rd[63:32] = pending1_src;  // pending1
  assign pend_hw_set[63:32] = '0;
  assign pend_paddr = PADDR[2:0];

  basechili_apb_regbank #(
    .ADDR_W   (3),
    .DATA_W   (32),
    .N        (N_PEND),
    .RESET    (RESET_PEND),
    .RW_MASK  (RW_PEND),
    .W1C_MASK (W1C_PEND)
  ) u_pend (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[1]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (pend_paddr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[1]),
    .PRDATA   (apb_prdata_s[63:32]),
    .PSLVERR  (apb_pslverr_s[1]),
    .reg_q    (),
    .hw_rd    (pend_hw_rd),
    .hw_set   (pend_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

  // ---- block en: 33 word(s) at 0x2000 (one per register, one empty: the block is sparse)
  localparam int                N_EN = 33;
  // words of the array elements present (N_CTX)
  localparam logic [1055:0] ACT_EN = {{32{1'b1}}, {32{N_CTX > 15}}, {32{N_CTX > 15}}, {32{N_CTX > 14}}, {32{N_CTX > 14}}, {32{N_CTX > 13}}, {32{N_CTX > 13}}, {32{N_CTX > 12}}, {32{N_CTX > 12}}, {32{N_CTX > 11}}, {32{N_CTX > 11}}, {32{N_CTX > 10}}, {32{N_CTX > 10}}, {32{N_CTX > 9}}, {32{N_CTX > 9}}, {32{N_CTX > 8}}, {32{N_CTX > 8}}, {32{N_CTX > 7}}, {32{N_CTX > 7}}, {32{N_CTX > 6}}, {32{N_CTX > 6}}, {32{N_CTX > 5}}, {32{N_CTX > 5}}, {32{N_CTX > 4}}, {32{N_CTX > 4}}, {32{N_CTX > 3}}, {32{N_CTX > 3}}, {32{N_CTX > 2}}, {32{N_CTX > 2}}, {32{N_CTX > 1}}, {32{N_CTX > 1}}, {32{N_CTX > 0}}, {32{N_CTX > 0}}};
  localparam logic [1055:0] RESET_EN = 1056'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_EN;
  localparam logic [1055:0] RW_EN = 1056'h0000_0000_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe_ffff_ffff_ffff_fffe & ACT_EN;
  localparam logic [1055:0] W1C_EN = 1056'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_EN;
  logic [1055:0] en_reg_q;    // rw and w1c bit values
  logic [1055:0] en_hw_rd;    // read-only bit values
  logic [1055:0] en_hw_set;   // w1c set requests

  logic [8:0] en_word;     // word address inside the block
  logic [5:0] en_slot;     // regbank word of the register selected there
  logic [7:0] en_rb_addr;  // regbank PADDR

  assign en_word = PADDR[10:2];
  assign en_rb_addr = {en_slot, PADDR[1:0]};

  // shared offsets: the register an access selects (by direction and bank field)
  always_comb begin
    en_slot = 6'd33;  // past the last register: PSLVERR
    case (en_word)
      9'd0: en_slot = 6'd0;  // enable0[0]
      9'd1: en_slot = 6'd1;  // enable1[0]
      9'd32: en_slot = 6'd2;  // enable0[1]
      9'd33: en_slot = 6'd3;  // enable1[1]
      9'd64: en_slot = 6'd4;  // enable0[2]
      9'd65: en_slot = 6'd5;  // enable1[2]
      9'd96: en_slot = 6'd6;  // enable0[3]
      9'd97: en_slot = 6'd7;  // enable1[3]
      9'd128: en_slot = 6'd8;  // enable0[4]
      9'd129: en_slot = 6'd9;  // enable1[4]
      9'd160: en_slot = 6'd10;  // enable0[5]
      9'd161: en_slot = 6'd11;  // enable1[5]
      9'd192: en_slot = 6'd12;  // enable0[6]
      9'd193: en_slot = 6'd13;  // enable1[6]
      9'd224: en_slot = 6'd14;  // enable0[7]
      9'd225: en_slot = 6'd15;  // enable1[7]
      9'd256: en_slot = 6'd16;  // enable0[8]
      9'd257: en_slot = 6'd17;  // enable1[8]
      9'd288: en_slot = 6'd18;  // enable0[9]
      9'd289: en_slot = 6'd19;  // enable1[9]
      9'd320: en_slot = 6'd20;  // enable0[10]
      9'd321: en_slot = 6'd21;  // enable1[10]
      9'd352: en_slot = 6'd22;  // enable0[11]
      9'd353: en_slot = 6'd23;  // enable1[11]
      9'd384: en_slot = 6'd24;  // enable0[12]
      9'd385: en_slot = 6'd25;  // enable1[12]
      9'd416: en_slot = 6'd26;  // enable0[13]
      9'd417: en_slot = 6'd27;  // enable1[13]
      9'd448: en_slot = 6'd28;  // enable0[14]
      9'd449: en_slot = 6'd29;  // enable1[14]
      9'd480: en_slot = 6'd30;  // enable0[15]
      9'd481: en_slot = 6'd31;  // enable1[15]
      default: if ({1'b0, en_word} < 10'd482) en_slot = 6'd32;  // empty word inside the block
    endcase
  end

  assign en_hw_rd[31:0] = '0;  // enable0[0]
  assign en_hw_set[31:0] = '0;
  assign en_hw_rd[63:32] = '0;  // enable1[0]
  assign en_hw_set[63:32] = '0;
  assign en_hw_rd[95:64] = '0;  // enable0[1]
  assign en_hw_set[95:64] = '0;
  assign en_hw_rd[127:96] = '0;  // enable1[1]
  assign en_hw_set[127:96] = '0;
  assign en_hw_rd[159:128] = '0;  // enable0[2]
  assign en_hw_set[159:128] = '0;
  assign en_hw_rd[191:160] = '0;  // enable1[2]
  assign en_hw_set[191:160] = '0;
  assign en_hw_rd[223:192] = '0;  // enable0[3]
  assign en_hw_set[223:192] = '0;
  assign en_hw_rd[255:224] = '0;  // enable1[3]
  assign en_hw_set[255:224] = '0;
  assign en_hw_rd[287:256] = '0;  // enable0[4]
  assign en_hw_set[287:256] = '0;
  assign en_hw_rd[319:288] = '0;  // enable1[4]
  assign en_hw_set[319:288] = '0;
  assign en_hw_rd[351:320] = '0;  // enable0[5]
  assign en_hw_set[351:320] = '0;
  assign en_hw_rd[383:352] = '0;  // enable1[5]
  assign en_hw_set[383:352] = '0;
  assign en_hw_rd[415:384] = '0;  // enable0[6]
  assign en_hw_set[415:384] = '0;
  assign en_hw_rd[447:416] = '0;  // enable1[6]
  assign en_hw_set[447:416] = '0;
  assign en_hw_rd[479:448] = '0;  // enable0[7]
  assign en_hw_set[479:448] = '0;
  assign en_hw_rd[511:480] = '0;  // enable1[7]
  assign en_hw_set[511:480] = '0;
  assign en_hw_rd[543:512] = '0;  // enable0[8]
  assign en_hw_set[543:512] = '0;
  assign en_hw_rd[575:544] = '0;  // enable1[8]
  assign en_hw_set[575:544] = '0;
  assign en_hw_rd[607:576] = '0;  // enable0[9]
  assign en_hw_set[607:576] = '0;
  assign en_hw_rd[639:608] = '0;  // enable1[9]
  assign en_hw_set[639:608] = '0;
  assign en_hw_rd[671:640] = '0;  // enable0[10]
  assign en_hw_set[671:640] = '0;
  assign en_hw_rd[703:672] = '0;  // enable1[10]
  assign en_hw_set[703:672] = '0;
  assign en_hw_rd[735:704] = '0;  // enable0[11]
  assign en_hw_set[735:704] = '0;
  assign en_hw_rd[767:736] = '0;  // enable1[11]
  assign en_hw_set[767:736] = '0;
  assign en_hw_rd[799:768] = '0;  // enable0[12]
  assign en_hw_set[799:768] = '0;
  assign en_hw_rd[831:800] = '0;  // enable1[12]
  assign en_hw_set[831:800] = '0;
  assign en_hw_rd[863:832] = '0;  // enable0[13]
  assign en_hw_set[863:832] = '0;
  assign en_hw_rd[895:864] = '0;  // enable1[13]
  assign en_hw_set[895:864] = '0;
  assign en_hw_rd[927:896] = '0;  // enable0[14]
  assign en_hw_set[927:896] = '0;
  assign en_hw_rd[959:928] = '0;  // enable1[14]
  assign en_hw_set[959:928] = '0;
  assign en_hw_rd[991:960] = '0;  // enable0[15]
  assign en_hw_set[991:960] = '0;
  assign en_hw_rd[1023:992] = '0;  // enable1[15]
  assign en_hw_set[1023:992] = '0;
  assign en_hw_rd[1055:1024] = '0;  // (no register)
  assign en_hw_set[1055:1024] = '0;
  assign enable0_src[30:0] = en_reg_q[31:1];
  assign enable1_src[31:0] = en_reg_q[63:32];
  assign enable0_src[61:31] = en_reg_q[95:65];
  assign enable1_src[63:32] = en_reg_q[127:96];
  assign enable0_src[92:62] = en_reg_q[159:129];
  assign enable1_src[95:64] = en_reg_q[191:160];
  assign enable0_src[123:93] = en_reg_q[223:193];
  assign enable1_src[127:96] = en_reg_q[255:224];
  assign enable0_src[154:124] = en_reg_q[287:257];
  assign enable1_src[159:128] = en_reg_q[319:288];
  assign enable0_src[185:155] = en_reg_q[351:321];
  assign enable1_src[191:160] = en_reg_q[383:352];
  assign enable0_src[216:186] = en_reg_q[415:385];
  assign enable1_src[223:192] = en_reg_q[447:416];
  assign enable0_src[247:217] = en_reg_q[479:449];
  assign enable1_src[255:224] = en_reg_q[511:480];
  assign enable0_src[278:248] = en_reg_q[543:513];
  assign enable1_src[287:256] = en_reg_q[575:544];
  assign enable0_src[309:279] = en_reg_q[607:577];
  assign enable1_src[319:288] = en_reg_q[639:608];
  assign enable0_src[340:310] = en_reg_q[671:641];
  assign enable1_src[351:320] = en_reg_q[703:672];
  assign enable0_src[371:341] = en_reg_q[735:705];
  assign enable1_src[383:352] = en_reg_q[767:736];
  assign enable0_src[402:372] = en_reg_q[799:769];
  assign enable1_src[415:384] = en_reg_q[831:800];
  assign enable0_src[433:403] = en_reg_q[863:833];
  assign enable1_src[447:416] = en_reg_q[895:864];
  assign enable0_src[464:434] = en_reg_q[927:897];
  assign enable1_src[479:448] = en_reg_q[959:928];
  assign enable0_src[495:465] = en_reg_q[991:961];
  assign enable1_src[511:480] = en_reg_q[1023:992];

  basechili_apb_regbank #(
    .ADDR_W   (8),
    .DATA_W   (32),
    .N        (N_EN),
    .RESET    (RESET_EN),
    .RW_MASK  (RW_EN),
    .W1C_MASK (W1C_EN)
  ) u_en (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[2]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (en_rb_addr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[2]),
    .PRDATA   (apb_prdata_s[95:64]),
    .PSLVERR  (apb_pslverr_s[2]),
    .reg_q    (en_reg_q),
    .hw_rd    (en_hw_rd),
    .hw_set   (en_hw_set),
    .wr_pulse (),
    .rd_pulse ()
  );

  // ---- block context: 33 word(s) at 0x200000 (one per register, one empty: the block is sparse)
  localparam int                N_CONTEXT = 33;
  // words of the array elements present (N_CTX)
  localparam logic [1055:0] ACT_CONTEXT = {{32{1'b1}}, {32{N_CTX > 15}}, {32{N_CTX > 15}}, {32{N_CTX > 14}}, {32{N_CTX > 14}}, {32{N_CTX > 13}}, {32{N_CTX > 13}}, {32{N_CTX > 12}}, {32{N_CTX > 12}}, {32{N_CTX > 11}}, {32{N_CTX > 11}}, {32{N_CTX > 10}}, {32{N_CTX > 10}}, {32{N_CTX > 9}}, {32{N_CTX > 9}}, {32{N_CTX > 8}}, {32{N_CTX > 8}}, {32{N_CTX > 7}}, {32{N_CTX > 7}}, {32{N_CTX > 6}}, {32{N_CTX > 6}}, {32{N_CTX > 5}}, {32{N_CTX > 5}}, {32{N_CTX > 4}}, {32{N_CTX > 4}}, {32{N_CTX > 3}}, {32{N_CTX > 3}}, {32{N_CTX > 2}}, {32{N_CTX > 2}}, {32{N_CTX > 1}}, {32{N_CTX > 1}}, {32{N_CTX > 0}}, {32{N_CTX > 0}}};
  localparam logic [1055:0] RESET_CONTEXT = 1056'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_CONTEXT;
  localparam logic [1055:0] RW_CONTEXT = 1056'h0000_0000_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007_0000_0000_0000_0007 & ACT_CONTEXT;
  localparam logic [1055:0] W1C_CONTEXT = 1056'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 & ACT_CONTEXT;
  logic [1055:0] context_reg_q;    // rw and w1c bit values
  logic [1055:0] context_hw_rd;    // read-only bit values
  logic [1055:0] context_hw_set;   // w1c set requests
  logic [32:0] context_wr_pulse;    // register written this cycle
  logic [32:0] context_rd_pulse;    // register read this cycle

  logic [13:0] context_word;     // word address inside the block
  logic [5:0] context_slot;     // regbank word of the register selected there
  logic [7:0] context_rb_addr;  // regbank PADDR

  assign context_word = PADDR[15:2];
  assign context_rb_addr = {context_slot, PADDR[1:0]};

  // shared offsets: the register an access selects (by direction and bank field)
  always_comb begin
    context_slot = 6'd33;  // past the last register: PSLVERR
    case (context_word)
      14'd0: context_slot = 6'd0;  // threshold[0]
      14'd1: context_slot = 6'd1;  // claim[0]
      14'd1024: context_slot = 6'd2;  // threshold[1]
      14'd1025: context_slot = 6'd3;  // claim[1]
      14'd2048: context_slot = 6'd4;  // threshold[2]
      14'd2049: context_slot = 6'd5;  // claim[2]
      14'd3072: context_slot = 6'd6;  // threshold[3]
      14'd3073: context_slot = 6'd7;  // claim[3]
      14'd4096: context_slot = 6'd8;  // threshold[4]
      14'd4097: context_slot = 6'd9;  // claim[4]
      14'd5120: context_slot = 6'd10;  // threshold[5]
      14'd5121: context_slot = 6'd11;  // claim[5]
      14'd6144: context_slot = 6'd12;  // threshold[6]
      14'd6145: context_slot = 6'd13;  // claim[6]
      14'd7168: context_slot = 6'd14;  // threshold[7]
      14'd7169: context_slot = 6'd15;  // claim[7]
      14'd8192: context_slot = 6'd16;  // threshold[8]
      14'd8193: context_slot = 6'd17;  // claim[8]
      14'd9216: context_slot = 6'd18;  // threshold[9]
      14'd9217: context_slot = 6'd19;  // claim[9]
      14'd10240: context_slot = 6'd20;  // threshold[10]
      14'd10241: context_slot = 6'd21;  // claim[10]
      14'd11264: context_slot = 6'd22;  // threshold[11]
      14'd11265: context_slot = 6'd23;  // claim[11]
      14'd12288: context_slot = 6'd24;  // threshold[12]
      14'd12289: context_slot = 6'd25;  // claim[12]
      14'd13312: context_slot = 6'd26;  // threshold[13]
      14'd13313: context_slot = 6'd27;  // claim[13]
      14'd14336: context_slot = 6'd28;  // threshold[14]
      14'd14337: context_slot = 6'd29;  // claim[14]
      14'd15360: context_slot = 6'd30;  // threshold[15]
      14'd15361: context_slot = 6'd31;  // claim[15]
      default: if ({1'b0, context_word} < 15'd15362) context_slot = 6'd32;  // empty word inside the block
    endcase
  end

  assign context_hw_rd[31:0] = '0;  // threshold[0]
  assign context_hw_set[31:0] = '0;
  assign context_hw_rd[63:32] = (N_CTX > 0) ? {26'b0, claim_id[5:0]} : '0;  // claim[0]
  assign context_hw_set[63:32] = '0;
  assign context_hw_rd[95:64] = '0;  // threshold[1]
  assign context_hw_set[95:64] = '0;
  assign context_hw_rd[127:96] = (N_CTX > 1) ? {26'b0, claim_id[11:6]} : '0;  // claim[1]
  assign context_hw_set[127:96] = '0;
  assign context_hw_rd[159:128] = '0;  // threshold[2]
  assign context_hw_set[159:128] = '0;
  assign context_hw_rd[191:160] = (N_CTX > 2) ? {26'b0, claim_id[17:12]} : '0;  // claim[2]
  assign context_hw_set[191:160] = '0;
  assign context_hw_rd[223:192] = '0;  // threshold[3]
  assign context_hw_set[223:192] = '0;
  assign context_hw_rd[255:224] = (N_CTX > 3) ? {26'b0, claim_id[23:18]} : '0;  // claim[3]
  assign context_hw_set[255:224] = '0;
  assign context_hw_rd[287:256] = '0;  // threshold[4]
  assign context_hw_set[287:256] = '0;
  assign context_hw_rd[319:288] = (N_CTX > 4) ? {26'b0, claim_id[29:24]} : '0;  // claim[4]
  assign context_hw_set[319:288] = '0;
  assign context_hw_rd[351:320] = '0;  // threshold[5]
  assign context_hw_set[351:320] = '0;
  assign context_hw_rd[383:352] = (N_CTX > 5) ? {26'b0, claim_id[35:30]} : '0;  // claim[5]
  assign context_hw_set[383:352] = '0;
  assign context_hw_rd[415:384] = '0;  // threshold[6]
  assign context_hw_set[415:384] = '0;
  assign context_hw_rd[447:416] = (N_CTX > 6) ? {26'b0, claim_id[41:36]} : '0;  // claim[6]
  assign context_hw_set[447:416] = '0;
  assign context_hw_rd[479:448] = '0;  // threshold[7]
  assign context_hw_set[479:448] = '0;
  assign context_hw_rd[511:480] = (N_CTX > 7) ? {26'b0, claim_id[47:42]} : '0;  // claim[7]
  assign context_hw_set[511:480] = '0;
  assign context_hw_rd[543:512] = '0;  // threshold[8]
  assign context_hw_set[543:512] = '0;
  assign context_hw_rd[575:544] = (N_CTX > 8) ? {26'b0, claim_id[53:48]} : '0;  // claim[8]
  assign context_hw_set[575:544] = '0;
  assign context_hw_rd[607:576] = '0;  // threshold[9]
  assign context_hw_set[607:576] = '0;
  assign context_hw_rd[639:608] = (N_CTX > 9) ? {26'b0, claim_id[59:54]} : '0;  // claim[9]
  assign context_hw_set[639:608] = '0;
  assign context_hw_rd[671:640] = '0;  // threshold[10]
  assign context_hw_set[671:640] = '0;
  assign context_hw_rd[703:672] = (N_CTX > 10) ? {26'b0, claim_id[65:60]} : '0;  // claim[10]
  assign context_hw_set[703:672] = '0;
  assign context_hw_rd[735:704] = '0;  // threshold[11]
  assign context_hw_set[735:704] = '0;
  assign context_hw_rd[767:736] = (N_CTX > 11) ? {26'b0, claim_id[71:66]} : '0;  // claim[11]
  assign context_hw_set[767:736] = '0;
  assign context_hw_rd[799:768] = '0;  // threshold[12]
  assign context_hw_set[799:768] = '0;
  assign context_hw_rd[831:800] = (N_CTX > 12) ? {26'b0, claim_id[77:72]} : '0;  // claim[12]
  assign context_hw_set[831:800] = '0;
  assign context_hw_rd[863:832] = '0;  // threshold[13]
  assign context_hw_set[863:832] = '0;
  assign context_hw_rd[895:864] = (N_CTX > 13) ? {26'b0, claim_id[83:78]} : '0;  // claim[13]
  assign context_hw_set[895:864] = '0;
  assign context_hw_rd[927:896] = '0;  // threshold[14]
  assign context_hw_set[927:896] = '0;
  assign context_hw_rd[959:928] = (N_CTX > 14) ? {26'b0, claim_id[89:84]} : '0;  // claim[14]
  assign context_hw_set[959:928] = '0;
  assign context_hw_rd[991:960] = '0;  // threshold[15]
  assign context_hw_set[991:960] = '0;
  assign context_hw_rd[1023:992] = (N_CTX > 15) ? {26'b0, claim_id[95:90]} : '0;  // claim[15]
  assign context_hw_set[1023:992] = '0;
  assign context_hw_rd[1055:1024] = '0;  // (no register)
  assign context_hw_set[1055:1024] = '0;
  assign threshold_value[2:0] = context_reg_q[2:0];
  assign claim_wr[0] = context_wr_pulse[1] && (N_CTX > 0);
  assign claim_rd[0] = context_rd_pulse[1] && (N_CTX > 0);
  assign threshold_value[5:3] = context_reg_q[66:64];
  assign claim_wr[1] = context_wr_pulse[3] && (N_CTX > 1);
  assign claim_rd[1] = context_rd_pulse[3] && (N_CTX > 1);
  assign threshold_value[8:6] = context_reg_q[130:128];
  assign claim_wr[2] = context_wr_pulse[5] && (N_CTX > 2);
  assign claim_rd[2] = context_rd_pulse[5] && (N_CTX > 2);
  assign threshold_value[11:9] = context_reg_q[194:192];
  assign claim_wr[3] = context_wr_pulse[7] && (N_CTX > 3);
  assign claim_rd[3] = context_rd_pulse[7] && (N_CTX > 3);
  assign threshold_value[14:12] = context_reg_q[258:256];
  assign claim_wr[4] = context_wr_pulse[9] && (N_CTX > 4);
  assign claim_rd[4] = context_rd_pulse[9] && (N_CTX > 4);
  assign threshold_value[17:15] = context_reg_q[322:320];
  assign claim_wr[5] = context_wr_pulse[11] && (N_CTX > 5);
  assign claim_rd[5] = context_rd_pulse[11] && (N_CTX > 5);
  assign threshold_value[20:18] = context_reg_q[386:384];
  assign claim_wr[6] = context_wr_pulse[13] && (N_CTX > 6);
  assign claim_rd[6] = context_rd_pulse[13] && (N_CTX > 6);
  assign threshold_value[23:21] = context_reg_q[450:448];
  assign claim_wr[7] = context_wr_pulse[15] && (N_CTX > 7);
  assign claim_rd[7] = context_rd_pulse[15] && (N_CTX > 7);
  assign threshold_value[26:24] = context_reg_q[514:512];
  assign claim_wr[8] = context_wr_pulse[17] && (N_CTX > 8);
  assign claim_rd[8] = context_rd_pulse[17] && (N_CTX > 8);
  assign threshold_value[29:27] = context_reg_q[578:576];
  assign claim_wr[9] = context_wr_pulse[19] && (N_CTX > 9);
  assign claim_rd[9] = context_rd_pulse[19] && (N_CTX > 9);
  assign threshold_value[32:30] = context_reg_q[642:640];
  assign claim_wr[10] = context_wr_pulse[21] && (N_CTX > 10);
  assign claim_rd[10] = context_rd_pulse[21] && (N_CTX > 10);
  assign threshold_value[35:33] = context_reg_q[706:704];
  assign claim_wr[11] = context_wr_pulse[23] && (N_CTX > 11);
  assign claim_rd[11] = context_rd_pulse[23] && (N_CTX > 11);
  assign threshold_value[38:36] = context_reg_q[770:768];
  assign claim_wr[12] = context_wr_pulse[25] && (N_CTX > 12);
  assign claim_rd[12] = context_rd_pulse[25] && (N_CTX > 12);
  assign threshold_value[41:39] = context_reg_q[834:832];
  assign claim_wr[13] = context_wr_pulse[27] && (N_CTX > 13);
  assign claim_rd[13] = context_rd_pulse[27] && (N_CTX > 13);
  assign threshold_value[44:42] = context_reg_q[898:896];
  assign claim_wr[14] = context_wr_pulse[29] && (N_CTX > 14);
  assign claim_rd[14] = context_rd_pulse[29] && (N_CTX > 14);
  assign threshold_value[47:45] = context_reg_q[962:960];
  assign claim_wr[15] = context_wr_pulse[31] && (N_CTX > 15);
  assign claim_rd[15] = context_rd_pulse[31] && (N_CTX > 15);

  basechili_apb_regbank #(
    .ADDR_W   (8),
    .DATA_W   (32),
    .N        (N_CONTEXT),
    .RESET    (RESET_CONTEXT),
    .RW_MASK  (RW_CONTEXT),
    .W1C_MASK (W1C_CONTEXT)
  ) u_context (
    .clk      (clk),
    .rst_n    (rst_n),
    .PSEL     (apb_psel_s[3]),
    .PENABLE  (PENABLE),
    .PWRITE   (PWRITE),
    .PADDR    (context_rb_addr),
    .PWDATA   (PWDATA),
    .PSTRB    (PSTRB),
    .PREADY   (apb_pready_s[3]),
    .PRDATA   (apb_prdata_s[127:96]),
    .PSLVERR  (apb_pslverr_s[3]),
    .reg_q    (context_reg_q),
    .hw_rd    (context_hw_rd),
    .hw_set   (context_hw_set),
    .wr_pulse (context_wr_pulse),
    .rd_pulse (context_rd_pulse)
  );

endmodule
