// ---------------------------------------------------
// File       : vgg_conv.v
//
// Description: top module of (modified) vgg16 conv. layers
//
// Version    : 1.1
// ---------------------------------------------------

//`define sim_
module vgg_conv #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10
    ) (
    input  wire           clk,
    input  wire           rst_n,
    // ddr interface
    output wire           vgg_conv_req,
    input  wire           ddr_rd_data_valid,
    input  wire           ddr_rdy,
    input  wire           ddr_wdf_rdy,
    input  wire [511:0]   ddr_rd_data,
    output wire [29:0]    ddr_addr,
    output wire [2:0]     ddr_cmd,
    output wire           ddr_en,
    output wire [511:0]   ddr_wdf_data,
    output wire [63:0]    ddr_wdf_mask, // stuck at 64'b1
    output wire           ddr_wdf_end,  // stuck at 1'b1
    output wire           ddr_wdf_wren,
    // CNN information
    input  wire [29:0]    vgg_conv_image_addr, // image data address
    input  wire [29:0]    vgg_conv_fm_addr1, // input fm data address
    input  wire [29:0]    vgg_conv_fm_addr2,    // top fm data address
    input  wire [29:0]    vgg_conv_ker_addr,   // kernel parameter data address
    input  wire           vgg_conv_data_ready, // image data and kernel parameters are loaded
    input  wire           vgg_conv_start, // start convolution operation
    output reg            vgg_conv_end, // end of convolution operation
    // last layer output, write to fc bram buffer
    input  wire           vgg_conv_fc_input_buffer_ready,
    (*mark_debug="TRUE"*)output reg            vgg_conv_last_data,
    (*mark_debug="TRUE"*)output wire           vgg_conv_bram_we, // enable writing to bram
    (*mark_debug="TRUE"*)output wire [9:0]     vgg_conv_bram_addr, // maximum 49*16=784
    output wire [32*(EXPONENT+MANTISSA+1)-1:0]  vgg_conv_llayer_o   // last layer pooling data
  );

  (*mark_debug="TRUE"*)wire [(EXPONENT+MANTISSA+1)-1:0]     _data_from_pe_array0;
  assign _data_from_pe_array0 = vgg_conv_llayer_o[(EXPONENT+MANTISSA+1)*(32-1-0+1)-1:(EXPONENT+MANTISSA+1)*(32-1-0)];
  // trigger at vgg_conv_start rising edge
  reg  _vgg_conv_trigger;
  reg  _vgg_conv_start_reg;
  wire _vgg_conv_start_rising_edge;

  always@(posedge clk) begin
    _vgg_conv_start_reg <= vgg_conv_start;
  end
  assign _vgg_conv_start_rising_edge = (!_vgg_conv_start_reg) && vgg_conv_start;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _vgg_conv_trigger <= 1'b0;
    end else begin
      if(_vgg_conv_start_rising_edge && vgg_conv_data_ready) begin
        _vgg_conv_trigger <= 1'b1;
      end else begin
        _vgg_conv_trigger <= 1'b0;
      end
    end
  end

  // layer index
  (*mark_debug="TRUE"*)reg [4:0] _vgg_conv_layer_index;
  (*mark_debug="TRUE"*)wire      _vgg_layer_conv_done;

  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _vgg_conv_layer_index <= 5'd0; // <-xxxxxxxxxxxxxxxx
    end else begin
      `ifndef sim_
      if(_vgg_conv_trigger) begin       // <-xxxxxxxxxxxxxxxx
        _vgg_conv_layer_index <= 5'd0;  // <-xxxxxxxxxxxxxxxx
      end else begin                    // <-xxxxxxxxxxxxxxxx
      `endif
        if(_vgg_layer_conv_done) begin
          `ifdef sim_
          $display("* %t: _vgg_layer_conv_done, at conv/vgg_conv.v", $realtime);
          $display("* %t: _vgg_layer_conv_done, at conv/vgg_conv.v", $realtime);
          $display("* %t: _vgg_layer_conv_done, at conv/vgg_conv.v", $realtime);
          `endif
          if(_vgg_conv_layer_index==5'd12) begin
            _vgg_conv_layer_index <= 5'd0;
          end else begin
            _vgg_conv_layer_index <= _vgg_conv_layer_index + 5'd1;
          end
        end
      `ifndef sim_
      end                               // <-xxxxxxxxxxxxxxxx
      `endif
    end
  end

  // data address
  reg  [29:0] _vgg_layer_bottom_addr;
  reg  [29:0] _vgg_layer_top_addr;

  always@(_vgg_conv_layer_index or vgg_conv_image_addr or
          vgg_conv_fm_addr1 or vgg_conv_fm_addr2) begin
    if(_vgg_conv_layer_index == 5'd0) begin
      _vgg_layer_bottom_addr = vgg_conv_image_addr;
      _vgg_layer_top_addr    = vgg_conv_fm_addr1;
    end else begin
      if(_vgg_conv_layer_index[0] == 1'b1) begin
        _vgg_layer_bottom_addr = vgg_conv_fm_addr1;
        _vgg_layer_top_addr    = vgg_conv_fm_addr2;
      end else begin
        _vgg_layer_bottom_addr = vgg_conv_fm_addr2;
        _vgg_layer_top_addr    = vgg_conv_fm_addr1;
      end
    end
  end

  // conv. end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      vgg_conv_end <= 1'b0;
    end else begin
      if(_vgg_conv_trigger) begin
        vgg_conv_end <= 1'b0;
      end else begin
        if(_vgg_conv_layer_index==5'd12 && _vgg_layer_conv_done) begin // last layer, conv. done
          vgg_conv_end <= 1'b1;
        end
      end
    end
  end

  // layer configuration
  reg         _vgg_layer_relu_en;
  reg         _vgg_layer_pooling_en;
  reg         _vgg_layer_last_layer;
  reg [9:0]   _vgg_layer_bias_num;
  reg [5:0]   _vgg_layer_bias_burst_num;
  reg [8:0]   _vgg_layer_bias_offset;
  reg [29:0]  _vgg_layer_ker_addr;
  // bottom
  reg [8:0]   _vgg_layer_bottom_width;
  reg [8:0]   _vgg_layer_bottom_height;
  reg [9:0]   _vgg_layer_bottom_channels;
  reg [29:0]  _vgg_layer_bottom_fm_size;
  reg [29:0]  _vgg_layer_bottom_1bar_size;
  reg [29:0]  _vgg_layer_bottom_half_bar_size;
  // top
  reg [29:0]  _vgg_layer_top_fm_size;
  reg [29:0]  _vgg_layer_top_half_bar_size;
  reg [9:0]   _vgg_layer_top_channels;
  `ifdef sim_
  reg _vgg_layer_cmp_top;
  reg _vgg_layer_cmp_bottom_ker;
  `endif

  always@(_vgg_conv_layer_index or vgg_conv_ker_addr) begin
    // layer relative
    _vgg_layer_relu_en    = 1'b0;
    _vgg_layer_pooling_en = 1'b0;
    _vgg_layer_last_layer = 1'b0;
    // ker_set
    _vgg_layer_bias_num   = 10'd0;
    _vgg_layer_bias_burst_num = 6'd0;
    _vgg_layer_bias_offset    = 9'd0;
    _vgg_layer_ker_addr       = 30'd0;
    // bottom
    _vgg_layer_bottom_width   = 9'd0;
    _vgg_layer_bottom_height  = 9'd0;
    _vgg_layer_bottom_channels= 10'd0;
    _vgg_layer_bottom_fm_size = 30'd0;
    _vgg_layer_bottom_1bar_size = 30'd0;
    _vgg_layer_bottom_half_bar_size = 30'd0;
    // top
    _vgg_layer_top_fm_size    = 30'd0;
    _vgg_layer_top_half_bar_size= 30'd0;
    _vgg_layer_top_channels   = 10'd0;
    `ifdef sim_ // simulation {{{
    _vgg_layer_cmp_top        = 1'b0;
    _vgg_layer_cmp_bottom_ker = 1'b0;
    `endif // }}}
    case(_vgg_conv_layer_index)
      5'd0: begin // conv1_1
        // layer relative
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
      //_vgg_data_ready <- _vgg_conv_start
      //_vgg_start // <- _vgg_conv_start
        // ker_set
        _vgg_layer_bias_num   = 10'd64; // number of bias
        _vgg_layer_bias_burst_num = 6'd2; // num_of_bias * float_data_width / ddr_data_width / burst_length
        _vgg_layer_bias_offset    = 9'd16; // num_of_bias * float_data_width / ddr_data_width
        _vgg_layer_ker_addr       = 30'd16 + vgg_conv_ker_addr; // <-x
        // bottom
        _vgg_layer_bottom_width   = 9'd16; // fm_width / atomic_width
        _vgg_layer_bottom_height  = 9'd16; // fm_height / atomic_height
        _vgg_layer_bottom_channels= 10'd3;
        _vgg_layer_bottom_fm_size = 30'd16384; // 64*4 * bottom_width * bottom_height * float_data_width / ddr_data_width
        _vgg_layer_bottom_1bar_size = 30'd1024; // 64*4 * bottom_width * float_data_width / ddr_data_width
        _vgg_layer_bottom_half_bar_size = 30'd512; // 64*2 * bottom_width * float_data_width / ddr_data_width
      //_vgg_bottom_addr // <- _vgg_conv_bottom_addr
        // top
        _vgg_layer_top_fm_size  = 30'd16384; // 64*4 * top_width * top_height * float_data_width / ddr_data_width
        _vgg_layer_top_half_bar_size= 30'd512; // 64*2 * top_width * top_height * float_data_width / ddr_data_width
        _vgg_layer_top_channels = 10'd64;
        `ifdef sim_
        $display("* %t: at conv1_1", $realtime);
        `endif
      //_vgg_top_addr // <- _vgg_conv_top_addr
      end
      5'd1: begin // conv1_2
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b1;
        // ker_set
        _vgg_layer_bias_num   = 10'd64;
        _vgg_layer_bias_burst_num = 6'd2;
        _vgg_layer_bias_offset    = 9'd16;
        _vgg_layer_ker_addr       = 30'd16 + vgg_conv_ker_addr + 30'd16+30'd432; // <-x conv1_1 param
        // bottom
        _vgg_layer_bottom_width   = 9'd16;
        _vgg_layer_bottom_height  = 9'd16;
        _vgg_layer_bottom_channels= 10'd64;
        _vgg_layer_bottom_fm_size = 30'd16384;
        _vgg_layer_bottom_1bar_size = 30'd1024;
        _vgg_layer_bottom_half_bar_size = 30'd512;
        // top
        _vgg_layer_top_fm_size    = 30'd4096;
        _vgg_layer_top_half_bar_size= 30'd256;
        _vgg_layer_top_channels   = 10'd64;
        `ifdef sim_
        $display("* %t: at conv1_2", $realtime);
        `endif
      end
      5'd2: begin // conv2_1
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd128;
        _vgg_layer_bias_burst_num = 6'd4;
        _vgg_layer_bias_offset    = 9'd32;
        _vgg_layer_ker_addr       = 30'd32 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216; // <-x conv1_1 + conv1_2
        // bottom
        _vgg_layer_bottom_width   = 9'd8;
        _vgg_layer_bottom_height  = 9'd8;
        _vgg_layer_bottom_channels= 10'd64;
        _vgg_layer_bottom_fm_size = 30'd4096;
        _vgg_layer_bottom_1bar_size = 30'd512;
        _vgg_layer_bottom_half_bar_size = 30'd256;
        // top
        _vgg_layer_top_fm_size    = 30'd4096;
        _vgg_layer_top_half_bar_size= 30'd256;
        _vgg_layer_top_channels   = 10'd128;
        `ifdef sim_
        $display("* %t: at conv2_1", $realtime);
        `endif
      end
      5'd3: begin // conv2_2
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b1;
        // ker_set
        _vgg_layer_bias_num   = 10'd128;
        _vgg_layer_bias_burst_num = 6'd4;
        _vgg_layer_bias_offset    = 9'd32;
        _vgg_layer_ker_addr       = 30'd32 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432; // <-x conv1_1 + conv1_2
        // bottom
        _vgg_layer_bottom_width   = 9'd8;
        _vgg_layer_bottom_height  = 9'd8;
        _vgg_layer_bottom_channels= 10'd128;
        _vgg_layer_bottom_fm_size = 30'd4096;
        _vgg_layer_bottom_1bar_size = 30'd512;
        _vgg_layer_bottom_half_bar_size = 30'd256;
        // top
        _vgg_layer_top_fm_size    = 30'd1024;
        _vgg_layer_top_half_bar_size= 30'd128;
        _vgg_layer_top_channels   = 10'd128;
        `ifdef sim_
        $display("* %t: at conv2_2", $realtime);
        `endif
      end
      5'd4: begin // conv3_1
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd256;
        _vgg_layer_bias_burst_num = 6'd8;
        _vgg_layer_bias_offset    = 9'd64;
        _vgg_layer_ker_addr       = 30'd64 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864;
        // bottom
        _vgg_layer_bottom_width   = 9'd4;
        _vgg_layer_bottom_height  = 9'd4;
        _vgg_layer_bottom_channels= 10'd128;
        _vgg_layer_bottom_fm_size = 30'd1024;
        _vgg_layer_bottom_1bar_size = 30'd256;
        _vgg_layer_bottom_half_bar_size = 30'd128;
        // top
        _vgg_layer_top_fm_size    = 30'd1024;
        _vgg_layer_top_half_bar_size= 30'd128;
        _vgg_layer_top_channels   = 10'd256;
        `ifdef sim_
        $display("* %t: at conv3_1", $realtime);
        `endif
      end
      5'd5: begin // conv3_2
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd256;
        _vgg_layer_bias_burst_num = 6'd8;
        _vgg_layer_bias_offset    = 9'd64;
        _vgg_layer_ker_addr       = 30'd64 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728;
        // bottom
        _vgg_layer_bottom_width   = 9'd4;
        _vgg_layer_bottom_height  = 9'd4;
        _vgg_layer_bottom_channels= 10'd256;
        _vgg_layer_bottom_fm_size = 30'd1024;
        _vgg_layer_bottom_1bar_size = 30'd256;
        _vgg_layer_bottom_half_bar_size = 30'd128;
        // top
        _vgg_layer_top_fm_size    = 30'd1024;
        _vgg_layer_top_half_bar_size= 30'd128;
        _vgg_layer_top_channels   = 10'd256;
        `ifdef sim_
        $display("* %t: at conv3_2", $realtime);
        `endif
      end
      5'd6: begin // conv3_3
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b1;
        // ker_set
        _vgg_layer_bias_num   = 10'd256;
        _vgg_layer_bias_burst_num = 6'd8;
        _vgg_layer_bias_offset    = 9'd64;
        _vgg_layer_ker_addr       = 30'd64 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456;
        // bottom
        _vgg_layer_bottom_width   = 9'd4;
        _vgg_layer_bottom_height  = 9'd4;
        _vgg_layer_bottom_channels= 10'd256;
        _vgg_layer_bottom_fm_size = 30'd1024;
        _vgg_layer_bottom_1bar_size = 30'd256;
        _vgg_layer_bottom_half_bar_size = 30'd128;
        // top
        _vgg_layer_top_fm_size    = 30'd256;
        _vgg_layer_top_half_bar_size= 30'd64;
        _vgg_layer_top_channels   = 10'd256;
        `ifdef sim_
        $display("* %t: at conv3_3", $realtime);
        `endif
      end
      5'd7: begin // conv4_1
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd512;
        _vgg_layer_bias_burst_num = 6'd16;
        _vgg_layer_bias_offset    = 9'd128;
        _vgg_layer_ker_addr       = 30'd128 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456 + 30'd64+30'd147456;
        // bottom
        _vgg_layer_bottom_width   = 9'd2;
        _vgg_layer_bottom_height  = 9'd2;
        _vgg_layer_bottom_channels= 10'd256;
        _vgg_layer_bottom_fm_size = 30'd256;
        _vgg_layer_bottom_1bar_size = 30'd128;
        _vgg_layer_bottom_half_bar_size = 30'd64;
        // top
        _vgg_layer_top_fm_size    = 30'd256;
        _vgg_layer_top_half_bar_size= 30'd64;
        _vgg_layer_top_channels   = 10'd512;
        `ifdef sim_
        $display("* %t: at conv4_1", $realtime);
        `endif
      end
      5'd8: begin // conv4_2
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd512;
        _vgg_layer_bias_burst_num = 6'd16;
        _vgg_layer_bias_offset    = 9'd128;
        _vgg_layer_ker_addr       = 30'd128 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456 + 30'd64+30'd147456 + 30'd128+30'd294912;
        // bottom
        _vgg_layer_bottom_width   = 9'd2;
        _vgg_layer_bottom_height  = 9'd2;
        _vgg_layer_bottom_channels= 10'd512;
        _vgg_layer_bottom_fm_size = 30'd256;
        _vgg_layer_bottom_1bar_size = 30'd128;
        _vgg_layer_bottom_half_bar_size = 30'd64;
        // top
        _vgg_layer_top_fm_size    = 30'd256;
        _vgg_layer_top_half_bar_size= 30'd64;
        _vgg_layer_top_channels   = 10'd512;
        `ifdef sim_
        $display("* %t: at conv4_2", $realtime);
        `endif
      end
      5'd9: begin // conv4_3
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b1;
        // ker_set
        _vgg_layer_bias_num   = 10'd512;
        _vgg_layer_bias_burst_num = 6'd16;
        _vgg_layer_bias_offset    = 9'd128;
        _vgg_layer_ker_addr       = 30'd128 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456 + 30'd64+30'd147456 + 30'd128+30'd294912 +
                                      30'd128+30'd589824;
        // bottom
        _vgg_layer_bottom_width   = 9'd2;
        _vgg_layer_bottom_height  = 9'd2;
        _vgg_layer_bottom_channels= 10'd512;
        _vgg_layer_bottom_fm_size = 30'd256;
        _vgg_layer_bottom_1bar_size = 30'd128;
        _vgg_layer_bottom_half_bar_size = 30'd64;
        // top
        _vgg_layer_top_fm_size    = 30'd64;
        _vgg_layer_top_half_bar_size= 30'd32;
        _vgg_layer_top_channels   = 10'd512;
        `ifdef sim_
        $display("* %t: at conv4_3", $realtime);
        `endif
      end
      5'd10: begin // conv5_1
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd512;
        _vgg_layer_bias_burst_num = 6'd16;
        _vgg_layer_bias_offset    = 9'd128;
        _vgg_layer_ker_addr       = 30'd128 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456 + 30'd64+30'd147456 + 30'd128+30'd294912 +
                                      30'd128+30'd589824 + 30'd128+30'd589824;
        // bottom
        _vgg_layer_bottom_width   = 9'd1;
        _vgg_layer_bottom_height  = 9'd1;
        _vgg_layer_bottom_channels= 10'd512;
        _vgg_layer_bottom_fm_size = 30'd64;
        _vgg_layer_bottom_1bar_size = 30'd64;
        _vgg_layer_bottom_half_bar_size = 30'd32;
        // top
        _vgg_layer_top_fm_size    = 30'd64;
        _vgg_layer_top_half_bar_size= 30'd32;
        _vgg_layer_top_channels   = 10'd512;
        `ifdef sim_
        $display("* %t: at conv5_1", $realtime);
        `endif
      end
      5'd11: begin // conv5_2
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b0;
        // ker_set
        _vgg_layer_bias_num   = 10'd512;
        _vgg_layer_bias_burst_num = 6'd16;
        _vgg_layer_bias_offset    = 9'd128;
        _vgg_layer_ker_addr       = 30'd128 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456 + 30'd64+30'd147456 + 30'd128+30'd294912 +
                                      30'd128+30'd589824 + 30'd128+30'd589824 + 30'd128+30'd589824;
        // bottom
        _vgg_layer_bottom_width   = 9'd1;
        _vgg_layer_bottom_height  = 9'd1;
        _vgg_layer_bottom_channels= 10'd512;
        _vgg_layer_bottom_fm_size = 30'd64;
        _vgg_layer_bottom_1bar_size = 30'd64;
        _vgg_layer_bottom_half_bar_size = 30'd32;
        // top
        _vgg_layer_top_fm_size    = 30'd64;
        _vgg_layer_top_half_bar_size= 30'd32;
        _vgg_layer_top_channels   = 10'd512;
        `ifdef sim_
        $display("* %t: at conv5_2", $realtime);
        `endif
        `ifdef sim_
        #100 $finish;
        `endif
      end
      5'd12: begin // conv5_3
        _vgg_layer_relu_en    = 1'b1;
        _vgg_layer_pooling_en = 1'b1;
        _vgg_layer_last_layer = 1'b1;
        // ker_set
        _vgg_layer_bias_num   = 10'd512;
        _vgg_layer_bias_burst_num = 6'd16;
        _vgg_layer_bias_offset    = 9'd128;
        _vgg_layer_ker_addr       = 30'd128 + vgg_conv_ker_addr + 30'd16+30'd432 + 30'd16+30'd9216 +
                                      30'd32+30'd18432 + 30'd32+30'd36864 + 30'd64+30'd73728 +
                                      30'd64+30'd147456 + 30'd64+30'd147456 + 30'd128+30'd294912 +
                                      30'd128+30'd589824 + 30'd128+30'd589824 + 30'd128+30'd589824 +
                                      30'd128+30'd589824;
        // bottom
        _vgg_layer_bottom_width   = 9'd1;
        _vgg_layer_bottom_height  = 9'd1;
        _vgg_layer_bottom_channels= 10'd512;
        _vgg_layer_bottom_fm_size = 30'd64;
        _vgg_layer_bottom_1bar_size = 30'd64;
        _vgg_layer_bottom_half_bar_size = 30'd32;
        // top
        _vgg_layer_top_fm_size    = 30'd16;
        _vgg_layer_top_half_bar_size= 30'd16;
        _vgg_layer_top_channels   = 10'd512;
        `ifdef sim_
        $display("* %t: at conv5_3", $realtime);
        `endif
    `ifdef sim_ // simulation {{{
        _vgg_layer_cmp_top        = 1'b1;
        _vgg_layer_cmp_bottom_ker = 1'b1;
    `endif // }}}
      end
    endcase
  end

  // input to conv_layer

  reg         _vgg_conv_start;
  reg         _vgg_conv_relu_en;
  reg         _vgg_conv_pooling_en;
  reg         _vgg_conv_last_layer;
  reg [9:0]   _vgg_conv_bias_num;
  reg [5:0]   _vgg_conv_bias_burst_num;
  reg [8:0]   _vgg_conv_bias_offset;
  reg [29:0]  _vgg_conv_ker_addr;
  // bottom
  reg [8:0]   _vgg_conv_bottom_width;
  reg [8:0]   _vgg_conv_bottom_height;
  reg [9:0]   _vgg_conv_bottom_channels;
  reg [29:0]  _vgg_conv_bottom_fm_size;
  reg [29:0]  _vgg_conv_bottom_1bar_size;
  reg [29:0]  _vgg_conv_bottom_half_bar_size;
  // top
  reg [29:0]  _vgg_conv_top_fm_size;
  reg [29:0]  _vgg_conv_top_half_bar_size;
  reg [9:0]   _vgg_conv_top_channels;
  reg [29:0]  _vgg_conv_bottom_addr;
  reg [29:0]  _vgg_conv_top_addr;
  `ifdef sim_
  reg         _vgg_conv_cmp_top;
  reg         _vgg_conv_cmp_bottom_ker;
  `endif

  reg   _vgg_conv_trigger_reg;    // first layer
  reg   _vgg_layer_conv_done_reg; // current layer done
  // wait fc input bram buffer valid at last layer
  reg   _vgg_conv_wait_last_layer; // wait
  reg   _vgg_conv_start_last_layer;
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _vgg_conv_wait_last_layer   <= 1'd0;
      _vgg_conv_start_last_layer  <= 1'd0;
    end else begin
      if(_vgg_layer_conv_done_reg && _vgg_layer_last_layer) begin // last layer
        _vgg_conv_wait_last_layer <= 1'b1;
      end else if(_vgg_conv_start==1'b1) begin // last layer conv. started
        _vgg_conv_wait_last_layer <= 1'b0;
      end
      //
      if(_vgg_conv_wait_last_layer && vgg_conv_fc_input_buffer_ready) begin
        _vgg_conv_start_last_layer <= 1'd1;
      end else if(_vgg_conv_start_last_layer) begin
        _vgg_conv_start_last_layer <= 1'd0;
      end
    end
  end
  // current layer convolution start
  always@(posedge clk) begin
    _vgg_conv_trigger_reg     <= _vgg_conv_trigger;
    _vgg_layer_conv_done_reg  <= _vgg_layer_conv_done;
  end
  always@(posedge clk) begin
    if(_vgg_conv_trigger_reg || _vgg_layer_conv_done_reg) begin
      _vgg_conv_relu_en               <= _vgg_layer_relu_en;
      _vgg_conv_pooling_en            <= _vgg_layer_pooling_en;
      _vgg_conv_last_layer            <= _vgg_layer_last_layer;

      _vgg_conv_bias_num              <= _vgg_layer_bias_num;
      _vgg_conv_bias_burst_num        <= _vgg_layer_bias_burst_num;
      _vgg_conv_bias_offset           <= _vgg_layer_bias_offset;
      _vgg_conv_ker_addr              <= _vgg_layer_ker_addr;

      _vgg_conv_bottom_width          <= _vgg_layer_bottom_width;
      _vgg_conv_bottom_height         <= _vgg_layer_bottom_height;
      _vgg_conv_bottom_channels       <= _vgg_layer_bottom_channels;
      _vgg_conv_bottom_fm_size        <= _vgg_layer_bottom_fm_size;
      _vgg_conv_bottom_1bar_size      <= _vgg_layer_bottom_1bar_size;
      _vgg_conv_bottom_half_bar_size  <= _vgg_layer_bottom_half_bar_size;

      _vgg_conv_top_fm_size           <= _vgg_layer_top_fm_size;
      _vgg_conv_top_half_bar_size     <= _vgg_layer_top_half_bar_size;
      _vgg_conv_top_channels          <= _vgg_layer_top_channels;

      _vgg_conv_bottom_addr           <= _vgg_layer_bottom_addr;
      _vgg_conv_top_addr              <= _vgg_layer_top_addr;

      `ifdef sim_
      _vgg_conv_cmp_top               <= _vgg_layer_cmp_top;
      _vgg_conv_cmp_bottom_ker        <= _vgg_layer_cmp_bottom_ker;
      `endif
    end
    if(_vgg_conv_trigger_reg) begin // first layer
      _vgg_conv_start                 <= 1'b1;
    end else if(_vgg_layer_last_layer) begin // last layer
      if(_vgg_conv_start_last_layer) begin
        _vgg_conv_start               <= 1'b1;
      end else begin
        _vgg_conv_start               <= 1'b0;
      end
    end else if(_vgg_layer_conv_done_reg && ((!_vgg_layer_last_layer) && (!_vgg_conv_last_layer))) begin // not the llayer
      _vgg_conv_start                 <= 1'b1;
    end else begin
      _vgg_conv_start                 <= 1'b0;
    end
  end

  wire _vgg_conv_last_data;

  conv conv_layer(
  `ifdef sim_ // simulation port {{{
      .fm_cmp_top(_vgg_conv_cmp_top),
      .fm_cmp_bottom_ker(_vgg_conv_cmp_bottom_ker),
  `endif // }}}
      .clk(clk),
      .rst_n(rst_n),
      .fm_ddr_req(vgg_conv_req),
      .ddr_rd_data_valid(ddr_rd_data_valid),
      .ddr_rdy(ddr_rdy),
      .ddr_rd_data(ddr_rd_data),
      .ddr_addr(ddr_addr),
      .ddr_cmd(ddr_cmd),
      .ddr_en(ddr_en),
      // top data to ddr
      .ddr_wdf_rdy(ddr_wdf_rdy),
      .ddr_wdf_wren(ddr_wdf_wren),
      .ddr_wdf_data(ddr_wdf_data),
      .ddr_wdf_mask(ddr_wdf_mask),
      .ddr_wdf_end(ddr_wdf_end),
      // layer configuration
      .fm_relu_en(_vgg_conv_relu_en), // <-x enable relu, should change the output data for top data checking
      .fm_pooling_en(_vgg_conv_pooling_en),
      .fm_last_layer(_vgg_conv_last_layer),
      // bottom
      .fm_width(_vgg_conv_bottom_width), // bottom data width / atomic_width
      .fm_height(_vgg_conv_bottom_height), // bottom data height / atomic_height
      .fm_bottom_ddr_addr(_vgg_conv_bottom_addr), // bottom data address to read from
      .fm_bottom_channels(_vgg_conv_bottom_channels), // num of bottom data channels
      .fm_size(_vgg_conv_bottom_fm_size), // 64*4*num_of_atom_in_height*num_of_atom_in_width*float_num_width/ddr_data_width(32bit)
      .fm_1bar_size(_vgg_conv_bottom_1bar_size),  // 14*fm_width*float_num_width/ddr_data_width -> 64*4*num_of_atom*float_num_width/ddr_data_width(32bit)
      .fm_half_bar_size(_vgg_conv_bottom_half_bar_size), // 7*rd_data_max_x*float_num_width/ddr_data_width -> 64*2*num_of_atom*float_num_width/ddr_data_width(32bit)
      // kernel and bias
      .fm_bias_num(_vgg_conv_bias_num), // num of top data channels -> num of bias
      .fm_bias_ddr_burst_num(_vgg_conv_bias_burst_num), // num of burst to read all bias data
      .fm_bias_offset(_vgg_conv_bias_offset), // address occupied by bias data
      .fm_ker_ddr_addr(_vgg_conv_ker_addr), // parameter data address
      // top
      .fm_top_ddr_addr(_vgg_conv_top_addr), // top data address to write to
      .fm_top_channels(_vgg_conv_top_channels), // top data channels
      .fm_top_fm_size(_vgg_conv_top_fm_size), // top data fm size
      .fm_top_half_bar_size(_vgg_conv_top_half_bar_size), // top data half bar size
      // last layer
      .fm_llayer_last_data(_vgg_conv_last_data),
      .fm_llayer_bram_we(vgg_conv_bram_we),
      .fm_llayer_bram_addr(vgg_conv_bram_addr),
      .fm_llayer_bram_o(vgg_conv_llayer_o),
      //
      .fm_data_ready(_vgg_conv_start), // bottom data and kernel data is ready on ddr -> convolution start
      .fm_start(_vgg_conv_start), // conv layer operation start signal
      .fm_conv_done(_vgg_layer_conv_done) // current layer convolution done
    );

  // conv. layer last data
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      vgg_conv_last_data <= 1'b0;
    end else begin
      if(_vgg_conv_last_data) begin
        vgg_conv_last_data <= 1'b1;
      end else begin
        if(vgg_conv_fc_input_buffer_ready) begin
          vgg_conv_last_data <= 1'b0;
        end
      end
    end
  end

endmodule
