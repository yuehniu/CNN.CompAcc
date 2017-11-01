// ---------------------------------------------------
// File       : conv.v
//
// Description: top module of convolution layer
//              connect with memory -- 1.1
//              connect with wr_op -- 1.2
//
// Version    : 1.2
// ---------------------------------------------------

`define NULL 0
//`define sim_
`ifdef sim_ // simulation {{{
  extern pointer  getFileDescriptor(input string fileName);
  extern void     closeFile(input pointer fileDescriptor);
  extern void     readProcRam(input pointer fileDescriptor, input bit readBottomData, input bit[9:0] ithFM,
                              input bit[8:0] xPos, input bit[8:0] yPos, input bit[8:0] xEndPos,
                              input bit[8:0] yEndPos, output bit[16*16*32-1:0] procRam);
                                                      // procRamHeight*procRamWidth*floatNum -1 : 0
  extern bit      cmpRam(input bit cmpEnable, input bit[16*16*32-1:0] ramDirectC, input bit[16*16*16-1:0] ramVerilog);
  extern void     readProcKer(input pointer fileDescriptor, input bit readKerData, input bit[29:0] ithKer,
                              output bit[32*3*3*32-1:0] procKer); // read ker_set data
  extern bit      cmpKer(input bit cmpKerEnable, input bit[32*3*3*32-1:0] kerDirectC, input bit[32*3*3*16-1:0] kerVerilog);
  extern void     readProcBias(input pointer fileDescriptor, input bit readBiasData, output bit[512*32-1:0] procBias);
  extern bit      cmpBias(input bit cmpBiasEnable, input bit[512*32-1:0] biasDirectC, input bit[512*16-1:0] biasVerilog);
  extern void     rearrangeRamData(input bit rearrangeEn, input bit[16*16*32-1:0] procPatch, output bit[14*14*3*3*32-1:0] blasRam);
  extern void     rearrangeKerData(input bit rearrangeEn, input bit[32*3*3*32-1:0] procKer, output bit[32*3*3*32-1:0] blasKer);
  extern bit      cmpCnnCorr(input bit[14*14*3*3*32-1:0] blasRam, input bit[32*3*3*32-1:0] procWeight, input bit[32*32-1:0] procConvOutput,
                              input bit[3:0] convX, input bit[3:0] convY, inout bit[31:0] maxError);
`endif // simulation }}}

module conv #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10
    ) (
  // -------------------- simulation --------------------{{{
  `ifdef sim_
    output wire [16*16*16-1:0]    fm_mem_patch_proc_ram, // [16*16*(EXPONENT+MANTISSA+1)-1:0]
    output wire [32*3*3*16-1:0]   fm_mem_ker, // [32*3*3*(EXPONENT+MANTISSA+1)-1:0]
    output wire                   fm_data_valid_last,
    input  wire                   fm_cmp_top,
    input  wire                   fm_cmp_bottom_ker,
  `endif
  // -------------------- simulation --------------------}}}
    input  wire           clk,
    input  wire           rst_n,
    // ddr interface
    output reg            fm_ddr_req,
    input  wire           ddr_rd_data_valid,
    input  wire           ddr_rdy,
    input  wire           ddr_wdf_rdy,
    input  wire [511:0]   ddr_rd_data,
    output reg  [29:0]    ddr_addr,
    output reg  [2:0]     ddr_cmd,
    output reg            ddr_en,
    output wire [511:0]   ddr_wdf_data,
    output wire [63:0]    ddr_wdf_mask, // stuck at 64'b1
    output wire           ddr_wdf_end,  // stuck at 1'b1
    output wire           ddr_wdf_wren,
    // layer configuration
    input  wire           fm_relu_en, // enable relu
    input  wire           fm_pooling_en, // enable pooling
    input  wire           fm_last_layer, // last input layer
    // bottom
    input  wire [8:0]     fm_width, // bottom data width / atomic_width
    input  wire [8:0]     fm_height, // bottom data height / atomic_height
    input  wire [29:0]    fm_bottom_ddr_addr, // bottom data address to read from
    input  wire [9:0]     fm_bottom_channels, // num of bottom data channels
    input  wire [29:0]    fm_size, // fm_width*fm_height*float_num_width/ddr_data_width
    input  wire [29:0]    fm_1bar_size, // 14*fm_width*float_num_width/ddr_data_width -> 64*4*num_of_atom*float_num_width/ddr_data_width(32bit)
    input  wire [29:0]    fm_half_bar_size, // 7*rd_data_max_x*float_num_width/ddr_data_width -> 64*2*num_of_atom*float_num_width/ddr_data_width(32bit)
    // kernel and bias
    input  wire [9:0]     fm_bias_num, // num of top data channels -> num of bias
    input  wire [5:0]     fm_bias_ddr_burst_num, // num of burst to read all bias data
    input  wire [8:0]     fm_bias_offset, // address occupied by bias data
    input  wire [29:0]    fm_ker_ddr_addr, // parameter data address
    // top
    input  wire [29:0]    fm_top_ddr_addr, // top data address to write to
    input  wire [9:0]     fm_top_channels, // num of top data channels
    input  wire [29:0]    fm_top_fm_size, // top feature map size
    input  wire [29:0]    fm_top_half_bar_size, // 7*rd_data_max_x*float_num_width/ddr_data_width -> 64*2*num_of_atom*float_num_width/ddr_data_width(32bit)
    // last layer
    output wire           fm_llayer_last_data,
    output wire           fm_llayer_bram_we,
    output wire [9:0]     fm_llayer_bram_addr,
    output wire [32*(EXPONENT+MANTISSA+1)-1:0] fm_llayer_bram_o,
    //
    input  wire           fm_data_ready, // bottom data and kernel data is ready on ddr -> convolution start
    input  wire           fm_start, // conv layer operation start signal
    output wire           fm_conv_done // current layer convolution(read & convolution & write) done
  );

  localparam ATOMIC_WIDTH = 14;
  localparam ATOMIC_HEIGHT = 14;
  localparam FLOAT_DATA_WIDTH = 16;
  localparam DDR_DATA_WIDTH = 64;
  localparam KER_CHANNELS = 32;
  localparam KER_HEIGHT = 3;
  localparam KER_WIDTH = 3;
  localparam DDR_PARAM_OFFSET = KER_CHANNELS * KER_HEIGHT * KER_WIDTH * FLOAT_DATA_WIDTH / DDR_DATA_WIDTH;

  localparam K_C      = 32; // kernel channels
  localparam K_H      = 3; // kernel height
  localparam K_W      = 3; // kernel width
  localparam ATOMIC_W = 14; // atomic width
  localparam ATOMIC_H = 14; // atomic height
  localparam MAX_O_CHANNEL = 512; // maximum output channels, maximum top feature map channels
  localparam DATA_WIDTH = EXPONENT+MANTISSA+1;

  wire [29:0]   _fm_rd_data_ddr_addr;
  wire [2:0]    _fm_rd_data_ddr_cmd;
  wire          _fm_rd_data_ddr_en;
  wire [29:0]   _fm_rd_param_ddr_addr;
  wire [2:0]    _fm_rd_param_ddr_cmd;
  wire          _fm_rd_param_ddr_en;
  wire [29:0]   _fm_wr_data_ddr_addr;
  wire [2:0]    _fm_wr_data_ddr_cmd;
  wire          _fm_wr_data_ddr_en;
  // conv_op
  wire          _fm_conv_start;
  wire          _fm_conv_busy;
  wire          _fm_conv_at_last_pos;
  wire          _fm_conv_last_valid;
  wire          _fm_conv_start_at_next_clk;
  wire          _fm_conv_next_ker_full;
  wire          _fm_conv_patch0;
  wire          _fm_conv_patch1;
  wire          _fm_conv_ker0;
  wire          _fm_conv_ker1;
  wire          _fm_conv_on_first_fm;
  wire          _fm_conv_on_last_fm;
  wire          _fm_conv_valid;
  wire [3:0]    _fm_conv_x;
  wire [3:0]    _fm_conv_y;
  wire [3:0]    _fm_to_conv_x;
  wire [3:0]    _fm_to_conv_y;
  wire [9:0]    _fm_conv_ker_num;
  wire [K_C*K_H*K_W*DATA_WIDTH-1:0]   _fm_conv_ker;
  wire [16*16*DATA_WIDTH-1:0]         _fm_conv_bottom;
  wire [7*7*DATA_WIDTH-1:0]           _fm_conv_top;
  wire [K_C*DATA_WIDTH-1:0]           _fm_conv_op_top_o;
  wire [K_C*DATA_WIDTH-1:0]           _fm_conv_op_partial_sum;
//wire                                _fm_conv_next_partial_sum;
  // pooling
  wire          _fm_pooling_last_pos;
  // write
  wire          _fm_wr_data_sw_on;
  wire          _fm_wr_data_top; // write enable
  wire          _fm_wr_data_x_eq_0;
  wire          _fm_wr_data_y_eq_0;
  wire          _fm_wr_data_x_eq_end;
  wire          _fm_wr_data_y_eq_end;
  wire          _fm_wr_data_next_channel;
  wire          _fm_wr_data_done;
  wire [K_C*DATA_WIDTH-1 : 0] _fm_wr_llayer_o;
  wire          _fm_wr_llayer_valid;
  wire          _fm_wr_llayer_last_pos;
  wire          _fm_wr_llayer_first_pos;
  wire [3:0]    _fm_wr_llayer_ker_set;
  // rd_ddr_data
  wire          _fm_rd_data_full;
  wire          _fm_rd_data_bottom;
  wire [8:0]    _fm_rd_data_x;
  wire [8:0]    _fm_rd_data_y;
  wire [8:0]    _fm_rd_data_end_of_x;
  wire [8:0]    _fm_rd_data_end_of_y;
  wire          _fm_rd_data_first_fm;
  wire [29:0]   _fm_rd_data_ith_offset;
  wire          _fm_rd_data_sw_on;
  wire [5:0]    _fm_rd_data_num_valid;
  wire [511:0]  _fm_rd_data_data;
  wire          _fm_rd_data_valid;
  wire          _fm_rd_data_patch_valid_last;
  wire          _fm_rd_data_patch_upper_valid_last;
  wire          _fm_rd_data_valid_first;
  wire          _fm_rd_data_x_eq_zero;
  wire          _fm_rd_data_x_eq_end;
  wire          _fm_rd_data_y_eq_zero;
  wire          _fm_rd_data_y_eq_end;
  wire          _fm_rd_data_patch0;
  wire          _fm_rd_data_patch1;
  // rd_ddr_param
  wire          _fm_rd_param_full;
  wire [29:0]   _fm_rd_ker_ddr_addr;
  wire          _fm_rd_param;
  wire          _fm_rd_param_ker_only;
  wire [29:0]   _fm_rd_param_addr;
  wire          _fm_rd_param_sw_on;
  wire          _fm_rd_param_valid;
  wire          _fm_rd_param_ker_valid;
  wire          _fm_rd_param_ker_valid_last;
  wire          _fm_rd_param_bias_valid;
  wire          _fm_rd_param_bias_valid_last;
  wire [511:0]  _fm_rd_param_data;
  wire          _fm_rd_param_ker0;
  wire          _fm_rd_param_ker1;
  // rd_bram_patch
  wire          _fm_rd_bram_patch;
  wire          _fm_rd_bram_patch_first_valid;
  wire          _fm_rd_bram_patch_last_valid;
  wire [11:0]   _fm_rd_bram_patch_addr;
  wire          _fm_rd_bram_patch_enb;
  wire          _fm_rd_bram_patch_valid;
  wire [11:0]   _fm_rd_bram_patch_addrb;
  // rd_bram_row
  wire          _fm_rd_bram_row;
  wire [09:0]   _fm_rd_bram_row_addr;
  wire          _fm_rd_bram_row_valid;
  wire          _fm_rd_bram_row_enb;
  wire [9:0]    _fm_rd_bram_row_addrb;

  // ddr input/output switch
  always@(_fm_rd_data_sw_on or _fm_rd_param_sw_on or _fm_rd_data_ddr_addr or
          _fm_rd_data_ddr_cmd or _fm_rd_data_ddr_en or _fm_rd_param_ddr_addr or
          _fm_rd_param_ddr_cmd or _fm_rd_param_ddr_en or _fm_wr_data_sw_on or
          _fm_wr_data_ddr_addr or _fm_wr_data_ddr_cmd or _fm_wr_data_ddr_en
          ) begin
    if(_fm_rd_data_sw_on) begin
      ddr_addr  = _fm_rd_data_ddr_addr;
      ddr_cmd   = _fm_rd_data_ddr_cmd;
      ddr_en    = _fm_rd_data_ddr_en;
    end else if(_fm_rd_param_sw_on) begin
      ddr_addr  = _fm_rd_param_ddr_addr;
      ddr_cmd   = _fm_rd_param_ddr_cmd;
      ddr_en    = _fm_rd_param_ddr_en;
    end else if(_fm_wr_data_sw_on) begin
      ddr_addr  = _fm_wr_data_ddr_addr;
      ddr_cmd   = _fm_wr_data_ddr_cmd;
      ddr_en    = _fm_wr_data_ddr_en;
    end else begin
      ddr_addr  = 30'h0;
      ddr_cmd   = 3'h0;
      ddr_en    = 1'b0;
    end
  end

`ifdef sim_ // simulation tasks/directC {{{
  integer fd_orig_data, fd_orig_param;

  wire [16*16*16-1:0]        _fm_rd_proc_ram; // <-x data width, May.28
  wire [K_C*K_H*K_W*16-1:0]  _fm_rd_ker; // <-x data width
  wire [MAX_O_CHANNEL*16-1:0]_fm_rd_bias; // <-x data width
  reg  [16*16*32-1:0]        _fm_directC_procRam; // <-x data width
  reg  [K_C*K_H*K_W*32-1:0]  _fm_directC_ker;
  reg  [MAX_O_CHANNEL*32-1:0]_fm_directC_bias;
  assign fm_data_valid_last = _fm_rd_data_full;
  assign fm_mem_ker         = _fm_rd_ker;
  assign fm_mem_patch_proc_ram  = _fm_rd_proc_ram;
  initial begin
    fd_orig_data = getFileDescriptor("../../data/conv5_3/conv5_3.orig.bottom.txt");
    fd_orig_param= getFileDescriptor("../../data/param/conv5_3.param.txt");
    if((fd_orig_data == `NULL) || (fd_orig_param == `NULL)) begin
      $display("fd handle is NULL(in conv.v)\n");
      $finish;
    end
  end
  // read bottom file {{{
  // read bottom file rising edge
  reg  _fm_rd_data_bottom_reg;
  reg  _fm_directC_readBottom;
  wire _fm_rd_data_bottom_rising_edge;
  assign _fm_rd_data_bottom_rising_edge = (!_fm_rd_data_bottom_reg) && _fm_rd_data_bottom;
  always@(posedge clk) begin
    _fm_rd_data_bottom_reg <= _fm_rd_data_bottom;
    _fm_directC_readBottom <= _fm_rd_data_bottom_rising_edge;
  end
  // read bottom count
  reg [9:0] _fm_directC_ithFM;
  always@(posedge clk) begin
    if(_fm_rd_data_bottom_rising_edge) begin
      if(_fm_rd_data_first_fm) begin
        _fm_directC_ithFM <= 10'h0;
      end else begin
        _fm_directC_ithFM <= _fm_directC_ithFM + 10'h1;
      end
    end
    if(_fm_directC_readBottom) begin
      readProcRam(fd_orig_data, _fm_directC_readBottom, _fm_directC_ithFM, _fm_rd_data_x,
                  _fm_rd_data_y, _fm_rd_data_end_of_x, _fm_rd_data_end_of_x, _fm_directC_procRam);
    end
  end
  //
  wire  _fm_fsm_decision;
  reg   _fm_fsm_decision_reg;
  always@(posedge clk) begin
    _fm_fsm_decision_reg <= _fm_fsm_decision;
  end

  // compare difference
  wire _fm_directC_cmpEn_wire;
  assign _fm_directC_cmpEn_wire = (!_fm_fsm_decision_reg && _fm_fsm_decision);
  reg  _fm_directC_cmpEn;
  always@(posedge clk) begin
    _fm_directC_cmpEn <= _fm_directC_cmpEn_wire;
  end
  reg  _fm_directC_checkNotPass;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fm_directC_checkNotPass  <= 1'b0;
    end else begin
    //$display("%t: before compare ram content", $realtime);
      if(_fm_directC_cmpEn && fm_cmp_bottom_ker) begin
        $display("%t: compare ram content", $realtime);
        _fm_directC_checkNotPass = cmpRam(_fm_directC_cmpEn, _fm_directC_procRam, _fm_rd_proc_ram);
      end
      if(_fm_directC_checkNotPass) begin
        $display("%t: procRam data check failed(in conv.v)", $realtime);
        #100 $finish;
      end
    end
  end
  // read bottom file}}}

  // read param{{{
  // read bias{{{
  reg  _fm_rd_bias_reg;
  reg  _fm_directC_readBias;
  wire _fm_rd_bias_falling_edge;
  assign _fm_rd_bias_falling_edge = _fm_rd_bias_reg && (!_fm_rd_param_ker_only);
  always@(posedge clk) begin
    _fm_rd_bias_reg       <= _fm_rd_param_ker_only;
    _fm_directC_readBias  <= _fm_rd_bias_falling_edge;
  end
  // read bias data
  always@(posedge clk) begin
    if(_fm_directC_readBias) begin
      readProcBias(fd_orig_param, _fm_directC_readBias, _fm_directC_bias);
    end
  end
  // compare
  reg  _fm_directC_cmpBias;
  reg  _fm_directC_checkBiasNotPass;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fm_directC_cmpBias <= 1'b0;
      _fm_directC_checkBiasNotPass <= 1'b0;
    end else begin
      _fm_directC_cmpBias <= _fm_rd_param_bias_valid_last;
      if(_fm_directC_cmpBias && fm_cmp_bottom_ker) begin
        _fm_directC_checkBiasNotPass = cmpBias(_fm_directC_cmpBias, _fm_directC_bias, _fm_rd_bias);
      end
      if(_fm_directC_checkBiasNotPass) begin
        $display("%t: bias check failed(in conv.v)", $realtime);
        #100 $finish;
      end
    end
  end
  wire [31:0] _bias_data01,_bias_data02,_bias_data03,_bias_data04,_bias_data05,_bias_data06,_bias_data07,_bias_data08,
              _bias_data09,_bias_data10,_bias_data11,_bias_data12,_bias_data13,_bias_data14,_bias_data15,_bias_data16;
  assign _bias_data01 = _fm_rd_bias[(511+1)*DATA_WIDTH-1 : 511*DATA_WIDTH];    assign _bias_data02 = _fm_rd_bias[(510+1)*DATA_WIDTH-1 : 510*DATA_WIDTH];
  assign _bias_data03 = _fm_rd_bias[(509+1)*DATA_WIDTH-1 : 509*DATA_WIDTH];    assign _bias_data04 = _fm_rd_bias[(508+1)*DATA_WIDTH-1 : 508*DATA_WIDTH];
  assign _bias_data05 = _fm_rd_bias[(507+1)*DATA_WIDTH-1 : 507*DATA_WIDTH];    assign _bias_data06 = _fm_rd_bias[(506+1)*DATA_WIDTH-1 : 506*DATA_WIDTH];
  assign _bias_data07 = _fm_rd_bias[(505+1)*DATA_WIDTH-1 : 505*DATA_WIDTH];    assign _bias_data08 = _fm_rd_bias[(504+1)*DATA_WIDTH-1 : 504*DATA_WIDTH];
  assign _bias_data09 = _fm_rd_bias[(503+1)*DATA_WIDTH-1 : 503*DATA_WIDTH];    assign _bias_data10 = _fm_rd_bias[(502+1)*DATA_WIDTH-1 : 502*DATA_WIDTH];
  assign _bias_data11 = _fm_rd_bias[(501+1)*DATA_WIDTH-1 : 501*DATA_WIDTH];    assign _bias_data12 = _fm_rd_bias[(500+1)*DATA_WIDTH-1 : 500*DATA_WIDTH];
  assign _bias_data13 = _fm_rd_bias[(499+1)*DATA_WIDTH-1 : 499*DATA_WIDTH];    assign _bias_data14 = _fm_rd_bias[(498+1)*DATA_WIDTH-1 : 498*DATA_WIDTH];
  assign _bias_data15 = _fm_rd_bias[(497+1)*DATA_WIDTH-1 : 497*DATA_WIDTH];    assign _bias_data16 = _fm_rd_bias[(496+1)*DATA_WIDTH-1 : 496*DATA_WIDTH];

  // read bias}}}
  // read ker_set{{{
  reg  _fm_rd_param_reg;
  reg  _fm_directC_readParam;
  wire _fm_rd_param_rising_edge;
  assign _fm_rd_param_rising_edge = (!_fm_rd_param_reg) && _fm_rd_param;
  always@(posedge clk) begin
    _fm_rd_param_reg      <= _fm_rd_param;
    _fm_directC_readParam <= _fm_rd_param_rising_edge;
  end
  // read kernel count
  reg  [29:0]  _fm_directC_ithKer;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fm_directC_ithKer <= (30'h0 - 30'd32);
    end else begin
      if(_fm_rd_param_rising_edge && fm_cmp_bottom_ker) begin
        if((_fm_conv_ker_num == (fm_bias_num-10'd32)) && _fm_conv_on_last_fm)begin // <-x should be in the last fm
          _fm_directC_ithKer <= 30'h0;
        end else begin
          _fm_directC_ithKer <= _fm_directC_ithKer + 30'd32;
        end
      end
      if(_fm_directC_readParam && fm_cmp_bottom_ker) begin
        readProcKer(fd_orig_param, _fm_directC_readParam, _fm_directC_ithKer, _fm_directC_ker);
      end
    end
  end
  // compare
  reg  _fm_directC_cmpKer;
  reg  _fm_directC_checkKerNotPass;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fm_directC_cmpKer          <= 1'b0;
      _fm_directC_checkKerNotPass <= 1'b0;
    end else begin
      _fm_directC_cmpKer <= _fm_rd_param_full;
      if(_fm_directC_cmpKer && fm_cmp_bottom_ker) begin
        _fm_directC_checkKerNotPass = cmpKer(_fm_directC_cmpKer, _fm_directC_ker, _fm_rd_ker);
      end
      if(_fm_directC_checkKerNotPass) begin
        $display("%t: ker_set check failed(in conv.v)", $realtime);
        #100 $finish;
      end
    end
  end 
  // read ker_set}}}
  // read param}}}

  // check conv_op output{{{
//// rising edge of conv_start
//reg  _fm_conv_start_reg;
//reg  _fm_directC_convPass;
//reg [ATOMIC_H*ATOMIC_W*K_H*K_W*DATA_WIDTH-1:0]  _fm_directC_blasRam;
//reg [K_C*K_H*K_W*DATA_WIDTH-1:0]                _fm_directC_blasKer;
//reg [DATA_WIDTH-1:0]                            _fm_directC_maxError;
//initial begin
//  _fm_directC_maxError = 32'h0;
//end
//wire _fm_conv_start_rising_edge;
//assign _fm_conv_start_rising_edge = (!_fm_conv_start_reg) && _fm_conv_start;
//always@(posedge clk) begin
//  _fm_conv_start_reg <= _fm_conv_start;
//  if(_fm_conv_start_rising_edge) begin
//    rearrangeRamData(_fm_conv_start_rising_edge, _fm_conv_bottom, _fm_directC_blasRam);
//    rearrangeKerData(_fm_conv_start_rising_edge, _fm_conv_ker, _fm_directC_blasKer);
//  end
//  if(_fm_conv_valid) begin
//    _fm_directC_convPass = cmpCnnCorr(_fm_directC_blasRam, _fm_directC_blasKer, _fm_conv_op_top_o, _fm_conv_x, _fm_conv_y, _fm_directC_maxError);
//  end
////if(_fm_directC_convPass) begin
////  $display("%t: xPos: %d, yPos: %d, error bit > 11", $realtime, _fm_conv_x, _fm_conv_y);
////end
//end
//wire [DATA_WIDTH-1:0] _fm_blasRam0, _fm_blasRamEnd, _fm_blasRamSecLast;
//assign _fm_blasRam0 = _fm_directC_blasRam[ATOMIC_H*ATOMIC_W*K_H*K_W*DATA_WIDTH-1:ATOMIC_H*ATOMIC_W*K_H*K_W*DATA_WIDTH-32];
//assign _fm_blasRamEnd = _fm_directC_blasRam[31:0];
//assign _fm_blasRamSecLast = _fm_directC_blasRam[63:32];
//wire [DATA_WIDTH-1:0] _fm_ker01, _fm_ker02, _fm_ker03, _fm_ker04, _fm_ker05, _fm_ker06, _fm_ker07, _fm_ker08, _fm_ker09;
//wire [DATA_WIDTH-1:0] _fm_data01, _fm_data02, _fm_data03, _fm_data04, _fm_data05, _fm_data06, _fm_data07, _fm_data08, _fm_data09;
//wire [DATA_WIDTH-1:0] _fm_top01;
//assign _fm_ker01  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 0)-1 : DATA_WIDTH*(K_C*K_H*K_W- 1)];
//assign _fm_ker02  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 1)-1 : DATA_WIDTH*(K_C*K_H*K_W- 2)];
//assign _fm_ker03  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 2)-1 : DATA_WIDTH*(K_C*K_H*K_W- 3)];
//assign _fm_ker04  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 3)-1 : DATA_WIDTH*(K_C*K_H*K_W- 4)];
//assign _fm_ker05  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 4)-1 : DATA_WIDTH*(K_C*K_H*K_W- 5)];
//assign _fm_ker06  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 5)-1 : DATA_WIDTH*(K_C*K_H*K_W- 6)];
//assign _fm_ker07  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 6)-1 : DATA_WIDTH*(K_C*K_H*K_W- 7)];
//assign _fm_ker08  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 7)-1 : DATA_WIDTH*(K_C*K_H*K_W- 8)];
//assign _fm_ker09  = _fm_conv_ker[DATA_WIDTH*(K_C*K_H*K_W- 8)-1 : DATA_WIDTH*(K_C*K_H*K_W- 9)];
//assign _fm_data01 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 0)-1 : DATA_WIDTH*(16*16- 1)];
//assign _fm_data02 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 1)-1 : DATA_WIDTH*(16*16- 2)];
//assign _fm_data03 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 2)-1 : DATA_WIDTH*(16*16- 3)];
//assign _fm_data04 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 0 - 16)-1 : DATA_WIDTH*(16*16- 1 - 16)];
//assign _fm_data05 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 1 - 16)-1 : DATA_WIDTH*(16*16- 2 - 16)];
//assign _fm_data06 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 2 - 16)-1 : DATA_WIDTH*(16*16- 3 - 16)];
//assign _fm_data07 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 0 - 32)-1 : DATA_WIDTH*(16*16- 1 - 32)];
//assign _fm_data08 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 1 - 32)-1 : DATA_WIDTH*(16*16- 2 - 32)];
//assign _fm_data09 = _fm_conv_bottom[DATA_WIDTH*(16*16 - 2 - 32)-1 : DATA_WIDTH*(16*16- 3 - 32)];
//assign _fm_top01  = _fm_conv_op_top_o[DATA_WIDTH*K_C- 1 : DATA_WIDTH*(K_C-1)];

  // compare top result
  reg  _fm_wr_data_top_reg;
  wire _fm_cmp_top_result_en;
  always@(posedge clk) begin
    _fm_wr_data_top_reg <= _fm_wr_data_top;
  end
  assign _fm_cmp_top_result_en = _fm_wr_data_top_reg;
  // }}}
`endif // simulation tasks/directC }}}

  // fsm
  wire _fm_conv_op_busy;
  assign _fm_conv_op_busy = (_fm_conv_busy || (_fm_conv_valid && (!_fm_conv_last_valid)));
  wire _fm_ddr_req;
  always@(posedge clk) begin
    fm_ddr_req <= _fm_ddr_req;
  end
  fsm fsm_control(
    `ifdef sim_ // {{{
    .fsm_decision(_fm_fsm_decision),
    `endif // }}}
    .rst_n(rst_n),
    .clk(clk),
    // ddr req
    .fsm_ddr_req(_fm_ddr_req),
    //
    .fsm_data_ready(fm_data_ready),
    .fsm_start(fm_start),
    .fsm_done(fm_conv_done),

    // pooling
    //   i
    .fsm_pooling_en(fm_pooling_en),
    .fsm_pooling_last_pos(_fm_pooling_last_pos),

    // conv_op
    //   i
    .fsm_conv_start_at_next_clk(_fm_conv_start_at_next_clk),
    .fsm_conv_at_last_pos(_fm_conv_at_last_pos),
    .fsm_conv_busy(_fm_conv_op_busy),
    .fsm_conv_last_valid(_fm_conv_last_valid),
    //   o
    .fsm_conv_start(_fm_conv_start),
  //.fsm_conv_next_ker_full(_fm_conv_next_ker_full), // <-x ker_set valid at next clk, force to convolve to the end
    .fsm_conv_on_patch0(_fm_conv_patch0),
    .fsm_conv_on_patch1(_fm_conv_patch1),
    .fsm_conv_on_ker0(_fm_conv_ker0),
    .fsm_conv_on_ker1(_fm_conv_ker1),
    .fsm_conv_on_first_fm(_fm_conv_on_first_fm),
    .fsm_conv_on_last_fm(_fm_conv_on_last_fm),
    .fsm_conv_cur_ker_num(_fm_conv_ker_num),

    // wr_ddr_op
    //   i
    .fsm_wr_data_done(_fm_wr_data_done),
    .fsm_last_layer(fm_last_layer),
    //   o
    .fsm_wr_data_top(_fm_wr_data_top), // write top data enable
    .fsm_wr_data_sw_on(_fm_wr_data_sw_on), // <-x ddr interface occupied by wr_ddr_data module
    .fsm_wr_data_x_eq_0(_fm_wr_data_x_eq_0),
    .fsm_wr_data_y_eq_0(_fm_wr_data_y_eq_0),
    .fsm_wr_data_x_eq_end(_fm_wr_data_x_eq_end),
    .fsm_wr_data_y_eq_end(_fm_wr_data_y_eq_end),

    // rd_ddr_data
    //   i
    .fsm_rd_data_full(_fm_rd_data_full),
    .fsm_rd_data_bottom_ddr_addr(fm_bottom_ddr_addr),
    .fsm_rd_data_bottom_channels(fm_bottom_channels),
    .fsm_rd_data_fm_width(fm_width),
    .fsm_rd_data_fm_height(fm_height),
    .fsm_rd_data_fm_size(fm_size),
    //   o
    .fsm_rd_data_bottom(_fm_rd_data_bottom),
    .fsm_rd_data_x(_fm_rd_data_x),
    .fsm_rd_data_y(_fm_rd_data_y),
    .fsm_rd_data_x_eq_0(_fm_rd_data_x_eq_zero),
    .fsm_rd_data_y_eq_0(_fm_rd_data_y_eq_zero),
    .fsm_rd_data_x_eq_end(_fm_rd_data_x_eq_end),
    .fsm_rd_data_y_eq_end(_fm_rd_data_y_eq_end),
    .fsm_rd_data_end_of_x(_fm_rd_data_end_of_x),
    .fsm_rd_data_end_of_y(_fm_rd_data_end_of_y),
    .fsm_rd_data_first_fm(_fm_rd_data_first_fm),
    .fsm_rd_data_ith_offset(_fm_rd_data_ith_offset),
    .fsm_rd_data_sw_on(_fm_rd_data_sw_on),
    .fsm_rd_data_patch0(_fm_rd_data_patch0),
    .fsm_rd_data_patch1(_fm_rd_data_patch1),

    // rd_ddr_param
    //   i
    .fsm_rd_param_full(_fm_rd_param_full),
    .fsm_rd_param_ker_ddr_addr(fm_ker_ddr_addr),
    .fsm_rd_param_bias_num(fm_bias_num),
    .fsm_rd_param_bias_offset(fm_bias_offset),
    //   o
    .fsm_rd_param(_fm_rd_param),
    .fsm_rd_param_ker_only(_fm_rd_param_ker_only),
    .fsm_rd_param_addr(_fm_rd_param_addr),
    .fsm_rd_param_sw_on(_fm_rd_param_sw_on),
    .fsm_rd_param_ker0(_fm_rd_param_ker0),
    .fsm_rd_param_ker1(_fm_rd_param_ker1),

    // rd_bram_patch
    //   i
    .fsm_rd_bram_patch_last_valid(_fm_rd_bram_patch_last_valid),
    //   o
    .fsm_rd_bram_patch_en(_fm_rd_bram_patch),
    .fsm_rd_bram_patch_addr(_fm_rd_bram_patch_addr),

    // rd_bram_row
    //   i
    .fsm_rd_bram_row_valid(_fm_rd_bram_row_valid),
    //   o
    .fsm_rd_bram_row_en(_fm_rd_bram_row),
    .fsm_rd_bram_row_addr(_fm_rd_bram_row_addr)
  );

  // instance
  conv_op cnn_conv(
    .conv_rst_n(rst_n),
    .conv_clk(clk),
    //
    .conv_start(_fm_conv_start),
  //.conv_next_ker_valid_at_next_clk(_fm_conv_next_ker_full), // <-x next ker_set is full
    .conv_output_last(_fm_conv_last_valid),
    .conv_first_pos(_fm_conv_start_at_next_clk), // convolution at next clk
    .conv_last_pos(_fm_conv_at_last_pos), // convolution at the last position
    .conv_busy(_fm_conv_busy), // convolution operation busy
    // mem interface
    .conv_rd_data_partial_sum(_fm_conv_op_rd_partial_sum),
    .conv_partial_sum_valid(_fm_conv_op_partial_sum_valid),
    .conv_partial_sum(_fm_conv_op_partial_sum),
    .conv_ker(_fm_conv_ker),
    .conv_bottom(_fm_conv_bottom),
    .conv_top(_fm_conv_op_top_o),
    .conv_output_valid(_fm_conv_valid),
    .conv_to_x(_fm_to_conv_x),
    .conv_to_y(_fm_to_conv_y),
    .conv_x(_fm_conv_x),
    .conv_y(_fm_conv_y)
  );

  // write to ddr
  wire _fm_wr_data_rd_top_buffer;
  wire _fm_wr_on_last_layer;
  wire _fm_wr_last_layer;
  reg  _fm_last_layer;
  always@(posedge clk) begin
    _fm_last_layer <= fm_last_layer;
  end
  assign _fm_wr_last_layer = (_fm_last_layer && _fm_wr_on_last_layer);
//wire _fm_grant_wr_rdy;
//wire _fm_grant_wr_wdf_rdy;
//assign _fm_grant_wr_rdy     = ddr_rdy && fm_ddr_grant;
//assign _fm_grant_wr_wdf_rdy = ddr_wdf_rdy && fm_ddr_grant;
  wr_ddr_data wr_data(
    .clk(clk),
    .rst_n(rst_n),

    .ddr_rdy(ddr_rdy),
    .ddr_wdf_rdy(ddr_wdf_rdy),
    .ddr_wdf_data(ddr_wdf_data),
    .ddr_wdf_mask(ddr_wdf_mask),
    .ddr_wdf_end(ddr_wdf_end),
    .ddr_wdf_wren(ddr_wdf_wren),
    .ddr_addr(_fm_wr_data_ddr_addr),
    .ddr_cmd(_fm_wr_data_ddr_cmd),
    .ddr_en(_fm_wr_data_ddr_en),

    .wr_data_top(_fm_wr_data_top), // write top data enable
    .wr_data_top_addr(fm_top_ddr_addr), // writing address
    .wr_data_top_channels(fm_top_channels), // num of top data channels
    .wr_data_data_i(_fm_conv_top),

    .wr_data_x_eq_0(_fm_wr_data_x_eq_0),
    .wr_data_y_eq_0(_fm_wr_data_y_eq_0),
    .wr_data_x_eq_end(_fm_wr_data_x_eq_end),
    .wr_data_y_eq_end(_fm_wr_data_y_eq_end),
  // -------------------- simulation --------------------{{{
  //.wr_data_x(_fm_wr_data_x), // patch coordinate in the fm, <-XXXXXXXXX substitude by x_eq_0/x_eq_end
  //.wr_data_y(_fm_wr_data_y), // <-XXXXXXXXX substitude by y_eq_0/y_eq_end
  //.wr_data_end_of_x(_fm_wr_data_end_of_x), // end of position, <-XXXXXXXXX substitude by x_eq_0/x_eq_end
  //.wr_data_end_of_y(_fm_wr_data_end_of_y), // <-XXXXXXXXX substitude by y_eq_0/y_eq_end
  // -------------------- simulation --------------------}}}
    .wr_data_pooling_en(fm_pooling_en), // is pooling layer output
    .wr_data_half_bar_size(fm_top_half_bar_size), // size of half bar
    .wr_data_fm_size(fm_top_fm_size),
    .wr_data_data_valid(_fm_top_data_valid), // <-x input port
    .wr_data_rd_top_buffer(_fm_wr_data_rd_top_buffer),
    .wr_data_next_quarter(_fm_wr_data_next_quarter), // <-x input port
    .wr_data_next_channel(_fm_wr_data_next_channel), // current channel finished, writing the last datum to ddr
    .wr_data_done(_fm_wr_data_done), // data writing done
    .wr_data_llayer_i(_fm_wr_llayer_o),   // last
    .wr_data_cur_ker_set(_fm_wr_llayer_ker_set),
    .wr_data_llayer_data_valid(_fm_wr_llayer_valid), // <-x input port
    .wr_data_llayer_valid_first(_fm_wr_llayer_first_pos),
    .wr_data_llayer_valid_last(_fm_wr_llayer_last_pos), // <-x input port
    .wr_data_last_layer(_fm_wr_last_layer), // <-x input port
    .wr_data_llayer_last_data(fm_llayer_last_data),
    .wr_data_bram_we(fm_llayer_bram_we), // <-x output port
    .wr_data_bram_addr(fm_llayer_bram_addr), // <-x output port
    .wr_data_llayer_o(fm_llayer_bram_o) // <-x output port
  );

`ifdef sim_
  // -------------------- simulation --------------------{{{
  wire [31:0] _rd_data01,_rd_data02,_rd_data03,_rd_data04,_rd_data05,_rd_data06,_rd_data07,_rd_data08,
              _rd_data09,_rd_data10,_rd_data11,_rd_data12,_rd_data13,_rd_data14,_rd_data15,_rd_data16;

  assign _rd_data01 = _fm_rd_data_data[511:480]; assign _rd_data02 = _fm_rd_data_data[479:448];
  assign _rd_data03 = _fm_rd_data_data[447:416]; assign _rd_data04 = _fm_rd_data_data[415:384];
  assign _rd_data05 = _fm_rd_data_data[383:352]; assign _rd_data06 = _fm_rd_data_data[351:320];
  assign _rd_data07 = _fm_rd_data_data[319:288]; assign _rd_data08 = _fm_rd_data_data[287:256];
  assign _rd_data09 = _fm_rd_data_data[255:224]; assign _rd_data10 = _fm_rd_data_data[223:192];
  assign _rd_data11 = _fm_rd_data_data[191:160]; assign _rd_data12 = _fm_rd_data_data[159:128];
  assign _rd_data13 = _fm_rd_data_data[127:96];  assign _rd_data14 = _fm_rd_data_data[95:64];
  assign _rd_data15 = _fm_rd_data_data[63:32];   assign _rd_data16 = _fm_rd_data_data[31:0];
  // -------------------- simulation --------------------}}}
`endif

//wire _fm_grant_rd_rdy;
//wire _fm_grant_rd_valid;
//assign _fm_grant_rd_rdy  = ddr_rdy && fm_ddr_grant;
//assign _fm_grant_rd_valid= ddr_rd_data_valid && fm_ddr_grant;
  rd_ddr_data ddr_data(
    .clk(clk),
    .rst_n(rst_n),
    // ddr
    .ddr_rd_data_valid(ddr_rd_data_valid),
    .ddr_rdy(ddr_rdy),
    .ddr_rd_data(ddr_rd_data),
    .ddr_addr(_fm_rd_data_ddr_addr),
    .ddr_cmd(_fm_rd_data_ddr_cmd),
    .ddr_en(_fm_rd_data_ddr_en),
    // FSM
    .rd_data_bottom(_fm_rd_data_bottom),
    .rd_data_bottom_addr(fm_bottom_ddr_addr),
    .rd_data_end_of_x(_fm_rd_data_end_of_x),
    .rd_data_end_of_y(_fm_rd_data_end_of_y),
    .rd_data_x(_fm_rd_data_x),
    .rd_data_y(_fm_rd_data_y),
    .rd_data_first_fm(_fm_rd_data_first_fm),
    .rd_data_bottom_ith_offset(_fm_rd_data_ith_offset),
    .rd_data_bar_offset(fm_1bar_size),
    .rd_data_half_bar_offset(fm_half_bar_size),
    // mem interface
    .rd_data_data(_fm_rd_data_data),
    .rd_data_num_valid(_fm_rd_data_num_valid),
    .rd_data_valid(_fm_rd_data_valid),
    .rd_data_patch_valid_last(_fm_rd_data_patch_valid_last),
    .rd_data_upper_valid_last(_fm_rd_data_patch_upper_valid_last),
    .rd_data_valid_first(_fm_rd_data_valid_first),
    .rd_data_full(_fm_rd_data_full)
  );

`ifdef sim_
  // -------------------- simulation --------------------{{{
  wire [31:0] _rd_param01,_rd_param02,_rd_param03,_rd_param04,_rd_param05,_rd_param06,_rd_param07,_rd_param08,
              _rd_param09,_rd_param10,_rd_param11,_rd_param12,_rd_param13,_rd_param14,_rd_param15,_rd_param16;

  assign _rd_param01 = _fm_rd_param_data[511:480]; assign _rd_param02 = _fm_rd_param_data[479:448];
  assign _rd_param03 = _fm_rd_param_data[447:416]; assign _rd_param04 = _fm_rd_param_data[415:384];
  assign _rd_param05 = _fm_rd_param_data[383:352]; assign _rd_param06 = _fm_rd_param_data[351:320];
  assign _rd_param07 = _fm_rd_param_data[319:288]; assign _rd_param08 = _fm_rd_param_data[287:256];
  assign _rd_param09 = _fm_rd_param_data[255:224]; assign _rd_param10 = _fm_rd_param_data[223:192];
  assign _rd_param11 = _fm_rd_param_data[191:160]; assign _rd_param12 = _fm_rd_param_data[159:128];
  assign _rd_param13 = _fm_rd_param_data[127:96];  assign _rd_param14 = _fm_rd_param_data[95:64];
  assign _rd_param15 = _fm_rd_param_data[63:32];   assign _rd_param16 = _fm_rd_param_data[31:0];
  // -------------------- simulation --------------------}}}
`endif

  assign _fm_rd_param_ker_valid = (_fm_rd_param_valid && (!_fm_rd_param_bias_valid));
//wire _fm_grant_param_rdy;
//wire _fm_grant_param_valid;
//assign _fm_grant_param_rdy    = ddr_rdy && fm_ddr_grant;
//assign _fm_grant_param_valid  = ddr_rd_data_valid && fm_ddr_grant;
  rd_ddr_param ddr_param(
    .clk(clk),
    .rst_n(rst_n),
    // ddr
    .ddr_rdy(ddr_rdy),
    .ddr_rd_data_valid(ddr_rd_data_valid),
    .ddr_rd_data(ddr_rd_data), // ddr_rd_data was connected to mem
    .ddr_addr(_fm_rd_param_ddr_addr),
    .ddr_cmd(_fm_rd_param_ddr_cmd),
    .ddr_en(_fm_rd_param_ddr_en),
    // FSM
    .rd_param(_fm_rd_param),
    .rd_param_ker_only(_fm_rd_param_ker_only),
    .rd_param_bias_burst_num(fm_bias_ddr_burst_num),
    .rd_param_addr(_fm_rd_param_addr),
    // mem interface
    .rd_param_valid(_fm_rd_param_valid),
    .rd_param_bias_valid(_fm_rd_param_bias_valid),
    .rd_param_bias_valid_last(_fm_rd_param_bias_valid_last),
    .rd_param_data(_fm_rd_param_data), // <-x added on Oct.31, connect to mem
    .rd_param_full(_fm_rd_param_full)
  );
  //
  rd_bram_patch bram_patch(
    .clk(clk),
    .rst_n(rst_n),
    .rd_data_bram_patch(_fm_rd_bram_patch),
    .rd_data_bram_patch_addr(_fm_rd_bram_patch_addr),
    // mem interface
    .rd_data_bram_patch_enb(_fm_rd_bram_patch_enb),   // enable port b
    .rd_data_bram_patch_valid(_fm_rd_bram_patch_valid), // data on port b is valid
    .rd_data_bram_patch_first(_fm_rd_bram_patch_first_valid),
    .rd_data_bram_patch_last(_fm_rd_bram_patch_last_valid),  // last valid data
    .rd_data_bram_patch_addrb(_fm_rd_bram_patch_addrb)  // read address
  );
  rd_bram_row bram_row(
    .clk(clk),
    .rst_n(rst_n),
    .rd_data_bram_row(_fm_rd_bram_row),
    .rd_data_bram_row_addr(_fm_rd_bram_row_addr),
    // mem interface
    .rd_data_bram_row_enb(_fm_rd_bram_row_enb),   // enable port b
    .rd_data_bram_row_valid(_fm_rd_bram_row_valid), // data on port b is valid
  //.rd_data_bram_row_last(_fm_rd_bram_row_valid),  // last valid data
    .rd_data_bram_row_addrb(_fm_rd_bram_row_addrb)  // read address
  );
//// memory
//assign _fm_rd_data_x_eq_zero= (_fm_rd_data_x == 9'h0);
//assign _fm_rd_data_x_eq_end = (_fm_rd_data_x == _fm_rd_data_end_of_x);
//assign _fm_rd_data_y_eq_zero= (_fm_rd_data_y == 9'h0);
//assign _fm_rd_data_y_eq_end = (_fm_rd_data_y == _fm_rd_data_end_of_y);
  mem_top mem(
  `ifdef sim_
  // -------------------- simulation --------------------{{{
    .mem_top_cmp_result_en(_fm_cmp_top_result_en),
    .mem_top_rd_proc_ram(_fm_rd_proc_ram),
    .mem_top_rd_ker(_fm_rd_ker),
    .mem_top_rd_bias(_fm_rd_bias),
    .mem_top_cmp_top(fm_cmp_top),
  // -------------------- simulation --------------------}}}
  `endif
    .clk(clk),
    .rst_n(rst_n),
    // conv_op
    .mem_top_ker(_fm_conv_ker),
    .mem_top_bottom(_fm_conv_bottom),
    .mem_top_data(_fm_conv_top), // top data to write to ddr
    .mem_top_partial_sum(_fm_conv_op_partial_sum),
    .mem_top_conv_data_i(_fm_conv_op_top_o), // conv_op module output
    .mem_top_rd_partial_sum(_fm_conv_op_rd_partial_sum), // from conv_op
    .mem_top_partial_sum_valid(_fm_conv_op_partial_sum_valid), // connect to conv_op
    .mem_top_conv_valid(_fm_conv_valid), // convolution data valid
    .mem_top_conv_x(_fm_conv_x), // output x position
    .mem_top_conv_y(_fm_conv_y), // output y position
    .mem_top_conv_to_x(_fm_to_conv_x),
    .mem_top_conv_to_y(_fm_to_conv_y),
    .mem_top_conv_on_first_fm(_fm_conv_on_first_fm), // convolve on first fm
    .mem_top_conv_cur_ker_set(_fm_conv_ker_num), // current convolutin kernel set
    .mem_top_conv_patch0(_fm_conv_patch0),
    .mem_top_conv_patch1(_fm_conv_patch1),
    .mem_top_conv_ker0(_fm_conv_ker0),
    .mem_top_conv_ker1(_fm_conv_ker1),
    // relu
    .mem_top_relu_en(fm_relu_en), // enable ReLU activation function
    // pooling
    .mem_top_conv_on_last_fm(_fm_conv_on_last_fm), // convolve on first fm
    .mem_top_pooling_en(fm_pooling_en), // pooling
    .mem_top_pooling_last_pos(_fm_pooling_last_pos), // output port
    // wr_ddr_op
    .mem_top_wr_ddr_en(_fm_wr_data_top),
    .mem_top_wr_rd_top_buffer(_fm_wr_data_rd_top_buffer),
    .mem_top_wr_next_channel(_fm_wr_data_next_channel), // <-x from wr_ddr_op module
    .mem_top_wr_next_quarter(_fm_wr_data_next_quarter), // <-x from wr_ddr_op module
    .mem_top_wr_done(_fm_wr_data_done), // <-x from wr_ddr_op module
    .mem_top_wr_data_valid(_fm_top_data_valid), // <-x to wr_ddr_op module
    // last layer
    .mem_top_last_layer(_fm_last_layer),
    .mem_top_last_layer_on(_fm_wr_on_last_layer),
    .mem_top_last_layer_o(_fm_wr_llayer_o),
    .mem_top_last_layer_valid(_fm_wr_llayer_valid),
    .mem_top_last_layer_last_pos(_fm_wr_llayer_last_pos),
    .mem_top_last_layer_first_pos(_fm_wr_llayer_first_pos),
    .mem_top_last_layer_ker_set(_fm_wr_llayer_ker_set),
    // rd_data
    .mem_top_rd_ddr_data_first_fm(_fm_rd_data_first_fm),
    .mem_top_rd_ddr_data_valid(_fm_rd_data_valid),
    .mem_top_rd_ddr_data_num_valid(_fm_rd_data_num_valid),
    .mem_top_rd_ddr_data_x_eq_zero(_fm_rd_data_x_eq_zero),
    .mem_top_rd_ddr_data_x_eq_end(_fm_rd_data_x_eq_end),
    .mem_top_rd_ddr_data_y_eq_zero(_fm_rd_data_y_eq_zero),
    .mem_top_rd_ddr_data_y_eq_end(_fm_rd_data_y_eq_end),
    .mem_top_rd_ddr_data_valid_first(_fm_rd_data_valid_first),
    .mem_top_rd_ddr_data_valid_last(_fm_rd_data_full),
    .mem_top_rd_ddr_data_patch_last(_fm_rd_data_patch_valid_last),
    .mem_top_rd_ddr_data_upper_valid_last(_fm_rd_data_patch_upper_valid_last),
    .mem_top_rd_ddr_data_i(_fm_rd_data_data),
    .mem_top_rd_ddr_data_patch0(_fm_rd_data_patch0),
    .mem_top_rd_ddr_data_patch1(_fm_rd_data_patch1),
    // rd_ker
    .mem_top_rd_ddr_param_i(_fm_rd_param_data),
    .mem_top_rd_ddr_ker_valid(_fm_rd_param_ker_valid),
    .mem_top_rd_ddr_ker_valid_last(_fm_rd_param_full),
    .mem_top_rd_ddr_ker_ker0(_fm_rd_param_ker0),
    .mem_top_rd_ddr_ker_ker1(_fm_rd_param_ker1),
    // rd_bias
    .mem_top_rd_ddr_bias_valid(_fm_rd_param_bias_valid),
    .mem_top_rd_ddr_bias_valid_last(_fm_rd_param_bias_valid_last),
    // rd_bram_patch
    .mem_top_rd_bram_patch_enb(_fm_rd_bram_patch_enb),
    .mem_top_rd_bram_patch_addrb(_fm_rd_bram_patch_addrb),
    .mem_top_rd_bram_patch_valid(_fm_rd_bram_patch_valid),
    .mem_top_rd_bram_patch_first(_fm_rd_bram_patch_first_valid),
    .mem_top_rd_bram_patch_last(_fm_rd_bram_patch_last_valid),
    // rd_bram_row
    .mem_top_rd_bram_row_enb(_fm_rd_bram_row_enb),
    .mem_top_rd_bram_row_addrb(_fm_rd_bram_row_addrb),
    .mem_top_rd_bram_row_valid(_fm_rd_bram_row_valid)
  );

endmodule
