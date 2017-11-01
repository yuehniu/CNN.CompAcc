// ---------------------------------------------------
// File       : wr_ddr_data.v
//
// Description: write data into ddr
//              pooling data not implemented -- 1.0
//              with pooling enabled
//              check 14x14 error -- 1.1
//              compensate for bram reading -- 1.2
//              16 bit data width (not checked) -- 1.3
//
// Version    : 1.3
// ---------------------------------------------------

//`define sim_
module wr_ddr_data#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter ATOMIC_H = 14,
    parameter ATOMIC_W = 14,
    parameter KER_C    = 32
  ) (
    input  wire                                                     clk,
    input  wire                                                     rst_n,
    // ddr
    input  wire                                                     ddr_rdy,
    input  wire                                                     ddr_wdf_rdy,
    output reg  [511:0]                                             ddr_wdf_data,
    output reg  [63:0]                                              ddr_wdf_mask,
    output reg                                                      ddr_wdf_end,
    output reg                                                      ddr_wdf_wren,
    output reg  [29:0]                                              ddr_addr,
    output reg  [2:0]                                               ddr_cmd,
    output reg                                                      ddr_en,
    //
    input  wire                                                     wr_data_top, // write top data
    input  wire [29:0]                                              wr_data_top_addr, // writing address; provided by top module, not fsm
    input  wire [9:0]                                               wr_data_top_channels, // num of top data channels; provided by top module, not fsm
    input  wire [7*7*(EXPONENT+MANTISSA+1)-1:0]                     wr_data_data_i,
    input  wire                                                     wr_data_x_eq_0,
    input  wire                                                     wr_data_y_eq_0,
    input  wire                                                     wr_data_x_eq_end,
    input  wire                                                     wr_data_y_eq_end,
    input  wire                                                     wr_data_pooling_en, // is pooling layer output; provided by top module, not fsm
    input  wire [29:0]                                              wr_data_half_bar_size, // size of half bar; provided by top module, not fsm
    input  wire [29:0]                                              wr_data_fm_size, // provided by top module, not fsm, output fm size
    input  wire                                                     wr_data_data_valid, // data valid on wr_data_data_i
    output reg                                                      wr_data_rd_top_buffer,
    output wire                                                     wr_data_next_quarter,   // writing the last datum of current 7x7, requiring the next 7x7 data
    output wire                                                     wr_data_next_channel, // current channel finished, writing the last datum to ddr
    output wire                                                     wr_data_done, // data writing done
    // last layer
    input  wire                                                     wr_data_last_layer, // is last conv. layer output; from top module, last input feature map
    input  wire [32*(EXPONENT+MANTISSA+1)-1:0]                      wr_data_llayer_i,   // last layer pooling data
    input  wire [3:0]                                               wr_data_cur_ker_set, // kernel set
    input  wire                                                     wr_data_llayer_data_valid, // last layer pooling data valid
    input  wire                                                     wr_data_llayer_valid_first,// first valid pooling data
    input  wire                                                     wr_data_llayer_valid_last, // last valid pooling data
    output reg                                                      wr_data_llayer_last_data,
    output reg                                                      wr_data_bram_we, // enable writing to bram
    output wire [9:0]                                               wr_data_bram_addr, // maximum 49*16=784
    (*mark_debug="TRUE"*)output reg  [32*(EXPONENT+MANTISSA+1)-1:0]                      wr_data_llayer_o   // last layer pooling data
  );

  localparam WR_DATA_RST    =3'd0;
  localparam WR_DATA_UPPER0 =3'd1; // top left 7x7
  localparam WR_DATA_UPPER1 =3'd2; // top right 7x7
  localparam WR_DATA_LOWER0 =3'd3; // bottom left 7x7
  localparam WR_DATA_LOWER1 =3'd4; // bottom right 7x7
  localparam WR_DATA_POOL   =3'd5; // write pooling data
  //
  localparam FLOAT_NUM_WIDTH  = 32;
  localparam DDR_DATA_WIDTH   = 64;
  localparam DDR_BURST_LEN    = 8; // ddr data burst length
  localparam DATA_WIDTH       = MANTISSA + EXPONENT + 1;
  localparam DDR_DATA_BURST_WIDTH = 512;
  localparam MINI_PATCH_NUM   = 4; // number of mini-patch in 1 atom(14x14)
  localparam MINI_PATCH_DATUM_NUM = 64; // number of datum in 1 7x7 mini-patch
  localparam DATUM_NUM        = MINI_PATCH_DATUM_NUM*MINI_PATCH_NUM*DATA_WIDTH/DDR_DATA_BURST_WIDTH; // num of burst data to write
  localparam MINI_1_SIZE = (7*7*DATA_WIDTH/DDR_DATA_WIDTH/DDR_BURST_LEN + 1)*DDR_BURST_LEN;
  localparam MINI_2_SIZE = 2*MINI_1_SIZE;
  localparam MINI_1_CNT  = MINI_PATCH_DATUM_NUM*DATA_WIDTH/DDR_DATA_BURST_WIDTH-1;
  localparam MINI_2_CNT  = 2*MINI_PATCH_DATUM_NUM*DATA_WIDTH/DDR_DATA_BURST_WIDTH-1;

  reg  [2:0]    _wr_data_state;
  reg  [2:0]    _wr_data_next_state;

  reg         _wr_data_data_next;
  reg [29:0]  _wr_data_patch_addr;
  reg [2:0]   _wr_data_data_cnt;
  reg [29:0]  _wr_data_fm_offset;
  reg [9:0]   _wr_data_channel_cnt; // channel counter, increase by 1 when the last datum is writen
  wire[511:0] _wr_data_0;
  wire[511:0] _wr_data_1;
  wire[9:0]   _wr_data_end_channel; // last channel number
  assign      _wr_data_end_channel = wr_data_top_channels - 1'b1;
  wire        _wr_data_upper0_last;
  wire        _wr_data_upper1_last;
  wire        _wr_data_lower0_last;
  wire        _wr_data_lower1_last;
  wire        _wr_data_pool_last;
//wire        _wr_data_upper0_next; // next quarter, compensate for time screw of bram reading operation
//wire        _wr_data_upper1_next;
//wire        _wr_data_lower0_next;
//wire        _wr_data_lower1_next;
//wire        _wr_data_pool_next;
  wire        _wr_data_last_channel;

  // FF
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _wr_data_state <= WR_DATA_RST;
    end else begin
      _wr_data_state <= _wr_data_next_state;
    end
  end
  // transition
  always@(_wr_data_state or wr_data_top or wr_data_pooling_en or 
          _wr_data_upper0_last or _wr_data_upper1_last or _wr_data_lower0_last or
          _wr_data_lower1_last or _wr_data_pool_last or
          _wr_data_last_channel) begin
    _wr_data_next_state = WR_DATA_RST;
    case(_wr_data_state)
      WR_DATA_RST: begin
        if(wr_data_top) begin
          if(wr_data_pooling_en) begin
            _wr_data_next_state = WR_DATA_POOL;
          end else begin
            _wr_data_next_state = WR_DATA_UPPER0;
          end
        end else begin
          _wr_data_next_state = WR_DATA_RST;
        end
      end
      // top left
      WR_DATA_UPPER0: begin
        if(_wr_data_upper0_last) begin
          _wr_data_next_state = WR_DATA_UPPER1;
        end else begin
          _wr_data_next_state = WR_DATA_UPPER0;
        end
      end
      // top right
      WR_DATA_UPPER1: begin
        if(_wr_data_upper1_last) begin
          _wr_data_next_state = WR_DATA_LOWER0;
        end else begin
          _wr_data_next_state = WR_DATA_UPPER1;
        end
      end
      // bottom left
      WR_DATA_LOWER0: begin
        if(_wr_data_lower0_last) begin
          _wr_data_next_state = WR_DATA_LOWER1;
        end else begin
          _wr_data_next_state = WR_DATA_LOWER0;
        end
      end
      // bottom right
      WR_DATA_LOWER1: begin
        if(_wr_data_lower1_last) begin
          if(_wr_data_last_channel) begin
            _wr_data_next_state = WR_DATA_RST;
          end else begin
            _wr_data_next_state = WR_DATA_UPPER0;
          end
        end else begin
          _wr_data_next_state = WR_DATA_LOWER1;
        end
      end
      // pooling
      WR_DATA_POOL: begin
        if(_wr_data_pool_last) begin
          if(_wr_data_last_channel) begin
            _wr_data_next_state = WR_DATA_RST;
          end else begin
            _wr_data_next_state = WR_DATA_POOL;
          end
        end else begin
          _wr_data_next_state = WR_DATA_POOL;
        end
      end
    endcase
  end
  // logic
  always@(_wr_data_state or ddr_rdy or ddr_wdf_rdy or wr_data_data_valid) begin
    ddr_en        = 1'b0;
    ddr_cmd       = 3'b1; // read
    ddr_wdf_end   = 1'b0;
    ddr_wdf_wren  = 1'b0;
    ddr_wdf_mask  = 64'hffffffff;
    _wr_data_data_next  = 1'b0;
    case(_wr_data_state)
      WR_DATA_RST: begin
        ddr_en        = 1'b0;
        ddr_cmd       = 3'b1; // read
        ddr_wdf_wren  = 1'b0;
      end
      WR_DATA_POOL,
      WR_DATA_UPPER0,
      WR_DATA_UPPER1: begin
        if(ddr_rdy && ddr_wdf_rdy && wr_data_data_valid) begin
          ddr_en  = 1'd1;
          ddr_cmd = 3'd0;
          ddr_wdf_end   = 1'b1;
          ddr_wdf_wren  = 1'b1;
          ddr_wdf_mask  = 64'h0; // no mask
          _wr_data_data_next  = 1'b1;
        end else begin
          ddr_en        = 1'd0;
          ddr_cmd       = 3'h0;
          ddr_wdf_wren  = 1'b0;
          _wr_data_data_next  = 1'b0;
        end
      end
      WR_DATA_LOWER0,
      WR_DATA_LOWER1: begin
        if(ddr_rdy && ddr_wdf_rdy && wr_data_data_valid) begin
          ddr_en  = 1'd1;
          ddr_cmd = 3'd0;
          ddr_wdf_end   = 1'b1;
          ddr_wdf_wren  = 1'b1;
          ddr_wdf_mask  = 64'h0; // no mask
          _wr_data_data_next  = 1'b1;
        end else begin
          ddr_en        = 1'd0;
          ddr_cmd       = 3'h0;
          ddr_wdf_wren  = 1'b0;
          _wr_data_data_next  = 1'b0;
        end
      end
    endcase
  end
  // ddr_addr
  always@(_wr_data_state or _wr_data_patch_addr or _wr_data_fm_offset or
          _wr_data_data_cnt or wr_data_half_bar_size) begin
    ddr_addr = 30'd0;
    case(_wr_data_state)
      WR_DATA_RST: begin
        ddr_addr = 30'd0;
      end
      WR_DATA_POOL,
      WR_DATA_UPPER0: begin
        ddr_addr  = _wr_data_patch_addr + _wr_data_fm_offset +
                   {{27'h0,_wr_data_data_cnt}<<3}; // <-x
      end
      WR_DATA_UPPER1: begin
        ddr_addr  = _wr_data_patch_addr + _wr_data_fm_offset +
                   {{27'h0,_wr_data_data_cnt}<<3} + MINI_1_SIZE; // <-x
      end
      WR_DATA_LOWER0: begin
        ddr_addr  = _wr_data_patch_addr + _wr_data_fm_offset +
                    wr_data_half_bar_size + {{27'h0,_wr_data_data_cnt}<<3}; // <-x
      end
      WR_DATA_LOWER1: begin
        ddr_addr  = _wr_data_patch_addr + _wr_data_fm_offset +
                    wr_data_half_bar_size + {{27'h0,_wr_data_data_cnt}<<3} + MINI_1_SIZE; // <-x
      end
    endcase
  end
  // patch addr
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _wr_data_patch_addr <= 30'd0;
    end else begin
      // update patch address
      if(wr_data_top && (_wr_data_state==WR_DATA_RST)) begin
        if(wr_data_x_eq_0) begin
          if(wr_data_y_eq_0) begin
          // output fm first address
            _wr_data_patch_addr <= wr_data_top_addr;
          end else begin
            // to next bar
            if(wr_data_pooling_en) begin
              _wr_data_patch_addr <= _wr_data_patch_addr + MINI_1_SIZE;
            end else begin
              _wr_data_patch_addr <= _wr_data_patch_addr + wr_data_half_bar_size + MINI_2_SIZE;
            end
          end
        end else begin
          // increment
          if(wr_data_pooling_en) begin
            _wr_data_patch_addr <= _wr_data_patch_addr + MINI_1_SIZE;
          end else begin
            _wr_data_patch_addr <= _wr_data_patch_addr + MINI_2_SIZE;
          end
        end
      end
      // reset
      if(wr_data_x_eq_end && wr_data_y_eq_end && wr_data_done) begin
        _wr_data_patch_addr <= 30'd0;
      end
    end
  end
  // fm offset, data counter, channel counter
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _wr_data_data_cnt   <= 3'h0;
      _wr_data_fm_offset  <= 30'h0;
      _wr_data_channel_cnt<= 10'h0;
    end else begin
      if(wr_data_top && (_wr_data_state==WR_DATA_RST)) begin
      // reset
        _wr_data_data_cnt   <= 3'h0;
        _wr_data_fm_offset  <= 30'h0;
        _wr_data_channel_cnt<= 10'h0;
      end else begin
      // increment
        if(_wr_data_data_next) begin
          _wr_data_data_cnt <= _wr_data_data_cnt + 1'b1;
        end
        if(_wr_data_upper0_last || _wr_data_upper1_last ||
           _wr_data_lower0_last || _wr_data_lower1_last ||
           _wr_data_pool_last) begin
        // end of current channel half/pooling patch data
          _wr_data_data_cnt <= 3'd0;
        end
        if(_wr_data_lower1_last) begin
        // increase fm offset and channel counter value at next clock
          _wr_data_fm_offset  <= _wr_data_fm_offset + wr_data_fm_size;
          _wr_data_channel_cnt<= _wr_data_channel_cnt + 1'b1;
        end
        if(_wr_data_pool_last) begin
          _wr_data_fm_offset  <= _wr_data_fm_offset + wr_data_fm_size;
          _wr_data_channel_cnt<= _wr_data_channel_cnt + 1'b1;
        end
      end
    end
  end
  // "last" signals
  assign _wr_data_last_channel = (_wr_data_channel_cnt == _wr_data_end_channel);
  assign _wr_data_upper0_last = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT) && (_wr_data_state==WR_DATA_UPPER0)) : 1'b0;
  assign _wr_data_upper1_last = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT) && (_wr_data_state==WR_DATA_UPPER1)) : 1'b0;
  assign _wr_data_lower0_last = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT) && (_wr_data_state==WR_DATA_LOWER0)) : 1'b0;
  assign _wr_data_lower1_last = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT) && (_wr_data_state==WR_DATA_LOWER1)) : 1'b0;
  assign _wr_data_pool_last   = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT) && (_wr_data_state==WR_DATA_POOL)) : 1'b0;
//assign _wr_data_upper0_next = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT-1) && (_wr_data_state==WR_DATA_UPPER0)) : 1'b0;
//assign _wr_data_upper1_next = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT-1) && (_wr_data_state==WR_DATA_UPPER1)) : 1'b0;
//assign _wr_data_lower0_next = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT-1) && (_wr_data_state==WR_DATA_LOWER0)) : 1'b0;
//assign _wr_data_lower1_next = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT-1) && (_wr_data_state==WR_DATA_LOWER1)) : 1'b0;
//assign _wr_data_pool_next   = ddr_wdf_wren ? ((_wr_data_data_cnt == MINI_1_CNT-1) && (_wr_data_state==WR_DATA_POOL)) : 1'b0;
  assign wr_data_next_channel = wr_data_pooling_en ? _wr_data_pool_last : _wr_data_lower1_last;
//assign wr_data_next_channel = wr_data_pooling_en ? _wr_data_pool_next : _wr_data_lower1_next;
//assign wr_data_next_quarter = _wr_data_lower0_next || _wr_data_lower1_next || _wr_data_upper0_next || _wr_data_upper1_next || _wr_data_pool_next;
  assign wr_data_next_quarter = _wr_data_lower0_last || _wr_data_lower1_last || _wr_data_upper0_last || _wr_data_upper1_last || _wr_data_pool_last;
  assign wr_data_done         = ((wr_data_pooling_en ? _wr_data_pool_last : _wr_data_lower1_last) && _wr_data_last_channel) ? 1'b1 : 1'b0;
  // data to write
//assign _wr_data_0  = wr_data_data_i[(49- 0)*DATA_WIDTH-1 : (49-32)*DATA_WIDTH];
  assign _wr_data_0[ 1*DATA_WIDTH - 1 :  0*DATA_WIDTH] = wr_data_data_i[49*DATA_WIDTH - 1: 48*DATA_WIDTH];
  assign _wr_data_0[ 2*DATA_WIDTH - 1 :  1*DATA_WIDTH] = wr_data_data_i[48*DATA_WIDTH - 1: 47*DATA_WIDTH];
  assign _wr_data_0[ 3*DATA_WIDTH - 1 :  2*DATA_WIDTH] = wr_data_data_i[47*DATA_WIDTH - 1: 46*DATA_WIDTH];
  assign _wr_data_0[ 4*DATA_WIDTH - 1 :  3*DATA_WIDTH] = wr_data_data_i[46*DATA_WIDTH - 1: 45*DATA_WIDTH];
  assign _wr_data_0[ 5*DATA_WIDTH - 1 :  4*DATA_WIDTH] = wr_data_data_i[45*DATA_WIDTH - 1: 44*DATA_WIDTH];
  assign _wr_data_0[ 6*DATA_WIDTH - 1 :  5*DATA_WIDTH] = wr_data_data_i[44*DATA_WIDTH - 1: 43*DATA_WIDTH];
  assign _wr_data_0[ 7*DATA_WIDTH - 1 :  6*DATA_WIDTH] = wr_data_data_i[43*DATA_WIDTH - 1: 42*DATA_WIDTH];
  assign _wr_data_0[ 8*DATA_WIDTH - 1 :  7*DATA_WIDTH] = wr_data_data_i[42*DATA_WIDTH - 1: 41*DATA_WIDTH];
  assign _wr_data_0[ 9*DATA_WIDTH - 1 :  8*DATA_WIDTH] = wr_data_data_i[41*DATA_WIDTH - 1: 40*DATA_WIDTH];
  assign _wr_data_0[10*DATA_WIDTH - 1 :  9*DATA_WIDTH] = wr_data_data_i[40*DATA_WIDTH - 1: 39*DATA_WIDTH];
  assign _wr_data_0[11*DATA_WIDTH - 1 : 10*DATA_WIDTH] = wr_data_data_i[39*DATA_WIDTH - 1: 38*DATA_WIDTH];
  assign _wr_data_0[12*DATA_WIDTH - 1 : 11*DATA_WIDTH] = wr_data_data_i[38*DATA_WIDTH - 1: 37*DATA_WIDTH];
  assign _wr_data_0[13*DATA_WIDTH - 1 : 12*DATA_WIDTH] = wr_data_data_i[37*DATA_WIDTH - 1: 36*DATA_WIDTH];
  assign _wr_data_0[14*DATA_WIDTH - 1 : 13*DATA_WIDTH] = wr_data_data_i[36*DATA_WIDTH - 1: 35*DATA_WIDTH];
  assign _wr_data_0[15*DATA_WIDTH - 1 : 14*DATA_WIDTH] = wr_data_data_i[35*DATA_WIDTH - 1: 34*DATA_WIDTH];
  assign _wr_data_0[16*DATA_WIDTH - 1 : 15*DATA_WIDTH] = wr_data_data_i[34*DATA_WIDTH - 1: 33*DATA_WIDTH];
  assign _wr_data_0[17*DATA_WIDTH - 1 : 16*DATA_WIDTH] = wr_data_data_i[33*DATA_WIDTH - 1: 32*DATA_WIDTH];
  assign _wr_data_0[18*DATA_WIDTH - 1 : 17*DATA_WIDTH] = wr_data_data_i[32*DATA_WIDTH - 1: 31*DATA_WIDTH];
  assign _wr_data_0[19*DATA_WIDTH - 1 : 18*DATA_WIDTH] = wr_data_data_i[31*DATA_WIDTH - 1: 30*DATA_WIDTH];
  assign _wr_data_0[20*DATA_WIDTH - 1 : 19*DATA_WIDTH] = wr_data_data_i[30*DATA_WIDTH - 1: 29*DATA_WIDTH];
  assign _wr_data_0[21*DATA_WIDTH - 1 : 20*DATA_WIDTH] = wr_data_data_i[29*DATA_WIDTH - 1: 28*DATA_WIDTH];
  assign _wr_data_0[22*DATA_WIDTH - 1 : 21*DATA_WIDTH] = wr_data_data_i[28*DATA_WIDTH - 1: 27*DATA_WIDTH];
  assign _wr_data_0[23*DATA_WIDTH - 1 : 22*DATA_WIDTH] = wr_data_data_i[27*DATA_WIDTH - 1: 26*DATA_WIDTH];
  assign _wr_data_0[24*DATA_WIDTH - 1 : 23*DATA_WIDTH] = wr_data_data_i[26*DATA_WIDTH - 1: 25*DATA_WIDTH];
  assign _wr_data_0[25*DATA_WIDTH - 1 : 24*DATA_WIDTH] = wr_data_data_i[25*DATA_WIDTH - 1: 24*DATA_WIDTH];
  assign _wr_data_0[26*DATA_WIDTH - 1 : 25*DATA_WIDTH] = wr_data_data_i[24*DATA_WIDTH - 1: 23*DATA_WIDTH];
  assign _wr_data_0[27*DATA_WIDTH - 1 : 26*DATA_WIDTH] = wr_data_data_i[23*DATA_WIDTH - 1: 22*DATA_WIDTH];
  assign _wr_data_0[28*DATA_WIDTH - 1 : 27*DATA_WIDTH] = wr_data_data_i[22*DATA_WIDTH - 1: 21*DATA_WIDTH];
  assign _wr_data_0[29*DATA_WIDTH - 1 : 28*DATA_WIDTH] = wr_data_data_i[21*DATA_WIDTH - 1: 20*DATA_WIDTH];
  assign _wr_data_0[30*DATA_WIDTH - 1 : 29*DATA_WIDTH] = wr_data_data_i[20*DATA_WIDTH - 1: 19*DATA_WIDTH];
  assign _wr_data_0[31*DATA_WIDTH - 1 : 30*DATA_WIDTH] = wr_data_data_i[19*DATA_WIDTH - 1: 18*DATA_WIDTH];
  assign _wr_data_0[32*DATA_WIDTH - 1 : 31*DATA_WIDTH] = wr_data_data_i[18*DATA_WIDTH - 1: 17*DATA_WIDTH];
//assign _wr_data_1  ={wr_data_data_i[(49-32)*DATA_WIDTH-1 : (49-49)*DATA_WIDTH],{(15*DATA_WIDTH){1'b1}}};
  assign _wr_data_1[ 1*DATA_WIDTH - 1 :  0*DATA_WIDTH] = wr_data_data_i[17*DATA_WIDTH - 1: 16*DATA_WIDTH];
  assign _wr_data_1[ 2*DATA_WIDTH - 1 :  1*DATA_WIDTH] = wr_data_data_i[16*DATA_WIDTH - 1: 15*DATA_WIDTH];
  assign _wr_data_1[ 3*DATA_WIDTH - 1 :  2*DATA_WIDTH] = wr_data_data_i[15*DATA_WIDTH - 1: 14*DATA_WIDTH];
  assign _wr_data_1[ 4*DATA_WIDTH - 1 :  3*DATA_WIDTH] = wr_data_data_i[14*DATA_WIDTH - 1: 13*DATA_WIDTH];
  assign _wr_data_1[ 5*DATA_WIDTH - 1 :  4*DATA_WIDTH] = wr_data_data_i[13*DATA_WIDTH - 1: 12*DATA_WIDTH];
  assign _wr_data_1[ 6*DATA_WIDTH - 1 :  5*DATA_WIDTH] = wr_data_data_i[12*DATA_WIDTH - 1: 11*DATA_WIDTH];
  assign _wr_data_1[ 7*DATA_WIDTH - 1 :  6*DATA_WIDTH] = wr_data_data_i[11*DATA_WIDTH - 1: 10*DATA_WIDTH];
  assign _wr_data_1[ 8*DATA_WIDTH - 1 :  7*DATA_WIDTH] = wr_data_data_i[10*DATA_WIDTH - 1: 09*DATA_WIDTH];
  assign _wr_data_1[ 9*DATA_WIDTH - 1 :  8*DATA_WIDTH] = wr_data_data_i[09*DATA_WIDTH - 1: 08*DATA_WIDTH];
  assign _wr_data_1[10*DATA_WIDTH - 1 :  9*DATA_WIDTH] = wr_data_data_i[08*DATA_WIDTH - 1: 07*DATA_WIDTH];
  assign _wr_data_1[11*DATA_WIDTH - 1 : 10*DATA_WIDTH] = wr_data_data_i[07*DATA_WIDTH - 1: 06*DATA_WIDTH];
  assign _wr_data_1[12*DATA_WIDTH - 1 : 11*DATA_WIDTH] = wr_data_data_i[06*DATA_WIDTH - 1: 05*DATA_WIDTH];
  assign _wr_data_1[13*DATA_WIDTH - 1 : 12*DATA_WIDTH] = wr_data_data_i[05*DATA_WIDTH - 1: 04*DATA_WIDTH];
  assign _wr_data_1[14*DATA_WIDTH - 1 : 13*DATA_WIDTH] = wr_data_data_i[04*DATA_WIDTH - 1: 03*DATA_WIDTH];
  assign _wr_data_1[15*DATA_WIDTH - 1 : 14*DATA_WIDTH] = wr_data_data_i[03*DATA_WIDTH - 1: 02*DATA_WIDTH];
  assign _wr_data_1[16*DATA_WIDTH - 1 : 15*DATA_WIDTH] = wr_data_data_i[02*DATA_WIDTH - 1: 01*DATA_WIDTH];
  assign _wr_data_1[17*DATA_WIDTH - 1 : 16*DATA_WIDTH] = wr_data_data_i[01*DATA_WIDTH - 1: 00*DATA_WIDTH];
  assign _wr_data_1[18*DATA_WIDTH - 1 : 17*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[19*DATA_WIDTH - 1 : 18*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[20*DATA_WIDTH - 1 : 19*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[21*DATA_WIDTH - 1 : 20*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[22*DATA_WIDTH - 1 : 21*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[23*DATA_WIDTH - 1 : 22*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[24*DATA_WIDTH - 1 : 23*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[25*DATA_WIDTH - 1 : 24*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[26*DATA_WIDTH - 1 : 25*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[27*DATA_WIDTH - 1 : 26*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[28*DATA_WIDTH - 1 : 27*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[29*DATA_WIDTH - 1 : 28*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[30*DATA_WIDTH - 1 : 29*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[31*DATA_WIDTH - 1 : 30*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  assign _wr_data_1[32*DATA_WIDTH - 1 : 31*DATA_WIDTH] = {(DATA_WIDTH){1'b1}};
  // read buffer
//always@(wr_data_next_quarter or _wr_data_state or _wr_data_next_state) begin
  always@(posedge clk) begin
    if(_wr_data_next_state!=WR_DATA_RST && _wr_data_state==WR_DATA_RST) begin
      wr_data_rd_top_buffer <= 1'b1;
    end else begin
      if(wr_data_next_quarter) begin
        wr_data_rd_top_buffer <= 1'b1;
      end else begin
        wr_data_rd_top_buffer <= 1'b0;
      end
    end
  end

  // data
  always@(_wr_data_data_cnt or wr_data_data_valid or
          _wr_data_0 or _wr_data_1) begin
    ddr_wdf_data = {(16*DATA_WIDTH){1'b1}};
    case(_wr_data_data_cnt)
      3'd0: begin
        if(wr_data_data_valid) begin
          ddr_wdf_data = _wr_data_0;
        end
      end
      3'd1: begin
        if(wr_data_data_valid) begin
          ddr_wdf_data = _wr_data_1;
        end
      end
    endcase
  end

  `ifdef sim_ // {{{
    wire [DATA_WIDTH-1:0] _wr_data_00;
    wire [DATA_WIDTH-1:0] _wr_data_01;
    wire [DATA_WIDTH-1:0] _wr_data_02;
    wire [DATA_WIDTH-1:0] _wr_data_03;
    wire [DATA_WIDTH-1:0] _wr_data_04;
    wire [DATA_WIDTH-1:0] _wr_data_05;
    wire [DATA_WIDTH-1:0] _wr_data_06;
    wire [DATA_WIDTH-1:0] _wr_data_07;
    wire [DATA_WIDTH-1:0] _wr_data_08;
    wire [DATA_WIDTH-1:0] _wr_data_09;
    wire [DATA_WIDTH-1:0] _wr_data_010;
    wire [DATA_WIDTH-1:0] _wr_data_011;
    wire [DATA_WIDTH-1:0] _wr_data_012;
    wire [DATA_WIDTH-1:0] _wr_data_013;
    wire [DATA_WIDTH-1:0] _wr_data_014;
    wire [DATA_WIDTH-1:0] _wr_data_015;
    assign _wr_data_00  =  _wr_data_0[16*DATA_WIDTH-1 : 15*DATA_WIDTH];
    assign _wr_data_01  =  _wr_data_0[15*DATA_WIDTH-1 : 14*DATA_WIDTH];
    assign _wr_data_02  =  _wr_data_0[14*DATA_WIDTH-1 : 13*DATA_WIDTH];
    assign _wr_data_03  =  _wr_data_0[13*DATA_WIDTH-1 : 12*DATA_WIDTH];
    assign _wr_data_04  =  _wr_data_0[12*DATA_WIDTH-1 : 11*DATA_WIDTH];
    assign _wr_data_05  =  _wr_data_0[11*DATA_WIDTH-1 : 10*DATA_WIDTH];
    assign _wr_data_06  =  _wr_data_0[10*DATA_WIDTH-1 : 09*DATA_WIDTH];
    assign _wr_data_07  =  _wr_data_0[09*DATA_WIDTH-1 : 08*DATA_WIDTH];
    assign _wr_data_08  =  _wr_data_0[08*DATA_WIDTH-1 : 07*DATA_WIDTH];
    assign _wr_data_09  =  _wr_data_0[07*DATA_WIDTH-1 : 06*DATA_WIDTH];
    assign _wr_data_010 =  _wr_data_0[06*DATA_WIDTH-1 : 05*DATA_WIDTH];
    assign _wr_data_011 =  _wr_data_0[05*DATA_WIDTH-1 : 04*DATA_WIDTH];
    assign _wr_data_012 =  _wr_data_0[04*DATA_WIDTH-1 : 03*DATA_WIDTH];
    assign _wr_data_013 =  _wr_data_0[03*DATA_WIDTH-1 : 02*DATA_WIDTH];
    assign _wr_data_014 =  _wr_data_0[02*DATA_WIDTH-1 : 01*DATA_WIDTH];
    assign _wr_data_015 =  _wr_data_0[01*DATA_WIDTH-1 : 00*DATA_WIDTH];

    wire [DATA_WIDTH-1:0] _wr_data_10;
    wire [DATA_WIDTH-1:0] _wr_data_11;
    wire [DATA_WIDTH-1:0] _wr_data_12;
    wire [DATA_WIDTH-1:0] _wr_data_13;
    wire [DATA_WIDTH-1:0] _wr_data_14;
    wire [DATA_WIDTH-1:0] _wr_data_15;
    wire [DATA_WIDTH-1:0] _wr_data_16;
    wire [DATA_WIDTH-1:0] _wr_data_17;
    wire [DATA_WIDTH-1:0] _wr_data_18;
    wire [DATA_WIDTH-1:0] _wr_data_19;
    wire [DATA_WIDTH-1:0] _wr_data_110;
    wire [DATA_WIDTH-1:0] _wr_data_111;
    wire [DATA_WIDTH-1:0] _wr_data_112;
    wire [DATA_WIDTH-1:0] _wr_data_113;
    wire [DATA_WIDTH-1:0] _wr_data_114;
    wire [DATA_WIDTH-1:0] _wr_data_115;
    assign _wr_data_10  =  _wr_data_1[16*DATA_WIDTH-1 : 15*DATA_WIDTH];
    assign _wr_data_11  =  _wr_data_1[15*DATA_WIDTH-1 : 14*DATA_WIDTH];
    assign _wr_data_12  =  _wr_data_1[14*DATA_WIDTH-1 : 13*DATA_WIDTH];
    assign _wr_data_13  =  _wr_data_1[13*DATA_WIDTH-1 : 12*DATA_WIDTH];
    assign _wr_data_14  =  _wr_data_1[12*DATA_WIDTH-1 : 11*DATA_WIDTH];
    assign _wr_data_15  =  _wr_data_1[11*DATA_WIDTH-1 : 10*DATA_WIDTH];
    assign _wr_data_16  =  _wr_data_1[10*DATA_WIDTH-1 : 09*DATA_WIDTH];
    assign _wr_data_17  =  _wr_data_1[09*DATA_WIDTH-1 : 08*DATA_WIDTH];
    assign _wr_data_18  =  _wr_data_1[08*DATA_WIDTH-1 : 07*DATA_WIDTH];
    assign _wr_data_19  =  _wr_data_1[07*DATA_WIDTH-1 : 06*DATA_WIDTH];
    assign _wr_data_110 =  _wr_data_1[06*DATA_WIDTH-1 : 05*DATA_WIDTH];
    assign _wr_data_111 =  _wr_data_1[05*DATA_WIDTH-1 : 04*DATA_WIDTH];
    assign _wr_data_112 =  _wr_data_1[04*DATA_WIDTH-1 : 03*DATA_WIDTH];
    assign _wr_data_113 =  _wr_data_1[03*DATA_WIDTH-1 : 02*DATA_WIDTH];
    assign _wr_data_114 =  _wr_data_1[02*DATA_WIDTH-1 : 01*DATA_WIDTH];
    assign _wr_data_115 =  _wr_data_1[01*DATA_WIDTH-1 : 00*DATA_WIDTH];

  `endif // }}}

  // last layer data write
  // enable && data
  reg [9:0] _wr_data_bram_base_addr;
  reg [9:0] _wr_data_bram_offset;
  always@(wr_data_last_layer or wr_data_cur_ker_set) begin
    if(!wr_data_last_layer) begin
      _wr_data_bram_base_addr = 10'd0;
    end else begin
      _wr_data_bram_base_addr = 10'd0;
      case(wr_data_cur_ker_set)
        4'd 0:  _wr_data_bram_base_addr = 10'd  0;
        4'd 1:  _wr_data_bram_base_addr = 10'd 49;
        4'd 2:  _wr_data_bram_base_addr = 10'd 98;
        4'd 3:  _wr_data_bram_base_addr = 10'd147;
        4'd 4:  _wr_data_bram_base_addr = 10'd196;
        4'd 5:  _wr_data_bram_base_addr = 10'd245;
        4'd 6:  _wr_data_bram_base_addr = 10'd294;
        4'd 7:  _wr_data_bram_base_addr = 10'd343;
        4'd 8:  _wr_data_bram_base_addr = 10'd392;
        4'd 9:  _wr_data_bram_base_addr = 10'd441;
        4'd10:  _wr_data_bram_base_addr = 10'd490;
        4'd11:  _wr_data_bram_base_addr = 10'd539;
        4'd12:  _wr_data_bram_base_addr = 10'd588;
        4'd13:  _wr_data_bram_base_addr = 10'd637;
        4'd14:  _wr_data_bram_base_addr = 10'd686;
        4'd15:  _wr_data_bram_base_addr = 10'd735;
      endcase
    end
  end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      wr_data_bram_we   <= 1'b0;
      wr_data_llayer_o  <= {(KER_C*DATA_WIDTH){1'b0}};
    end else begin
      if(wr_data_last_layer) begin
        if(wr_data_llayer_data_valid) begin
          wr_data_bram_we   <= 1'b1;
          wr_data_llayer_o[ 1*16 - 1 :  0*16] <= wr_data_llayer_i[32*16 - 1: 31*16];
          wr_data_llayer_o[ 2*16 - 1 :  1*16] <= wr_data_llayer_i[31*16 - 1: 30*16];
          wr_data_llayer_o[ 3*16 - 1 :  2*16] <= wr_data_llayer_i[30*16 - 1: 29*16];
          wr_data_llayer_o[ 4*16 - 1 :  3*16] <= wr_data_llayer_i[29*16 - 1: 28*16];
          wr_data_llayer_o[ 5*16 - 1 :  4*16] <= wr_data_llayer_i[28*16 - 1: 27*16];
          wr_data_llayer_o[ 6*16 - 1 :  5*16] <= wr_data_llayer_i[27*16 - 1: 26*16];
          wr_data_llayer_o[ 7*16 - 1 :  6*16] <= wr_data_llayer_i[26*16 - 1: 25*16];
          wr_data_llayer_o[ 8*16 - 1 :  7*16] <= wr_data_llayer_i[25*16 - 1: 24*16];
          wr_data_llayer_o[ 9*16 - 1 :  8*16] <= wr_data_llayer_i[24*16 - 1: 23*16];
          wr_data_llayer_o[10*16 - 1 :  9*16] <= wr_data_llayer_i[23*16 - 1: 22*16];
          wr_data_llayer_o[11*16 - 1 : 10*16] <= wr_data_llayer_i[22*16 - 1: 21*16];
          wr_data_llayer_o[12*16 - 1 : 11*16] <= wr_data_llayer_i[21*16 - 1: 20*16];
          wr_data_llayer_o[13*16 - 1 : 12*16] <= wr_data_llayer_i[20*16 - 1: 19*16];
          wr_data_llayer_o[14*16 - 1 : 13*16] <= wr_data_llayer_i[19*16 - 1: 18*16];
          wr_data_llayer_o[15*16 - 1 : 14*16] <= wr_data_llayer_i[18*16 - 1: 17*16];
          wr_data_llayer_o[16*16 - 1 : 15*16] <= wr_data_llayer_i[17*16 - 1: 16*16];
          wr_data_llayer_o[17*16 - 1 : 16*16] <= wr_data_llayer_i[16*16 - 1: 15*16];
          wr_data_llayer_o[18*16 - 1 : 17*16] <= wr_data_llayer_i[15*16 - 1: 14*16];
          wr_data_llayer_o[19*16 - 1 : 18*16] <= wr_data_llayer_i[14*16 - 1: 13*16];
          wr_data_llayer_o[20*16 - 1 : 19*16] <= wr_data_llayer_i[13*16 - 1: 12*16];
          wr_data_llayer_o[21*16 - 1 : 20*16] <= wr_data_llayer_i[12*16 - 1: 11*16];
          wr_data_llayer_o[22*16 - 1 : 21*16] <= wr_data_llayer_i[11*16 - 1: 10*16];
          wr_data_llayer_o[23*16 - 1 : 22*16] <= wr_data_llayer_i[10*16 - 1:  9*16];
          wr_data_llayer_o[24*16 - 1 : 23*16] <= wr_data_llayer_i[ 9*16 - 1:  8*16];
          wr_data_llayer_o[25*16 - 1 : 24*16] <= wr_data_llayer_i[ 8*16 - 1:  7*16];
          wr_data_llayer_o[26*16 - 1 : 25*16] <= wr_data_llayer_i[ 7*16 - 1:  6*16];
          wr_data_llayer_o[27*16 - 1 : 26*16] <= wr_data_llayer_i[ 6*16 - 1:  5*16];
          wr_data_llayer_o[28*16 - 1 : 27*16] <= wr_data_llayer_i[ 5*16 - 1:  4*16];
          wr_data_llayer_o[29*16 - 1 : 28*16] <= wr_data_llayer_i[ 4*16 - 1:  3*16];
          wr_data_llayer_o[30*16 - 1 : 29*16] <= wr_data_llayer_i[ 3*16 - 1:  2*16];
          wr_data_llayer_o[31*16 - 1 : 30*16] <= wr_data_llayer_i[ 2*16 - 1:  1*16];
          wr_data_llayer_o[32*16 - 1 : 31*16] <= wr_data_llayer_i[ 1*16 - 1:  0*16];
        end else begin
          wr_data_bram_we   <= 1'b0;
        end
      end else begin
        wr_data_bram_we   <= 1'b0;
      end
    end
  end
  // address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _wr_data_bram_offset  <= 10'd0;
    end else begin
      if(wr_data_last_layer) begin
        if(wr_data_llayer_valid_first) begin
          _wr_data_bram_offset  <= 10'd0;
        end else if(wr_data_llayer_data_valid) begin
          if(_wr_data_bram_offset==10'd42) begin
            _wr_data_bram_offset  <= 10'd1;
          end else if(_wr_data_bram_offset==10'd43) begin
            _wr_data_bram_offset  <= 10'd2;
          end else if(_wr_data_bram_offset==10'd44) begin
            _wr_data_bram_offset  <= 10'd3;
          end else if(_wr_data_bram_offset==10'd45) begin
            _wr_data_bram_offset  <= 10'd4;
          end else if(_wr_data_bram_offset==10'd46) begin
            _wr_data_bram_offset  <= 10'd5;
          end else if(_wr_data_bram_offset==10'd47) begin
            _wr_data_bram_offset  <= 10'd6;
          end else begin
            _wr_data_bram_offset  <= _wr_data_bram_offset + 10'd7;
          end
        end
      end
    end
  end
  assign wr_data_bram_addr = _wr_data_bram_offset + _wr_data_bram_base_addr;
  // last conv. data
  always@(posedge clk) begin
    wr_data_llayer_last_data <= wr_data_llayer_valid_last;
    `ifdef sim_
    if(wr_data_llayer_valid_last) begin
      $display("* %t: last layer last valid (at conv/wr_op/wr_ddr_data.7x7.v)", $realtime);
      $display("* %t: last layer last valid (at conv/wr_op/wr_ddr_data.7x7.v)", $realtime);
      $display("* %t: last layer last valid (at conv/wr_op/wr_ddr_data.7x7.v)", $realtime);
    end
    `endif
  end

endmodule
