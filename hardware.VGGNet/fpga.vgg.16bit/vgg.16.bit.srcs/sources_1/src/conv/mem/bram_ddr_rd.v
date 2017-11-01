// ---------------------------------------------------
// File       : bram_ddr_rd.v
//
// Description: read from bram(ddr mode)
//
// Version    : 1.0
// ---------------------------------------------------

//`define sim_
module bram_ddr_rd #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter PORT_ADDR_WIDTH = 12
  ) (
    input  wire                                 clk,
    input  wire                                 rst_n,
    // addr
    input  wire[3:0]                            bram_rd_ddr_ker_set,
    input  wire[4:0]                            bram_rd_ddr_channel_idx, // channel index in one kernel set
    input  wire[1:0]                            bram_rd_ddr_quarter_num,
    output reg [32*PORT_ADDR_WIDTH-1 : 0]       bram_rd_ddr_addr_a,
    output reg [32*PORT_ADDR_WIDTH-1 : 0]       bram_rd_ddr_addr_b,
    // enable
    input  wire                                 bram_rd_ddr_en,     // enable
    input  wire                                 bram_rd_ddr_rd_en,  //in conv, port b read enable
    input  wire                                 bram_rd_ddr_next_quar, // clear valid signal
    output reg                                  bram_rd_ddr_en_bram,
    output reg                                  bram_rd_ddr_bram_valid,
    // data
    input  wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_ddr_a_data,
    input  wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_ddr_b_data,
    output reg                                  bram_rd_ddr_data_valid,
    output reg [49*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_ddr_data
  );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  wire[PORT_ADDR_WIDTH-1 : 0]     _bram_rd_ddr_base_addr;
  reg [95*PORT_ADDR_WIDTH-1 : 0]  _bram_rd_ddr_addr;
  reg [80*DATA_WIDTH-1 : 0]       _bram_rd_ddr_data;
  reg [4:0]                       _bram_rd_ddr_channel_idx_1;
  reg [4:0]                       _bram_rd_ddr_channel_idx_2;
  reg [4:0]                       _bram_rd_ddr_channel_idx_3;
  reg [4:0]                       _bram_rd_ddr_channel_idx_4;
  reg                             _bram_rd_ddr_rd_en;
  assign _bram_rd_ddr_base_addr = {bram_rd_ddr_ker_set,bram_rd_ddr_quarter_num}*6'd49;

  // enable
  always@(posedge clk) begin
    _bram_rd_ddr_rd_en      <= bram_rd_ddr_rd_en;
    bram_rd_ddr_en_bram     <= _bram_rd_ddr_rd_en;
    bram_rd_ddr_bram_valid  <= bram_rd_ddr_en_bram;
  end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_rd_ddr_data_valid  <= 1'b0;
    end else begin 
      if(!bram_rd_ddr_en || bram_rd_ddr_next_quar) begin
        bram_rd_ddr_data_valid  <= 1'b0;
      end else if(bram_rd_ddr_en && bram_rd_ddr_bram_valid) begin
        bram_rd_ddr_data_valid  <= 1'b1;
      end
    end
  end
  // address {{{
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _bram_rd_ddr_addr <= {(64*DATA_WIDTH){1'b0}};
    end else begin
      if(bram_rd_ddr_rd_en) begin
        _bram_rd_ddr_addr[95*PORT_ADDR_WIDTH-1 : 94*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd33;
        _bram_rd_ddr_addr[94*PORT_ADDR_WIDTH-1 : 93*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd34;
        _bram_rd_ddr_addr[93*PORT_ADDR_WIDTH-1 : 92*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd35;
        _bram_rd_ddr_addr[92*PORT_ADDR_WIDTH-1 : 91*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd36;
        _bram_rd_ddr_addr[91*PORT_ADDR_WIDTH-1 : 90*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd37;
        _bram_rd_ddr_addr[90*PORT_ADDR_WIDTH-1 : 89*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd38;
        _bram_rd_ddr_addr[89*PORT_ADDR_WIDTH-1 : 88*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd39;
        _bram_rd_ddr_addr[88*PORT_ADDR_WIDTH-1 : 87*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd40;
        _bram_rd_ddr_addr[87*PORT_ADDR_WIDTH-1 : 86*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd41;
        _bram_rd_ddr_addr[86*PORT_ADDR_WIDTH-1 : 85*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd42;
        _bram_rd_ddr_addr[85*PORT_ADDR_WIDTH-1 : 84*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd43;
        _bram_rd_ddr_addr[84*PORT_ADDR_WIDTH-1 : 83*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd44;
        _bram_rd_ddr_addr[83*PORT_ADDR_WIDTH-1 : 82*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd45;
        _bram_rd_ddr_addr[82*PORT_ADDR_WIDTH-1 : 81*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd46;
        _bram_rd_ddr_addr[81*PORT_ADDR_WIDTH-1 : 80*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd47;
        _bram_rd_ddr_addr[80*PORT_ADDR_WIDTH-1 : 79*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd48;
        _bram_rd_ddr_addr[79*PORT_ADDR_WIDTH-1 : 78*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[78*PORT_ADDR_WIDTH-1 : 77*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[77*PORT_ADDR_WIDTH-1 : 76*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[76*PORT_ADDR_WIDTH-1 : 75*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[75*PORT_ADDR_WIDTH-1 : 74*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[74*PORT_ADDR_WIDTH-1 : 73*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[73*PORT_ADDR_WIDTH-1 : 72*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[72*PORT_ADDR_WIDTH-1 : 71*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[71*PORT_ADDR_WIDTH-1 : 70*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[70*PORT_ADDR_WIDTH-1 : 69*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[69*PORT_ADDR_WIDTH-1 : 68*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[68*PORT_ADDR_WIDTH-1 : 67*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[67*PORT_ADDR_WIDTH-1 : 66*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[66*PORT_ADDR_WIDTH-1 : 65*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[65*PORT_ADDR_WIDTH-1 : 64*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[64*PORT_ADDR_WIDTH-1 : 63*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd0 ;
        _bram_rd_ddr_addr[63*PORT_ADDR_WIDTH-1 : 62*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd1 ;
        _bram_rd_ddr_addr[62*PORT_ADDR_WIDTH-1 : 61*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd2 ;
        _bram_rd_ddr_addr[61*PORT_ADDR_WIDTH-1 : 60*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd3 ;
        _bram_rd_ddr_addr[60*PORT_ADDR_WIDTH-1 : 59*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd4 ;
        _bram_rd_ddr_addr[59*PORT_ADDR_WIDTH-1 : 58*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd5 ;
        _bram_rd_ddr_addr[58*PORT_ADDR_WIDTH-1 : 57*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd6 ;
        _bram_rd_ddr_addr[57*PORT_ADDR_WIDTH-1 : 56*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd7 ;
        _bram_rd_ddr_addr[56*PORT_ADDR_WIDTH-1 : 55*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd8 ;
        _bram_rd_ddr_addr[55*PORT_ADDR_WIDTH-1 : 54*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd9 ;
        _bram_rd_ddr_addr[54*PORT_ADDR_WIDTH-1 : 53*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd10;
        _bram_rd_ddr_addr[53*PORT_ADDR_WIDTH-1 : 52*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd11;
        _bram_rd_ddr_addr[52*PORT_ADDR_WIDTH-1 : 51*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd12;
        _bram_rd_ddr_addr[51*PORT_ADDR_WIDTH-1 : 50*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd13;
        _bram_rd_ddr_addr[50*PORT_ADDR_WIDTH-1 : 49*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd14;
        _bram_rd_ddr_addr[49*PORT_ADDR_WIDTH-1 : 48*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd15;
        _bram_rd_ddr_addr[48*PORT_ADDR_WIDTH-1 : 47*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd16;
        _bram_rd_ddr_addr[47*PORT_ADDR_WIDTH-1 : 46*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd17;
        _bram_rd_ddr_addr[46*PORT_ADDR_WIDTH-1 : 45*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd18;
        _bram_rd_ddr_addr[45*PORT_ADDR_WIDTH-1 : 44*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd19;
        _bram_rd_ddr_addr[44*PORT_ADDR_WIDTH-1 : 43*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd20;
        _bram_rd_ddr_addr[43*PORT_ADDR_WIDTH-1 : 42*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd21;
        _bram_rd_ddr_addr[42*PORT_ADDR_WIDTH-1 : 41*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd22;
        _bram_rd_ddr_addr[41*PORT_ADDR_WIDTH-1 : 40*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd23;
        _bram_rd_ddr_addr[40*PORT_ADDR_WIDTH-1 : 39*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd24;
        _bram_rd_ddr_addr[39*PORT_ADDR_WIDTH-1 : 38*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd25;
        _bram_rd_ddr_addr[38*PORT_ADDR_WIDTH-1 : 37*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd26;
        _bram_rd_ddr_addr[37*PORT_ADDR_WIDTH-1 : 36*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd27;
        _bram_rd_ddr_addr[36*PORT_ADDR_WIDTH-1 : 35*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd28;
        _bram_rd_ddr_addr[35*PORT_ADDR_WIDTH-1 : 34*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd29;
        _bram_rd_ddr_addr[34*PORT_ADDR_WIDTH-1 : 33*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd30;
        _bram_rd_ddr_addr[33*PORT_ADDR_WIDTH-1 : 32*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd31;
        _bram_rd_ddr_addr[32*PORT_ADDR_WIDTH-1 : 31*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd32;
        _bram_rd_ddr_addr[31*PORT_ADDR_WIDTH-1 : 30*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd33;
        _bram_rd_ddr_addr[30*PORT_ADDR_WIDTH-1 : 29*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd34;
        _bram_rd_ddr_addr[29*PORT_ADDR_WIDTH-1 : 28*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd35;
        _bram_rd_ddr_addr[28*PORT_ADDR_WIDTH-1 : 27*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd36;
        _bram_rd_ddr_addr[27*PORT_ADDR_WIDTH-1 : 26*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd37;
        _bram_rd_ddr_addr[26*PORT_ADDR_WIDTH-1 : 25*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd38;
        _bram_rd_ddr_addr[25*PORT_ADDR_WIDTH-1 : 24*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd39;
        _bram_rd_ddr_addr[24*PORT_ADDR_WIDTH-1 : 23*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd40;
        _bram_rd_ddr_addr[23*PORT_ADDR_WIDTH-1 : 22*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd41;
        _bram_rd_ddr_addr[22*PORT_ADDR_WIDTH-1 : 21*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd42;
        _bram_rd_ddr_addr[21*PORT_ADDR_WIDTH-1 : 20*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd43;
        _bram_rd_ddr_addr[20*PORT_ADDR_WIDTH-1 : 19*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd44;
        _bram_rd_ddr_addr[19*PORT_ADDR_WIDTH-1 : 18*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd45;
        _bram_rd_ddr_addr[18*PORT_ADDR_WIDTH-1 : 17*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd46;
        _bram_rd_ddr_addr[17*PORT_ADDR_WIDTH-1 : 16*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd47;
        _bram_rd_ddr_addr[16*PORT_ADDR_WIDTH-1 : 15*PORT_ADDR_WIDTH] <= _bram_rd_ddr_base_addr + 12'd48;
        _bram_rd_ddr_addr[15*PORT_ADDR_WIDTH-1 : 14*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[14*PORT_ADDR_WIDTH-1 : 13*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[13*PORT_ADDR_WIDTH-1 : 12*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[12*PORT_ADDR_WIDTH-1 : 11*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[11*PORT_ADDR_WIDTH-1 : 10*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[10*PORT_ADDR_WIDTH-1 :  9*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 9*PORT_ADDR_WIDTH-1 :  8*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 8*PORT_ADDR_WIDTH-1 :  7*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 7*PORT_ADDR_WIDTH-1 :  6*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 6*PORT_ADDR_WIDTH-1 :  5*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 5*PORT_ADDR_WIDTH-1 :  4*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 4*PORT_ADDR_WIDTH-1 :  3*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 3*PORT_ADDR_WIDTH-1 :  2*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 2*PORT_ADDR_WIDTH-1 :  1*PORT_ADDR_WIDTH] <= 12'd0;
        _bram_rd_ddr_addr[ 1*PORT_ADDR_WIDTH-1 :  0*PORT_ADDR_WIDTH] <= 12'd0;
      end
    end
  end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_rd_ddr_addr_a <= {32*PORT_ADDR_WIDTH{1'b0}};
      bram_rd_ddr_addr_b <= {32*PORT_ADDR_WIDTH{1'b0}};
    end else begin
      case(_bram_rd_ddr_channel_idx_1)
        5'd0 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+0 )*PORT_ADDR_WIDTH-1 : 0 *PORT_ADDR_WIDTH];
        5'd1 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+1 )*PORT_ADDR_WIDTH-1 : 1 *PORT_ADDR_WIDTH];
        5'd2 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+2 )*PORT_ADDR_WIDTH-1 : 2 *PORT_ADDR_WIDTH];
        5'd3 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+3 )*PORT_ADDR_WIDTH-1 : 3 *PORT_ADDR_WIDTH];
        5'd4 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+4 )*PORT_ADDR_WIDTH-1 : 4 *PORT_ADDR_WIDTH];
        5'd5 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+5 )*PORT_ADDR_WIDTH-1 : 5 *PORT_ADDR_WIDTH];
        5'd6 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+6 )*PORT_ADDR_WIDTH-1 : 6 *PORT_ADDR_WIDTH];
        5'd7 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+7 )*PORT_ADDR_WIDTH-1 : 7 *PORT_ADDR_WIDTH];
        5'd8 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+8 )*PORT_ADDR_WIDTH-1 : 8 *PORT_ADDR_WIDTH];
        5'd9 : {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+9 )*PORT_ADDR_WIDTH-1 : 9 *PORT_ADDR_WIDTH];
        5'd10: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+10)*PORT_ADDR_WIDTH-1 : 10*PORT_ADDR_WIDTH];
        5'd11: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+11)*PORT_ADDR_WIDTH-1 : 11*PORT_ADDR_WIDTH];
        5'd12: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+12)*PORT_ADDR_WIDTH-1 : 12*PORT_ADDR_WIDTH];
        5'd13: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+13)*PORT_ADDR_WIDTH-1 : 13*PORT_ADDR_WIDTH];
        5'd14: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+14)*PORT_ADDR_WIDTH-1 : 14*PORT_ADDR_WIDTH];
        5'd15: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+15)*PORT_ADDR_WIDTH-1 : 15*PORT_ADDR_WIDTH];
        5'd16: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+16)*PORT_ADDR_WIDTH-1 : 16*PORT_ADDR_WIDTH];
        5'd17: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+17)*PORT_ADDR_WIDTH-1 : 17*PORT_ADDR_WIDTH];
        5'd18: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+18)*PORT_ADDR_WIDTH-1 : 18*PORT_ADDR_WIDTH];
        5'd19: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+19)*PORT_ADDR_WIDTH-1 : 19*PORT_ADDR_WIDTH];
        5'd20: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+20)*PORT_ADDR_WIDTH-1 : 20*PORT_ADDR_WIDTH];
        5'd21: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+21)*PORT_ADDR_WIDTH-1 : 21*PORT_ADDR_WIDTH];
        5'd22: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+22)*PORT_ADDR_WIDTH-1 : 22*PORT_ADDR_WIDTH];
        5'd23: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+23)*PORT_ADDR_WIDTH-1 : 23*PORT_ADDR_WIDTH];
        5'd24: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+24)*PORT_ADDR_WIDTH-1 : 24*PORT_ADDR_WIDTH];
        5'd25: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+25)*PORT_ADDR_WIDTH-1 : 25*PORT_ADDR_WIDTH];
        5'd26: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+26)*PORT_ADDR_WIDTH-1 : 26*PORT_ADDR_WIDTH];
        5'd27: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+27)*PORT_ADDR_WIDTH-1 : 27*PORT_ADDR_WIDTH];
        5'd28: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+28)*PORT_ADDR_WIDTH-1 : 28*PORT_ADDR_WIDTH];
        5'd29: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+29)*PORT_ADDR_WIDTH-1 : 29*PORT_ADDR_WIDTH];
        5'd30: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+30)*PORT_ADDR_WIDTH-1 : 30*PORT_ADDR_WIDTH];
        5'd31: {bram_rd_ddr_addr_a,bram_rd_ddr_addr_b} <= _bram_rd_ddr_addr[(64+31)*PORT_ADDR_WIDTH-1 : 31*PORT_ADDR_WIDTH];
      endcase
    end
  end
  // }}}
  // data
  // channel index delay
  always@(posedge clk) begin
    _bram_rd_ddr_channel_idx_1 <= bram_rd_ddr_channel_idx;
    _bram_rd_ddr_channel_idx_2 <= _bram_rd_ddr_channel_idx_1;
    _bram_rd_ddr_channel_idx_3 <= _bram_rd_ddr_channel_idx_2;
    _bram_rd_ddr_channel_idx_4 <= _bram_rd_ddr_channel_idx_3;
  end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _bram_rd_ddr_data <= {(80*DATA_WIDTH){1'b0}};
    end else begin
      if(bram_rd_ddr_bram_valid) begin
        _bram_rd_ddr_data <= {bram_rd_ddr_a_data,bram_rd_ddr_b_data,bram_rd_ddr_a_data[32*DATA_WIDTH-1 : (32-16)*DATA_WIDTH]};
      end
    end
  end
  always@(_bram_rd_ddr_channel_idx_4 or _bram_rd_ddr_data or bram_rd_ddr_data_valid) begin
    if(bram_rd_ddr_data_valid) begin
      bram_rd_ddr_data = {(49*DATA_WIDTH){1'b0}};
      case(_bram_rd_ddr_channel_idx_4)
        5'd0 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-0 )*DATA_WIDTH-1 : (31-0 )*DATA_WIDTH];
        5'd1 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-1 )*DATA_WIDTH-1 : (31-1 )*DATA_WIDTH];
        5'd2 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-2 )*DATA_WIDTH-1 : (31-2 )*DATA_WIDTH];
        5'd3 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-3 )*DATA_WIDTH-1 : (31-3 )*DATA_WIDTH];
        5'd4 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-4 )*DATA_WIDTH-1 : (31-4 )*DATA_WIDTH];
        5'd5 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-5 )*DATA_WIDTH-1 : (31-5 )*DATA_WIDTH];
        5'd6 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-6 )*DATA_WIDTH-1 : (31-6 )*DATA_WIDTH];
        5'd7 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-7 )*DATA_WIDTH-1 : (31-7 )*DATA_WIDTH];
        5'd8 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-8 )*DATA_WIDTH-1 : (31-8 )*DATA_WIDTH];
        5'd9 : bram_rd_ddr_data = _bram_rd_ddr_data[(80-9 )*DATA_WIDTH-1 : (31-9 )*DATA_WIDTH];
        5'd10: bram_rd_ddr_data = _bram_rd_ddr_data[(80-10)*DATA_WIDTH-1 : (31-10)*DATA_WIDTH];
        5'd11: bram_rd_ddr_data = _bram_rd_ddr_data[(80-11)*DATA_WIDTH-1 : (31-11)*DATA_WIDTH];
        5'd12: bram_rd_ddr_data = _bram_rd_ddr_data[(80-12)*DATA_WIDTH-1 : (31-12)*DATA_WIDTH];
        5'd13: bram_rd_ddr_data = _bram_rd_ddr_data[(80-13)*DATA_WIDTH-1 : (31-13)*DATA_WIDTH];
        5'd14: bram_rd_ddr_data = _bram_rd_ddr_data[(80-14)*DATA_WIDTH-1 : (31-14)*DATA_WIDTH];
        5'd15: bram_rd_ddr_data = _bram_rd_ddr_data[(80-15)*DATA_WIDTH-1 : (31-15)*DATA_WIDTH];
        5'd16: bram_rd_ddr_data = _bram_rd_ddr_data[(80-16)*DATA_WIDTH-1 : (31-16)*DATA_WIDTH];
        5'd17: bram_rd_ddr_data = _bram_rd_ddr_data[(80-17)*DATA_WIDTH-1 : (31-17)*DATA_WIDTH];
        5'd18: bram_rd_ddr_data = _bram_rd_ddr_data[(80-18)*DATA_WIDTH-1 : (31-18)*DATA_WIDTH];
        5'd19: bram_rd_ddr_data = _bram_rd_ddr_data[(80-19)*DATA_WIDTH-1 : (31-19)*DATA_WIDTH];
        5'd20: bram_rd_ddr_data = _bram_rd_ddr_data[(80-20)*DATA_WIDTH-1 : (31-20)*DATA_WIDTH];
        5'd21: bram_rd_ddr_data = _bram_rd_ddr_data[(80-21)*DATA_WIDTH-1 : (31-21)*DATA_WIDTH];
        5'd22: bram_rd_ddr_data = _bram_rd_ddr_data[(80-22)*DATA_WIDTH-1 : (31-22)*DATA_WIDTH];
        5'd23: bram_rd_ddr_data = _bram_rd_ddr_data[(80-23)*DATA_WIDTH-1 : (31-23)*DATA_WIDTH];
        5'd24: bram_rd_ddr_data = _bram_rd_ddr_data[(80-24)*DATA_WIDTH-1 : (31-24)*DATA_WIDTH];
        5'd25: bram_rd_ddr_data = _bram_rd_ddr_data[(80-25)*DATA_WIDTH-1 : (31-25)*DATA_WIDTH];
        5'd26: bram_rd_ddr_data = _bram_rd_ddr_data[(80-26)*DATA_WIDTH-1 : (31-26)*DATA_WIDTH];
        5'd27: bram_rd_ddr_data = _bram_rd_ddr_data[(80-27)*DATA_WIDTH-1 : (31-27)*DATA_WIDTH];
        5'd28: bram_rd_ddr_data = _bram_rd_ddr_data[(80-28)*DATA_WIDTH-1 : (31-28)*DATA_WIDTH];
        5'd29: bram_rd_ddr_data = _bram_rd_ddr_data[(80-29)*DATA_WIDTH-1 : (31-29)*DATA_WIDTH];
        5'd30: bram_rd_ddr_data = _bram_rd_ddr_data[(80-30)*DATA_WIDTH-1 : (31-30)*DATA_WIDTH];
        5'd31: bram_rd_ddr_data = _bram_rd_ddr_data[(80-31)*DATA_WIDTH-1 : (31-31)*DATA_WIDTH];
      endcase
    end else begin
      bram_rd_ddr_data = {(49*DATA_WIDTH){1'b0}};
    end
  end

  `ifdef sim_ // {{{
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data00;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data01;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data02;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data03;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data04;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data05;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data06;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data07;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data08;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data09;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data10;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data11;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data12;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data13;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data14;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data15;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data16;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data17;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data18;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data19;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data20;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data21;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data22;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data23;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data24;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data25;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data26;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data27;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data28;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data29;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data30;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data31;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data32;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data33;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data34;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data35;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data36;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data37;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data38;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data39;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data40;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data41;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data42;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data43;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data44;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data45;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data46;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data47;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data48;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data49;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data50;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data51;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data52;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data53;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data54;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data55;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data56;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data57;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data58;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data59;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data60;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data61;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data62;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data63;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data64;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data65;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data66;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data67;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data68;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data69;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data70;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data71;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data72;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data73;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data74;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data75;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data76;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data77;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data78;
  wire[DATA_WIDTH-1 : 0] _bram_rd_ddr_data79;

//assign _bram_rd_ddr_data00 = bram_rd_ddr_a_data[(32-00)*DATA_WIDTH-1 : (32-01)*DATA_WIDTH];
//assign _bram_rd_ddr_data01 = bram_rd_ddr_a_data[(32-01)*DATA_WIDTH-1 : (32-02)*DATA_WIDTH];
//assign _bram_rd_ddr_data02 = bram_rd_ddr_a_data[(32-02)*DATA_WIDTH-1 : (32-03)*DATA_WIDTH];
//assign _bram_rd_ddr_data03 = bram_rd_ddr_a_data[(32-03)*DATA_WIDTH-1 : (32-04)*DATA_WIDTH];
//assign _bram_rd_ddr_data04 = bram_rd_ddr_a_data[(32-04)*DATA_WIDTH-1 : (32-05)*DATA_WIDTH];
//assign _bram_rd_ddr_data05 = bram_rd_ddr_a_data[(32-05)*DATA_WIDTH-1 : (32-06)*DATA_WIDTH];
//assign _bram_rd_ddr_data06 = bram_rd_ddr_a_data[(32-06)*DATA_WIDTH-1 : (32-07)*DATA_WIDTH];
//assign _bram_rd_ddr_data07 = bram_rd_ddr_a_data[(32-07)*DATA_WIDTH-1 : (32-08)*DATA_WIDTH];
//assign _bram_rd_ddr_data08 = bram_rd_ddr_a_data[(32-08)*DATA_WIDTH-1 : (32-09)*DATA_WIDTH];
//assign _bram_rd_ddr_data09 = bram_rd_ddr_a_data[(32-09)*DATA_WIDTH-1 : (32-10)*DATA_WIDTH];
//assign _bram_rd_ddr_data10 = bram_rd_ddr_a_data[(32-10)*DATA_WIDTH-1 : (32-11)*DATA_WIDTH];
//assign _bram_rd_ddr_data11 = bram_rd_ddr_a_data[(32-11)*DATA_WIDTH-1 : (32-12)*DATA_WIDTH];
//assign _bram_rd_ddr_data12 = bram_rd_ddr_a_data[(32-12)*DATA_WIDTH-1 : (32-13)*DATA_WIDTH];
//assign _bram_rd_ddr_data13 = bram_rd_ddr_a_data[(32-13)*DATA_WIDTH-1 : (32-14)*DATA_WIDTH];
//assign _bram_rd_ddr_data14 = bram_rd_ddr_a_data[(32-14)*DATA_WIDTH-1 : (32-15)*DATA_WIDTH];
//assign _bram_rd_ddr_data15 = bram_rd_ddr_a_data[(32-15)*DATA_WIDTH-1 : (32-16)*DATA_WIDTH];
//assign _bram_rd_ddr_data16 = bram_rd_ddr_a_data[(32-16)*DATA_WIDTH-1 : (32-17)*DATA_WIDTH];
//assign _bram_rd_ddr_data17 = bram_rd_ddr_a_data[(32-17)*DATA_WIDTH-1 : (32-18)*DATA_WIDTH];
//assign _bram_rd_ddr_data18 = bram_rd_ddr_a_data[(32-18)*DATA_WIDTH-1 : (32-19)*DATA_WIDTH];
//assign _bram_rd_ddr_data19 = bram_rd_ddr_a_data[(32-19)*DATA_WIDTH-1 : (32-20)*DATA_WIDTH];
//assign _bram_rd_ddr_data20 = bram_rd_ddr_a_data[(32-20)*DATA_WIDTH-1 : (32-21)*DATA_WIDTH];
//assign _bram_rd_ddr_data21 = bram_rd_ddr_a_data[(32-21)*DATA_WIDTH-1 : (32-22)*DATA_WIDTH];
//assign _bram_rd_ddr_data22 = bram_rd_ddr_a_data[(32-22)*DATA_WIDTH-1 : (32-23)*DATA_WIDTH];
//assign _bram_rd_ddr_data23 = bram_rd_ddr_a_data[(32-23)*DATA_WIDTH-1 : (32-24)*DATA_WIDTH];
//assign _bram_rd_ddr_data24 = bram_rd_ddr_a_data[(32-24)*DATA_WIDTH-1 : (32-25)*DATA_WIDTH];
//assign _bram_rd_ddr_data25 = bram_rd_ddr_a_data[(32-25)*DATA_WIDTH-1 : (32-26)*DATA_WIDTH];
//assign _bram_rd_ddr_data26 = bram_rd_ddr_a_data[(32-26)*DATA_WIDTH-1 : (32-27)*DATA_WIDTH];
//assign _bram_rd_ddr_data27 = bram_rd_ddr_a_data[(32-27)*DATA_WIDTH-1 : (32-28)*DATA_WIDTH];
//assign _bram_rd_ddr_data28 = bram_rd_ddr_a_data[(32-28)*DATA_WIDTH-1 : (32-29)*DATA_WIDTH];
//assign _bram_rd_ddr_data29 = bram_rd_ddr_a_data[(32-29)*DATA_WIDTH-1 : (32-30)*DATA_WIDTH];
//assign _bram_rd_ddr_data30 = bram_rd_ddr_a_data[(32-30)*DATA_WIDTH-1 : (32-31)*DATA_WIDTH];
//assign _bram_rd_ddr_data31 = bram_rd_ddr_a_data[(32-31)*DATA_WIDTH-1 : (32-32)*DATA_WIDTH];

  assign _bram_rd_ddr_data00 = _bram_rd_ddr_data[(80-00)*DATA_WIDTH-1 : (80-01)*DATA_WIDTH];
  assign _bram_rd_ddr_data01 = _bram_rd_ddr_data[(80-01)*DATA_WIDTH-1 : (80-02)*DATA_WIDTH];
  assign _bram_rd_ddr_data02 = _bram_rd_ddr_data[(80-02)*DATA_WIDTH-1 : (80-03)*DATA_WIDTH];
  assign _bram_rd_ddr_data03 = _bram_rd_ddr_data[(80-03)*DATA_WIDTH-1 : (80-04)*DATA_WIDTH];
  assign _bram_rd_ddr_data04 = _bram_rd_ddr_data[(80-04)*DATA_WIDTH-1 : (80-05)*DATA_WIDTH];
  assign _bram_rd_ddr_data05 = _bram_rd_ddr_data[(80-05)*DATA_WIDTH-1 : (80-06)*DATA_WIDTH];
  assign _bram_rd_ddr_data06 = _bram_rd_ddr_data[(80-06)*DATA_WIDTH-1 : (80-07)*DATA_WIDTH];
  assign _bram_rd_ddr_data07 = _bram_rd_ddr_data[(80-07)*DATA_WIDTH-1 : (80-08)*DATA_WIDTH];
  assign _bram_rd_ddr_data08 = _bram_rd_ddr_data[(80-08)*DATA_WIDTH-1 : (80-09)*DATA_WIDTH];
  assign _bram_rd_ddr_data09 = _bram_rd_ddr_data[(80-09)*DATA_WIDTH-1 : (80-10)*DATA_WIDTH];
  assign _bram_rd_ddr_data10 = _bram_rd_ddr_data[(80-10)*DATA_WIDTH-1 : (80-11)*DATA_WIDTH];
  assign _bram_rd_ddr_data11 = _bram_rd_ddr_data[(80-11)*DATA_WIDTH-1 : (80-12)*DATA_WIDTH];
  assign _bram_rd_ddr_data12 = _bram_rd_ddr_data[(80-12)*DATA_WIDTH-1 : (80-13)*DATA_WIDTH];
  assign _bram_rd_ddr_data13 = _bram_rd_ddr_data[(80-13)*DATA_WIDTH-1 : (80-14)*DATA_WIDTH];
  assign _bram_rd_ddr_data14 = _bram_rd_ddr_data[(80-14)*DATA_WIDTH-1 : (80-15)*DATA_WIDTH];
  assign _bram_rd_ddr_data15 = _bram_rd_ddr_data[(80-15)*DATA_WIDTH-1 : (80-16)*DATA_WIDTH];
  assign _bram_rd_ddr_data16 = _bram_rd_ddr_data[(80-16)*DATA_WIDTH-1 : (80-17)*DATA_WIDTH];
  assign _bram_rd_ddr_data17 = _bram_rd_ddr_data[(80-17)*DATA_WIDTH-1 : (80-18)*DATA_WIDTH];
  assign _bram_rd_ddr_data18 = _bram_rd_ddr_data[(80-18)*DATA_WIDTH-1 : (80-19)*DATA_WIDTH];
  assign _bram_rd_ddr_data19 = _bram_rd_ddr_data[(80-19)*DATA_WIDTH-1 : (80-20)*DATA_WIDTH];
  assign _bram_rd_ddr_data20 = _bram_rd_ddr_data[(80-20)*DATA_WIDTH-1 : (80-21)*DATA_WIDTH];
  assign _bram_rd_ddr_data21 = _bram_rd_ddr_data[(80-21)*DATA_WIDTH-1 : (80-22)*DATA_WIDTH];
  assign _bram_rd_ddr_data22 = _bram_rd_ddr_data[(80-22)*DATA_WIDTH-1 : (80-23)*DATA_WIDTH];
  assign _bram_rd_ddr_data23 = _bram_rd_ddr_data[(80-23)*DATA_WIDTH-1 : (80-24)*DATA_WIDTH];
  assign _bram_rd_ddr_data24 = _bram_rd_ddr_data[(80-24)*DATA_WIDTH-1 : (80-25)*DATA_WIDTH];
  assign _bram_rd_ddr_data25 = _bram_rd_ddr_data[(80-25)*DATA_WIDTH-1 : (80-26)*DATA_WIDTH];
  assign _bram_rd_ddr_data26 = _bram_rd_ddr_data[(80-26)*DATA_WIDTH-1 : (80-27)*DATA_WIDTH];
  assign _bram_rd_ddr_data27 = _bram_rd_ddr_data[(80-27)*DATA_WIDTH-1 : (80-28)*DATA_WIDTH];
  assign _bram_rd_ddr_data28 = _bram_rd_ddr_data[(80-28)*DATA_WIDTH-1 : (80-29)*DATA_WIDTH];
  assign _bram_rd_ddr_data29 = _bram_rd_ddr_data[(80-29)*DATA_WIDTH-1 : (80-30)*DATA_WIDTH];
  assign _bram_rd_ddr_data30 = _bram_rd_ddr_data[(80-30)*DATA_WIDTH-1 : (80-31)*DATA_WIDTH];
  assign _bram_rd_ddr_data31 = _bram_rd_ddr_data[(80-31)*DATA_WIDTH-1 : (80-32)*DATA_WIDTH];
  assign _bram_rd_ddr_data32 = _bram_rd_ddr_data[(80-32)*DATA_WIDTH-1 : (80-33)*DATA_WIDTH];
  assign _bram_rd_ddr_data33 = _bram_rd_ddr_data[(80-33)*DATA_WIDTH-1 : (80-34)*DATA_WIDTH];
  assign _bram_rd_ddr_data34 = _bram_rd_ddr_data[(80-34)*DATA_WIDTH-1 : (80-35)*DATA_WIDTH];
  assign _bram_rd_ddr_data35 = _bram_rd_ddr_data[(80-35)*DATA_WIDTH-1 : (80-36)*DATA_WIDTH];
  assign _bram_rd_ddr_data36 = _bram_rd_ddr_data[(80-36)*DATA_WIDTH-1 : (80-37)*DATA_WIDTH];
  assign _bram_rd_ddr_data37 = _bram_rd_ddr_data[(80-37)*DATA_WIDTH-1 : (80-38)*DATA_WIDTH];
  assign _bram_rd_ddr_data38 = _bram_rd_ddr_data[(80-38)*DATA_WIDTH-1 : (80-39)*DATA_WIDTH];
  assign _bram_rd_ddr_data39 = _bram_rd_ddr_data[(80-39)*DATA_WIDTH-1 : (80-40)*DATA_WIDTH];
  assign _bram_rd_ddr_data40 = _bram_rd_ddr_data[(80-40)*DATA_WIDTH-1 : (80-41)*DATA_WIDTH];
  assign _bram_rd_ddr_data41 = _bram_rd_ddr_data[(80-41)*DATA_WIDTH-1 : (80-42)*DATA_WIDTH];
  assign _bram_rd_ddr_data42 = _bram_rd_ddr_data[(80-42)*DATA_WIDTH-1 : (80-43)*DATA_WIDTH];
  assign _bram_rd_ddr_data43 = _bram_rd_ddr_data[(80-43)*DATA_WIDTH-1 : (80-44)*DATA_WIDTH];
  assign _bram_rd_ddr_data44 = _bram_rd_ddr_data[(80-44)*DATA_WIDTH-1 : (80-45)*DATA_WIDTH];
  assign _bram_rd_ddr_data45 = _bram_rd_ddr_data[(80-45)*DATA_WIDTH-1 : (80-46)*DATA_WIDTH];
  assign _bram_rd_ddr_data46 = _bram_rd_ddr_data[(80-46)*DATA_WIDTH-1 : (80-47)*DATA_WIDTH];
  assign _bram_rd_ddr_data47 = _bram_rd_ddr_data[(80-47)*DATA_WIDTH-1 : (80-48)*DATA_WIDTH];
  assign _bram_rd_ddr_data48 = _bram_rd_ddr_data[(80-48)*DATA_WIDTH-1 : (80-49)*DATA_WIDTH];
  assign _bram_rd_ddr_data49 = _bram_rd_ddr_data[(80-49)*DATA_WIDTH-1 : (80-50)*DATA_WIDTH];
  assign _bram_rd_ddr_data50 = _bram_rd_ddr_data[(80-50)*DATA_WIDTH-1 : (80-51)*DATA_WIDTH];
  assign _bram_rd_ddr_data51 = _bram_rd_ddr_data[(80-51)*DATA_WIDTH-1 : (80-52)*DATA_WIDTH];
  assign _bram_rd_ddr_data52 = _bram_rd_ddr_data[(80-52)*DATA_WIDTH-1 : (80-53)*DATA_WIDTH];
  assign _bram_rd_ddr_data53 = _bram_rd_ddr_data[(80-53)*DATA_WIDTH-1 : (80-54)*DATA_WIDTH];
  assign _bram_rd_ddr_data54 = _bram_rd_ddr_data[(80-54)*DATA_WIDTH-1 : (80-55)*DATA_WIDTH];
  assign _bram_rd_ddr_data55 = _bram_rd_ddr_data[(80-55)*DATA_WIDTH-1 : (80-56)*DATA_WIDTH];
  assign _bram_rd_ddr_data56 = _bram_rd_ddr_data[(80-56)*DATA_WIDTH-1 : (80-57)*DATA_WIDTH];
  assign _bram_rd_ddr_data57 = _bram_rd_ddr_data[(80-57)*DATA_WIDTH-1 : (80-58)*DATA_WIDTH];
  assign _bram_rd_ddr_data58 = _bram_rd_ddr_data[(80-58)*DATA_WIDTH-1 : (80-59)*DATA_WIDTH];
  assign _bram_rd_ddr_data59 = _bram_rd_ddr_data[(80-59)*DATA_WIDTH-1 : (80-60)*DATA_WIDTH];
  assign _bram_rd_ddr_data60 = _bram_rd_ddr_data[(80-60)*DATA_WIDTH-1 : (80-61)*DATA_WIDTH];
  assign _bram_rd_ddr_data61 = _bram_rd_ddr_data[(80-61)*DATA_WIDTH-1 : (80-62)*DATA_WIDTH];
  assign _bram_rd_ddr_data62 = _bram_rd_ddr_data[(80-62)*DATA_WIDTH-1 : (80-63)*DATA_WIDTH];
  assign _bram_rd_ddr_data63 = _bram_rd_ddr_data[(80-63)*DATA_WIDTH-1 : (80-64)*DATA_WIDTH];
  assign _bram_rd_ddr_data64 = _bram_rd_ddr_data[(80-64)*DATA_WIDTH-1 : (80-65)*DATA_WIDTH];
  assign _bram_rd_ddr_data65 = _bram_rd_ddr_data[(80-65)*DATA_WIDTH-1 : (80-66)*DATA_WIDTH];
  assign _bram_rd_ddr_data66 = _bram_rd_ddr_data[(80-66)*DATA_WIDTH-1 : (80-67)*DATA_WIDTH];
  assign _bram_rd_ddr_data67 = _bram_rd_ddr_data[(80-67)*DATA_WIDTH-1 : (80-68)*DATA_WIDTH];
  assign _bram_rd_ddr_data68 = _bram_rd_ddr_data[(80-68)*DATA_WIDTH-1 : (80-69)*DATA_WIDTH];
  assign _bram_rd_ddr_data69 = _bram_rd_ddr_data[(80-69)*DATA_WIDTH-1 : (80-70)*DATA_WIDTH];
  assign _bram_rd_ddr_data70 = _bram_rd_ddr_data[(80-70)*DATA_WIDTH-1 : (80-71)*DATA_WIDTH];
  assign _bram_rd_ddr_data71 = _bram_rd_ddr_data[(80-71)*DATA_WIDTH-1 : (80-72)*DATA_WIDTH];
  assign _bram_rd_ddr_data72 = _bram_rd_ddr_data[(80-72)*DATA_WIDTH-1 : (80-73)*DATA_WIDTH];
  assign _bram_rd_ddr_data73 = _bram_rd_ddr_data[(80-73)*DATA_WIDTH-1 : (80-74)*DATA_WIDTH];
  assign _bram_rd_ddr_data74 = _bram_rd_ddr_data[(80-74)*DATA_WIDTH-1 : (80-75)*DATA_WIDTH];
  assign _bram_rd_ddr_data75 = _bram_rd_ddr_data[(80-75)*DATA_WIDTH-1 : (80-76)*DATA_WIDTH];
  assign _bram_rd_ddr_data76 = _bram_rd_ddr_data[(80-76)*DATA_WIDTH-1 : (80-77)*DATA_WIDTH];
  assign _bram_rd_ddr_data77 = _bram_rd_ddr_data[(80-77)*DATA_WIDTH-1 : (80-78)*DATA_WIDTH];
  assign _bram_rd_ddr_data78 = _bram_rd_ddr_data[(80-78)*DATA_WIDTH-1 : (80-79)*DATA_WIDTH];
  assign _bram_rd_ddr_data79 = _bram_rd_ddr_data[(80-79)*DATA_WIDTH-1 : (80-80)*DATA_WIDTH];
  `endif
  // }}}

endmodule
