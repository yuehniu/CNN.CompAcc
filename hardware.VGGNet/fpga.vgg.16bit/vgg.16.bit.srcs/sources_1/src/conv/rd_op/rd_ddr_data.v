// ---------------------------------------------------
// File       : rd_ddr_data.v
//
// Description: read data(patch and padding) from ddr
//              remove state RD_DATA_PATCH_BRAM
//              add bottom address
//              prevent last valid blocking
//              correct reading (x,end) error
//              no valid signal on reset -- 1.8
//              compatible with mem_top -- 1.9
//              change storage arrangement -- 1.10
//              store mini-patch in integral num of ddr data burst -- 1.11
//              16 bit data -- 1.12
//
// Version    : 1.12
// ---------------------------------------------------

module rd_ddr_data(
    input  wire           clk,
    input  wire           rst_n,
    // ddr
    input  wire           ddr_rd_data_valid,
    input  wire           ddr_rdy,
    input  wire [511:0]   ddr_rd_data,
    output reg  [29:0]    ddr_addr,
    output reg  [2:0]     ddr_cmd,
    output reg            ddr_en,
    //
    input  wire           rd_data_bottom,     // read bottom data enable
    input  wire [29:0]    rd_data_bottom_addr,// read bottom data address, start address of bottom data
    input  wire [8:0]     rd_data_end_of_x,
    input  wire [8:0]     rd_data_end_of_y,
    input  wire [8:0]     rd_data_x,          // column index of the patch, stable till end
    input  wire [8:0]     rd_data_y,          // row index of the patch
    input  wire           rd_data_first_fm,   // first input feature map, update base address
    input  wire [29:0]    rd_data_bottom_ith_offset,  // ith bottom feature map size, stable till end
    input  wire [29:0]    rd_data_bar_offset, // 14*rd_data_max_x*float_num_width/ddr_data_width
    input  wire [29:0]    rd_data_half_bar_offset, // 7*rd_data_max_x*float_num_width/ddr_data_width
    output reg  [511:0]   rd_data_data, // rearranged ddr data
    output reg  [5:0]     rd_data_num_valid, // num of valid float data(32 bits) in rd_data_data
    output reg            rd_data_valid,
    output reg            rd_data_patch_valid_last,
    output reg            rd_data_upper_valid_last,
    output reg            rd_data_valid_first,
    output reg            rd_data_full
  );

  // states
  localparam RD_DATA_RST        = 4'd0;
  localparam RD_DATA_UPPER_PATCH= 4'd1;
  localparam RD_DATA_LOWER_PATCH= 4'd2;
  localparam RD_DATA_PADDING    = 4'd3;
  // constant parameter
  localparam FLOAT_NUM_WIDTH  = 16;
  localparam DATA_WIDTH       = FLOAT_NUM_WIDTH;
  localparam DDR_DATA_WIDTH   = 64;
  localparam DDR_BURST_LEN    = 8; // ddr data burst length
  //
  localparam RD_MINI_1_SIZE = (7*7*FLOAT_NUM_WIDTH/DDR_DATA_WIDTH/DDR_BURST_LEN + 1)*DDR_BURST_LEN;
  localparam RD_MINI_2_SIZE = 2*RD_MINI_1_SIZE;
  localparam RD_MINI_3_SIZE = 3*RD_MINI_1_SIZE;
  localparam RD_HALF_0Y_CNT = (7*7*FLOAT_NUM_WIDTH/DDR_DATA_WIDTH/DDR_BURST_LEN + 1)*3 - 1; // 4*3-1
  localparam RD_HALF_XY_CNT = (7*7*FLOAT_NUM_WIDTH/DDR_DATA_WIDTH/DDR_BURST_LEN + 1)*2 - 1; // 4*2-1
  localparam RD_HALF_EY_CNT = (7*7*FLOAT_NUM_WIDTH/DDR_DATA_WIDTH/DDR_BURST_LEN + 1)*1 - 1; // 4*1-1
  localparam RD_PADDING_0Y_CNT = 3;
  localparam RD_PADDING_XY_CNT = 2;
  localparam RD_PADDING_EY_CNT = 1;
  localparam RD_TOTAL_0Y_CNT= 2*RD_HALF_0Y_CNT+1 +RD_PADDING_0Y_CNT;
  localparam RD_TOTAL_XY_CNT= 2*RD_HALF_XY_CNT+1 +RD_PADDING_XY_CNT;
  localparam RD_TOTAL_EY_CNT= 2*RD_HALF_EY_CNT+1 +RD_PADDING_EY_CNT;

  reg  [3:0]    _rd_data_state;
  reg  [3:0]    _rd_data_next_state;

  reg           _rd_data_on_padding;
  reg           _rd_data_upper_last;
  reg           _rd_data_lower_last;
  reg           _rd_data_padding_stop;
//reg           rd_data_upper_valid_last;
  reg  [3:0]    _rd_data_upper_cnt;
  reg  [3:0]    _rd_data_lower_cnt;
  reg  [4:0]    _rd_data_valid_cnt;
  reg  [1:0]    _rd_data_padding_cnt;
  reg  [29:0]   _rd_data_upper_offset;
  reg  [29:0]   _rd_data_lower_offset;
  reg  [29:0]   _rd_data_padding_offset;
  reg  [29:0]   _rd_data_upper_addr;
  reg  [29:0]   _rd_data_lower_addr;
  reg  [29:0]   _rd_data_padding_addr;
  reg           _rd_data_upper_next;
  reg           _rd_data_lower_next;
  reg           _rd_data_padding_next;
  // lead by 1 clk
  reg           _rd_data_full;
  wire          _rd_data_valid_first;
  reg           _rd_data_patch_valid_last;
  reg           _rd_data_upper_valid_last;
  reg [5:0]     _rd_data_num_valid;
//assign        rd_data_num_valid = _rd_data_num_valid;

  assign _rd_data_valid_first = (ddr_rd_data_valid && (_rd_data_valid_cnt == 5'h0) && (_rd_data_state!=RD_DATA_RST));
  // relay
  always@(posedge clk) begin
    rd_data_valid             <= (ddr_rd_data_valid && _rd_data_state!=RD_DATA_RST);
    rd_data_patch_valid_last  <= _rd_data_patch_valid_last;
    rd_data_upper_valid_last  <= _rd_data_upper_valid_last;
    rd_data_valid_first       <= _rd_data_valid_first;
    rd_data_full              <= _rd_data_full;
    rd_data_num_valid         <= _rd_data_num_valid;
  //rd_data_data              <= {ddr_rd_data};
    rd_data_data[ 1*DATA_WIDTH - 1 :  0*DATA_WIDTH] <= ddr_rd_data[32*DATA_WIDTH - 1: 31*DATA_WIDTH];
    rd_data_data[ 2*DATA_WIDTH - 1 :  1*DATA_WIDTH] <= ddr_rd_data[31*DATA_WIDTH - 1: 30*DATA_WIDTH];
    rd_data_data[ 3*DATA_WIDTH - 1 :  2*DATA_WIDTH] <= ddr_rd_data[30*DATA_WIDTH - 1: 29*DATA_WIDTH];
    rd_data_data[ 4*DATA_WIDTH - 1 :  3*DATA_WIDTH] <= ddr_rd_data[29*DATA_WIDTH - 1: 28*DATA_WIDTH];
    rd_data_data[ 5*DATA_WIDTH - 1 :  4*DATA_WIDTH] <= ddr_rd_data[28*DATA_WIDTH - 1: 27*DATA_WIDTH];
    rd_data_data[ 6*DATA_WIDTH - 1 :  5*DATA_WIDTH] <= ddr_rd_data[27*DATA_WIDTH - 1: 26*DATA_WIDTH];
    rd_data_data[ 7*DATA_WIDTH - 1 :  6*DATA_WIDTH] <= ddr_rd_data[26*DATA_WIDTH - 1: 25*DATA_WIDTH];
    rd_data_data[ 8*DATA_WIDTH - 1 :  7*DATA_WIDTH] <= ddr_rd_data[25*DATA_WIDTH - 1: 24*DATA_WIDTH];
    rd_data_data[ 9*DATA_WIDTH - 1 :  8*DATA_WIDTH] <= ddr_rd_data[24*DATA_WIDTH - 1: 23*DATA_WIDTH];
    rd_data_data[10*DATA_WIDTH - 1 :  9*DATA_WIDTH] <= ddr_rd_data[23*DATA_WIDTH - 1: 22*DATA_WIDTH];
    rd_data_data[11*DATA_WIDTH - 1 : 10*DATA_WIDTH] <= ddr_rd_data[22*DATA_WIDTH - 1: 21*DATA_WIDTH];
    rd_data_data[12*DATA_WIDTH - 1 : 11*DATA_WIDTH] <= ddr_rd_data[21*DATA_WIDTH - 1: 20*DATA_WIDTH];
    rd_data_data[13*DATA_WIDTH - 1 : 12*DATA_WIDTH] <= ddr_rd_data[20*DATA_WIDTH - 1: 19*DATA_WIDTH];
    rd_data_data[14*DATA_WIDTH - 1 : 13*DATA_WIDTH] <= ddr_rd_data[19*DATA_WIDTH - 1: 18*DATA_WIDTH];
    rd_data_data[15*DATA_WIDTH - 1 : 14*DATA_WIDTH] <= ddr_rd_data[18*DATA_WIDTH - 1: 17*DATA_WIDTH];
    rd_data_data[16*DATA_WIDTH - 1 : 15*DATA_WIDTH] <= ddr_rd_data[17*DATA_WIDTH - 1: 16*DATA_WIDTH];
    rd_data_data[17*DATA_WIDTH - 1 : 16*DATA_WIDTH] <= ddr_rd_data[16*DATA_WIDTH - 1: 15*DATA_WIDTH];
    rd_data_data[18*DATA_WIDTH - 1 : 17*DATA_WIDTH] <= ddr_rd_data[15*DATA_WIDTH - 1: 14*DATA_WIDTH];
    rd_data_data[19*DATA_WIDTH - 1 : 18*DATA_WIDTH] <= ddr_rd_data[14*DATA_WIDTH - 1: 13*DATA_WIDTH];
    rd_data_data[20*DATA_WIDTH - 1 : 19*DATA_WIDTH] <= ddr_rd_data[13*DATA_WIDTH - 1: 12*DATA_WIDTH];
    rd_data_data[21*DATA_WIDTH - 1 : 20*DATA_WIDTH] <= ddr_rd_data[12*DATA_WIDTH - 1: 11*DATA_WIDTH];
    rd_data_data[22*DATA_WIDTH - 1 : 21*DATA_WIDTH] <= ddr_rd_data[11*DATA_WIDTH - 1: 10*DATA_WIDTH];
    rd_data_data[23*DATA_WIDTH - 1 : 22*DATA_WIDTH] <= ddr_rd_data[10*DATA_WIDTH - 1:  9*DATA_WIDTH];
    rd_data_data[24*DATA_WIDTH - 1 : 23*DATA_WIDTH] <= ddr_rd_data[ 9*DATA_WIDTH - 1:  8*DATA_WIDTH];
    rd_data_data[25*DATA_WIDTH - 1 : 24*DATA_WIDTH] <= ddr_rd_data[ 8*DATA_WIDTH - 1:  7*DATA_WIDTH];
    rd_data_data[26*DATA_WIDTH - 1 : 25*DATA_WIDTH] <= ddr_rd_data[ 7*DATA_WIDTH - 1:  6*DATA_WIDTH];
    rd_data_data[27*DATA_WIDTH - 1 : 26*DATA_WIDTH] <= ddr_rd_data[ 6*DATA_WIDTH - 1:  5*DATA_WIDTH];
    rd_data_data[28*DATA_WIDTH - 1 : 27*DATA_WIDTH] <= ddr_rd_data[ 5*DATA_WIDTH - 1:  4*DATA_WIDTH];
    rd_data_data[29*DATA_WIDTH - 1 : 28*DATA_WIDTH] <= ddr_rd_data[ 4*DATA_WIDTH - 1:  3*DATA_WIDTH];
    rd_data_data[30*DATA_WIDTH - 1 : 29*DATA_WIDTH] <= ddr_rd_data[ 3*DATA_WIDTH - 1:  2*DATA_WIDTH];
    rd_data_data[31*DATA_WIDTH - 1 : 30*DATA_WIDTH] <= ddr_rd_data[ 2*DATA_WIDTH - 1:  1*DATA_WIDTH];
    rd_data_data[32*DATA_WIDTH - 1 : 31*DATA_WIDTH] <= ddr_rd_data[ 1*DATA_WIDTH - 1:  0*DATA_WIDTH];
  end

  // FF
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_state <= RD_DATA_RST;
    end else begin
      _rd_data_state <= _rd_data_next_state;
    end
  end
  // transition
  always@(_rd_data_state or rd_data_bottom or _rd_data_upper_last or
          _rd_data_lower_last or _rd_data_full) begin
    _rd_data_next_state = RD_DATA_RST;
    case(_rd_data_state)
      RD_DATA_RST: begin
        if(rd_data_bottom) begin
          _rd_data_next_state = RD_DATA_UPPER_PATCH;
        end else begin
          _rd_data_next_state = RD_DATA_RST;
        end
      end
      RD_DATA_UPPER_PATCH: begin
        if(_rd_data_upper_last) begin
          _rd_data_next_state = RD_DATA_LOWER_PATCH;
        end else begin
          _rd_data_next_state = RD_DATA_UPPER_PATCH;
        end
      end
      RD_DATA_LOWER_PATCH: begin
        if(_rd_data_lower_last) begin
          _rd_data_next_state = RD_DATA_PADDING;
        end else begin
          _rd_data_next_state = RD_DATA_LOWER_PATCH;
        end
      end
      RD_DATA_PADDING: begin
        if(_rd_data_full) begin
          _rd_data_next_state = RD_DATA_RST;
        end else begin
          _rd_data_next_state = RD_DATA_PADDING;
        end
      end
    endcase
  end
  // logic
  always@(_rd_data_state or _rd_data_upper_addr or _rd_data_upper_offset or
          _rd_data_lower_addr or _rd_data_lower_offset or _rd_data_padding_addr or
          _rd_data_padding_offset or ddr_rdy or _rd_data_padding_stop) begin
    ddr_en    = 1'b0;
    ddr_cmd   = 3'h1;
    ddr_addr  = 30'h0;
    _rd_data_upper_next = 1'b0;
    _rd_data_lower_next = 1'b0;
    _rd_data_padding_next = 1'b0;
    case(_rd_data_state)
      RD_DATA_RST: begin
        ddr_en = 1'b0;
      end
      RD_DATA_UPPER_PATCH: begin
        if(ddr_rdy) begin
          ddr_en    = 1'b1;
          ddr_cmd   = 3'h1;
          ddr_addr  = _rd_data_upper_addr + _rd_data_upper_offset;
          _rd_data_upper_next = 1'b1;
        end else begin
          ddr_en    = 1'b0;
          ddr_cmd   = 3'h1;
          ddr_addr  = _rd_data_upper_addr + _rd_data_upper_offset;
        end
      end
      RD_DATA_LOWER_PATCH: begin
        if(ddr_rdy) begin
          ddr_en    = 1'b1;
          ddr_cmd   = 3'h1;
          ddr_addr  = _rd_data_lower_addr + _rd_data_lower_offset;
          _rd_data_lower_next = 1'b1;
        end else begin
          ddr_en    = 1'b0;
          ddr_cmd   = 3'h1;
          ddr_addr  = _rd_data_lower_addr + _rd_data_lower_offset;
        end
      end
      RD_DATA_PADDING: begin
        if(_rd_data_padding_stop) begin
          ddr_en    = 1'b0;
          ddr_cmd   = 3'h1;
          ddr_addr  = _rd_data_padding_addr + _rd_data_padding_offset;
        end else begin
          if(ddr_rdy) begin
            ddr_en  = 1'b1;
            ddr_cmd = 3'h1;
            ddr_addr= _rd_data_padding_addr + _rd_data_padding_offset;
            _rd_data_padding_next = 1'b1;
          end else begin
            ddr_en  = 1'b0;
            ddr_cmd = 3'h1;
            ddr_addr= _rd_data_padding_addr + _rd_data_padding_offset;
            _rd_data_padding_next = 1'b0;
          end
        end
      end
    endcase
  end
  // patch address and padding address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_upper_addr <= 30'h0;
      _rd_data_lower_addr <= 30'h0;
      _rd_data_padding_addr <= 30'h0;
    end else begin
      if(rd_data_bottom && rd_data_first_fm && (_rd_data_state == RD_DATA_RST)) begin
        if(rd_data_x == 9'h0) begin
          if(rd_data_y == 9'h0) begin
            _rd_data_upper_addr <= rd_data_bottom_addr;
            _rd_data_lower_addr <= rd_data_bottom_addr + rd_data_half_bar_offset;
            _rd_data_padding_addr <= rd_data_bottom_addr + rd_data_bar_offset;
          end else begin
            _rd_data_upper_addr <= _rd_data_upper_addr + rd_data_half_bar_offset + RD_MINI_1_SIZE;
            _rd_data_lower_addr <= _rd_data_lower_addr + rd_data_half_bar_offset + RD_MINI_1_SIZE;
            _rd_data_padding_addr <= _rd_data_padding_addr + rd_data_half_bar_offset + RD_MINI_1_SIZE;
          end
        end else if(rd_data_x == 9'h1) begin
          _rd_data_upper_addr <= _rd_data_upper_addr + RD_MINI_3_SIZE;
          _rd_data_lower_addr <= _rd_data_lower_addr + RD_MINI_3_SIZE;
          _rd_data_padding_addr <= _rd_data_padding_addr + RD_MINI_3_SIZE;
        end else begin
          _rd_data_upper_addr <= _rd_data_upper_addr + RD_MINI_2_SIZE;
          _rd_data_lower_addr <= _rd_data_lower_addr + RD_MINI_2_SIZE;
          _rd_data_padding_addr <= _rd_data_padding_addr + RD_MINI_2_SIZE;
        end
      end
    end
  end
  // patch offset and padding offset
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_upper_offset <= 30'h0;
      _rd_data_lower_offset <= 30'h0;
      _rd_data_padding_offset <= 30'h0;
    end else begin
      if(rd_data_bottom && (_rd_data_state==RD_DATA_RST)) begin
      // reset
        _rd_data_upper_offset <= rd_data_bottom_ith_offset;
        _rd_data_lower_offset <= rd_data_bottom_ith_offset;
        _rd_data_padding_offset <= rd_data_bottom_ith_offset;
      end else begin
      // increment
        if(_rd_data_upper_next) begin
          _rd_data_upper_offset <= _rd_data_upper_offset + DDR_BURST_LEN;
        end
        if(_rd_data_lower_next) begin
          _rd_data_lower_offset <= _rd_data_lower_offset + DDR_BURST_LEN;
        end
        if(_rd_data_padding_next) begin
          _rd_data_padding_offset <= _rd_data_padding_offset + RD_MINI_1_SIZE;
        end
      end
    end
  end
  // patch counter, padding counter and valid counter
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_upper_cnt <= 4'h0;
      _rd_data_lower_cnt <= 4'h0;
      _rd_data_valid_cnt <= 5'h0;
      _rd_data_padding_cnt <= 2'h0;
    end else begin
      if(rd_data_bottom && (_rd_data_state==RD_DATA_RST)) begin
      // reset
        _rd_data_upper_cnt <= 4'h0;
        _rd_data_lower_cnt <= 4'h0;
        _rd_data_valid_cnt <= 5'h0;
        _rd_data_padding_cnt <= 2'h0;
      end else begin
      // increment
        if(_rd_data_upper_next) begin
          _rd_data_upper_cnt <= _rd_data_upper_cnt + 1'b1;
        end
        if(_rd_data_lower_next) begin
          _rd_data_lower_cnt <= _rd_data_lower_cnt + 1'b1;
        end
        if(_rd_data_padding_next) begin
          _rd_data_padding_cnt <= _rd_data_padding_cnt + 1'b1;
        end
        if(ddr_rd_data_valid && (_rd_data_state!=RD_DATA_RST)) begin
          _rd_data_valid_cnt <= _rd_data_valid_cnt + 1'b1;
        end
        // reset
        if(_rd_data_full) begin
          _rd_data_upper_cnt <= 4'h0;
          _rd_data_lower_cnt <= 4'h0;
          _rd_data_valid_cnt <= 5'h0;
          _rd_data_padding_cnt <= 2'h0;
        end
      end
    end
  end
  // 'last' signal
  always@(rst_n or _rd_data_upper_cnt or _rd_data_lower_cnt or ddr_rd_data_valid or
          _rd_data_padding_cnt or _rd_data_valid_cnt or rd_data_x or ddr_rdy or
          rd_data_y or rd_data_end_of_x or rd_data_end_of_y or _rd_data_state) begin
  //if(!rst_n) begin
  //  rd_data_full        = 1'b0;
  //  _rd_data_upper_last = 1'b0;
  //  _rd_data_lower_last = 1'b0;
  //  _rd_data_padding_stop = 1'b0;
  //  rd_data_patch_valid_last = 1'b0;
  //  rd_data_upper_valid_last = 1'b0;
  //end else begin
      if(rd_data_x == 9'h0) begin
      // (0,y)
        if(rd_data_x == rd_data_end_of_x) begin // 14x14
          _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_XY_CNT));
          _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_XY_CNT));
          _rd_data_padding_stop = (_rd_data_state!=RD_DATA_RST);
          _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_XY_CNT - RD_PADDING_XY_CNT)));
          _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_XY_CNT));
          _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_XY_CNT - RD_PADDING_XY_CNT)));
        end else begin // >14x14
          if(rd_data_y == rd_data_end_of_y) begin
            _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_0Y_CNT));
            _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_0Y_CNT));
            _rd_data_padding_stop = (_rd_data_state!=RD_DATA_RST);
            _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_0Y_CNT - RD_PADDING_0Y_CNT)));
            _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_0Y_CNT));
            _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_0Y_CNT - RD_PADDING_0Y_CNT)));
          end else begin
            _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_0Y_CNT));
            _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_0Y_CNT));
            _rd_data_padding_stop = ((_rd_data_state!=RD_DATA_RST) && (_rd_data_padding_cnt == RD_PADDING_0Y_CNT));
            _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_0Y_CNT - RD_PADDING_0Y_CNT)));
            _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_0Y_CNT));
            _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_TOTAL_0Y_CNT));
          end
        end
      end else if(rd_data_x == rd_data_end_of_x) begin
      // (e,y)
        if(rd_data_y == rd_data_end_of_y) begin
          _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_EY_CNT));
          _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_EY_CNT));
          _rd_data_padding_stop = (_rd_data_state!=RD_DATA_RST);
          _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_EY_CNT - RD_PADDING_EY_CNT)));
          _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_EY_CNT));
          _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_EY_CNT - RD_PADDING_EY_CNT)));
        end else begin
          _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_EY_CNT));
          _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_EY_CNT));
          _rd_data_padding_stop = ((_rd_data_state!=RD_DATA_RST) && (_rd_data_padding_cnt == RD_PADDING_EY_CNT));
          _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_EY_CNT - RD_PADDING_EY_CNT)));
          _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_EY_CNT));
          _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_TOTAL_EY_CNT));
        end
      end else begin
      // (x,y)
        if(rd_data_y == rd_data_end_of_y) begin
          _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_XY_CNT));
          _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_XY_CNT));
          _rd_data_padding_stop = (_rd_data_state!=RD_DATA_RST);
          _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_XY_CNT - RD_PADDING_XY_CNT)));
          _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_XY_CNT));
          _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_XY_CNT - RD_PADDING_XY_CNT)));
        end else begin
          _rd_data_upper_last = (ddr_rdy && (_rd_data_upper_cnt == RD_HALF_XY_CNT));
          _rd_data_lower_last = (ddr_rdy && (_rd_data_lower_cnt == RD_HALF_XY_CNT));
          _rd_data_padding_stop = ((_rd_data_state!=RD_DATA_RST) && (_rd_data_padding_cnt == RD_PADDING_XY_CNT));
          _rd_data_patch_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == (RD_TOTAL_XY_CNT - RD_PADDING_XY_CNT)));
          _rd_data_upper_valid_last = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_HALF_XY_CNT));
          _rd_data_full  = (ddr_rd_data_valid && (_rd_data_valid_cnt == RD_TOTAL_XY_CNT));
        end
      end
  //end
  end
  // on padding
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_on_padding <= 1'b0;
    end else begin
      if(_rd_data_patch_valid_last) begin
        if(_rd_data_full) begin
          _rd_data_on_padding <= 1'b0;
        end else begin
          _rd_data_on_padding <= 1'b1;
        end
      end
      if(_rd_data_full && (!_rd_data_patch_valid_last)) begin
        _rd_data_on_padding <= 1'b0;
      end
    end
  end
  // data valid, num of valid datum in data burst
  always@(ddr_rd_data_valid or _rd_data_upper_valid_last or _rd_data_valid_cnt or
          _rd_data_patch_valid_last or _rd_data_on_padding or _rd_data_state) begin
    if(ddr_rd_data_valid && (_rd_data_state!=RD_DATA_RST)) begin
      if(_rd_data_upper_valid_last || _rd_data_patch_valid_last || ((_rd_data_valid_cnt[0]==1'h1) && !_rd_data_on_padding) ) begin
        _rd_data_num_valid = 6'd17;
      end else if(_rd_data_on_padding) begin
        _rd_data_num_valid = 6'd7;
      end else begin
        _rd_data_num_valid = 6'd32;
      end
    end else begin
      _rd_data_num_valid = 6'd0;
    end
  end

endmodule
