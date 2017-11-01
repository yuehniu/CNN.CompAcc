// ---------------------------------------------------
// File       : mem_ker.v
//
// Description: read/write from/to param weight reg, asynchronous read
//              reset _mem_ker_offset -- 1.1
//              16 bit data width -- 1.2
//
// Version    : 1.2
// ---------------------------------------------------

module mem_ker#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter K_C      = 32,
    parameter K_H      = 3,
    parameter K_W      = 3
  ) (
    input  wire                                           clk,
    input  wire                                           rst_n,
    input  wire                                           mem_ker_valid,      // kernel data valid
    input  wire                                           mem_ker_last,       // last kernel data burst
  //input  wire                                           mem_ker_burst_cnt,  // 
    input  wire[511:0]                                    mem_ker_i,          // kernel data burst from ddr
    output wire[K_C*K_H*K_W*(EXPONENT+MANTISSA+1)-1:0]    mem_ker_o           // ker_channels*ker_height*ker_width
  );

  localparam BURST_LEN  = 8;
  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;
  localparam MAX_NUM_OF_CHANNELS  = 512;
  localparam DDR_BURST_DATA_WIDTH = 512;
  localparam NUM_OF_DATA_IN_1_BURST =  DDR_BURST_DATA_WIDTH / DATA_WIDTH;
  localparam KERNEL_CHANNELS  = 32;
  localparam KERNEL_HEIGHT    = 3;
  localparam KERNEL_WIDTH     = 3;

  reg  [DATA_WIDTH-1:0] _mem_ker[0:KERNEL_CHANNELS*KERNEL_HEIGHT*KERNEL_WIDTH-1];
  reg  [9:0]            _mem_ker_offset;

  // kernel memory address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_ker_offset <= 10'h0;
    end else begin
      // increment
      if(mem_ker_valid) begin
        _mem_ker_offset <= _mem_ker_offset + NUM_OF_DATA_IN_1_BURST;
      end
      // reset
      if(mem_ker_last) begin
        _mem_ker_offset <= 10'h0;
      end
    end
  end

  // memory data
  always@(posedge clk) begin
    if(mem_ker_valid) begin
      _mem_ker[_mem_ker_offset + 0] <= mem_ker_i[(31+1)*DATA_WIDTH-1 : 31*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 1] <= mem_ker_i[(30+1)*DATA_WIDTH-1 : 30*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 2] <= mem_ker_i[(29+1)*DATA_WIDTH-1 : 29*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 3] <= mem_ker_i[(28+1)*DATA_WIDTH-1 : 28*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 4] <= mem_ker_i[(27+1)*DATA_WIDTH-1 : 27*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 5] <= mem_ker_i[(26+1)*DATA_WIDTH-1 : 26*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 6] <= mem_ker_i[(25+1)*DATA_WIDTH-1 : 25*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 7] <= mem_ker_i[(24+1)*DATA_WIDTH-1 : 24*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 8] <= mem_ker_i[(23+1)*DATA_WIDTH-1 : 23*DATA_WIDTH];
      _mem_ker[_mem_ker_offset + 9] <= mem_ker_i[(22+1)*DATA_WIDTH-1 : 22*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +10] <= mem_ker_i[(21+1)*DATA_WIDTH-1 : 21*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +11] <= mem_ker_i[(20+1)*DATA_WIDTH-1 : 20*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +12] <= mem_ker_i[(19+1)*DATA_WIDTH-1 : 19*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +13] <= mem_ker_i[(18+1)*DATA_WIDTH-1 : 18*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +14] <= mem_ker_i[(17+1)*DATA_WIDTH-1 : 17*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +15] <= mem_ker_i[(16+1)*DATA_WIDTH-1 : 16*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +16] <= mem_ker_i[(15+1)*DATA_WIDTH-1 : 15*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +17] <= mem_ker_i[(14+1)*DATA_WIDTH-1 : 14*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +18] <= mem_ker_i[(13+1)*DATA_WIDTH-1 : 13*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +19] <= mem_ker_i[(12+1)*DATA_WIDTH-1 : 12*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +20] <= mem_ker_i[(11+1)*DATA_WIDTH-1 : 11*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +21] <= mem_ker_i[(10+1)*DATA_WIDTH-1 : 10*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +22] <= mem_ker_i[( 9+1)*DATA_WIDTH-1 :  9*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +23] <= mem_ker_i[( 8+1)*DATA_WIDTH-1 :  8*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +24] <= mem_ker_i[( 7+1)*DATA_WIDTH-1 :  7*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +25] <= mem_ker_i[( 6+1)*DATA_WIDTH-1 :  6*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +26] <= mem_ker_i[( 5+1)*DATA_WIDTH-1 :  5*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +27] <= mem_ker_i[( 4+1)*DATA_WIDTH-1 :  4*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +28] <= mem_ker_i[( 3+1)*DATA_WIDTH-1 :  3*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +29] <= mem_ker_i[( 2+1)*DATA_WIDTH-1 :  2*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +30] <= mem_ker_i[( 1+1)*DATA_WIDTH-1 :  1*DATA_WIDTH];
      _mem_ker[_mem_ker_offset +31] <= mem_ker_i[( 0+1)*DATA_WIDTH-1 :  0*DATA_WIDTH];
    end
  end

  // output
  genvar i;
  generate
    for(i=0; i<KERNEL_CHANNELS*KERNEL_HEIGHT*KERNEL_WIDTH; i=i+1) begin
      assign mem_ker_o[(i+1)*DATA_WIDTH-1: i*DATA_WIDTH] = _mem_ker[KERNEL_CHANNELS*KERNEL_HEIGHT*KERNEL_WIDTH-1-i];
    end
  endgenerate

  // -------------------- simulation --------------------{{{
  wire[31:0] _mem_ker_data01,_mem_ker_data02,_mem_ker_data03,_mem_ker_data04,_mem_ker_data05,_mem_ker_data06,_mem_ker_data07,_mem_ker_data08,
             _mem_ker_data09,_mem_ker_data10,_mem_ker_data11,_mem_ker_data12,_mem_ker_data13,_mem_ker_data14,_mem_ker_data15,_mem_ker_data16;

  assign _mem_ker_data01 = mem_ker_i[511:480]; assign _mem_ker_data02 = mem_ker_i[479:448];
  assign _mem_ker_data03 = mem_ker_i[447:416]; assign _mem_ker_data04 = mem_ker_i[415:384];
  assign _mem_ker_data05 = mem_ker_i[383:352]; assign _mem_ker_data06 = mem_ker_i[351:320];
  assign _mem_ker_data07 = mem_ker_i[319:288]; assign _mem_ker_data08 = mem_ker_i[287:256];
  assign _mem_ker_data09 = mem_ker_i[255:224]; assign _mem_ker_data10 = mem_ker_i[223:192];
  assign _mem_ker_data11 = mem_ker_i[191:160]; assign _mem_ker_data12 = mem_ker_i[159:128];
  assign _mem_ker_data13 = mem_ker_i[127:96];  assign _mem_ker_data14 = mem_ker_i[95:64];
  assign _mem_ker_data15 = mem_ker_i[63:32];   assign _mem_ker_data16 = mem_ker_i[31:0];

  // -------------------- simulation --------------------}}}

endmodule
