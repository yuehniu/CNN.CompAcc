// ---------------------------------------------------
// File       : mem_data.v.vivado.v
//
// Description: partial convolution result storage module,
//              convolution result of current ker_set,
//              asynchronous read
//              merged with mem_bias -- 1.1
//              merged with pooling -- 1.2
//              output with bias checked -- 1.3
//              check relu -- 1.4
//              bias connects to partial_sum -- 1.5
//              connect with ofbuf.v -- 1.6
//
// Version    : 1.6
// ---------------------------------------------------

//`define sim_ // drirectC simulation {{{
`define NULL 0
`define TOPCHANNEL 512
`define END_X 0
`define END_Y 0
`ifdef sim_
  extern pointer  getFileDescriptor(input string fileName);
  extern void     closeFile(input pointer fileDescriptor);
  //                                                                        convolution position in the fm
  extern bit      cmpTop(input bit cmpTopEn, input bit cmpPoolEn, input pointer fileDescriptor, input bit[8:0] posX,
                          input bit[8:0] posY, input bit[`TOPCHANNEL*14*14*32-1:0] verilogTopResult, inout bit[31:0] maxError);
  extern bit      cmp7x7output(input bit cmp7x7En, input bit cmpPoolEn, input pointer fileDescriptor, input bit[8:0] posX,
                          input bit[8:0] posY, input bit[1:0] quarterIdx, input bit[9:0] channelIdx, input bit[7*7*32-1:0] verilogOutputData);
`endif //}}}
module mem_data#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter ATOMIC_W = 14, // atomic width
    parameter ATOMIC_H = 14, // atomic height
    parameter KER_C         = 32, // number of kernels at each conv operation
    parameter MAX_O_CHANNEL = 512 // maximum output channels, maximum top feature map channels
  ) (
    input  wire                                                             clk,
    input  wire                                                             rst_n,
  `ifdef sim_ // {{{
    input  wire                                                             mem_cmp_result, // compare convolution result
    input  wire                                                             mem_cmp_top,
    output wire[MAX_O_CHANNEL*(EXPONENT+MANTISSA+1)-1:0]                    mem_bias,
  `endif // }}}
    // bias interface
    input  wire                                                             mem_bias_valid,     // bias data valid
    input  wire                                                             mem_bias_last,      // last bias data burst
    input  wire[511:0]                                                      mem_bias_i,         // bias data
    // bias interface
    input  wire                                                             mem_data_cur_on_first_fm, // operate on first fm, need to add bias when convolve on first fm
    input  wire                                                             mem_data_relu_en, // activiation function
    // pooling interface
    input  wire                                                             mem_data_pooling_en, // current layer should be subsampled
    input  wire                                                             mem_data_last_fm, // convolving on last fm
    output wire                                                             mem_data_pooling_last_pos, // last valid pooling data will be written
    // pooling interface
    input  wire[9:0]                                                        mem_data_cur_ker_set, // current convolution kernel set, used to select data address, remain stable untill the end of pooling operation
    input  wire[3:0]                                                        mem_data_conv_x,  // convolution output x position, used to select data address, valid on conv_valid, otherwise, it should be zero
    input  wire[3:0]                                                        mem_data_conv_y,  // convolution output y position, used to select data address
    input  wire[3:0]                                                        mem_data_to_conv_x, // to convolve at posX
    input  wire[3:0]                                                        mem_data_to_conv_y, // to convolve at posY
    input  wire                                                             mem_data_conv_rd_partial_sum, // read partial sum, should be synchronized with _to_conv_x/y
    output wire                                                             mem_data_conv_partial_sum_valid, // partial sum data valid
    input  wire                                                             mem_data_conv_valid, // convolution output valid
    input  wire[(EXPONENT+MANTISSA+1)*KER_C-1:0]                            mem_data_conv_data_i, // convolution output (+bias, if needed), 1x32
    output wire[(EXPONENT+MANTISSA+1)*KER_C-1:0]                            mem_data_conv_partial_sum, // partial summation
  //input  wire                                                             mem_data_wr_to_fc_bram, // write output to fully connected layer bram buffer
  //input  wire                                                             mem_data_wr_to_ddr, // write output data to ddr
    input  wire                                                             mem_data_wr_next_channel, // next channel of convolution result, wr_ddr_op module is writing the last data in current channel
    input  wire                                                             mem_data_wr_data_re, // write data to ddr enable
    input  wire                                                             mem_data_rd_buffer,
    input  wire                                                             mem_data_wr_next_quarter, // next quarter of convolution result
    output wire                                                             mem_data_wr_data_valid, // next quarter of convolution result
    input  wire                                                             mem_data_wr_done, // writing operation finished
    output wire[7*7*(EXPONENT+MANTISSA+1)-1:0]                              mem_data_data, // data to write into ddr
    // last layer
    input  wire                                                             mem_data_last_layer,
    output reg [(EXPONENT+MANTISSA+1)*KER_C-1:0]                            mem_data_conv_data_last_layer_o,
    output reg                                                              mem_data_last_layer_valid,
    output reg                                                              mem_data_last_layer_last_pos,
    output reg                                                              mem_data_last_layer_first_pos,
    output reg                                                              mem_data_last_layer_on, // on last layer
    output reg [3:0]                                                        mem_data_last_layer_ker_set
  );

  localparam DATA_WIDTH   = EXPONENT + MANTISSA + 1;
  localparam MAX_NUM_OF_CHANNELS  = 512;
  localparam DDR_BURST_DATA_WIDTH = 512;
  localparam NUM_OF_DATA_IN_1_BURST =  DDR_BURST_DATA_WIDTH / DATA_WIDTH;

  reg  [4:0]                              _mem_data_channel_idx; // channel index
  reg  [1:0]                              _mem_data_quar_num; // index of 4 14x14 quarter
  wire [3:0]                              _mem_data_rd_x;   // partial sum reading position
  wire [3:0]                              _mem_data_rd_y;
  reg  [1:0]                              _mem_data_output_mode; // conv., pooling, buffer output
  // kernel set
  reg  [3:0]                              _mem_data_ofmem_portion; // 0~15
  wire [3:0]                              _mem_data_ker_set; // 0~15
  wire                                    _mem_data_conv_rd_valid;
  wire                                    _mem_data_wr_en; // buffer write enable
  // bias buffer
  wire [KER_C*DATA_WIDTH-1 : 0]           _mem_data_bias_data;// bias data to add
  wire [KER_C*DATA_WIDTH-1 : 0]           _mem_data_pre_data; // previous summation result
  reg  [9:0]                              _mem_data_cur_ker_set;
  // pooling
  wire [(EXPONENT+MANTISSA+1)*KER_C-1:0]  _mem_data_pooling_o; // pooling result
  wire [(EXPONENT+MANTISSA+1)*KER_C-1:0]  _mem_data_max_op2; // 2nd operand of 1x32_max
  reg  [(EXPONENT+MANTISSA+1)*KER_C-1:0]  _mem_data_max_reg;
  wire [(EXPONENT+MANTISSA+1)*KER_C-1:0]  _mem_data_max_o;
  reg  [3:0]                              _mem_data_pooling_x;
  reg  [3:0]                              _mem_data_pooling_y;
  reg  [3:0]                              _mem_data_pooling_rd_y;
  wire                                    _mem_data_pooling_we;
  wire                                    _mem_data_pooling_re;
  wire                                    _mem_data_conv_we;
  wire [3:0]                              _mem_data_wr_x;
  wire [3:0]                              _mem_data_wr_y;
  // last layer
  wire                                    _mem_data_pooling_first_pos;


  assign mem_data_conv_partial_sum  = mem_data_cur_on_first_fm ? _mem_data_bias_data : _mem_data_pre_data;

  //-------------------------------- bias --------------------------------{{{
  reg  [DATA_WIDTH-1:0]   _mem_bias[0:MAX_NUM_OF_CHANNELS-1];
  reg  [9:0]              _mem_bias_offset;

  always@(posedge clk) begin
    _mem_data_cur_ker_set <= mem_data_cur_ker_set;
  end

  // bias memory address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_bias_offset <= 10'h0;
    end else begin
      // increment
      if(mem_bias_valid) begin
        _mem_bias_offset <= _mem_bias_offset+NUM_OF_DATA_IN_1_BURST;
      end
      // reset
      if(mem_bias_last) begin
        _mem_bias_offset <= 10'h0;
      end
    end
  end
  // memory content, no reset
  always@(posedge clk) begin
    if(mem_bias_valid) begin
      _mem_bias[_mem_bias_offset+ 0] <= mem_bias_i[(31+1)*DATA_WIDTH-1 : 31*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 1] <= mem_bias_i[(30+1)*DATA_WIDTH-1 : 30*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 2] <= mem_bias_i[(29+1)*DATA_WIDTH-1 : 29*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 3] <= mem_bias_i[(28+1)*DATA_WIDTH-1 : 28*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 4] <= mem_bias_i[(27+1)*DATA_WIDTH-1 : 27*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 5] <= mem_bias_i[(26+1)*DATA_WIDTH-1 : 26*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 6] <= mem_bias_i[(25+1)*DATA_WIDTH-1 : 25*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 7] <= mem_bias_i[(24+1)*DATA_WIDTH-1 : 24*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 8] <= mem_bias_i[(23+1)*DATA_WIDTH-1 : 23*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+ 9] <= mem_bias_i[(22+1)*DATA_WIDTH-1 : 22*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+10] <= mem_bias_i[(21+1)*DATA_WIDTH-1 : 21*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+11] <= mem_bias_i[(20+1)*DATA_WIDTH-1 : 20*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+12] <= mem_bias_i[(19+1)*DATA_WIDTH-1 : 19*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+13] <= mem_bias_i[(18+1)*DATA_WIDTH-1 : 18*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+14] <= mem_bias_i[(17+1)*DATA_WIDTH-1 : 17*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+15] <= mem_bias_i[(16+1)*DATA_WIDTH-1 : 16*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+16] <= mem_bias_i[(15+1)*DATA_WIDTH-1 : 15*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+17] <= mem_bias_i[(14+1)*DATA_WIDTH-1 : 14*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+18] <= mem_bias_i[(13+1)*DATA_WIDTH-1 : 13*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+19] <= mem_bias_i[(12+1)*DATA_WIDTH-1 : 12*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+20] <= mem_bias_i[(11+1)*DATA_WIDTH-1 : 11*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+21] <= mem_bias_i[(10+1)*DATA_WIDTH-1 : 10*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+22] <= mem_bias_i[( 9+1)*DATA_WIDTH-1 :  9*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+23] <= mem_bias_i[( 8+1)*DATA_WIDTH-1 :  8*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+24] <= mem_bias_i[( 7+1)*DATA_WIDTH-1 :  7*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+25] <= mem_bias_i[( 6+1)*DATA_WIDTH-1 :  6*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+26] <= mem_bias_i[( 5+1)*DATA_WIDTH-1 :  5*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+27] <= mem_bias_i[( 4+1)*DATA_WIDTH-1 :  4*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+28] <= mem_bias_i[( 3+1)*DATA_WIDTH-1 :  3*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+29] <= mem_bias_i[( 2+1)*DATA_WIDTH-1 :  2*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+30] <= mem_bias_i[( 1+1)*DATA_WIDTH-1 :  1*DATA_WIDTH];
      _mem_bias[_mem_bias_offset+31] <= mem_bias_i[( 0+1)*DATA_WIDTH-1 :  0*DATA_WIDTH];
    end
  end

  // bias data to add
  assign _mem_data_bias_data ={_mem_bias[_mem_data_cur_ker_set + 0], _mem_bias[_mem_data_cur_ker_set + 1], _mem_bias[_mem_data_cur_ker_set + 2], _mem_bias[_mem_data_cur_ker_set + 3],
                               _mem_bias[_mem_data_cur_ker_set + 4], _mem_bias[_mem_data_cur_ker_set + 5], _mem_bias[_mem_data_cur_ker_set + 6], _mem_bias[_mem_data_cur_ker_set + 7],
                               _mem_bias[_mem_data_cur_ker_set + 8], _mem_bias[_mem_data_cur_ker_set + 9], _mem_bias[_mem_data_cur_ker_set +10], _mem_bias[_mem_data_cur_ker_set +11],
                               _mem_bias[_mem_data_cur_ker_set +12], _mem_bias[_mem_data_cur_ker_set +13], _mem_bias[_mem_data_cur_ker_set +14], _mem_bias[_mem_data_cur_ker_set +15],
                               _mem_bias[_mem_data_cur_ker_set +16], _mem_bias[_mem_data_cur_ker_set +17], _mem_bias[_mem_data_cur_ker_set +18], _mem_bias[_mem_data_cur_ker_set +19],
                               _mem_bias[_mem_data_cur_ker_set +20], _mem_bias[_mem_data_cur_ker_set +21], _mem_bias[_mem_data_cur_ker_set +22], _mem_bias[_mem_data_cur_ker_set +23],
                               _mem_bias[_mem_data_cur_ker_set +24], _mem_bias[_mem_data_cur_ker_set +25], _mem_bias[_mem_data_cur_ker_set +26], _mem_bias[_mem_data_cur_ker_set +27],
                               _mem_bias[_mem_data_cur_ker_set +28], _mem_bias[_mem_data_cur_ker_set +29], _mem_bias[_mem_data_cur_ker_set +30], _mem_bias[_mem_data_cur_ker_set +31]};

`ifdef sim_ // bias info{{{
  genvar i;
  generate
    for(i=0; i<MAX_NUM_OF_CHANNELS; i=i+1) begin
      assign mem_bias[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] = _mem_bias[MAX_NUM_OF_CHANNELS - 1 - i];
    end
  endgenerate
  wire [31:0] _bias_data01,_bias_data02,_bias_data03,_bias_data04,_bias_data05,_bias_data06,_bias_data07,_bias_data08,
              _bias_data09,_bias_data10,_bias_data11,_bias_data12,_bias_data13,_bias_data14,_bias_data15,_bias_data16;
  assign _bias_data01 = _mem_bias[0];   assign _bias_data02 = _mem_bias[1];
  assign _bias_data03 = _mem_bias[2];   assign _bias_data04 = _mem_bias[3];
  assign _bias_data05 = _mem_bias[4];   assign _bias_data06 = _mem_bias[5];
  assign _bias_data07 = _mem_bias[6];   assign _bias_data08 = _mem_bias[7];
  assign _bias_data09 = _mem_bias[8];   assign _bias_data10 = _mem_bias[9];
  assign _bias_data11 = _mem_bias[10];  assign _bias_data12 = _mem_bias[11];
  assign _bias_data13 = _mem_bias[12];  assign _bias_data14 = _mem_bias[13];
  assign _bias_data15 = _mem_bias[14];  assign _bias_data16 = _mem_bias[15];
`endif // }}}

  //-------------------------------- bias --------------------------------}}}

  assign _mem_data_ker_set  = _mem_data_output_mode==2'd2 ? _mem_data_ofmem_portion : _mem_data_cur_ker_set[8:5];
  assign _mem_data_rd_x     = _mem_data_output_mode==2'd2 ? 4'd0 : mem_data_to_conv_x;
  assign _mem_data_rd_y     = _mem_data_output_mode==2'd2 ? 4'd0 : mem_data_to_conv_y;
//`ifdef sim_
    assign _mem_data_wr_en    = _mem_data_conv_we || (_mem_data_pooling_we); // simulation only
//`else
//  assign _mem_data_wr_en    = _mem_data_conv_we || (_mem_data_pooling_we && (!mem_data_last_layer));
//`endif
  assign mem_data_conv_partial_sum_valid = _mem_data_conv_rd_valid;

  // mode
  always@(mem_data_wr_data_re or mem_data_conv_valid or mem_data_pooling_en or mem_data_last_fm) begin
    if(mem_data_conv_valid) begin
      if(mem_data_pooling_en && mem_data_last_fm) begin // pooling
        _mem_data_output_mode = 2'd1;
      end else begin // normal
        _mem_data_output_mode = 2'd0;
      end
    end else if(mem_data_wr_data_re) begin // write data to ddr
      _mem_data_output_mode = 2'd2;
    end else begin
      _mem_data_output_mode = 2'd0;
    end
  end

  // buffer reading position
    // quarter number, 0 -- TL, 1 -- TR, 2 -- BL, 3 -- BR
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_data_quar_num <= 2'd0;
    end else begin
      if(mem_data_wr_data_re) begin // write data to ddr
        if(mem_data_wr_done || mem_data_pooling_en) begin
          _mem_data_quar_num <= 2'd0;
        end else if(mem_data_wr_next_quarter) begin
          _mem_data_quar_num <= _mem_data_quar_num + 2'd1;
        end
      end
    end
  end
  // channel index 0~31, portion number of ofmem 0~15
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_data_channel_idx   <= 5'd0;
      _mem_data_ofmem_portion <= 4'd0;
    end else begin
      if(mem_data_wr_data_re) begin // write data to ddr
        if(mem_data_wr_done) begin
        // reset
          _mem_data_channel_idx   <= 5'd0;
          _mem_data_ofmem_portion <= 4'd0;
        end else if(mem_data_wr_next_channel) begin
        // increment
          if(_mem_data_channel_idx==5'd31) begin
            _mem_data_channel_idx <= 5'd0;
            _mem_data_ofmem_portion <= _mem_data_ofmem_portion + 4'd1;
          end else begin
            _mem_data_channel_idx <= _mem_data_channel_idx + 5'd1;
          end
        end
      end
    end
  end

  `ifdef sim_ // compare 7x7 output data {{{
  reg  _mem_data_directC_cmp7x7NotPass;
  reg  [9:0] _mem_data_channel_index;
  reg  [9:0] _mem_data_channel_index_reg;
  integer fd_orig_top;
  initial begin
    _mem_data_directC_cmp7x7NotPass = 0;
    fd_orig_top = getFileDescriptor("../../data/conv5_3/pool5.conv5_3.orig.top.txt"); //"../../data/orig.top.pool0.txt"); // 
    if(fd_orig_top == (`NULL)) begin
      $display("top fd handle is NULL\n");
      $finish;
    end
  end
  // position
  reg  [8:0]  _mem_cmp7x7_posX;
  reg  [8:0]  _mem_cmp7x7_posY;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_cmp7x7_posX <= 9'd0;
      _mem_cmp7x7_posY <= 9'd0;
    end else begin
      if(mem_data_wr_done) begin
        if(_mem_cmp7x7_posX==`END_X) begin
          _mem_cmp7x7_posX <= 9'd0;
        end else begin
          _mem_cmp7x7_posX <= _mem_cmp7x7_posX+9'd1;
        end
        if(_mem_cmp7x7_posX==`END_X) begin
          if(_mem_cmp7x7_posY==`END_Y) begin
            _mem_cmp7x7_posY <= 9'd0;
          end else begin
            _mem_cmp7x7_posY <= _mem_cmp7x7_posY + 9'd1;
          end
        end 
      end
    end
  end
  // channel index
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_data_channel_index <= 10'd0;
    end else begin
      if(mem_data_wr_done) begin
        _mem_data_channel_index <= 10'd0;
      end else if(mem_data_wr_next_channel) begin
        _mem_data_channel_index <= _mem_data_channel_index + 10'd1;
      end
    end
  end
  always@(posedge clk or negedge rst_n) begin
    _mem_data_channel_index_reg <= _mem_data_channel_index;
  end
  always@(posedge clk or negedge rst_n) begin
    if(rst_n) begin
      if(mem_data_wr_data_re && mem_data_wr_next_quarter) begin
        _mem_data_directC_cmp7x7NotPass = cmp7x7output(mem_cmp_result && mem_cmp_top && mem_data_wr_next_quarter, mem_data_pooling_en, fd_orig_top, _mem_cmp7x7_posX, _mem_cmp7x7_posY, _mem_data_quar_num, _mem_data_channel_index, mem_data_data);
        $display("%t: check 7x7 data", $realtime);
      end
      if(_mem_data_directC_cmp7x7NotPass) begin
        $display("%t: 7x7 data check failed", $realtime);
      //#100 $finish;
      end
    end
  end

  `endif //}}}

  // pooling
  mem_1x32_max #(
    .EXPONENT(EXPONENT),
    .MANTISSA(MANTISSA),
    .KER_C(KER_C)
  ) mem_data_pool1x32 (
    .clk(clk),
    .mem_max_v1(mem_data_conv_data_i), // conv. result
    .mem_max_v2(_mem_data_max_op2),
    .mem_max_en(mem_data_last_fm),
    .mem_max_o(_mem_data_max_o)
  );

  // 2nd comparison operand
  assign _mem_data_max_op2 = _mem_data_output_mode==2'd0 ? {(KER_C*DATA_WIDTH){1'b0}} :
                                      ((mem_data_conv_y[0]==1'b1) ? _mem_data_max_reg :
                                       ((mem_data_conv_x[0]==1'b1) ? _mem_data_pooling_o : {(KER_C*DATA_WIDTH){1'b0}}));

  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_data_max_reg <= {(KER_C*DATA_WIDTH){1'b0}};
    end else begin
      if(mem_data_conv_y[0]==1'b0) begin
        _mem_data_max_reg <= _mem_data_max_o;
      end
    end
  end

  // pooling result writing position
  always@(mem_data_conv_x) begin
    _mem_data_pooling_x = 4'd0;
    case(mem_data_conv_x)
      4'd0,
      4'd1: _mem_data_pooling_x = 4'd0;
      4'd2,
      4'd3: _mem_data_pooling_x = 4'd1;
      4'd4,
      4'd5: _mem_data_pooling_x = 4'd2;
      4'd6,
      4'd7: _mem_data_pooling_x = 4'd3;
      4'd8,
      4'd9: _mem_data_pooling_x = 4'd4;
      4'd10,
      4'd11: _mem_data_pooling_x = 4'd5;
      4'd12,
      4'd13: _mem_data_pooling_x = 4'd6;
    endcase
  end
  always@(mem_data_conv_y) begin
    _mem_data_pooling_y = 4'd0;
    case(mem_data_conv_y)
      4'd0,
      4'd1: _mem_data_pooling_y = 4'd0;
      4'd2,
      4'd3: _mem_data_pooling_y = 4'd1;
      4'd4,
      4'd5: _mem_data_pooling_y = 4'd2;
      4'd6,
      4'd7: _mem_data_pooling_y = 4'd3;
      4'd8,
      4'd9: _mem_data_pooling_y = 4'd4;
      4'd10,
      4'd11: _mem_data_pooling_y = 4'd5;
      4'd12,
      4'd13: _mem_data_pooling_y = 4'd6;
    endcase
  end
  // pooling result reading
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_data_pooling_rd_y <= 4'd0;
    end else begin
      if(_mem_data_pooling_re) begin
        if(_mem_data_pooling_rd_y==4'd6) begin
          _mem_data_pooling_rd_y <= 4'd0;
        end else begin
          _mem_data_pooling_rd_y <= _mem_data_pooling_rd_y + 4'd1;
        end
      end
    end
  end
  // pooling write/read enable
  assign _mem_data_pooling_we = (mem_data_pooling_en && mem_data_last_fm) && (mem_data_conv_y[0]==1'b1);
  assign _mem_data_pooling_re = (mem_data_pooling_en && mem_data_last_fm) &&
                            ((mem_data_conv_x[0]==1'b1 && mem_data_conv_y[0]==1'b0 && mem_data_conv_y!=4'd10 && mem_data_conv_y!=4'd12) ||
                             (mem_data_conv_x[0]==1'b0 && mem_data_conv_y==4'd10) ||
                             (mem_data_conv_x[0]==1'b0 && mem_data_conv_y==4'd12));
  // disable conv_we
  assign _mem_data_conv_we = (mem_data_pooling_en && mem_data_last_fm) ? 1'b0 : mem_data_conv_valid;
  // write x/y
  assign _mem_data_wr_x  = (mem_data_pooling_en && mem_data_last_fm) ? _mem_data_pooling_x : mem_data_conv_x;
  assign _mem_data_wr_y  = (mem_data_pooling_en && mem_data_last_fm) ? _mem_data_pooling_y : mem_data_conv_y;
  assign mem_data_pooling_last_pos = (mem_data_conv_x==4'd13 && mem_data_conv_y==4'd13 && mem_data_pooling_en && mem_data_last_fm) ? 1'b1 : 1'b0;
  assign _mem_data_pooling_first_pos = (mem_data_conv_x==4'd1 && mem_data_conv_y==4'd1 && mem_data_pooling_en && mem_data_last_fm) ? 1'b1 : 1'b0;

  // output buffer
  bram_data #(
    .EXPONENT(EXPONENT),
    .MANTISSA(MANTISSA),
    .PORT_ADDR_WIDTH(12)
  ) mem_bram_data (
    .rst_n(rst_n),
    .clk(clk),
    .bram_data_quarter_num(_mem_data_quar_num), // ddr related only
    .bram_data_ker_set(_mem_data_ker_set),
    .bram_data_channel_idx(_mem_data_channel_idx), // ddr related only
    .bram_data_wr_x(_mem_data_wr_x),
    .bram_data_wr_y(_mem_data_wr_y),
    .bram_data_rd_x(_mem_data_rd_x),
    .bram_data_rd_y(_mem_data_rd_y),
    .bram_data_pooling_rd_x(_mem_data_pooling_x[2:0]),
    .bram_data_pooling_rd_y(_mem_data_pooling_rd_y[2:0]),
    .bram_data_data_i(_mem_data_max_o),
    .bram_data_wr_en(_mem_data_wr_en),
    .bram_data_conv_rd_en(mem_data_conv_rd_partial_sum),
    .bram_data_pooling_rd_en(_mem_data_pooling_re),
    .bram_data_wr_ddr_rd_en(mem_data_wr_data_re),
    .bram_data_rd_top_buffer(mem_data_rd_buffer),
  //.bram_data_wr_ddr_rd_next_quar(_mem_data_wr_on_the_next_quar),
    .bram_data_wr_ddr_rd_next_quar(mem_data_wr_next_quarter),
    .bram_data_pre_data(_mem_data_pre_data),
    .bram_data_ddr_do(mem_data_data),
    .bram_data_pooling_data(_mem_data_pooling_o),
    .bram_data_ddr_rd_valid(mem_data_wr_data_valid),
    .bram_data_conv_rd_valid(_mem_data_conv_rd_valid),
    .bram_data_pooling_rd_valid()
  );


  // last layer pooling output
  always@(posedge clk) begin
    if(mem_data_last_layer) begin
      mem_data_last_layer_valid   <= (_mem_data_pooling_we && mem_data_conv_x[0]==1'b1);
      mem_data_last_layer_last_pos<= mem_data_pooling_last_pos && (_mem_data_cur_ker_set[8:5]==4'd15);
      mem_data_last_layer_ker_set <= _mem_data_cur_ker_set[8:5];
      mem_data_last_layer_on      <= 1'b1;
      mem_data_last_layer_first_pos <= _mem_data_pooling_first_pos;
      if(_mem_data_pooling_we) begin
        mem_data_conv_data_last_layer_o <= _mem_data_max_o;
      end
    end else begin
      mem_data_last_layer_on      <= 1'b0;
      mem_data_last_layer_valid   <= 1'd0;
      mem_data_last_layer_last_pos<= 1'd0;
      mem_data_last_layer_ker_set <= 4'd0;
      mem_data_last_layer_first_pos   <= 1'b0;
    //mem_data_conv_data_last_layer_o <= {(DATA_WIDTH*KER_C){1'b1}};
    end
  end

endmodule
