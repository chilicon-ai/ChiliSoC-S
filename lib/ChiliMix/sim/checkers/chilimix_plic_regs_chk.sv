// =============================================================================
// GENERATED FILE - DO NOT EDIT
// =============================================================================
// checker :: chilimix_plic_regs_chk (simulation and formal; bound into every chilimix_plic_regs)
//
// The plic register map as properties: read values, reset values, rw
// writes with PSTRB, w1c clears and sets, access pulses, PREADY, PSLVERR
//. Implication-free: yosys-slang
// rejects |-> and |=>, so "a |=> b" is !past_ok || !$past(rst_n) || !$past(a) || b.
// -----------------------------------------------------------------------------
module chilimix_plic_regs_chk #(
  parameter int N_CTX = 1  // contexts present (1 .. 16)
) (
  input logic clk,
  input logic rst_n,
  input logic PSEL,
  input logic PENABLE,
  input logic PWRITE,
  input logic [21:0] PADDR,
  input logic [31:0] PWDATA,
  input logic [3:0] PSTRB,
  input logic PREADY,
  input logic [31:0] PRDATA,
  input logic PSLVERR,
  input logic [188:0] priority_value,
  input logic [30:0] pending0_src,
  input logic [31:0] pending1_src,
  input logic [495:0] enable0_src,
  input logic [511:0] enable1_src,
  input logic [47:0] threshold_value,
  input logic [95:0] claim_id,
  input logic [15:0] claim_rd,
  input logic [15:0] claim_wr
);

  logic past_ok = 1'b0;  // a previous clock edge exists ($past is defined)
  always @(posedge clk) past_ok <= 1'b1;

  logic access;          // APB ACCESS phase
  logic err;             // the access must give PSLVERR
  logic any_rd;          // a read selects some register
  logic [31:0] bit_en;  // PSTRB as a bit mask
  logic [128:0] hit;  // the address (and direction / bank) selects element k

  assign access = PSEL && PENABLE;
  always_comb begin
    for (int b = 0; b < 32; b++) bit_en[b] = PSTRB[b / 8];
  end
  assign hit[0] = PADDR[21:2] == 20'd1;  // priority[0]
  assign hit[1] = PADDR[21:2] == 20'd2;  // priority[1]
  assign hit[2] = PADDR[21:2] == 20'd3;  // priority[2]
  assign hit[3] = PADDR[21:2] == 20'd4;  // priority[3]
  assign hit[4] = PADDR[21:2] == 20'd5;  // priority[4]
  assign hit[5] = PADDR[21:2] == 20'd6;  // priority[5]
  assign hit[6] = PADDR[21:2] == 20'd7;  // priority[6]
  assign hit[7] = PADDR[21:2] == 20'd8;  // priority[7]
  assign hit[8] = PADDR[21:2] == 20'd9;  // priority[8]
  assign hit[9] = PADDR[21:2] == 20'd10;  // priority[9]
  assign hit[10] = PADDR[21:2] == 20'd11;  // priority[10]
  assign hit[11] = PADDR[21:2] == 20'd12;  // priority[11]
  assign hit[12] = PADDR[21:2] == 20'd13;  // priority[12]
  assign hit[13] = PADDR[21:2] == 20'd14;  // priority[13]
  assign hit[14] = PADDR[21:2] == 20'd15;  // priority[14]
  assign hit[15] = PADDR[21:2] == 20'd16;  // priority[15]
  assign hit[16] = PADDR[21:2] == 20'd17;  // priority[16]
  assign hit[17] = PADDR[21:2] == 20'd18;  // priority[17]
  assign hit[18] = PADDR[21:2] == 20'd19;  // priority[18]
  assign hit[19] = PADDR[21:2] == 20'd20;  // priority[19]
  assign hit[20] = PADDR[21:2] == 20'd21;  // priority[20]
  assign hit[21] = PADDR[21:2] == 20'd22;  // priority[21]
  assign hit[22] = PADDR[21:2] == 20'd23;  // priority[22]
  assign hit[23] = PADDR[21:2] == 20'd24;  // priority[23]
  assign hit[24] = PADDR[21:2] == 20'd25;  // priority[24]
  assign hit[25] = PADDR[21:2] == 20'd26;  // priority[25]
  assign hit[26] = PADDR[21:2] == 20'd27;  // priority[26]
  assign hit[27] = PADDR[21:2] == 20'd28;  // priority[27]
  assign hit[28] = PADDR[21:2] == 20'd29;  // priority[28]
  assign hit[29] = PADDR[21:2] == 20'd30;  // priority[29]
  assign hit[30] = PADDR[21:2] == 20'd31;  // priority[30]
  assign hit[31] = PADDR[21:2] == 20'd32;  // priority[31]
  assign hit[32] = PADDR[21:2] == 20'd33;  // priority[32]
  assign hit[33] = PADDR[21:2] == 20'd34;  // priority[33]
  assign hit[34] = PADDR[21:2] == 20'd35;  // priority[34]
  assign hit[35] = PADDR[21:2] == 20'd36;  // priority[35]
  assign hit[36] = PADDR[21:2] == 20'd37;  // priority[36]
  assign hit[37] = PADDR[21:2] == 20'd38;  // priority[37]
  assign hit[38] = PADDR[21:2] == 20'd39;  // priority[38]
  assign hit[39] = PADDR[21:2] == 20'd40;  // priority[39]
  assign hit[40] = PADDR[21:2] == 20'd41;  // priority[40]
  assign hit[41] = PADDR[21:2] == 20'd42;  // priority[41]
  assign hit[42] = PADDR[21:2] == 20'd43;  // priority[42]
  assign hit[43] = PADDR[21:2] == 20'd44;  // priority[43]
  assign hit[44] = PADDR[21:2] == 20'd45;  // priority[44]
  assign hit[45] = PADDR[21:2] == 20'd46;  // priority[45]
  assign hit[46] = PADDR[21:2] == 20'd47;  // priority[46]
  assign hit[47] = PADDR[21:2] == 20'd48;  // priority[47]
  assign hit[48] = PADDR[21:2] == 20'd49;  // priority[48]
  assign hit[49] = PADDR[21:2] == 20'd50;  // priority[49]
  assign hit[50] = PADDR[21:2] == 20'd51;  // priority[50]
  assign hit[51] = PADDR[21:2] == 20'd52;  // priority[51]
  assign hit[52] = PADDR[21:2] == 20'd53;  // priority[52]
  assign hit[53] = PADDR[21:2] == 20'd54;  // priority[53]
  assign hit[54] = PADDR[21:2] == 20'd55;  // priority[54]
  assign hit[55] = PADDR[21:2] == 20'd56;  // priority[55]
  assign hit[56] = PADDR[21:2] == 20'd57;  // priority[56]
  assign hit[57] = PADDR[21:2] == 20'd58;  // priority[57]
  assign hit[58] = PADDR[21:2] == 20'd59;  // priority[58]
  assign hit[59] = PADDR[21:2] == 20'd60;  // priority[59]
  assign hit[60] = PADDR[21:2] == 20'd61;  // priority[60]
  assign hit[61] = PADDR[21:2] == 20'd62;  // priority[61]
  assign hit[62] = PADDR[21:2] == 20'd63;  // priority[62]
  assign hit[63] = PADDR[21:2] == 20'd1024;  // pending0
  assign hit[64] = PADDR[21:2] == 20'd1025;  // pending1
  assign hit[65] = PADDR[21:2] == 20'd2048;  // enable0[0]
  assign hit[66] = PADDR[21:2] == 20'd2049;  // enable1[0]
  assign hit[67] = PADDR[21:2] == 20'd2080;  // enable0[1]
  assign hit[68] = PADDR[21:2] == 20'd2081;  // enable1[1]
  assign hit[69] = PADDR[21:2] == 20'd2112;  // enable0[2]
  assign hit[70] = PADDR[21:2] == 20'd2113;  // enable1[2]
  assign hit[71] = PADDR[21:2] == 20'd2144;  // enable0[3]
  assign hit[72] = PADDR[21:2] == 20'd2145;  // enable1[3]
  assign hit[73] = PADDR[21:2] == 20'd2176;  // enable0[4]
  assign hit[74] = PADDR[21:2] == 20'd2177;  // enable1[4]
  assign hit[75] = PADDR[21:2] == 20'd2208;  // enable0[5]
  assign hit[76] = PADDR[21:2] == 20'd2209;  // enable1[5]
  assign hit[77] = PADDR[21:2] == 20'd2240;  // enable0[6]
  assign hit[78] = PADDR[21:2] == 20'd2241;  // enable1[6]
  assign hit[79] = PADDR[21:2] == 20'd2272;  // enable0[7]
  assign hit[80] = PADDR[21:2] == 20'd2273;  // enable1[7]
  assign hit[81] = PADDR[21:2] == 20'd2304;  // enable0[8]
  assign hit[82] = PADDR[21:2] == 20'd2305;  // enable1[8]
  assign hit[83] = PADDR[21:2] == 20'd2336;  // enable0[9]
  assign hit[84] = PADDR[21:2] == 20'd2337;  // enable1[9]
  assign hit[85] = PADDR[21:2] == 20'd2368;  // enable0[10]
  assign hit[86] = PADDR[21:2] == 20'd2369;  // enable1[10]
  assign hit[87] = PADDR[21:2] == 20'd2400;  // enable0[11]
  assign hit[88] = PADDR[21:2] == 20'd2401;  // enable1[11]
  assign hit[89] = PADDR[21:2] == 20'd2432;  // enable0[12]
  assign hit[90] = PADDR[21:2] == 20'd2433;  // enable1[12]
  assign hit[91] = PADDR[21:2] == 20'd2464;  // enable0[13]
  assign hit[92] = PADDR[21:2] == 20'd2465;  // enable1[13]
  assign hit[93] = PADDR[21:2] == 20'd2496;  // enable0[14]
  assign hit[94] = PADDR[21:2] == 20'd2497;  // enable1[14]
  assign hit[95] = PADDR[21:2] == 20'd2528;  // enable0[15]
  assign hit[96] = PADDR[21:2] == 20'd2529;  // enable1[15]
  assign hit[97] = PADDR[21:2] == 20'd524288;  // threshold[0]
  assign hit[98] = PADDR[21:2] == 20'd524289;  // claim[0]
  assign hit[99] = PADDR[21:2] == 20'd525312;  // threshold[1]
  assign hit[100] = PADDR[21:2] == 20'd525313;  // claim[1]
  assign hit[101] = PADDR[21:2] == 20'd526336;  // threshold[2]
  assign hit[102] = PADDR[21:2] == 20'd526337;  // claim[2]
  assign hit[103] = PADDR[21:2] == 20'd527360;  // threshold[3]
  assign hit[104] = PADDR[21:2] == 20'd527361;  // claim[3]
  assign hit[105] = PADDR[21:2] == 20'd528384;  // threshold[4]
  assign hit[106] = PADDR[21:2] == 20'd528385;  // claim[4]
  assign hit[107] = PADDR[21:2] == 20'd529408;  // threshold[5]
  assign hit[108] = PADDR[21:2] == 20'd529409;  // claim[5]
  assign hit[109] = PADDR[21:2] == 20'd530432;  // threshold[6]
  assign hit[110] = PADDR[21:2] == 20'd530433;  // claim[6]
  assign hit[111] = PADDR[21:2] == 20'd531456;  // threshold[7]
  assign hit[112] = PADDR[21:2] == 20'd531457;  // claim[7]
  assign hit[113] = PADDR[21:2] == 20'd532480;  // threshold[8]
  assign hit[114] = PADDR[21:2] == 20'd532481;  // claim[8]
  assign hit[115] = PADDR[21:2] == 20'd533504;  // threshold[9]
  assign hit[116] = PADDR[21:2] == 20'd533505;  // claim[9]
  assign hit[117] = PADDR[21:2] == 20'd534528;  // threshold[10]
  assign hit[118] = PADDR[21:2] == 20'd534529;  // claim[10]
  assign hit[119] = PADDR[21:2] == 20'd535552;  // threshold[11]
  assign hit[120] = PADDR[21:2] == 20'd535553;  // claim[11]
  assign hit[121] = PADDR[21:2] == 20'd536576;  // threshold[12]
  assign hit[122] = PADDR[21:2] == 20'd536577;  // claim[12]
  assign hit[123] = PADDR[21:2] == 20'd537600;  // threshold[13]
  assign hit[124] = PADDR[21:2] == 20'd537601;  // claim[13]
  assign hit[125] = PADDR[21:2] == 20'd538624;  // threshold[14]
  assign hit[126] = PADDR[21:2] == 20'd538625;  // claim[14]
  assign hit[127] = PADDR[21:2] == 20'd539648;  // threshold[15]
  assign hit[128] = PADDR[21:2] == 20'd539649;  // claim[15]
  assign err = !((PADDR[21:8] == 14'd0 && {1'b0, PADDR[7:2]} < 7'd64) || (PADDR[21:3] == 19'd512 && {1'b0, PADDR[2:2]} < 2'd2) || (PADDR[21:11] == 11'd4 && {1'b0, PADDR[10:2]} < 10'd482) || (PADDR[21:16] == 6'd32 && {1'b0, PADDR[15:2]} < 15'd15362));
  assign any_rd = !PWRITE && (hit[0] || hit[1] || hit[2] || hit[3] || hit[4] || hit[5] || hit[6] || hit[7] || hit[8] || hit[9] || hit[10] || hit[11] || hit[12] || hit[13] || hit[14] || hit[15] || hit[16] || hit[17] || hit[18] || hit[19] || hit[20] || hit[21] || hit[22] || hit[23] || hit[24] || hit[25] || hit[26] || hit[27] || hit[28] || hit[29] || hit[30] || hit[31] || hit[32] || hit[33] || hit[34] || hit[35] || hit[36] || hit[37] || hit[38] || hit[39] || hit[40] || hit[41] || hit[42] || hit[43] || hit[44] || hit[45] || hit[46] || hit[47] || hit[48] || hit[49] || hit[50] || hit[51] || hit[52] || hit[53] || hit[54] || hit[55] || hit[56] || hit[57] || hit[58] || hit[59] || hit[60] || hit[61] || hit[62] || hit[63] || hit[64] || hit[65] || hit[66] || hit[67] || hit[68] || hit[69] || hit[70] || hit[71] || hit[72] || hit[73] || hit[74] || hit[75] || hit[76] || hit[77] || hit[78] || hit[79] || hit[80] || hit[81] || hit[82] || hit[83] || hit[84] || hit[85] || hit[86] || hit[87] || hit[88] || hit[89] || hit[90] || hit[91] || hit[92] || hit[93] || hit[94] || hit[95] || hit[96] || hit[97] || hit[98] || hit[99] || hit[100] || hit[101] || hit[102] || hit[103] || hit[104] || hit[105] || hit[106] || hit[107] || hit[108] || hit[109] || hit[110] || hit[111] || hit[112] || hit[113] || hit[114] || hit[115] || hit[116] || hit[117] || hit[118] || hit[119] || hit[120] || hit[121] || hit[122] || hit[123] || hit[124] || hit[125] || hit[126] || hit[127] || hit[128]);

  // ---- port
  always @(posedge clk) begin
    p_pready_high: assert (PREADY)
      else $error("chilimix_plic_regs: PREADY low");
    p_pslverr_exact: assert (!rst_n || !access || PSLVERR == err)
      else $error("chilimix_plic_regs: PSLVERR %b for PADDR %h", PSLVERR, PADDR);
    p_read_none_zero: assert (!rst_n || !access || PWRITE || err || any_rd || PRDATA == '0)
      else $error("chilimix_plic_regs: read of no register at %h returned %h", PADDR, PRDATA);
  end

  // ---- reads (every cycle out of reset)
  always @(posedge clk) if (rst_n) begin
    // priority[0] at 0x4
    p_priority_0_rd: assert (!(access && !PWRITE && hit[0]) || PRDATA == {29'b0, priority_value[2:0]})
      else $error("chilimix_plic_regs: priority[0] read %h", PRDATA);
    p_priority_0_rd_cov: cover (access && !PWRITE && hit[0]);
    // priority[1] at 0x8
    p_priority_1_rd: assert (!(access && !PWRITE && hit[1]) || PRDATA == {29'b0, priority_value[5:3]})
      else $error("chilimix_plic_regs: priority[1] read %h", PRDATA);
    p_priority_1_rd_cov: cover (access && !PWRITE && hit[1]);
    // priority[2] at 0xc
    p_priority_2_rd: assert (!(access && !PWRITE && hit[2]) || PRDATA == {29'b0, priority_value[8:6]})
      else $error("chilimix_plic_regs: priority[2] read %h", PRDATA);
    p_priority_2_rd_cov: cover (access && !PWRITE && hit[2]);
    // priority[3] at 0x10
    p_priority_3_rd: assert (!(access && !PWRITE && hit[3]) || PRDATA == {29'b0, priority_value[11:9]})
      else $error("chilimix_plic_regs: priority[3] read %h", PRDATA);
    p_priority_3_rd_cov: cover (access && !PWRITE && hit[3]);
    // priority[4] at 0x14
    p_priority_4_rd: assert (!(access && !PWRITE && hit[4]) || PRDATA == {29'b0, priority_value[14:12]})
      else $error("chilimix_plic_regs: priority[4] read %h", PRDATA);
    p_priority_4_rd_cov: cover (access && !PWRITE && hit[4]);
    // priority[5] at 0x18
    p_priority_5_rd: assert (!(access && !PWRITE && hit[5]) || PRDATA == {29'b0, priority_value[17:15]})
      else $error("chilimix_plic_regs: priority[5] read %h", PRDATA);
    p_priority_5_rd_cov: cover (access && !PWRITE && hit[5]);
    // priority[6] at 0x1c
    p_priority_6_rd: assert (!(access && !PWRITE && hit[6]) || PRDATA == {29'b0, priority_value[20:18]})
      else $error("chilimix_plic_regs: priority[6] read %h", PRDATA);
    p_priority_6_rd_cov: cover (access && !PWRITE && hit[6]);
    // priority[7] at 0x20
    p_priority_7_rd: assert (!(access && !PWRITE && hit[7]) || PRDATA == {29'b0, priority_value[23:21]})
      else $error("chilimix_plic_regs: priority[7] read %h", PRDATA);
    p_priority_7_rd_cov: cover (access && !PWRITE && hit[7]);
    // priority[8] at 0x24
    p_priority_8_rd: assert (!(access && !PWRITE && hit[8]) || PRDATA == {29'b0, priority_value[26:24]})
      else $error("chilimix_plic_regs: priority[8] read %h", PRDATA);
    p_priority_8_rd_cov: cover (access && !PWRITE && hit[8]);
    // priority[9] at 0x28
    p_priority_9_rd: assert (!(access && !PWRITE && hit[9]) || PRDATA == {29'b0, priority_value[29:27]})
      else $error("chilimix_plic_regs: priority[9] read %h", PRDATA);
    p_priority_9_rd_cov: cover (access && !PWRITE && hit[9]);
    // priority[10] at 0x2c
    p_priority_10_rd: assert (!(access && !PWRITE && hit[10]) || PRDATA == {29'b0, priority_value[32:30]})
      else $error("chilimix_plic_regs: priority[10] read %h", PRDATA);
    p_priority_10_rd_cov: cover (access && !PWRITE && hit[10]);
    // priority[11] at 0x30
    p_priority_11_rd: assert (!(access && !PWRITE && hit[11]) || PRDATA == {29'b0, priority_value[35:33]})
      else $error("chilimix_plic_regs: priority[11] read %h", PRDATA);
    p_priority_11_rd_cov: cover (access && !PWRITE && hit[11]);
    // priority[12] at 0x34
    p_priority_12_rd: assert (!(access && !PWRITE && hit[12]) || PRDATA == {29'b0, priority_value[38:36]})
      else $error("chilimix_plic_regs: priority[12] read %h", PRDATA);
    p_priority_12_rd_cov: cover (access && !PWRITE && hit[12]);
    // priority[13] at 0x38
    p_priority_13_rd: assert (!(access && !PWRITE && hit[13]) || PRDATA == {29'b0, priority_value[41:39]})
      else $error("chilimix_plic_regs: priority[13] read %h", PRDATA);
    p_priority_13_rd_cov: cover (access && !PWRITE && hit[13]);
    // priority[14] at 0x3c
    p_priority_14_rd: assert (!(access && !PWRITE && hit[14]) || PRDATA == {29'b0, priority_value[44:42]})
      else $error("chilimix_plic_regs: priority[14] read %h", PRDATA);
    p_priority_14_rd_cov: cover (access && !PWRITE && hit[14]);
    // priority[15] at 0x40
    p_priority_15_rd: assert (!(access && !PWRITE && hit[15]) || PRDATA == {29'b0, priority_value[47:45]})
      else $error("chilimix_plic_regs: priority[15] read %h", PRDATA);
    p_priority_15_rd_cov: cover (access && !PWRITE && hit[15]);
    // priority[16] at 0x44
    p_priority_16_rd: assert (!(access && !PWRITE && hit[16]) || PRDATA == {29'b0, priority_value[50:48]})
      else $error("chilimix_plic_regs: priority[16] read %h", PRDATA);
    p_priority_16_rd_cov: cover (access && !PWRITE && hit[16]);
    // priority[17] at 0x48
    p_priority_17_rd: assert (!(access && !PWRITE && hit[17]) || PRDATA == {29'b0, priority_value[53:51]})
      else $error("chilimix_plic_regs: priority[17] read %h", PRDATA);
    p_priority_17_rd_cov: cover (access && !PWRITE && hit[17]);
    // priority[18] at 0x4c
    p_priority_18_rd: assert (!(access && !PWRITE && hit[18]) || PRDATA == {29'b0, priority_value[56:54]})
      else $error("chilimix_plic_regs: priority[18] read %h", PRDATA);
    p_priority_18_rd_cov: cover (access && !PWRITE && hit[18]);
    // priority[19] at 0x50
    p_priority_19_rd: assert (!(access && !PWRITE && hit[19]) || PRDATA == {29'b0, priority_value[59:57]})
      else $error("chilimix_plic_regs: priority[19] read %h", PRDATA);
    p_priority_19_rd_cov: cover (access && !PWRITE && hit[19]);
    // priority[20] at 0x54
    p_priority_20_rd: assert (!(access && !PWRITE && hit[20]) || PRDATA == {29'b0, priority_value[62:60]})
      else $error("chilimix_plic_regs: priority[20] read %h", PRDATA);
    p_priority_20_rd_cov: cover (access && !PWRITE && hit[20]);
    // priority[21] at 0x58
    p_priority_21_rd: assert (!(access && !PWRITE && hit[21]) || PRDATA == {29'b0, priority_value[65:63]})
      else $error("chilimix_plic_regs: priority[21] read %h", PRDATA);
    p_priority_21_rd_cov: cover (access && !PWRITE && hit[21]);
    // priority[22] at 0x5c
    p_priority_22_rd: assert (!(access && !PWRITE && hit[22]) || PRDATA == {29'b0, priority_value[68:66]})
      else $error("chilimix_plic_regs: priority[22] read %h", PRDATA);
    p_priority_22_rd_cov: cover (access && !PWRITE && hit[22]);
    // priority[23] at 0x60
    p_priority_23_rd: assert (!(access && !PWRITE && hit[23]) || PRDATA == {29'b0, priority_value[71:69]})
      else $error("chilimix_plic_regs: priority[23] read %h", PRDATA);
    p_priority_23_rd_cov: cover (access && !PWRITE && hit[23]);
    // priority[24] at 0x64
    p_priority_24_rd: assert (!(access && !PWRITE && hit[24]) || PRDATA == {29'b0, priority_value[74:72]})
      else $error("chilimix_plic_regs: priority[24] read %h", PRDATA);
    p_priority_24_rd_cov: cover (access && !PWRITE && hit[24]);
    // priority[25] at 0x68
    p_priority_25_rd: assert (!(access && !PWRITE && hit[25]) || PRDATA == {29'b0, priority_value[77:75]})
      else $error("chilimix_plic_regs: priority[25] read %h", PRDATA);
    p_priority_25_rd_cov: cover (access && !PWRITE && hit[25]);
    // priority[26] at 0x6c
    p_priority_26_rd: assert (!(access && !PWRITE && hit[26]) || PRDATA == {29'b0, priority_value[80:78]})
      else $error("chilimix_plic_regs: priority[26] read %h", PRDATA);
    p_priority_26_rd_cov: cover (access && !PWRITE && hit[26]);
    // priority[27] at 0x70
    p_priority_27_rd: assert (!(access && !PWRITE && hit[27]) || PRDATA == {29'b0, priority_value[83:81]})
      else $error("chilimix_plic_regs: priority[27] read %h", PRDATA);
    p_priority_27_rd_cov: cover (access && !PWRITE && hit[27]);
    // priority[28] at 0x74
    p_priority_28_rd: assert (!(access && !PWRITE && hit[28]) || PRDATA == {29'b0, priority_value[86:84]})
      else $error("chilimix_plic_regs: priority[28] read %h", PRDATA);
    p_priority_28_rd_cov: cover (access && !PWRITE && hit[28]);
    // priority[29] at 0x78
    p_priority_29_rd: assert (!(access && !PWRITE && hit[29]) || PRDATA == {29'b0, priority_value[89:87]})
      else $error("chilimix_plic_regs: priority[29] read %h", PRDATA);
    p_priority_29_rd_cov: cover (access && !PWRITE && hit[29]);
    // priority[30] at 0x7c
    p_priority_30_rd: assert (!(access && !PWRITE && hit[30]) || PRDATA == {29'b0, priority_value[92:90]})
      else $error("chilimix_plic_regs: priority[30] read %h", PRDATA);
    p_priority_30_rd_cov: cover (access && !PWRITE && hit[30]);
    // priority[31] at 0x80
    p_priority_31_rd: assert (!(access && !PWRITE && hit[31]) || PRDATA == {29'b0, priority_value[95:93]})
      else $error("chilimix_plic_regs: priority[31] read %h", PRDATA);
    p_priority_31_rd_cov: cover (access && !PWRITE && hit[31]);
    // priority[32] at 0x84
    p_priority_32_rd: assert (!(access && !PWRITE && hit[32]) || PRDATA == {29'b0, priority_value[98:96]})
      else $error("chilimix_plic_regs: priority[32] read %h", PRDATA);
    p_priority_32_rd_cov: cover (access && !PWRITE && hit[32]);
    // priority[33] at 0x88
    p_priority_33_rd: assert (!(access && !PWRITE && hit[33]) || PRDATA == {29'b0, priority_value[101:99]})
      else $error("chilimix_plic_regs: priority[33] read %h", PRDATA);
    p_priority_33_rd_cov: cover (access && !PWRITE && hit[33]);
    // priority[34] at 0x8c
    p_priority_34_rd: assert (!(access && !PWRITE && hit[34]) || PRDATA == {29'b0, priority_value[104:102]})
      else $error("chilimix_plic_regs: priority[34] read %h", PRDATA);
    p_priority_34_rd_cov: cover (access && !PWRITE && hit[34]);
    // priority[35] at 0x90
    p_priority_35_rd: assert (!(access && !PWRITE && hit[35]) || PRDATA == {29'b0, priority_value[107:105]})
      else $error("chilimix_plic_regs: priority[35] read %h", PRDATA);
    p_priority_35_rd_cov: cover (access && !PWRITE && hit[35]);
    // priority[36] at 0x94
    p_priority_36_rd: assert (!(access && !PWRITE && hit[36]) || PRDATA == {29'b0, priority_value[110:108]})
      else $error("chilimix_plic_regs: priority[36] read %h", PRDATA);
    p_priority_36_rd_cov: cover (access && !PWRITE && hit[36]);
    // priority[37] at 0x98
    p_priority_37_rd: assert (!(access && !PWRITE && hit[37]) || PRDATA == {29'b0, priority_value[113:111]})
      else $error("chilimix_plic_regs: priority[37] read %h", PRDATA);
    p_priority_37_rd_cov: cover (access && !PWRITE && hit[37]);
    // priority[38] at 0x9c
    p_priority_38_rd: assert (!(access && !PWRITE && hit[38]) || PRDATA == {29'b0, priority_value[116:114]})
      else $error("chilimix_plic_regs: priority[38] read %h", PRDATA);
    p_priority_38_rd_cov: cover (access && !PWRITE && hit[38]);
    // priority[39] at 0xa0
    p_priority_39_rd: assert (!(access && !PWRITE && hit[39]) || PRDATA == {29'b0, priority_value[119:117]})
      else $error("chilimix_plic_regs: priority[39] read %h", PRDATA);
    p_priority_39_rd_cov: cover (access && !PWRITE && hit[39]);
    // priority[40] at 0xa4
    p_priority_40_rd: assert (!(access && !PWRITE && hit[40]) || PRDATA == {29'b0, priority_value[122:120]})
      else $error("chilimix_plic_regs: priority[40] read %h", PRDATA);
    p_priority_40_rd_cov: cover (access && !PWRITE && hit[40]);
    // priority[41] at 0xa8
    p_priority_41_rd: assert (!(access && !PWRITE && hit[41]) || PRDATA == {29'b0, priority_value[125:123]})
      else $error("chilimix_plic_regs: priority[41] read %h", PRDATA);
    p_priority_41_rd_cov: cover (access && !PWRITE && hit[41]);
    // priority[42] at 0xac
    p_priority_42_rd: assert (!(access && !PWRITE && hit[42]) || PRDATA == {29'b0, priority_value[128:126]})
      else $error("chilimix_plic_regs: priority[42] read %h", PRDATA);
    p_priority_42_rd_cov: cover (access && !PWRITE && hit[42]);
    // priority[43] at 0xb0
    p_priority_43_rd: assert (!(access && !PWRITE && hit[43]) || PRDATA == {29'b0, priority_value[131:129]})
      else $error("chilimix_plic_regs: priority[43] read %h", PRDATA);
    p_priority_43_rd_cov: cover (access && !PWRITE && hit[43]);
    // priority[44] at 0xb4
    p_priority_44_rd: assert (!(access && !PWRITE && hit[44]) || PRDATA == {29'b0, priority_value[134:132]})
      else $error("chilimix_plic_regs: priority[44] read %h", PRDATA);
    p_priority_44_rd_cov: cover (access && !PWRITE && hit[44]);
    // priority[45] at 0xb8
    p_priority_45_rd: assert (!(access && !PWRITE && hit[45]) || PRDATA == {29'b0, priority_value[137:135]})
      else $error("chilimix_plic_regs: priority[45] read %h", PRDATA);
    p_priority_45_rd_cov: cover (access && !PWRITE && hit[45]);
    // priority[46] at 0xbc
    p_priority_46_rd: assert (!(access && !PWRITE && hit[46]) || PRDATA == {29'b0, priority_value[140:138]})
      else $error("chilimix_plic_regs: priority[46] read %h", PRDATA);
    p_priority_46_rd_cov: cover (access && !PWRITE && hit[46]);
    // priority[47] at 0xc0
    p_priority_47_rd: assert (!(access && !PWRITE && hit[47]) || PRDATA == {29'b0, priority_value[143:141]})
      else $error("chilimix_plic_regs: priority[47] read %h", PRDATA);
    p_priority_47_rd_cov: cover (access && !PWRITE && hit[47]);
    // priority[48] at 0xc4
    p_priority_48_rd: assert (!(access && !PWRITE && hit[48]) || PRDATA == {29'b0, priority_value[146:144]})
      else $error("chilimix_plic_regs: priority[48] read %h", PRDATA);
    p_priority_48_rd_cov: cover (access && !PWRITE && hit[48]);
    // priority[49] at 0xc8
    p_priority_49_rd: assert (!(access && !PWRITE && hit[49]) || PRDATA == {29'b0, priority_value[149:147]})
      else $error("chilimix_plic_regs: priority[49] read %h", PRDATA);
    p_priority_49_rd_cov: cover (access && !PWRITE && hit[49]);
    // priority[50] at 0xcc
    p_priority_50_rd: assert (!(access && !PWRITE && hit[50]) || PRDATA == {29'b0, priority_value[152:150]})
      else $error("chilimix_plic_regs: priority[50] read %h", PRDATA);
    p_priority_50_rd_cov: cover (access && !PWRITE && hit[50]);
    // priority[51] at 0xd0
    p_priority_51_rd: assert (!(access && !PWRITE && hit[51]) || PRDATA == {29'b0, priority_value[155:153]})
      else $error("chilimix_plic_regs: priority[51] read %h", PRDATA);
    p_priority_51_rd_cov: cover (access && !PWRITE && hit[51]);
    // priority[52] at 0xd4
    p_priority_52_rd: assert (!(access && !PWRITE && hit[52]) || PRDATA == {29'b0, priority_value[158:156]})
      else $error("chilimix_plic_regs: priority[52] read %h", PRDATA);
    p_priority_52_rd_cov: cover (access && !PWRITE && hit[52]);
    // priority[53] at 0xd8
    p_priority_53_rd: assert (!(access && !PWRITE && hit[53]) || PRDATA == {29'b0, priority_value[161:159]})
      else $error("chilimix_plic_regs: priority[53] read %h", PRDATA);
    p_priority_53_rd_cov: cover (access && !PWRITE && hit[53]);
    // priority[54] at 0xdc
    p_priority_54_rd: assert (!(access && !PWRITE && hit[54]) || PRDATA == {29'b0, priority_value[164:162]})
      else $error("chilimix_plic_regs: priority[54] read %h", PRDATA);
    p_priority_54_rd_cov: cover (access && !PWRITE && hit[54]);
    // priority[55] at 0xe0
    p_priority_55_rd: assert (!(access && !PWRITE && hit[55]) || PRDATA == {29'b0, priority_value[167:165]})
      else $error("chilimix_plic_regs: priority[55] read %h", PRDATA);
    p_priority_55_rd_cov: cover (access && !PWRITE && hit[55]);
    // priority[56] at 0xe4
    p_priority_56_rd: assert (!(access && !PWRITE && hit[56]) || PRDATA == {29'b0, priority_value[170:168]})
      else $error("chilimix_plic_regs: priority[56] read %h", PRDATA);
    p_priority_56_rd_cov: cover (access && !PWRITE && hit[56]);
    // priority[57] at 0xe8
    p_priority_57_rd: assert (!(access && !PWRITE && hit[57]) || PRDATA == {29'b0, priority_value[173:171]})
      else $error("chilimix_plic_regs: priority[57] read %h", PRDATA);
    p_priority_57_rd_cov: cover (access && !PWRITE && hit[57]);
    // priority[58] at 0xec
    p_priority_58_rd: assert (!(access && !PWRITE && hit[58]) || PRDATA == {29'b0, priority_value[176:174]})
      else $error("chilimix_plic_regs: priority[58] read %h", PRDATA);
    p_priority_58_rd_cov: cover (access && !PWRITE && hit[58]);
    // priority[59] at 0xf0
    p_priority_59_rd: assert (!(access && !PWRITE && hit[59]) || PRDATA == {29'b0, priority_value[179:177]})
      else $error("chilimix_plic_regs: priority[59] read %h", PRDATA);
    p_priority_59_rd_cov: cover (access && !PWRITE && hit[59]);
    // priority[60] at 0xf4
    p_priority_60_rd: assert (!(access && !PWRITE && hit[60]) || PRDATA == {29'b0, priority_value[182:180]})
      else $error("chilimix_plic_regs: priority[60] read %h", PRDATA);
    p_priority_60_rd_cov: cover (access && !PWRITE && hit[60]);
    // priority[61] at 0xf8
    p_priority_61_rd: assert (!(access && !PWRITE && hit[61]) || PRDATA == {29'b0, priority_value[185:183]})
      else $error("chilimix_plic_regs: priority[61] read %h", PRDATA);
    p_priority_61_rd_cov: cover (access && !PWRITE && hit[61]);
    // priority[62] at 0xfc
    p_priority_62_rd: assert (!(access && !PWRITE && hit[62]) || PRDATA == {29'b0, priority_value[188:186]})
      else $error("chilimix_plic_regs: priority[62] read %h", PRDATA);
    p_priority_62_rd_cov: cover (access && !PWRITE && hit[62]);
    // pending0 at 0x1000
    p_pending0_rd: assert (!(access && !PWRITE && hit[63]) || PRDATA == {pending0_src, 1'b0})
      else $error("chilimix_plic_regs: pending0 read %h", PRDATA);
    p_pending0_rd_cov: cover (access && !PWRITE && hit[63]);
    // pending1 at 0x1004
    p_pending1_rd: assert (!(access && !PWRITE && hit[64]) || PRDATA == pending1_src)
      else $error("chilimix_plic_regs: pending1 read %h", PRDATA);
    p_pending1_rd_cov: cover (access && !PWRITE && hit[64]);
    // enable0[0] at 0x2000
    p_enable0_0_rd: assert (!(access && !PWRITE && hit[65]) || PRDATA == ((N_CTX > 0) ? {enable0_src[30:0], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[0] read %h", PRDATA);
    p_enable0_0_rd_cov: cover (access && !PWRITE && hit[65]);
    // enable1[0] at 0x2004
    p_enable1_0_rd: assert (!(access && !PWRITE && hit[66]) || PRDATA == ((N_CTX > 0) ? enable1_src[31:0] : '0))
      else $error("chilimix_plic_regs: enable1[0] read %h", PRDATA);
    p_enable1_0_rd_cov: cover (access && !PWRITE && hit[66]);
    // enable0[1] at 0x2080
    p_enable0_1_rd: assert (!(access && !PWRITE && hit[67]) || PRDATA == ((N_CTX > 1) ? {enable0_src[61:31], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[1] read %h", PRDATA);
    p_enable0_1_rd_cov: cover (access && !PWRITE && hit[67]);
    // enable1[1] at 0x2084
    p_enable1_1_rd: assert (!(access && !PWRITE && hit[68]) || PRDATA == ((N_CTX > 1) ? enable1_src[63:32] : '0))
      else $error("chilimix_plic_regs: enable1[1] read %h", PRDATA);
    p_enable1_1_rd_cov: cover (access && !PWRITE && hit[68]);
    // enable0[2] at 0x2100
    p_enable0_2_rd: assert (!(access && !PWRITE && hit[69]) || PRDATA == ((N_CTX > 2) ? {enable0_src[92:62], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[2] read %h", PRDATA);
    p_enable0_2_rd_cov: cover (access && !PWRITE && hit[69]);
    // enable1[2] at 0x2104
    p_enable1_2_rd: assert (!(access && !PWRITE && hit[70]) || PRDATA == ((N_CTX > 2) ? enable1_src[95:64] : '0))
      else $error("chilimix_plic_regs: enable1[2] read %h", PRDATA);
    p_enable1_2_rd_cov: cover (access && !PWRITE && hit[70]);
    // enable0[3] at 0x2180
    p_enable0_3_rd: assert (!(access && !PWRITE && hit[71]) || PRDATA == ((N_CTX > 3) ? {enable0_src[123:93], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[3] read %h", PRDATA);
    p_enable0_3_rd_cov: cover (access && !PWRITE && hit[71]);
    // enable1[3] at 0x2184
    p_enable1_3_rd: assert (!(access && !PWRITE && hit[72]) || PRDATA == ((N_CTX > 3) ? enable1_src[127:96] : '0))
      else $error("chilimix_plic_regs: enable1[3] read %h", PRDATA);
    p_enable1_3_rd_cov: cover (access && !PWRITE && hit[72]);
    // enable0[4] at 0x2200
    p_enable0_4_rd: assert (!(access && !PWRITE && hit[73]) || PRDATA == ((N_CTX > 4) ? {enable0_src[154:124], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[4] read %h", PRDATA);
    p_enable0_4_rd_cov: cover (access && !PWRITE && hit[73]);
    // enable1[4] at 0x2204
    p_enable1_4_rd: assert (!(access && !PWRITE && hit[74]) || PRDATA == ((N_CTX > 4) ? enable1_src[159:128] : '0))
      else $error("chilimix_plic_regs: enable1[4] read %h", PRDATA);
    p_enable1_4_rd_cov: cover (access && !PWRITE && hit[74]);
    // enable0[5] at 0x2280
    p_enable0_5_rd: assert (!(access && !PWRITE && hit[75]) || PRDATA == ((N_CTX > 5) ? {enable0_src[185:155], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[5] read %h", PRDATA);
    p_enable0_5_rd_cov: cover (access && !PWRITE && hit[75]);
    // enable1[5] at 0x2284
    p_enable1_5_rd: assert (!(access && !PWRITE && hit[76]) || PRDATA == ((N_CTX > 5) ? enable1_src[191:160] : '0))
      else $error("chilimix_plic_regs: enable1[5] read %h", PRDATA);
    p_enable1_5_rd_cov: cover (access && !PWRITE && hit[76]);
    // enable0[6] at 0x2300
    p_enable0_6_rd: assert (!(access && !PWRITE && hit[77]) || PRDATA == ((N_CTX > 6) ? {enable0_src[216:186], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[6] read %h", PRDATA);
    p_enable0_6_rd_cov: cover (access && !PWRITE && hit[77]);
    // enable1[6] at 0x2304
    p_enable1_6_rd: assert (!(access && !PWRITE && hit[78]) || PRDATA == ((N_CTX > 6) ? enable1_src[223:192] : '0))
      else $error("chilimix_plic_regs: enable1[6] read %h", PRDATA);
    p_enable1_6_rd_cov: cover (access && !PWRITE && hit[78]);
    // enable0[7] at 0x2380
    p_enable0_7_rd: assert (!(access && !PWRITE && hit[79]) || PRDATA == ((N_CTX > 7) ? {enable0_src[247:217], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[7] read %h", PRDATA);
    p_enable0_7_rd_cov: cover (access && !PWRITE && hit[79]);
    // enable1[7] at 0x2384
    p_enable1_7_rd: assert (!(access && !PWRITE && hit[80]) || PRDATA == ((N_CTX > 7) ? enable1_src[255:224] : '0))
      else $error("chilimix_plic_regs: enable1[7] read %h", PRDATA);
    p_enable1_7_rd_cov: cover (access && !PWRITE && hit[80]);
    // enable0[8] at 0x2400
    p_enable0_8_rd: assert (!(access && !PWRITE && hit[81]) || PRDATA == ((N_CTX > 8) ? {enable0_src[278:248], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[8] read %h", PRDATA);
    p_enable0_8_rd_cov: cover (access && !PWRITE && hit[81]);
    // enable1[8] at 0x2404
    p_enable1_8_rd: assert (!(access && !PWRITE && hit[82]) || PRDATA == ((N_CTX > 8) ? enable1_src[287:256] : '0))
      else $error("chilimix_plic_regs: enable1[8] read %h", PRDATA);
    p_enable1_8_rd_cov: cover (access && !PWRITE && hit[82]);
    // enable0[9] at 0x2480
    p_enable0_9_rd: assert (!(access && !PWRITE && hit[83]) || PRDATA == ((N_CTX > 9) ? {enable0_src[309:279], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[9] read %h", PRDATA);
    p_enable0_9_rd_cov: cover (access && !PWRITE && hit[83]);
    // enable1[9] at 0x2484
    p_enable1_9_rd: assert (!(access && !PWRITE && hit[84]) || PRDATA == ((N_CTX > 9) ? enable1_src[319:288] : '0))
      else $error("chilimix_plic_regs: enable1[9] read %h", PRDATA);
    p_enable1_9_rd_cov: cover (access && !PWRITE && hit[84]);
    // enable0[10] at 0x2500
    p_enable0_10_rd: assert (!(access && !PWRITE && hit[85]) || PRDATA == ((N_CTX > 10) ? {enable0_src[340:310], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[10] read %h", PRDATA);
    p_enable0_10_rd_cov: cover (access && !PWRITE && hit[85]);
    // enable1[10] at 0x2504
    p_enable1_10_rd: assert (!(access && !PWRITE && hit[86]) || PRDATA == ((N_CTX > 10) ? enable1_src[351:320] : '0))
      else $error("chilimix_plic_regs: enable1[10] read %h", PRDATA);
    p_enable1_10_rd_cov: cover (access && !PWRITE && hit[86]);
    // enable0[11] at 0x2580
    p_enable0_11_rd: assert (!(access && !PWRITE && hit[87]) || PRDATA == ((N_CTX > 11) ? {enable0_src[371:341], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[11] read %h", PRDATA);
    p_enable0_11_rd_cov: cover (access && !PWRITE && hit[87]);
    // enable1[11] at 0x2584
    p_enable1_11_rd: assert (!(access && !PWRITE && hit[88]) || PRDATA == ((N_CTX > 11) ? enable1_src[383:352] : '0))
      else $error("chilimix_plic_regs: enable1[11] read %h", PRDATA);
    p_enable1_11_rd_cov: cover (access && !PWRITE && hit[88]);
    // enable0[12] at 0x2600
    p_enable0_12_rd: assert (!(access && !PWRITE && hit[89]) || PRDATA == ((N_CTX > 12) ? {enable0_src[402:372], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[12] read %h", PRDATA);
    p_enable0_12_rd_cov: cover (access && !PWRITE && hit[89]);
    // enable1[12] at 0x2604
    p_enable1_12_rd: assert (!(access && !PWRITE && hit[90]) || PRDATA == ((N_CTX > 12) ? enable1_src[415:384] : '0))
      else $error("chilimix_plic_regs: enable1[12] read %h", PRDATA);
    p_enable1_12_rd_cov: cover (access && !PWRITE && hit[90]);
    // enable0[13] at 0x2680
    p_enable0_13_rd: assert (!(access && !PWRITE && hit[91]) || PRDATA == ((N_CTX > 13) ? {enable0_src[433:403], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[13] read %h", PRDATA);
    p_enable0_13_rd_cov: cover (access && !PWRITE && hit[91]);
    // enable1[13] at 0x2684
    p_enable1_13_rd: assert (!(access && !PWRITE && hit[92]) || PRDATA == ((N_CTX > 13) ? enable1_src[447:416] : '0))
      else $error("chilimix_plic_regs: enable1[13] read %h", PRDATA);
    p_enable1_13_rd_cov: cover (access && !PWRITE && hit[92]);
    // enable0[14] at 0x2700
    p_enable0_14_rd: assert (!(access && !PWRITE && hit[93]) || PRDATA == ((N_CTX > 14) ? {enable0_src[464:434], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[14] read %h", PRDATA);
    p_enable0_14_rd_cov: cover (access && !PWRITE && hit[93]);
    // enable1[14] at 0x2704
    p_enable1_14_rd: assert (!(access && !PWRITE && hit[94]) || PRDATA == ((N_CTX > 14) ? enable1_src[479:448] : '0))
      else $error("chilimix_plic_regs: enable1[14] read %h", PRDATA);
    p_enable1_14_rd_cov: cover (access && !PWRITE && hit[94]);
    // enable0[15] at 0x2780
    p_enable0_15_rd: assert (!(access && !PWRITE && hit[95]) || PRDATA == ((N_CTX > 15) ? {enable0_src[495:465], 1'b0} : '0))
      else $error("chilimix_plic_regs: enable0[15] read %h", PRDATA);
    p_enable0_15_rd_cov: cover (access && !PWRITE && hit[95]);
    // enable1[15] at 0x2784
    p_enable1_15_rd: assert (!(access && !PWRITE && hit[96]) || PRDATA == ((N_CTX > 15) ? enable1_src[511:480] : '0))
      else $error("chilimix_plic_regs: enable1[15] read %h", PRDATA);
    p_enable1_15_rd_cov: cover (access && !PWRITE && hit[96]);
    // threshold[0] at 0x200000
    p_threshold_0_rd: assert (!(access && !PWRITE && hit[97]) || PRDATA == ((N_CTX > 0) ? {29'b0, threshold_value[2:0]} : '0))
      else $error("chilimix_plic_regs: threshold[0] read %h", PRDATA);
    p_threshold_0_rd_cov: cover (access && !PWRITE && hit[97]);
    // claim[0] at 0x200004
    p_claim_0_rd: assert (!(access && !PWRITE && hit[98]) || PRDATA == ((N_CTX > 0) ? {26'b0, claim_id[5:0]} : '0))
      else $error("chilimix_plic_regs: claim[0] read %h", PRDATA);
    p_claim_0_rd_cov: cover (access && !PWRITE && hit[98]);
    p_claim_0_rdp: assert (claim_rd[0] == ((N_CTX > 0) ? (access && !PWRITE && hit[98]) : 1'b0))
      else $error("chilimix_plic_regs: claim[0] read pulse wrong");
    // threshold[1] at 0x201000
    p_threshold_1_rd: assert (!(access && !PWRITE && hit[99]) || PRDATA == ((N_CTX > 1) ? {29'b0, threshold_value[5:3]} : '0))
      else $error("chilimix_plic_regs: threshold[1] read %h", PRDATA);
    p_threshold_1_rd_cov: cover (access && !PWRITE && hit[99]);
    // claim[1] at 0x201004
    p_claim_1_rd: assert (!(access && !PWRITE && hit[100]) || PRDATA == ((N_CTX > 1) ? {26'b0, claim_id[11:6]} : '0))
      else $error("chilimix_plic_regs: claim[1] read %h", PRDATA);
    p_claim_1_rd_cov: cover (access && !PWRITE && hit[100]);
    p_claim_1_rdp: assert (claim_rd[1] == ((N_CTX > 1) ? (access && !PWRITE && hit[100]) : 1'b0))
      else $error("chilimix_plic_regs: claim[1] read pulse wrong");
    // threshold[2] at 0x202000
    p_threshold_2_rd: assert (!(access && !PWRITE && hit[101]) || PRDATA == ((N_CTX > 2) ? {29'b0, threshold_value[8:6]} : '0))
      else $error("chilimix_plic_regs: threshold[2] read %h", PRDATA);
    p_threshold_2_rd_cov: cover (access && !PWRITE && hit[101]);
    // claim[2] at 0x202004
    p_claim_2_rd: assert (!(access && !PWRITE && hit[102]) || PRDATA == ((N_CTX > 2) ? {26'b0, claim_id[17:12]} : '0))
      else $error("chilimix_plic_regs: claim[2] read %h", PRDATA);
    p_claim_2_rd_cov: cover (access && !PWRITE && hit[102]);
    p_claim_2_rdp: assert (claim_rd[2] == ((N_CTX > 2) ? (access && !PWRITE && hit[102]) : 1'b0))
      else $error("chilimix_plic_regs: claim[2] read pulse wrong");
    // threshold[3] at 0x203000
    p_threshold_3_rd: assert (!(access && !PWRITE && hit[103]) || PRDATA == ((N_CTX > 3) ? {29'b0, threshold_value[11:9]} : '0))
      else $error("chilimix_plic_regs: threshold[3] read %h", PRDATA);
    p_threshold_3_rd_cov: cover (access && !PWRITE && hit[103]);
    // claim[3] at 0x203004
    p_claim_3_rd: assert (!(access && !PWRITE && hit[104]) || PRDATA == ((N_CTX > 3) ? {26'b0, claim_id[23:18]} : '0))
      else $error("chilimix_plic_regs: claim[3] read %h", PRDATA);
    p_claim_3_rd_cov: cover (access && !PWRITE && hit[104]);
    p_claim_3_rdp: assert (claim_rd[3] == ((N_CTX > 3) ? (access && !PWRITE && hit[104]) : 1'b0))
      else $error("chilimix_plic_regs: claim[3] read pulse wrong");
    // threshold[4] at 0x204000
    p_threshold_4_rd: assert (!(access && !PWRITE && hit[105]) || PRDATA == ((N_CTX > 4) ? {29'b0, threshold_value[14:12]} : '0))
      else $error("chilimix_plic_regs: threshold[4] read %h", PRDATA);
    p_threshold_4_rd_cov: cover (access && !PWRITE && hit[105]);
    // claim[4] at 0x204004
    p_claim_4_rd: assert (!(access && !PWRITE && hit[106]) || PRDATA == ((N_CTX > 4) ? {26'b0, claim_id[29:24]} : '0))
      else $error("chilimix_plic_regs: claim[4] read %h", PRDATA);
    p_claim_4_rd_cov: cover (access && !PWRITE && hit[106]);
    p_claim_4_rdp: assert (claim_rd[4] == ((N_CTX > 4) ? (access && !PWRITE && hit[106]) : 1'b0))
      else $error("chilimix_plic_regs: claim[4] read pulse wrong");
    // threshold[5] at 0x205000
    p_threshold_5_rd: assert (!(access && !PWRITE && hit[107]) || PRDATA == ((N_CTX > 5) ? {29'b0, threshold_value[17:15]} : '0))
      else $error("chilimix_plic_regs: threshold[5] read %h", PRDATA);
    p_threshold_5_rd_cov: cover (access && !PWRITE && hit[107]);
    // claim[5] at 0x205004
    p_claim_5_rd: assert (!(access && !PWRITE && hit[108]) || PRDATA == ((N_CTX > 5) ? {26'b0, claim_id[35:30]} : '0))
      else $error("chilimix_plic_regs: claim[5] read %h", PRDATA);
    p_claim_5_rd_cov: cover (access && !PWRITE && hit[108]);
    p_claim_5_rdp: assert (claim_rd[5] == ((N_CTX > 5) ? (access && !PWRITE && hit[108]) : 1'b0))
      else $error("chilimix_plic_regs: claim[5] read pulse wrong");
    // threshold[6] at 0x206000
    p_threshold_6_rd: assert (!(access && !PWRITE && hit[109]) || PRDATA == ((N_CTX > 6) ? {29'b0, threshold_value[20:18]} : '0))
      else $error("chilimix_plic_regs: threshold[6] read %h", PRDATA);
    p_threshold_6_rd_cov: cover (access && !PWRITE && hit[109]);
    // claim[6] at 0x206004
    p_claim_6_rd: assert (!(access && !PWRITE && hit[110]) || PRDATA == ((N_CTX > 6) ? {26'b0, claim_id[41:36]} : '0))
      else $error("chilimix_plic_regs: claim[6] read %h", PRDATA);
    p_claim_6_rd_cov: cover (access && !PWRITE && hit[110]);
    p_claim_6_rdp: assert (claim_rd[6] == ((N_CTX > 6) ? (access && !PWRITE && hit[110]) : 1'b0))
      else $error("chilimix_plic_regs: claim[6] read pulse wrong");
    // threshold[7] at 0x207000
    p_threshold_7_rd: assert (!(access && !PWRITE && hit[111]) || PRDATA == ((N_CTX > 7) ? {29'b0, threshold_value[23:21]} : '0))
      else $error("chilimix_plic_regs: threshold[7] read %h", PRDATA);
    p_threshold_7_rd_cov: cover (access && !PWRITE && hit[111]);
    // claim[7] at 0x207004
    p_claim_7_rd: assert (!(access && !PWRITE && hit[112]) || PRDATA == ((N_CTX > 7) ? {26'b0, claim_id[47:42]} : '0))
      else $error("chilimix_plic_regs: claim[7] read %h", PRDATA);
    p_claim_7_rd_cov: cover (access && !PWRITE && hit[112]);
    p_claim_7_rdp: assert (claim_rd[7] == ((N_CTX > 7) ? (access && !PWRITE && hit[112]) : 1'b0))
      else $error("chilimix_plic_regs: claim[7] read pulse wrong");
    // threshold[8] at 0x208000
    p_threshold_8_rd: assert (!(access && !PWRITE && hit[113]) || PRDATA == ((N_CTX > 8) ? {29'b0, threshold_value[26:24]} : '0))
      else $error("chilimix_plic_regs: threshold[8] read %h", PRDATA);
    p_threshold_8_rd_cov: cover (access && !PWRITE && hit[113]);
    // claim[8] at 0x208004
    p_claim_8_rd: assert (!(access && !PWRITE && hit[114]) || PRDATA == ((N_CTX > 8) ? {26'b0, claim_id[53:48]} : '0))
      else $error("chilimix_plic_regs: claim[8] read %h", PRDATA);
    p_claim_8_rd_cov: cover (access && !PWRITE && hit[114]);
    p_claim_8_rdp: assert (claim_rd[8] == ((N_CTX > 8) ? (access && !PWRITE && hit[114]) : 1'b0))
      else $error("chilimix_plic_regs: claim[8] read pulse wrong");
    // threshold[9] at 0x209000
    p_threshold_9_rd: assert (!(access && !PWRITE && hit[115]) || PRDATA == ((N_CTX > 9) ? {29'b0, threshold_value[29:27]} : '0))
      else $error("chilimix_plic_regs: threshold[9] read %h", PRDATA);
    p_threshold_9_rd_cov: cover (access && !PWRITE && hit[115]);
    // claim[9] at 0x209004
    p_claim_9_rd: assert (!(access && !PWRITE && hit[116]) || PRDATA == ((N_CTX > 9) ? {26'b0, claim_id[59:54]} : '0))
      else $error("chilimix_plic_regs: claim[9] read %h", PRDATA);
    p_claim_9_rd_cov: cover (access && !PWRITE && hit[116]);
    p_claim_9_rdp: assert (claim_rd[9] == ((N_CTX > 9) ? (access && !PWRITE && hit[116]) : 1'b0))
      else $error("chilimix_plic_regs: claim[9] read pulse wrong");
    // threshold[10] at 0x20a000
    p_threshold_10_rd: assert (!(access && !PWRITE && hit[117]) || PRDATA == ((N_CTX > 10) ? {29'b0, threshold_value[32:30]} : '0))
      else $error("chilimix_plic_regs: threshold[10] read %h", PRDATA);
    p_threshold_10_rd_cov: cover (access && !PWRITE && hit[117]);
    // claim[10] at 0x20a004
    p_claim_10_rd: assert (!(access && !PWRITE && hit[118]) || PRDATA == ((N_CTX > 10) ? {26'b0, claim_id[65:60]} : '0))
      else $error("chilimix_plic_regs: claim[10] read %h", PRDATA);
    p_claim_10_rd_cov: cover (access && !PWRITE && hit[118]);
    p_claim_10_rdp: assert (claim_rd[10] == ((N_CTX > 10) ? (access && !PWRITE && hit[118]) : 1'b0))
      else $error("chilimix_plic_regs: claim[10] read pulse wrong");
    // threshold[11] at 0x20b000
    p_threshold_11_rd: assert (!(access && !PWRITE && hit[119]) || PRDATA == ((N_CTX > 11) ? {29'b0, threshold_value[35:33]} : '0))
      else $error("chilimix_plic_regs: threshold[11] read %h", PRDATA);
    p_threshold_11_rd_cov: cover (access && !PWRITE && hit[119]);
    // claim[11] at 0x20b004
    p_claim_11_rd: assert (!(access && !PWRITE && hit[120]) || PRDATA == ((N_CTX > 11) ? {26'b0, claim_id[71:66]} : '0))
      else $error("chilimix_plic_regs: claim[11] read %h", PRDATA);
    p_claim_11_rd_cov: cover (access && !PWRITE && hit[120]);
    p_claim_11_rdp: assert (claim_rd[11] == ((N_CTX > 11) ? (access && !PWRITE && hit[120]) : 1'b0))
      else $error("chilimix_plic_regs: claim[11] read pulse wrong");
    // threshold[12] at 0x20c000
    p_threshold_12_rd: assert (!(access && !PWRITE && hit[121]) || PRDATA == ((N_CTX > 12) ? {29'b0, threshold_value[38:36]} : '0))
      else $error("chilimix_plic_regs: threshold[12] read %h", PRDATA);
    p_threshold_12_rd_cov: cover (access && !PWRITE && hit[121]);
    // claim[12] at 0x20c004
    p_claim_12_rd: assert (!(access && !PWRITE && hit[122]) || PRDATA == ((N_CTX > 12) ? {26'b0, claim_id[77:72]} : '0))
      else $error("chilimix_plic_regs: claim[12] read %h", PRDATA);
    p_claim_12_rd_cov: cover (access && !PWRITE && hit[122]);
    p_claim_12_rdp: assert (claim_rd[12] == ((N_CTX > 12) ? (access && !PWRITE && hit[122]) : 1'b0))
      else $error("chilimix_plic_regs: claim[12] read pulse wrong");
    // threshold[13] at 0x20d000
    p_threshold_13_rd: assert (!(access && !PWRITE && hit[123]) || PRDATA == ((N_CTX > 13) ? {29'b0, threshold_value[41:39]} : '0))
      else $error("chilimix_plic_regs: threshold[13] read %h", PRDATA);
    p_threshold_13_rd_cov: cover (access && !PWRITE && hit[123]);
    // claim[13] at 0x20d004
    p_claim_13_rd: assert (!(access && !PWRITE && hit[124]) || PRDATA == ((N_CTX > 13) ? {26'b0, claim_id[83:78]} : '0))
      else $error("chilimix_plic_regs: claim[13] read %h", PRDATA);
    p_claim_13_rd_cov: cover (access && !PWRITE && hit[124]);
    p_claim_13_rdp: assert (claim_rd[13] == ((N_CTX > 13) ? (access && !PWRITE && hit[124]) : 1'b0))
      else $error("chilimix_plic_regs: claim[13] read pulse wrong");
    // threshold[14] at 0x20e000
    p_threshold_14_rd: assert (!(access && !PWRITE && hit[125]) || PRDATA == ((N_CTX > 14) ? {29'b0, threshold_value[44:42]} : '0))
      else $error("chilimix_plic_regs: threshold[14] read %h", PRDATA);
    p_threshold_14_rd_cov: cover (access && !PWRITE && hit[125]);
    // claim[14] at 0x20e004
    p_claim_14_rd: assert (!(access && !PWRITE && hit[126]) || PRDATA == ((N_CTX > 14) ? {26'b0, claim_id[89:84]} : '0))
      else $error("chilimix_plic_regs: claim[14] read %h", PRDATA);
    p_claim_14_rd_cov: cover (access && !PWRITE && hit[126]);
    p_claim_14_rdp: assert (claim_rd[14] == ((N_CTX > 14) ? (access && !PWRITE && hit[126]) : 1'b0))
      else $error("chilimix_plic_regs: claim[14] read pulse wrong");
    // threshold[15] at 0x20f000
    p_threshold_15_rd: assert (!(access && !PWRITE && hit[127]) || PRDATA == ((N_CTX > 15) ? {29'b0, threshold_value[47:45]} : '0))
      else $error("chilimix_plic_regs: threshold[15] read %h", PRDATA);
    p_threshold_15_rd_cov: cover (access && !PWRITE && hit[127]);
    // claim[15] at 0x20f004
    p_claim_15_rd: assert (!(access && !PWRITE && hit[128]) || PRDATA == ((N_CTX > 15) ? {26'b0, claim_id[95:90]} : '0))
      else $error("chilimix_plic_regs: claim[15] read %h", PRDATA);
    p_claim_15_rd_cov: cover (access && !PWRITE && hit[128]);
    p_claim_15_rdp: assert (claim_rd[15] == ((N_CTX > 15) ? (access && !PWRITE && hit[128]) : 1'b0))
      else $error("chilimix_plic_regs: claim[15] read pulse wrong");
  end

  // ---- writes and reset values
  always @(posedge clk) begin
    // priority[0] writes
    p_priority_0_wr_cov: cover (rst_n && (access && PWRITE && hit[0]));
    p_priority_0_value_rst: assert (!past_ok || $past(rst_n) || priority_value[2:0] == 3'h0)
      else $error("chilimix_plic_regs: priority[0].value reset value %h", priority_value[2:0]);
    p_priority_0_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[2:0] == ($past((access && PWRITE && hit[0])) ? (($past(priority_value[2:0]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[2:0])))
      else $error("chilimix_plic_regs: priority[0].value is %h after a write / hold", priority_value[2:0]);
    // priority[1] writes
    p_priority_1_wr_cov: cover (rst_n && (access && PWRITE && hit[1]));
    p_priority_1_value_rst: assert (!past_ok || $past(rst_n) || priority_value[5:3] == 3'h0)
      else $error("chilimix_plic_regs: priority[1].value reset value %h", priority_value[5:3]);
    p_priority_1_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[5:3] == ($past((access && PWRITE && hit[1])) ? (($past(priority_value[5:3]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[5:3])))
      else $error("chilimix_plic_regs: priority[1].value is %h after a write / hold", priority_value[5:3]);
    // priority[2] writes
    p_priority_2_wr_cov: cover (rst_n && (access && PWRITE && hit[2]));
    p_priority_2_value_rst: assert (!past_ok || $past(rst_n) || priority_value[8:6] == 3'h0)
      else $error("chilimix_plic_regs: priority[2].value reset value %h", priority_value[8:6]);
    p_priority_2_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[8:6] == ($past((access && PWRITE && hit[2])) ? (($past(priority_value[8:6]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[8:6])))
      else $error("chilimix_plic_regs: priority[2].value is %h after a write / hold", priority_value[8:6]);
    // priority[3] writes
    p_priority_3_wr_cov: cover (rst_n && (access && PWRITE && hit[3]));
    p_priority_3_value_rst: assert (!past_ok || $past(rst_n) || priority_value[11:9] == 3'h0)
      else $error("chilimix_plic_regs: priority[3].value reset value %h", priority_value[11:9]);
    p_priority_3_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[11:9] == ($past((access && PWRITE && hit[3])) ? (($past(priority_value[11:9]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[11:9])))
      else $error("chilimix_plic_regs: priority[3].value is %h after a write / hold", priority_value[11:9]);
    // priority[4] writes
    p_priority_4_wr_cov: cover (rst_n && (access && PWRITE && hit[4]));
    p_priority_4_value_rst: assert (!past_ok || $past(rst_n) || priority_value[14:12] == 3'h0)
      else $error("chilimix_plic_regs: priority[4].value reset value %h", priority_value[14:12]);
    p_priority_4_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[14:12] == ($past((access && PWRITE && hit[4])) ? (($past(priority_value[14:12]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[14:12])))
      else $error("chilimix_plic_regs: priority[4].value is %h after a write / hold", priority_value[14:12]);
    // priority[5] writes
    p_priority_5_wr_cov: cover (rst_n && (access && PWRITE && hit[5]));
    p_priority_5_value_rst: assert (!past_ok || $past(rst_n) || priority_value[17:15] == 3'h0)
      else $error("chilimix_plic_regs: priority[5].value reset value %h", priority_value[17:15]);
    p_priority_5_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[17:15] == ($past((access && PWRITE && hit[5])) ? (($past(priority_value[17:15]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[17:15])))
      else $error("chilimix_plic_regs: priority[5].value is %h after a write / hold", priority_value[17:15]);
    // priority[6] writes
    p_priority_6_wr_cov: cover (rst_n && (access && PWRITE && hit[6]));
    p_priority_6_value_rst: assert (!past_ok || $past(rst_n) || priority_value[20:18] == 3'h0)
      else $error("chilimix_plic_regs: priority[6].value reset value %h", priority_value[20:18]);
    p_priority_6_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[20:18] == ($past((access && PWRITE && hit[6])) ? (($past(priority_value[20:18]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[20:18])))
      else $error("chilimix_plic_regs: priority[6].value is %h after a write / hold", priority_value[20:18]);
    // priority[7] writes
    p_priority_7_wr_cov: cover (rst_n && (access && PWRITE && hit[7]));
    p_priority_7_value_rst: assert (!past_ok || $past(rst_n) || priority_value[23:21] == 3'h0)
      else $error("chilimix_plic_regs: priority[7].value reset value %h", priority_value[23:21]);
    p_priority_7_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[23:21] == ($past((access && PWRITE && hit[7])) ? (($past(priority_value[23:21]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[23:21])))
      else $error("chilimix_plic_regs: priority[7].value is %h after a write / hold", priority_value[23:21]);
    // priority[8] writes
    p_priority_8_wr_cov: cover (rst_n && (access && PWRITE && hit[8]));
    p_priority_8_value_rst: assert (!past_ok || $past(rst_n) || priority_value[26:24] == 3'h0)
      else $error("chilimix_plic_regs: priority[8].value reset value %h", priority_value[26:24]);
    p_priority_8_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[26:24] == ($past((access && PWRITE && hit[8])) ? (($past(priority_value[26:24]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[26:24])))
      else $error("chilimix_plic_regs: priority[8].value is %h after a write / hold", priority_value[26:24]);
    // priority[9] writes
    p_priority_9_wr_cov: cover (rst_n && (access && PWRITE && hit[9]));
    p_priority_9_value_rst: assert (!past_ok || $past(rst_n) || priority_value[29:27] == 3'h0)
      else $error("chilimix_plic_regs: priority[9].value reset value %h", priority_value[29:27]);
    p_priority_9_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[29:27] == ($past((access && PWRITE && hit[9])) ? (($past(priority_value[29:27]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[29:27])))
      else $error("chilimix_plic_regs: priority[9].value is %h after a write / hold", priority_value[29:27]);
    // priority[10] writes
    p_priority_10_wr_cov: cover (rst_n && (access && PWRITE && hit[10]));
    p_priority_10_value_rst: assert (!past_ok || $past(rst_n) || priority_value[32:30] == 3'h0)
      else $error("chilimix_plic_regs: priority[10].value reset value %h", priority_value[32:30]);
    p_priority_10_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[32:30] == ($past((access && PWRITE && hit[10])) ? (($past(priority_value[32:30]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[32:30])))
      else $error("chilimix_plic_regs: priority[10].value is %h after a write / hold", priority_value[32:30]);
    // priority[11] writes
    p_priority_11_wr_cov: cover (rst_n && (access && PWRITE && hit[11]));
    p_priority_11_value_rst: assert (!past_ok || $past(rst_n) || priority_value[35:33] == 3'h0)
      else $error("chilimix_plic_regs: priority[11].value reset value %h", priority_value[35:33]);
    p_priority_11_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[35:33] == ($past((access && PWRITE && hit[11])) ? (($past(priority_value[35:33]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[35:33])))
      else $error("chilimix_plic_regs: priority[11].value is %h after a write / hold", priority_value[35:33]);
    // priority[12] writes
    p_priority_12_wr_cov: cover (rst_n && (access && PWRITE && hit[12]));
    p_priority_12_value_rst: assert (!past_ok || $past(rst_n) || priority_value[38:36] == 3'h0)
      else $error("chilimix_plic_regs: priority[12].value reset value %h", priority_value[38:36]);
    p_priority_12_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[38:36] == ($past((access && PWRITE && hit[12])) ? (($past(priority_value[38:36]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[38:36])))
      else $error("chilimix_plic_regs: priority[12].value is %h after a write / hold", priority_value[38:36]);
    // priority[13] writes
    p_priority_13_wr_cov: cover (rst_n && (access && PWRITE && hit[13]));
    p_priority_13_value_rst: assert (!past_ok || $past(rst_n) || priority_value[41:39] == 3'h0)
      else $error("chilimix_plic_regs: priority[13].value reset value %h", priority_value[41:39]);
    p_priority_13_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[41:39] == ($past((access && PWRITE && hit[13])) ? (($past(priority_value[41:39]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[41:39])))
      else $error("chilimix_plic_regs: priority[13].value is %h after a write / hold", priority_value[41:39]);
    // priority[14] writes
    p_priority_14_wr_cov: cover (rst_n && (access && PWRITE && hit[14]));
    p_priority_14_value_rst: assert (!past_ok || $past(rst_n) || priority_value[44:42] == 3'h0)
      else $error("chilimix_plic_regs: priority[14].value reset value %h", priority_value[44:42]);
    p_priority_14_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[44:42] == ($past((access && PWRITE && hit[14])) ? (($past(priority_value[44:42]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[44:42])))
      else $error("chilimix_plic_regs: priority[14].value is %h after a write / hold", priority_value[44:42]);
    // priority[15] writes
    p_priority_15_wr_cov: cover (rst_n && (access && PWRITE && hit[15]));
    p_priority_15_value_rst: assert (!past_ok || $past(rst_n) || priority_value[47:45] == 3'h0)
      else $error("chilimix_plic_regs: priority[15].value reset value %h", priority_value[47:45]);
    p_priority_15_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[47:45] == ($past((access && PWRITE && hit[15])) ? (($past(priority_value[47:45]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[47:45])))
      else $error("chilimix_plic_regs: priority[15].value is %h after a write / hold", priority_value[47:45]);
    // priority[16] writes
    p_priority_16_wr_cov: cover (rst_n && (access && PWRITE && hit[16]));
    p_priority_16_value_rst: assert (!past_ok || $past(rst_n) || priority_value[50:48] == 3'h0)
      else $error("chilimix_plic_regs: priority[16].value reset value %h", priority_value[50:48]);
    p_priority_16_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[50:48] == ($past((access && PWRITE && hit[16])) ? (($past(priority_value[50:48]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[50:48])))
      else $error("chilimix_plic_regs: priority[16].value is %h after a write / hold", priority_value[50:48]);
    // priority[17] writes
    p_priority_17_wr_cov: cover (rst_n && (access && PWRITE && hit[17]));
    p_priority_17_value_rst: assert (!past_ok || $past(rst_n) || priority_value[53:51] == 3'h0)
      else $error("chilimix_plic_regs: priority[17].value reset value %h", priority_value[53:51]);
    p_priority_17_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[53:51] == ($past((access && PWRITE && hit[17])) ? (($past(priority_value[53:51]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[53:51])))
      else $error("chilimix_plic_regs: priority[17].value is %h after a write / hold", priority_value[53:51]);
    // priority[18] writes
    p_priority_18_wr_cov: cover (rst_n && (access && PWRITE && hit[18]));
    p_priority_18_value_rst: assert (!past_ok || $past(rst_n) || priority_value[56:54] == 3'h0)
      else $error("chilimix_plic_regs: priority[18].value reset value %h", priority_value[56:54]);
    p_priority_18_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[56:54] == ($past((access && PWRITE && hit[18])) ? (($past(priority_value[56:54]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[56:54])))
      else $error("chilimix_plic_regs: priority[18].value is %h after a write / hold", priority_value[56:54]);
    // priority[19] writes
    p_priority_19_wr_cov: cover (rst_n && (access && PWRITE && hit[19]));
    p_priority_19_value_rst: assert (!past_ok || $past(rst_n) || priority_value[59:57] == 3'h0)
      else $error("chilimix_plic_regs: priority[19].value reset value %h", priority_value[59:57]);
    p_priority_19_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[59:57] == ($past((access && PWRITE && hit[19])) ? (($past(priority_value[59:57]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[59:57])))
      else $error("chilimix_plic_regs: priority[19].value is %h after a write / hold", priority_value[59:57]);
    // priority[20] writes
    p_priority_20_wr_cov: cover (rst_n && (access && PWRITE && hit[20]));
    p_priority_20_value_rst: assert (!past_ok || $past(rst_n) || priority_value[62:60] == 3'h0)
      else $error("chilimix_plic_regs: priority[20].value reset value %h", priority_value[62:60]);
    p_priority_20_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[62:60] == ($past((access && PWRITE && hit[20])) ? (($past(priority_value[62:60]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[62:60])))
      else $error("chilimix_plic_regs: priority[20].value is %h after a write / hold", priority_value[62:60]);
    // priority[21] writes
    p_priority_21_wr_cov: cover (rst_n && (access && PWRITE && hit[21]));
    p_priority_21_value_rst: assert (!past_ok || $past(rst_n) || priority_value[65:63] == 3'h0)
      else $error("chilimix_plic_regs: priority[21].value reset value %h", priority_value[65:63]);
    p_priority_21_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[65:63] == ($past((access && PWRITE && hit[21])) ? (($past(priority_value[65:63]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[65:63])))
      else $error("chilimix_plic_regs: priority[21].value is %h after a write / hold", priority_value[65:63]);
    // priority[22] writes
    p_priority_22_wr_cov: cover (rst_n && (access && PWRITE && hit[22]));
    p_priority_22_value_rst: assert (!past_ok || $past(rst_n) || priority_value[68:66] == 3'h0)
      else $error("chilimix_plic_regs: priority[22].value reset value %h", priority_value[68:66]);
    p_priority_22_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[68:66] == ($past((access && PWRITE && hit[22])) ? (($past(priority_value[68:66]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[68:66])))
      else $error("chilimix_plic_regs: priority[22].value is %h after a write / hold", priority_value[68:66]);
    // priority[23] writes
    p_priority_23_wr_cov: cover (rst_n && (access && PWRITE && hit[23]));
    p_priority_23_value_rst: assert (!past_ok || $past(rst_n) || priority_value[71:69] == 3'h0)
      else $error("chilimix_plic_regs: priority[23].value reset value %h", priority_value[71:69]);
    p_priority_23_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[71:69] == ($past((access && PWRITE && hit[23])) ? (($past(priority_value[71:69]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[71:69])))
      else $error("chilimix_plic_regs: priority[23].value is %h after a write / hold", priority_value[71:69]);
    // priority[24] writes
    p_priority_24_wr_cov: cover (rst_n && (access && PWRITE && hit[24]));
    p_priority_24_value_rst: assert (!past_ok || $past(rst_n) || priority_value[74:72] == 3'h0)
      else $error("chilimix_plic_regs: priority[24].value reset value %h", priority_value[74:72]);
    p_priority_24_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[74:72] == ($past((access && PWRITE && hit[24])) ? (($past(priority_value[74:72]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[74:72])))
      else $error("chilimix_plic_regs: priority[24].value is %h after a write / hold", priority_value[74:72]);
    // priority[25] writes
    p_priority_25_wr_cov: cover (rst_n && (access && PWRITE && hit[25]));
    p_priority_25_value_rst: assert (!past_ok || $past(rst_n) || priority_value[77:75] == 3'h0)
      else $error("chilimix_plic_regs: priority[25].value reset value %h", priority_value[77:75]);
    p_priority_25_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[77:75] == ($past((access && PWRITE && hit[25])) ? (($past(priority_value[77:75]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[77:75])))
      else $error("chilimix_plic_regs: priority[25].value is %h after a write / hold", priority_value[77:75]);
    // priority[26] writes
    p_priority_26_wr_cov: cover (rst_n && (access && PWRITE && hit[26]));
    p_priority_26_value_rst: assert (!past_ok || $past(rst_n) || priority_value[80:78] == 3'h0)
      else $error("chilimix_plic_regs: priority[26].value reset value %h", priority_value[80:78]);
    p_priority_26_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[80:78] == ($past((access && PWRITE && hit[26])) ? (($past(priority_value[80:78]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[80:78])))
      else $error("chilimix_plic_regs: priority[26].value is %h after a write / hold", priority_value[80:78]);
    // priority[27] writes
    p_priority_27_wr_cov: cover (rst_n && (access && PWRITE && hit[27]));
    p_priority_27_value_rst: assert (!past_ok || $past(rst_n) || priority_value[83:81] == 3'h0)
      else $error("chilimix_plic_regs: priority[27].value reset value %h", priority_value[83:81]);
    p_priority_27_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[83:81] == ($past((access && PWRITE && hit[27])) ? (($past(priority_value[83:81]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[83:81])))
      else $error("chilimix_plic_regs: priority[27].value is %h after a write / hold", priority_value[83:81]);
    // priority[28] writes
    p_priority_28_wr_cov: cover (rst_n && (access && PWRITE && hit[28]));
    p_priority_28_value_rst: assert (!past_ok || $past(rst_n) || priority_value[86:84] == 3'h0)
      else $error("chilimix_plic_regs: priority[28].value reset value %h", priority_value[86:84]);
    p_priority_28_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[86:84] == ($past((access && PWRITE && hit[28])) ? (($past(priority_value[86:84]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[86:84])))
      else $error("chilimix_plic_regs: priority[28].value is %h after a write / hold", priority_value[86:84]);
    // priority[29] writes
    p_priority_29_wr_cov: cover (rst_n && (access && PWRITE && hit[29]));
    p_priority_29_value_rst: assert (!past_ok || $past(rst_n) || priority_value[89:87] == 3'h0)
      else $error("chilimix_plic_regs: priority[29].value reset value %h", priority_value[89:87]);
    p_priority_29_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[89:87] == ($past((access && PWRITE && hit[29])) ? (($past(priority_value[89:87]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[89:87])))
      else $error("chilimix_plic_regs: priority[29].value is %h after a write / hold", priority_value[89:87]);
    // priority[30] writes
    p_priority_30_wr_cov: cover (rst_n && (access && PWRITE && hit[30]));
    p_priority_30_value_rst: assert (!past_ok || $past(rst_n) || priority_value[92:90] == 3'h0)
      else $error("chilimix_plic_regs: priority[30].value reset value %h", priority_value[92:90]);
    p_priority_30_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[92:90] == ($past((access && PWRITE && hit[30])) ? (($past(priority_value[92:90]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[92:90])))
      else $error("chilimix_plic_regs: priority[30].value is %h after a write / hold", priority_value[92:90]);
    // priority[31] writes
    p_priority_31_wr_cov: cover (rst_n && (access && PWRITE && hit[31]));
    p_priority_31_value_rst: assert (!past_ok || $past(rst_n) || priority_value[95:93] == 3'h0)
      else $error("chilimix_plic_regs: priority[31].value reset value %h", priority_value[95:93]);
    p_priority_31_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[95:93] == ($past((access && PWRITE && hit[31])) ? (($past(priority_value[95:93]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[95:93])))
      else $error("chilimix_plic_regs: priority[31].value is %h after a write / hold", priority_value[95:93]);
    // priority[32] writes
    p_priority_32_wr_cov: cover (rst_n && (access && PWRITE && hit[32]));
    p_priority_32_value_rst: assert (!past_ok || $past(rst_n) || priority_value[98:96] == 3'h0)
      else $error("chilimix_plic_regs: priority[32].value reset value %h", priority_value[98:96]);
    p_priority_32_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[98:96] == ($past((access && PWRITE && hit[32])) ? (($past(priority_value[98:96]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[98:96])))
      else $error("chilimix_plic_regs: priority[32].value is %h after a write / hold", priority_value[98:96]);
    // priority[33] writes
    p_priority_33_wr_cov: cover (rst_n && (access && PWRITE && hit[33]));
    p_priority_33_value_rst: assert (!past_ok || $past(rst_n) || priority_value[101:99] == 3'h0)
      else $error("chilimix_plic_regs: priority[33].value reset value %h", priority_value[101:99]);
    p_priority_33_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[101:99] == ($past((access && PWRITE && hit[33])) ? (($past(priority_value[101:99]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[101:99])))
      else $error("chilimix_plic_regs: priority[33].value is %h after a write / hold", priority_value[101:99]);
    // priority[34] writes
    p_priority_34_wr_cov: cover (rst_n && (access && PWRITE && hit[34]));
    p_priority_34_value_rst: assert (!past_ok || $past(rst_n) || priority_value[104:102] == 3'h0)
      else $error("chilimix_plic_regs: priority[34].value reset value %h", priority_value[104:102]);
    p_priority_34_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[104:102] == ($past((access && PWRITE && hit[34])) ? (($past(priority_value[104:102]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[104:102])))
      else $error("chilimix_plic_regs: priority[34].value is %h after a write / hold", priority_value[104:102]);
    // priority[35] writes
    p_priority_35_wr_cov: cover (rst_n && (access && PWRITE && hit[35]));
    p_priority_35_value_rst: assert (!past_ok || $past(rst_n) || priority_value[107:105] == 3'h0)
      else $error("chilimix_plic_regs: priority[35].value reset value %h", priority_value[107:105]);
    p_priority_35_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[107:105] == ($past((access && PWRITE && hit[35])) ? (($past(priority_value[107:105]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[107:105])))
      else $error("chilimix_plic_regs: priority[35].value is %h after a write / hold", priority_value[107:105]);
    // priority[36] writes
    p_priority_36_wr_cov: cover (rst_n && (access && PWRITE && hit[36]));
    p_priority_36_value_rst: assert (!past_ok || $past(rst_n) || priority_value[110:108] == 3'h0)
      else $error("chilimix_plic_regs: priority[36].value reset value %h", priority_value[110:108]);
    p_priority_36_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[110:108] == ($past((access && PWRITE && hit[36])) ? (($past(priority_value[110:108]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[110:108])))
      else $error("chilimix_plic_regs: priority[36].value is %h after a write / hold", priority_value[110:108]);
    // priority[37] writes
    p_priority_37_wr_cov: cover (rst_n && (access && PWRITE && hit[37]));
    p_priority_37_value_rst: assert (!past_ok || $past(rst_n) || priority_value[113:111] == 3'h0)
      else $error("chilimix_plic_regs: priority[37].value reset value %h", priority_value[113:111]);
    p_priority_37_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[113:111] == ($past((access && PWRITE && hit[37])) ? (($past(priority_value[113:111]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[113:111])))
      else $error("chilimix_plic_regs: priority[37].value is %h after a write / hold", priority_value[113:111]);
    // priority[38] writes
    p_priority_38_wr_cov: cover (rst_n && (access && PWRITE && hit[38]));
    p_priority_38_value_rst: assert (!past_ok || $past(rst_n) || priority_value[116:114] == 3'h0)
      else $error("chilimix_plic_regs: priority[38].value reset value %h", priority_value[116:114]);
    p_priority_38_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[116:114] == ($past((access && PWRITE && hit[38])) ? (($past(priority_value[116:114]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[116:114])))
      else $error("chilimix_plic_regs: priority[38].value is %h after a write / hold", priority_value[116:114]);
    // priority[39] writes
    p_priority_39_wr_cov: cover (rst_n && (access && PWRITE && hit[39]));
    p_priority_39_value_rst: assert (!past_ok || $past(rst_n) || priority_value[119:117] == 3'h0)
      else $error("chilimix_plic_regs: priority[39].value reset value %h", priority_value[119:117]);
    p_priority_39_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[119:117] == ($past((access && PWRITE && hit[39])) ? (($past(priority_value[119:117]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[119:117])))
      else $error("chilimix_plic_regs: priority[39].value is %h after a write / hold", priority_value[119:117]);
    // priority[40] writes
    p_priority_40_wr_cov: cover (rst_n && (access && PWRITE && hit[40]));
    p_priority_40_value_rst: assert (!past_ok || $past(rst_n) || priority_value[122:120] == 3'h0)
      else $error("chilimix_plic_regs: priority[40].value reset value %h", priority_value[122:120]);
    p_priority_40_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[122:120] == ($past((access && PWRITE && hit[40])) ? (($past(priority_value[122:120]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[122:120])))
      else $error("chilimix_plic_regs: priority[40].value is %h after a write / hold", priority_value[122:120]);
    // priority[41] writes
    p_priority_41_wr_cov: cover (rst_n && (access && PWRITE && hit[41]));
    p_priority_41_value_rst: assert (!past_ok || $past(rst_n) || priority_value[125:123] == 3'h0)
      else $error("chilimix_plic_regs: priority[41].value reset value %h", priority_value[125:123]);
    p_priority_41_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[125:123] == ($past((access && PWRITE && hit[41])) ? (($past(priority_value[125:123]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[125:123])))
      else $error("chilimix_plic_regs: priority[41].value is %h after a write / hold", priority_value[125:123]);
    // priority[42] writes
    p_priority_42_wr_cov: cover (rst_n && (access && PWRITE && hit[42]));
    p_priority_42_value_rst: assert (!past_ok || $past(rst_n) || priority_value[128:126] == 3'h0)
      else $error("chilimix_plic_regs: priority[42].value reset value %h", priority_value[128:126]);
    p_priority_42_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[128:126] == ($past((access && PWRITE && hit[42])) ? (($past(priority_value[128:126]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[128:126])))
      else $error("chilimix_plic_regs: priority[42].value is %h after a write / hold", priority_value[128:126]);
    // priority[43] writes
    p_priority_43_wr_cov: cover (rst_n && (access && PWRITE && hit[43]));
    p_priority_43_value_rst: assert (!past_ok || $past(rst_n) || priority_value[131:129] == 3'h0)
      else $error("chilimix_plic_regs: priority[43].value reset value %h", priority_value[131:129]);
    p_priority_43_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[131:129] == ($past((access && PWRITE && hit[43])) ? (($past(priority_value[131:129]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[131:129])))
      else $error("chilimix_plic_regs: priority[43].value is %h after a write / hold", priority_value[131:129]);
    // priority[44] writes
    p_priority_44_wr_cov: cover (rst_n && (access && PWRITE && hit[44]));
    p_priority_44_value_rst: assert (!past_ok || $past(rst_n) || priority_value[134:132] == 3'h0)
      else $error("chilimix_plic_regs: priority[44].value reset value %h", priority_value[134:132]);
    p_priority_44_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[134:132] == ($past((access && PWRITE && hit[44])) ? (($past(priority_value[134:132]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[134:132])))
      else $error("chilimix_plic_regs: priority[44].value is %h after a write / hold", priority_value[134:132]);
    // priority[45] writes
    p_priority_45_wr_cov: cover (rst_n && (access && PWRITE && hit[45]));
    p_priority_45_value_rst: assert (!past_ok || $past(rst_n) || priority_value[137:135] == 3'h0)
      else $error("chilimix_plic_regs: priority[45].value reset value %h", priority_value[137:135]);
    p_priority_45_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[137:135] == ($past((access && PWRITE && hit[45])) ? (($past(priority_value[137:135]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[137:135])))
      else $error("chilimix_plic_regs: priority[45].value is %h after a write / hold", priority_value[137:135]);
    // priority[46] writes
    p_priority_46_wr_cov: cover (rst_n && (access && PWRITE && hit[46]));
    p_priority_46_value_rst: assert (!past_ok || $past(rst_n) || priority_value[140:138] == 3'h0)
      else $error("chilimix_plic_regs: priority[46].value reset value %h", priority_value[140:138]);
    p_priority_46_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[140:138] == ($past((access && PWRITE && hit[46])) ? (($past(priority_value[140:138]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[140:138])))
      else $error("chilimix_plic_regs: priority[46].value is %h after a write / hold", priority_value[140:138]);
    // priority[47] writes
    p_priority_47_wr_cov: cover (rst_n && (access && PWRITE && hit[47]));
    p_priority_47_value_rst: assert (!past_ok || $past(rst_n) || priority_value[143:141] == 3'h0)
      else $error("chilimix_plic_regs: priority[47].value reset value %h", priority_value[143:141]);
    p_priority_47_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[143:141] == ($past((access && PWRITE && hit[47])) ? (($past(priority_value[143:141]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[143:141])))
      else $error("chilimix_plic_regs: priority[47].value is %h after a write / hold", priority_value[143:141]);
    // priority[48] writes
    p_priority_48_wr_cov: cover (rst_n && (access && PWRITE && hit[48]));
    p_priority_48_value_rst: assert (!past_ok || $past(rst_n) || priority_value[146:144] == 3'h0)
      else $error("chilimix_plic_regs: priority[48].value reset value %h", priority_value[146:144]);
    p_priority_48_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[146:144] == ($past((access && PWRITE && hit[48])) ? (($past(priority_value[146:144]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[146:144])))
      else $error("chilimix_plic_regs: priority[48].value is %h after a write / hold", priority_value[146:144]);
    // priority[49] writes
    p_priority_49_wr_cov: cover (rst_n && (access && PWRITE && hit[49]));
    p_priority_49_value_rst: assert (!past_ok || $past(rst_n) || priority_value[149:147] == 3'h0)
      else $error("chilimix_plic_regs: priority[49].value reset value %h", priority_value[149:147]);
    p_priority_49_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[149:147] == ($past((access && PWRITE && hit[49])) ? (($past(priority_value[149:147]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[149:147])))
      else $error("chilimix_plic_regs: priority[49].value is %h after a write / hold", priority_value[149:147]);
    // priority[50] writes
    p_priority_50_wr_cov: cover (rst_n && (access && PWRITE && hit[50]));
    p_priority_50_value_rst: assert (!past_ok || $past(rst_n) || priority_value[152:150] == 3'h0)
      else $error("chilimix_plic_regs: priority[50].value reset value %h", priority_value[152:150]);
    p_priority_50_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[152:150] == ($past((access && PWRITE && hit[50])) ? (($past(priority_value[152:150]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[152:150])))
      else $error("chilimix_plic_regs: priority[50].value is %h after a write / hold", priority_value[152:150]);
    // priority[51] writes
    p_priority_51_wr_cov: cover (rst_n && (access && PWRITE && hit[51]));
    p_priority_51_value_rst: assert (!past_ok || $past(rst_n) || priority_value[155:153] == 3'h0)
      else $error("chilimix_plic_regs: priority[51].value reset value %h", priority_value[155:153]);
    p_priority_51_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[155:153] == ($past((access && PWRITE && hit[51])) ? (($past(priority_value[155:153]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[155:153])))
      else $error("chilimix_plic_regs: priority[51].value is %h after a write / hold", priority_value[155:153]);
    // priority[52] writes
    p_priority_52_wr_cov: cover (rst_n && (access && PWRITE && hit[52]));
    p_priority_52_value_rst: assert (!past_ok || $past(rst_n) || priority_value[158:156] == 3'h0)
      else $error("chilimix_plic_regs: priority[52].value reset value %h", priority_value[158:156]);
    p_priority_52_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[158:156] == ($past((access && PWRITE && hit[52])) ? (($past(priority_value[158:156]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[158:156])))
      else $error("chilimix_plic_regs: priority[52].value is %h after a write / hold", priority_value[158:156]);
    // priority[53] writes
    p_priority_53_wr_cov: cover (rst_n && (access && PWRITE && hit[53]));
    p_priority_53_value_rst: assert (!past_ok || $past(rst_n) || priority_value[161:159] == 3'h0)
      else $error("chilimix_plic_regs: priority[53].value reset value %h", priority_value[161:159]);
    p_priority_53_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[161:159] == ($past((access && PWRITE && hit[53])) ? (($past(priority_value[161:159]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[161:159])))
      else $error("chilimix_plic_regs: priority[53].value is %h after a write / hold", priority_value[161:159]);
    // priority[54] writes
    p_priority_54_wr_cov: cover (rst_n && (access && PWRITE && hit[54]));
    p_priority_54_value_rst: assert (!past_ok || $past(rst_n) || priority_value[164:162] == 3'h0)
      else $error("chilimix_plic_regs: priority[54].value reset value %h", priority_value[164:162]);
    p_priority_54_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[164:162] == ($past((access && PWRITE && hit[54])) ? (($past(priority_value[164:162]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[164:162])))
      else $error("chilimix_plic_regs: priority[54].value is %h after a write / hold", priority_value[164:162]);
    // priority[55] writes
    p_priority_55_wr_cov: cover (rst_n && (access && PWRITE && hit[55]));
    p_priority_55_value_rst: assert (!past_ok || $past(rst_n) || priority_value[167:165] == 3'h0)
      else $error("chilimix_plic_regs: priority[55].value reset value %h", priority_value[167:165]);
    p_priority_55_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[167:165] == ($past((access && PWRITE && hit[55])) ? (($past(priority_value[167:165]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[167:165])))
      else $error("chilimix_plic_regs: priority[55].value is %h after a write / hold", priority_value[167:165]);
    // priority[56] writes
    p_priority_56_wr_cov: cover (rst_n && (access && PWRITE && hit[56]));
    p_priority_56_value_rst: assert (!past_ok || $past(rst_n) || priority_value[170:168] == 3'h0)
      else $error("chilimix_plic_regs: priority[56].value reset value %h", priority_value[170:168]);
    p_priority_56_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[170:168] == ($past((access && PWRITE && hit[56])) ? (($past(priority_value[170:168]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[170:168])))
      else $error("chilimix_plic_regs: priority[56].value is %h after a write / hold", priority_value[170:168]);
    // priority[57] writes
    p_priority_57_wr_cov: cover (rst_n && (access && PWRITE && hit[57]));
    p_priority_57_value_rst: assert (!past_ok || $past(rst_n) || priority_value[173:171] == 3'h0)
      else $error("chilimix_plic_regs: priority[57].value reset value %h", priority_value[173:171]);
    p_priority_57_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[173:171] == ($past((access && PWRITE && hit[57])) ? (($past(priority_value[173:171]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[173:171])))
      else $error("chilimix_plic_regs: priority[57].value is %h after a write / hold", priority_value[173:171]);
    // priority[58] writes
    p_priority_58_wr_cov: cover (rst_n && (access && PWRITE && hit[58]));
    p_priority_58_value_rst: assert (!past_ok || $past(rst_n) || priority_value[176:174] == 3'h0)
      else $error("chilimix_plic_regs: priority[58].value reset value %h", priority_value[176:174]);
    p_priority_58_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[176:174] == ($past((access && PWRITE && hit[58])) ? (($past(priority_value[176:174]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[176:174])))
      else $error("chilimix_plic_regs: priority[58].value is %h after a write / hold", priority_value[176:174]);
    // priority[59] writes
    p_priority_59_wr_cov: cover (rst_n && (access && PWRITE && hit[59]));
    p_priority_59_value_rst: assert (!past_ok || $past(rst_n) || priority_value[179:177] == 3'h0)
      else $error("chilimix_plic_regs: priority[59].value reset value %h", priority_value[179:177]);
    p_priority_59_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[179:177] == ($past((access && PWRITE && hit[59])) ? (($past(priority_value[179:177]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[179:177])))
      else $error("chilimix_plic_regs: priority[59].value is %h after a write / hold", priority_value[179:177]);
    // priority[60] writes
    p_priority_60_wr_cov: cover (rst_n && (access && PWRITE && hit[60]));
    p_priority_60_value_rst: assert (!past_ok || $past(rst_n) || priority_value[182:180] == 3'h0)
      else $error("chilimix_plic_regs: priority[60].value reset value %h", priority_value[182:180]);
    p_priority_60_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[182:180] == ($past((access && PWRITE && hit[60])) ? (($past(priority_value[182:180]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[182:180])))
      else $error("chilimix_plic_regs: priority[60].value is %h after a write / hold", priority_value[182:180]);
    // priority[61] writes
    p_priority_61_wr_cov: cover (rst_n && (access && PWRITE && hit[61]));
    p_priority_61_value_rst: assert (!past_ok || $past(rst_n) || priority_value[185:183] == 3'h0)
      else $error("chilimix_plic_regs: priority[61].value reset value %h", priority_value[185:183]);
    p_priority_61_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[185:183] == ($past((access && PWRITE && hit[61])) ? (($past(priority_value[185:183]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[185:183])))
      else $error("chilimix_plic_regs: priority[61].value is %h after a write / hold", priority_value[185:183]);
    // priority[62] writes
    p_priority_62_wr_cov: cover (rst_n && (access && PWRITE && hit[62]));
    p_priority_62_value_rst: assert (!past_ok || $past(rst_n) || priority_value[188:186] == 3'h0)
      else $error("chilimix_plic_regs: priority[62].value reset value %h", priority_value[188:186]);
    p_priority_62_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || priority_value[188:186] == ($past((access && PWRITE && hit[62])) ? (($past(priority_value[188:186]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(priority_value[188:186])))
      else $error("chilimix_plic_regs: priority[62].value is %h after a write / hold", priority_value[188:186]);
    // pending0 writes
    p_pending0_wr_cov: cover (rst_n && (access && PWRITE && hit[63]));
    // pending1 writes
    p_pending1_wr_cov: cover (rst_n && (access && PWRITE && hit[64]));
    // enable0[0] writes
    p_enable0_0_wr_cov: cover (rst_n && (access && PWRITE && hit[65]));
    p_enable0_0_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[30:0] == ((N_CTX > 0) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[0].src reset value %h", enable0_src[30:0]);
    p_enable0_0_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[30:0] == ((N_CTX > 0) ? ($past((access && PWRITE && hit[65])) ? (($past(enable0_src[30:0]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[30:0])) : '0))
      else $error("chilimix_plic_regs: enable0[0].src is %h after a write / hold", enable0_src[30:0]);
    // enable1[0] writes
    p_enable1_0_wr_cov: cover (rst_n && (access && PWRITE && hit[66]));
    p_enable1_0_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[31:0] == ((N_CTX > 0) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[0].src reset value %h", enable1_src[31:0]);
    p_enable1_0_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[31:0] == ((N_CTX > 0) ? ($past((access && PWRITE && hit[66])) ? (($past(enable1_src[31:0]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[31:0])) : '0))
      else $error("chilimix_plic_regs: enable1[0].src is %h after a write / hold", enable1_src[31:0]);
    // enable0[1] writes
    p_enable0_1_wr_cov: cover (rst_n && (access && PWRITE && hit[67]));
    p_enable0_1_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[61:31] == ((N_CTX > 1) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[1].src reset value %h", enable0_src[61:31]);
    p_enable0_1_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[61:31] == ((N_CTX > 1) ? ($past((access && PWRITE && hit[67])) ? (($past(enable0_src[61:31]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[61:31])) : '0))
      else $error("chilimix_plic_regs: enable0[1].src is %h after a write / hold", enable0_src[61:31]);
    // enable1[1] writes
    p_enable1_1_wr_cov: cover (rst_n && (access && PWRITE && hit[68]));
    p_enable1_1_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[63:32] == ((N_CTX > 1) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[1].src reset value %h", enable1_src[63:32]);
    p_enable1_1_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[63:32] == ((N_CTX > 1) ? ($past((access && PWRITE && hit[68])) ? (($past(enable1_src[63:32]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[63:32])) : '0))
      else $error("chilimix_plic_regs: enable1[1].src is %h after a write / hold", enable1_src[63:32]);
    // enable0[2] writes
    p_enable0_2_wr_cov: cover (rst_n && (access && PWRITE && hit[69]));
    p_enable0_2_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[92:62] == ((N_CTX > 2) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[2].src reset value %h", enable0_src[92:62]);
    p_enable0_2_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[92:62] == ((N_CTX > 2) ? ($past((access && PWRITE && hit[69])) ? (($past(enable0_src[92:62]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[92:62])) : '0))
      else $error("chilimix_plic_regs: enable0[2].src is %h after a write / hold", enable0_src[92:62]);
    // enable1[2] writes
    p_enable1_2_wr_cov: cover (rst_n && (access && PWRITE && hit[70]));
    p_enable1_2_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[95:64] == ((N_CTX > 2) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[2].src reset value %h", enable1_src[95:64]);
    p_enable1_2_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[95:64] == ((N_CTX > 2) ? ($past((access && PWRITE && hit[70])) ? (($past(enable1_src[95:64]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[95:64])) : '0))
      else $error("chilimix_plic_regs: enable1[2].src is %h after a write / hold", enable1_src[95:64]);
    // enable0[3] writes
    p_enable0_3_wr_cov: cover (rst_n && (access && PWRITE && hit[71]));
    p_enable0_3_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[123:93] == ((N_CTX > 3) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[3].src reset value %h", enable0_src[123:93]);
    p_enable0_3_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[123:93] == ((N_CTX > 3) ? ($past((access && PWRITE && hit[71])) ? (($past(enable0_src[123:93]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[123:93])) : '0))
      else $error("chilimix_plic_regs: enable0[3].src is %h after a write / hold", enable0_src[123:93]);
    // enable1[3] writes
    p_enable1_3_wr_cov: cover (rst_n && (access && PWRITE && hit[72]));
    p_enable1_3_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[127:96] == ((N_CTX > 3) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[3].src reset value %h", enable1_src[127:96]);
    p_enable1_3_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[127:96] == ((N_CTX > 3) ? ($past((access && PWRITE && hit[72])) ? (($past(enable1_src[127:96]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[127:96])) : '0))
      else $error("chilimix_plic_regs: enable1[3].src is %h after a write / hold", enable1_src[127:96]);
    // enable0[4] writes
    p_enable0_4_wr_cov: cover (rst_n && (access && PWRITE && hit[73]));
    p_enable0_4_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[154:124] == ((N_CTX > 4) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[4].src reset value %h", enable0_src[154:124]);
    p_enable0_4_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[154:124] == ((N_CTX > 4) ? ($past((access && PWRITE && hit[73])) ? (($past(enable0_src[154:124]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[154:124])) : '0))
      else $error("chilimix_plic_regs: enable0[4].src is %h after a write / hold", enable0_src[154:124]);
    // enable1[4] writes
    p_enable1_4_wr_cov: cover (rst_n && (access && PWRITE && hit[74]));
    p_enable1_4_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[159:128] == ((N_CTX > 4) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[4].src reset value %h", enable1_src[159:128]);
    p_enable1_4_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[159:128] == ((N_CTX > 4) ? ($past((access && PWRITE && hit[74])) ? (($past(enable1_src[159:128]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[159:128])) : '0))
      else $error("chilimix_plic_regs: enable1[4].src is %h after a write / hold", enable1_src[159:128]);
    // enable0[5] writes
    p_enable0_5_wr_cov: cover (rst_n && (access && PWRITE && hit[75]));
    p_enable0_5_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[185:155] == ((N_CTX > 5) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[5].src reset value %h", enable0_src[185:155]);
    p_enable0_5_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[185:155] == ((N_CTX > 5) ? ($past((access && PWRITE && hit[75])) ? (($past(enable0_src[185:155]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[185:155])) : '0))
      else $error("chilimix_plic_regs: enable0[5].src is %h after a write / hold", enable0_src[185:155]);
    // enable1[5] writes
    p_enable1_5_wr_cov: cover (rst_n && (access && PWRITE && hit[76]));
    p_enable1_5_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[191:160] == ((N_CTX > 5) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[5].src reset value %h", enable1_src[191:160]);
    p_enable1_5_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[191:160] == ((N_CTX > 5) ? ($past((access && PWRITE && hit[76])) ? (($past(enable1_src[191:160]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[191:160])) : '0))
      else $error("chilimix_plic_regs: enable1[5].src is %h after a write / hold", enable1_src[191:160]);
    // enable0[6] writes
    p_enable0_6_wr_cov: cover (rst_n && (access && PWRITE && hit[77]));
    p_enable0_6_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[216:186] == ((N_CTX > 6) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[6].src reset value %h", enable0_src[216:186]);
    p_enable0_6_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[216:186] == ((N_CTX > 6) ? ($past((access && PWRITE && hit[77])) ? (($past(enable0_src[216:186]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[216:186])) : '0))
      else $error("chilimix_plic_regs: enable0[6].src is %h after a write / hold", enable0_src[216:186]);
    // enable1[6] writes
    p_enable1_6_wr_cov: cover (rst_n && (access && PWRITE && hit[78]));
    p_enable1_6_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[223:192] == ((N_CTX > 6) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[6].src reset value %h", enable1_src[223:192]);
    p_enable1_6_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[223:192] == ((N_CTX > 6) ? ($past((access && PWRITE && hit[78])) ? (($past(enable1_src[223:192]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[223:192])) : '0))
      else $error("chilimix_plic_regs: enable1[6].src is %h after a write / hold", enable1_src[223:192]);
    // enable0[7] writes
    p_enable0_7_wr_cov: cover (rst_n && (access && PWRITE && hit[79]));
    p_enable0_7_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[247:217] == ((N_CTX > 7) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[7].src reset value %h", enable0_src[247:217]);
    p_enable0_7_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[247:217] == ((N_CTX > 7) ? ($past((access && PWRITE && hit[79])) ? (($past(enable0_src[247:217]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[247:217])) : '0))
      else $error("chilimix_plic_regs: enable0[7].src is %h after a write / hold", enable0_src[247:217]);
    // enable1[7] writes
    p_enable1_7_wr_cov: cover (rst_n && (access && PWRITE && hit[80]));
    p_enable1_7_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[255:224] == ((N_CTX > 7) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[7].src reset value %h", enable1_src[255:224]);
    p_enable1_7_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[255:224] == ((N_CTX > 7) ? ($past((access && PWRITE && hit[80])) ? (($past(enable1_src[255:224]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[255:224])) : '0))
      else $error("chilimix_plic_regs: enable1[7].src is %h after a write / hold", enable1_src[255:224]);
    // enable0[8] writes
    p_enable0_8_wr_cov: cover (rst_n && (access && PWRITE && hit[81]));
    p_enable0_8_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[278:248] == ((N_CTX > 8) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[8].src reset value %h", enable0_src[278:248]);
    p_enable0_8_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[278:248] == ((N_CTX > 8) ? ($past((access && PWRITE && hit[81])) ? (($past(enable0_src[278:248]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[278:248])) : '0))
      else $error("chilimix_plic_regs: enable0[8].src is %h after a write / hold", enable0_src[278:248]);
    // enable1[8] writes
    p_enable1_8_wr_cov: cover (rst_n && (access && PWRITE && hit[82]));
    p_enable1_8_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[287:256] == ((N_CTX > 8) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[8].src reset value %h", enable1_src[287:256]);
    p_enable1_8_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[287:256] == ((N_CTX > 8) ? ($past((access && PWRITE && hit[82])) ? (($past(enable1_src[287:256]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[287:256])) : '0))
      else $error("chilimix_plic_regs: enable1[8].src is %h after a write / hold", enable1_src[287:256]);
    // enable0[9] writes
    p_enable0_9_wr_cov: cover (rst_n && (access && PWRITE && hit[83]));
    p_enable0_9_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[309:279] == ((N_CTX > 9) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[9].src reset value %h", enable0_src[309:279]);
    p_enable0_9_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[309:279] == ((N_CTX > 9) ? ($past((access && PWRITE && hit[83])) ? (($past(enable0_src[309:279]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[309:279])) : '0))
      else $error("chilimix_plic_regs: enable0[9].src is %h after a write / hold", enable0_src[309:279]);
    // enable1[9] writes
    p_enable1_9_wr_cov: cover (rst_n && (access && PWRITE && hit[84]));
    p_enable1_9_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[319:288] == ((N_CTX > 9) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[9].src reset value %h", enable1_src[319:288]);
    p_enable1_9_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[319:288] == ((N_CTX > 9) ? ($past((access && PWRITE && hit[84])) ? (($past(enable1_src[319:288]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[319:288])) : '0))
      else $error("chilimix_plic_regs: enable1[9].src is %h after a write / hold", enable1_src[319:288]);
    // enable0[10] writes
    p_enable0_10_wr_cov: cover (rst_n && (access && PWRITE && hit[85]));
    p_enable0_10_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[340:310] == ((N_CTX > 10) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[10].src reset value %h", enable0_src[340:310]);
    p_enable0_10_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[340:310] == ((N_CTX > 10) ? ($past((access && PWRITE && hit[85])) ? (($past(enable0_src[340:310]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[340:310])) : '0))
      else $error("chilimix_plic_regs: enable0[10].src is %h after a write / hold", enable0_src[340:310]);
    // enable1[10] writes
    p_enable1_10_wr_cov: cover (rst_n && (access && PWRITE && hit[86]));
    p_enable1_10_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[351:320] == ((N_CTX > 10) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[10].src reset value %h", enable1_src[351:320]);
    p_enable1_10_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[351:320] == ((N_CTX > 10) ? ($past((access && PWRITE && hit[86])) ? (($past(enable1_src[351:320]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[351:320])) : '0))
      else $error("chilimix_plic_regs: enable1[10].src is %h after a write / hold", enable1_src[351:320]);
    // enable0[11] writes
    p_enable0_11_wr_cov: cover (rst_n && (access && PWRITE && hit[87]));
    p_enable0_11_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[371:341] == ((N_CTX > 11) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[11].src reset value %h", enable0_src[371:341]);
    p_enable0_11_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[371:341] == ((N_CTX > 11) ? ($past((access && PWRITE && hit[87])) ? (($past(enable0_src[371:341]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[371:341])) : '0))
      else $error("chilimix_plic_regs: enable0[11].src is %h after a write / hold", enable0_src[371:341]);
    // enable1[11] writes
    p_enable1_11_wr_cov: cover (rst_n && (access && PWRITE && hit[88]));
    p_enable1_11_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[383:352] == ((N_CTX > 11) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[11].src reset value %h", enable1_src[383:352]);
    p_enable1_11_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[383:352] == ((N_CTX > 11) ? ($past((access && PWRITE && hit[88])) ? (($past(enable1_src[383:352]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[383:352])) : '0))
      else $error("chilimix_plic_regs: enable1[11].src is %h after a write / hold", enable1_src[383:352]);
    // enable0[12] writes
    p_enable0_12_wr_cov: cover (rst_n && (access && PWRITE && hit[89]));
    p_enable0_12_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[402:372] == ((N_CTX > 12) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[12].src reset value %h", enable0_src[402:372]);
    p_enable0_12_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[402:372] == ((N_CTX > 12) ? ($past((access && PWRITE && hit[89])) ? (($past(enable0_src[402:372]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[402:372])) : '0))
      else $error("chilimix_plic_regs: enable0[12].src is %h after a write / hold", enable0_src[402:372]);
    // enable1[12] writes
    p_enable1_12_wr_cov: cover (rst_n && (access && PWRITE && hit[90]));
    p_enable1_12_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[415:384] == ((N_CTX > 12) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[12].src reset value %h", enable1_src[415:384]);
    p_enable1_12_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[415:384] == ((N_CTX > 12) ? ($past((access && PWRITE && hit[90])) ? (($past(enable1_src[415:384]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[415:384])) : '0))
      else $error("chilimix_plic_regs: enable1[12].src is %h after a write / hold", enable1_src[415:384]);
    // enable0[13] writes
    p_enable0_13_wr_cov: cover (rst_n && (access && PWRITE && hit[91]));
    p_enable0_13_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[433:403] == ((N_CTX > 13) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[13].src reset value %h", enable0_src[433:403]);
    p_enable0_13_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[433:403] == ((N_CTX > 13) ? ($past((access && PWRITE && hit[91])) ? (($past(enable0_src[433:403]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[433:403])) : '0))
      else $error("chilimix_plic_regs: enable0[13].src is %h after a write / hold", enable0_src[433:403]);
    // enable1[13] writes
    p_enable1_13_wr_cov: cover (rst_n && (access && PWRITE && hit[92]));
    p_enable1_13_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[447:416] == ((N_CTX > 13) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[13].src reset value %h", enable1_src[447:416]);
    p_enable1_13_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[447:416] == ((N_CTX > 13) ? ($past((access && PWRITE && hit[92])) ? (($past(enable1_src[447:416]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[447:416])) : '0))
      else $error("chilimix_plic_regs: enable1[13].src is %h after a write / hold", enable1_src[447:416]);
    // enable0[14] writes
    p_enable0_14_wr_cov: cover (rst_n && (access && PWRITE && hit[93]));
    p_enable0_14_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[464:434] == ((N_CTX > 14) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[14].src reset value %h", enable0_src[464:434]);
    p_enable0_14_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[464:434] == ((N_CTX > 14) ? ($past((access && PWRITE && hit[93])) ? (($past(enable0_src[464:434]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[464:434])) : '0))
      else $error("chilimix_plic_regs: enable0[14].src is %h after a write / hold", enable0_src[464:434]);
    // enable1[14] writes
    p_enable1_14_wr_cov: cover (rst_n && (access && PWRITE && hit[94]));
    p_enable1_14_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[479:448] == ((N_CTX > 14) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[14].src reset value %h", enable1_src[479:448]);
    p_enable1_14_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[479:448] == ((N_CTX > 14) ? ($past((access && PWRITE && hit[94])) ? (($past(enable1_src[479:448]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[479:448])) : '0))
      else $error("chilimix_plic_regs: enable1[14].src is %h after a write / hold", enable1_src[479:448]);
    // enable0[15] writes
    p_enable0_15_wr_cov: cover (rst_n && (access && PWRITE && hit[95]));
    p_enable0_15_src_rst: assert (!past_ok || $past(rst_n) || enable0_src[495:465] == ((N_CTX > 15) ? 31'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable0[15].src reset value %h", enable0_src[495:465]);
    p_enable0_15_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable0_src[495:465] == ((N_CTX > 15) ? ($past((access && PWRITE && hit[95])) ? (($past(enable0_src[495:465]) & ~$past(bit_en[31:1])) | ($past(PWDATA[31:1]) & $past(bit_en[31:1]))) : $past(enable0_src[495:465])) : '0))
      else $error("chilimix_plic_regs: enable0[15].src is %h after a write / hold", enable0_src[495:465]);
    // enable1[15] writes
    p_enable1_15_wr_cov: cover (rst_n && (access && PWRITE && hit[96]));
    p_enable1_15_src_rst: assert (!past_ok || $past(rst_n) || enable1_src[511:480] == ((N_CTX > 15) ? 32'h0000_0000 : '0))
      else $error("chilimix_plic_regs: enable1[15].src reset value %h", enable1_src[511:480]);
    p_enable1_15_src_wr: assert (!rst_n || !past_ok || !$past(rst_n) || enable1_src[511:480] == ((N_CTX > 15) ? ($past((access && PWRITE && hit[96])) ? (($past(enable1_src[511:480]) & ~$past(bit_en[31:0])) | ($past(PWDATA[31:0]) & $past(bit_en[31:0]))) : $past(enable1_src[511:480])) : '0))
      else $error("chilimix_plic_regs: enable1[15].src is %h after a write / hold", enable1_src[511:480]);
    // threshold[0] writes
    p_threshold_0_wr_cov: cover (rst_n && (access && PWRITE && hit[97]));
    p_threshold_0_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[2:0] == ((N_CTX > 0) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[0].value reset value %h", threshold_value[2:0]);
    p_threshold_0_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[2:0] == ((N_CTX > 0) ? ($past((access && PWRITE && hit[97])) ? (($past(threshold_value[2:0]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[2:0])) : '0))
      else $error("chilimix_plic_regs: threshold[0].value is %h after a write / hold", threshold_value[2:0]);
    // claim[0] writes
    p_claim_0_wr_cov: cover (rst_n && (access && PWRITE && hit[98]));
    p_claim_0_wrp: assert (!rst_n || claim_wr[0] == ((N_CTX > 0) ? (access && PWRITE && hit[98]) : 1'b0))
      else $error("chilimix_plic_regs: claim[0] write pulse wrong");
    // threshold[1] writes
    p_threshold_1_wr_cov: cover (rst_n && (access && PWRITE && hit[99]));
    p_threshold_1_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[5:3] == ((N_CTX > 1) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[1].value reset value %h", threshold_value[5:3]);
    p_threshold_1_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[5:3] == ((N_CTX > 1) ? ($past((access && PWRITE && hit[99])) ? (($past(threshold_value[5:3]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[5:3])) : '0))
      else $error("chilimix_plic_regs: threshold[1].value is %h after a write / hold", threshold_value[5:3]);
    // claim[1] writes
    p_claim_1_wr_cov: cover (rst_n && (access && PWRITE && hit[100]));
    p_claim_1_wrp: assert (!rst_n || claim_wr[1] == ((N_CTX > 1) ? (access && PWRITE && hit[100]) : 1'b0))
      else $error("chilimix_plic_regs: claim[1] write pulse wrong");
    // threshold[2] writes
    p_threshold_2_wr_cov: cover (rst_n && (access && PWRITE && hit[101]));
    p_threshold_2_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[8:6] == ((N_CTX > 2) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[2].value reset value %h", threshold_value[8:6]);
    p_threshold_2_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[8:6] == ((N_CTX > 2) ? ($past((access && PWRITE && hit[101])) ? (($past(threshold_value[8:6]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[8:6])) : '0))
      else $error("chilimix_plic_regs: threshold[2].value is %h after a write / hold", threshold_value[8:6]);
    // claim[2] writes
    p_claim_2_wr_cov: cover (rst_n && (access && PWRITE && hit[102]));
    p_claim_2_wrp: assert (!rst_n || claim_wr[2] == ((N_CTX > 2) ? (access && PWRITE && hit[102]) : 1'b0))
      else $error("chilimix_plic_regs: claim[2] write pulse wrong");
    // threshold[3] writes
    p_threshold_3_wr_cov: cover (rst_n && (access && PWRITE && hit[103]));
    p_threshold_3_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[11:9] == ((N_CTX > 3) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[3].value reset value %h", threshold_value[11:9]);
    p_threshold_3_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[11:9] == ((N_CTX > 3) ? ($past((access && PWRITE && hit[103])) ? (($past(threshold_value[11:9]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[11:9])) : '0))
      else $error("chilimix_plic_regs: threshold[3].value is %h after a write / hold", threshold_value[11:9]);
    // claim[3] writes
    p_claim_3_wr_cov: cover (rst_n && (access && PWRITE && hit[104]));
    p_claim_3_wrp: assert (!rst_n || claim_wr[3] == ((N_CTX > 3) ? (access && PWRITE && hit[104]) : 1'b0))
      else $error("chilimix_plic_regs: claim[3] write pulse wrong");
    // threshold[4] writes
    p_threshold_4_wr_cov: cover (rst_n && (access && PWRITE && hit[105]));
    p_threshold_4_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[14:12] == ((N_CTX > 4) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[4].value reset value %h", threshold_value[14:12]);
    p_threshold_4_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[14:12] == ((N_CTX > 4) ? ($past((access && PWRITE && hit[105])) ? (($past(threshold_value[14:12]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[14:12])) : '0))
      else $error("chilimix_plic_regs: threshold[4].value is %h after a write / hold", threshold_value[14:12]);
    // claim[4] writes
    p_claim_4_wr_cov: cover (rst_n && (access && PWRITE && hit[106]));
    p_claim_4_wrp: assert (!rst_n || claim_wr[4] == ((N_CTX > 4) ? (access && PWRITE && hit[106]) : 1'b0))
      else $error("chilimix_plic_regs: claim[4] write pulse wrong");
    // threshold[5] writes
    p_threshold_5_wr_cov: cover (rst_n && (access && PWRITE && hit[107]));
    p_threshold_5_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[17:15] == ((N_CTX > 5) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[5].value reset value %h", threshold_value[17:15]);
    p_threshold_5_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[17:15] == ((N_CTX > 5) ? ($past((access && PWRITE && hit[107])) ? (($past(threshold_value[17:15]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[17:15])) : '0))
      else $error("chilimix_plic_regs: threshold[5].value is %h after a write / hold", threshold_value[17:15]);
    // claim[5] writes
    p_claim_5_wr_cov: cover (rst_n && (access && PWRITE && hit[108]));
    p_claim_5_wrp: assert (!rst_n || claim_wr[5] == ((N_CTX > 5) ? (access && PWRITE && hit[108]) : 1'b0))
      else $error("chilimix_plic_regs: claim[5] write pulse wrong");
    // threshold[6] writes
    p_threshold_6_wr_cov: cover (rst_n && (access && PWRITE && hit[109]));
    p_threshold_6_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[20:18] == ((N_CTX > 6) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[6].value reset value %h", threshold_value[20:18]);
    p_threshold_6_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[20:18] == ((N_CTX > 6) ? ($past((access && PWRITE && hit[109])) ? (($past(threshold_value[20:18]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[20:18])) : '0))
      else $error("chilimix_plic_regs: threshold[6].value is %h after a write / hold", threshold_value[20:18]);
    // claim[6] writes
    p_claim_6_wr_cov: cover (rst_n && (access && PWRITE && hit[110]));
    p_claim_6_wrp: assert (!rst_n || claim_wr[6] == ((N_CTX > 6) ? (access && PWRITE && hit[110]) : 1'b0))
      else $error("chilimix_plic_regs: claim[6] write pulse wrong");
    // threshold[7] writes
    p_threshold_7_wr_cov: cover (rst_n && (access && PWRITE && hit[111]));
    p_threshold_7_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[23:21] == ((N_CTX > 7) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[7].value reset value %h", threshold_value[23:21]);
    p_threshold_7_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[23:21] == ((N_CTX > 7) ? ($past((access && PWRITE && hit[111])) ? (($past(threshold_value[23:21]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[23:21])) : '0))
      else $error("chilimix_plic_regs: threshold[7].value is %h after a write / hold", threshold_value[23:21]);
    // claim[7] writes
    p_claim_7_wr_cov: cover (rst_n && (access && PWRITE && hit[112]));
    p_claim_7_wrp: assert (!rst_n || claim_wr[7] == ((N_CTX > 7) ? (access && PWRITE && hit[112]) : 1'b0))
      else $error("chilimix_plic_regs: claim[7] write pulse wrong");
    // threshold[8] writes
    p_threshold_8_wr_cov: cover (rst_n && (access && PWRITE && hit[113]));
    p_threshold_8_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[26:24] == ((N_CTX > 8) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[8].value reset value %h", threshold_value[26:24]);
    p_threshold_8_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[26:24] == ((N_CTX > 8) ? ($past((access && PWRITE && hit[113])) ? (($past(threshold_value[26:24]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[26:24])) : '0))
      else $error("chilimix_plic_regs: threshold[8].value is %h after a write / hold", threshold_value[26:24]);
    // claim[8] writes
    p_claim_8_wr_cov: cover (rst_n && (access && PWRITE && hit[114]));
    p_claim_8_wrp: assert (!rst_n || claim_wr[8] == ((N_CTX > 8) ? (access && PWRITE && hit[114]) : 1'b0))
      else $error("chilimix_plic_regs: claim[8] write pulse wrong");
    // threshold[9] writes
    p_threshold_9_wr_cov: cover (rst_n && (access && PWRITE && hit[115]));
    p_threshold_9_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[29:27] == ((N_CTX > 9) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[9].value reset value %h", threshold_value[29:27]);
    p_threshold_9_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[29:27] == ((N_CTX > 9) ? ($past((access && PWRITE && hit[115])) ? (($past(threshold_value[29:27]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[29:27])) : '0))
      else $error("chilimix_plic_regs: threshold[9].value is %h after a write / hold", threshold_value[29:27]);
    // claim[9] writes
    p_claim_9_wr_cov: cover (rst_n && (access && PWRITE && hit[116]));
    p_claim_9_wrp: assert (!rst_n || claim_wr[9] == ((N_CTX > 9) ? (access && PWRITE && hit[116]) : 1'b0))
      else $error("chilimix_plic_regs: claim[9] write pulse wrong");
    // threshold[10] writes
    p_threshold_10_wr_cov: cover (rst_n && (access && PWRITE && hit[117]));
    p_threshold_10_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[32:30] == ((N_CTX > 10) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[10].value reset value %h", threshold_value[32:30]);
    p_threshold_10_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[32:30] == ((N_CTX > 10) ? ($past((access && PWRITE && hit[117])) ? (($past(threshold_value[32:30]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[32:30])) : '0))
      else $error("chilimix_plic_regs: threshold[10].value is %h after a write / hold", threshold_value[32:30]);
    // claim[10] writes
    p_claim_10_wr_cov: cover (rst_n && (access && PWRITE && hit[118]));
    p_claim_10_wrp: assert (!rst_n || claim_wr[10] == ((N_CTX > 10) ? (access && PWRITE && hit[118]) : 1'b0))
      else $error("chilimix_plic_regs: claim[10] write pulse wrong");
    // threshold[11] writes
    p_threshold_11_wr_cov: cover (rst_n && (access && PWRITE && hit[119]));
    p_threshold_11_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[35:33] == ((N_CTX > 11) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[11].value reset value %h", threshold_value[35:33]);
    p_threshold_11_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[35:33] == ((N_CTX > 11) ? ($past((access && PWRITE && hit[119])) ? (($past(threshold_value[35:33]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[35:33])) : '0))
      else $error("chilimix_plic_regs: threshold[11].value is %h after a write / hold", threshold_value[35:33]);
    // claim[11] writes
    p_claim_11_wr_cov: cover (rst_n && (access && PWRITE && hit[120]));
    p_claim_11_wrp: assert (!rst_n || claim_wr[11] == ((N_CTX > 11) ? (access && PWRITE && hit[120]) : 1'b0))
      else $error("chilimix_plic_regs: claim[11] write pulse wrong");
    // threshold[12] writes
    p_threshold_12_wr_cov: cover (rst_n && (access && PWRITE && hit[121]));
    p_threshold_12_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[38:36] == ((N_CTX > 12) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[12].value reset value %h", threshold_value[38:36]);
    p_threshold_12_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[38:36] == ((N_CTX > 12) ? ($past((access && PWRITE && hit[121])) ? (($past(threshold_value[38:36]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[38:36])) : '0))
      else $error("chilimix_plic_regs: threshold[12].value is %h after a write / hold", threshold_value[38:36]);
    // claim[12] writes
    p_claim_12_wr_cov: cover (rst_n && (access && PWRITE && hit[122]));
    p_claim_12_wrp: assert (!rst_n || claim_wr[12] == ((N_CTX > 12) ? (access && PWRITE && hit[122]) : 1'b0))
      else $error("chilimix_plic_regs: claim[12] write pulse wrong");
    // threshold[13] writes
    p_threshold_13_wr_cov: cover (rst_n && (access && PWRITE && hit[123]));
    p_threshold_13_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[41:39] == ((N_CTX > 13) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[13].value reset value %h", threshold_value[41:39]);
    p_threshold_13_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[41:39] == ((N_CTX > 13) ? ($past((access && PWRITE && hit[123])) ? (($past(threshold_value[41:39]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[41:39])) : '0))
      else $error("chilimix_plic_regs: threshold[13].value is %h after a write / hold", threshold_value[41:39]);
    // claim[13] writes
    p_claim_13_wr_cov: cover (rst_n && (access && PWRITE && hit[124]));
    p_claim_13_wrp: assert (!rst_n || claim_wr[13] == ((N_CTX > 13) ? (access && PWRITE && hit[124]) : 1'b0))
      else $error("chilimix_plic_regs: claim[13] write pulse wrong");
    // threshold[14] writes
    p_threshold_14_wr_cov: cover (rst_n && (access && PWRITE && hit[125]));
    p_threshold_14_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[44:42] == ((N_CTX > 14) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[14].value reset value %h", threshold_value[44:42]);
    p_threshold_14_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[44:42] == ((N_CTX > 14) ? ($past((access && PWRITE && hit[125])) ? (($past(threshold_value[44:42]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[44:42])) : '0))
      else $error("chilimix_plic_regs: threshold[14].value is %h after a write / hold", threshold_value[44:42]);
    // claim[14] writes
    p_claim_14_wr_cov: cover (rst_n && (access && PWRITE && hit[126]));
    p_claim_14_wrp: assert (!rst_n || claim_wr[14] == ((N_CTX > 14) ? (access && PWRITE && hit[126]) : 1'b0))
      else $error("chilimix_plic_regs: claim[14] write pulse wrong");
    // threshold[15] writes
    p_threshold_15_wr_cov: cover (rst_n && (access && PWRITE && hit[127]));
    p_threshold_15_value_rst: assert (!past_ok || $past(rst_n) || threshold_value[47:45] == ((N_CTX > 15) ? 3'h0 : '0))
      else $error("chilimix_plic_regs: threshold[15].value reset value %h", threshold_value[47:45]);
    p_threshold_15_value_wr: assert (!rst_n || !past_ok || !$past(rst_n) || threshold_value[47:45] == ((N_CTX > 15) ? ($past((access && PWRITE && hit[127])) ? (($past(threshold_value[47:45]) & ~$past(bit_en[2:0])) | ($past(PWDATA[2:0]) & $past(bit_en[2:0]))) : $past(threshold_value[47:45])) : '0))
      else $error("chilimix_plic_regs: threshold[15].value is %h after a write / hold", threshold_value[47:45]);
    // claim[15] writes
    p_claim_15_wr_cov: cover (rst_n && (access && PWRITE && hit[128]));
    p_claim_15_wrp: assert (!rst_n || claim_wr[15] == ((N_CTX > 15) ? (access && PWRITE && hit[128]) : 1'b0))
      else $error("chilimix_plic_regs: claim[15] write pulse wrong");
  end

endmodule

bind chilimix_plic_regs chilimix_plic_regs_chk #(.N_CTX(N_CTX)) u_chk (.*);
