// ---------------------------------------------------
// File       : mem_top.v
//
// Description: read/write from/to memory
//              bias data is added inside mem_top module
//
// Version    : 1.0
// ---------------------------------------------------

//`define sim_
module mem_top#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter K_C      = 32, // kernel channels
    parameter K_H      = 3, // kernel height
    parameter K_W      = 3, // kernel width
    parameter ATOMIC_W = 14, // atomic width
    parameter ATOMIC_H = 14, // atomic height
    parameter MAX_O_CHANNEL = 512 // maximum output channels, maximum top feature map channels
  ) (
  `ifdef sim_
  // -------------------- simulation --------------------{{{
    input  wire                                                             mem_top_cmp_result_en,
    input  wire                                                             mem_top_cmp_top,
    output wire[16*16*(EXPONENT+MANTISSA+1)-1:0]                            mem_top_rd_proc_ram,
    output wire[K_C*K_H*K_W*(EXPONENT+MANTISSA+1)-1:0]                      mem_top_rd_ker,
    output wire[MAX_O_CHANNEL*(EXPONENT+MANTISSA+1)-1:0]                    mem_top_rd_bias,
  // -------------------- simulation --------------------}}}
  `endif
    input  wire                                                             clk,
    input  wire                                                             rst_n,
    // conv_op
    output wire[K_C*K_H*K_W*(EXPONENT+MANTISSA+1)-1:0]                      mem_top_ker, // kernel weight, connect to conv_op, bias data is added inside mem_top module
    output wire[16*16*(EXPONENT+MANTISSA+1)-1:0]                            mem_top_bottom, // bottom data, connect to conv_op
    output wire[7*7*(EXPONENT+MANTISSA+1)-1:0]                              mem_top_data,  // top data, connect to wr_op   <-XXXXXXXXXXXXX
    output wire[K_C*(EXPONENT+MANTISSA+1)-1:0]                              mem_top_partial_sum, // (partial summation of mem_data) or (bias data)
    input  wire[K_C*(EXPONENT+MANTISSA+1)-1:0]                              mem_top_conv_data_i, // convolution results   <-XXXXXXXXXXXXX
    input  wire                                                             mem_top_rd_partial_sum,
    output wire                                                             mem_top_partial_sum_valid,
    input  wire                                                             mem_top_conv_valid, // convolution output valid   <-XXXXXXXXXXXXX
    input  wire[3:0]                                                        mem_top_conv_x, // convolution output x position   <-XXXXXXXXXXXXX
    input  wire[3:0]                                                        mem_top_conv_y, // convolution output x position   <-XXXXXXXXXXXXX
    input  wire[3:0]                                                        mem_top_conv_to_x, // to convolve at posX
    input  wire[3:0]                                                        mem_top_conv_to_y, // to convolve at posY
    input  wire                                                             mem_top_conv_on_first_fm, // current convolving on first fm
    input  wire                                                             mem_top_conv_on_last_fm, // current convolving on last fm
    input  wire[9:0]                                                        mem_top_conv_cur_ker_set, // current convolution kernel set
    input  wire                                                             mem_top_conv_patch0, // flags on convolution patch0
    input  wire                                                             mem_top_conv_patch1,
    input  wire                                                             mem_top_conv_ker0, // flags on convolution ker0
    input  wire                                                             mem_top_conv_ker1,
    // relu
    input  wire                                                             mem_top_relu_en, // enable ReLU
    // pooling (with relu)
    input  wire                                                             mem_top_pooling_en, // enable pooling
    output wire                                                             mem_top_pooling_last_pos, // last pooling position
    // wr_ddr_op
    input  wire                                                             mem_top_wr_ddr_en, // write data to ddr
    input  wire                                                             mem_top_wr_rd_top_buffer,
    input  wire                                                             mem_top_wr_next_channel, // next channel of convolution result, wr_ddr_op module is writing the last data in current channel
    input  wire                                                             mem_top_wr_next_quarter, // next quart of convolution output buffer
    input  wire                                                             mem_top_wr_done, // writing operation finished
    output wire                                                             mem_top_wr_data_valid, // output buffer data valid
    // last layer
    input  wire                                                             mem_top_last_layer,
    output wire                                                             mem_top_last_layer_on,
    output wire[(EXPONENT+MANTISSA+1)*K_C-1:0]                              mem_top_last_layer_o,
    output wire                                                             mem_top_last_layer_valid,
    output wire                                                             mem_top_last_layer_last_pos,
    output wire                                                             mem_top_last_layer_first_pos,
    output wire[3:0]                                                        mem_top_last_layer_ker_set,
    // rd_data
    input  wire                                                             mem_top_rd_ddr_data_first_fm, // first feature map
    input  wire                                                             mem_top_rd_ddr_data_valid, // ddr bottom data valid
    input  wire[5:0]                                                        mem_top_rd_ddr_data_num_valid, // # of valid ddr bottom data
    input  wire                                                             mem_top_rd_ddr_data_x_eq_zero, // ddr bottom data position x==0
    input  wire                                                             mem_top_rd_ddr_data_x_eq_end,  // ddr bottom data position x==end
    input  wire                                                             mem_top_rd_ddr_data_y_eq_zero, // ddr bottom data position y==0
    input  wire                                                             mem_top_rd_ddr_data_y_eq_end, // ddr bottom data position y==end
    input  wire                                                             mem_top_rd_ddr_data_valid_first, // first valid ddr bottom data
    input  wire                                                             mem_top_rd_ddr_data_valid_last,  // last valid ddr bottom data
    input  wire                                                             mem_top_rd_ddr_data_patch_last, // last valid ddr patch data
    input  wire                                                             mem_top_rd_ddr_data_upper_valid_last, // last valid upper patch data
    input  wire[511:0]                                                      mem_top_rd_ddr_data_i, // ddr bottom data burst
    input  wire                                                             mem_top_rd_ddr_data_patch0, // flags on read patch0
    input  wire                                                             mem_top_rd_ddr_data_patch1,
    // rd_ker
    input  wire[511:0]                                                      mem_top_rd_ddr_param_i, // ddr param data
    input  wire                                                             mem_top_rd_ddr_ker_valid, // ddr weight data valid
    input  wire                                                             mem_top_rd_ddr_ker_valid_last, // last valid ddr weight data
    input  wire                                                             mem_top_rd_ddr_ker_ker0,
    input  wire                                                             mem_top_rd_ddr_ker_ker1,
    // rd_bias
    input  wire                                                             mem_top_rd_ddr_bias_valid, // ddr bias data valid
    input  wire                                                             mem_top_rd_ddr_bias_valid_last, // last valid ddr bias data
    // rd_bram_row interface, controled by fsm
    input  wire                                                             mem_top_rd_bram_row_enb, // enable bram_row port b read
    input  wire[9:0]                                                        mem_top_rd_bram_row_addrb, // bram_row reading address
    input  wire                                                             mem_top_rd_bram_row_valid, // bram_row data valid
    // rd_bram_patch interface, controled by fsm
    input  wire                                                             mem_top_rd_bram_patch_enb, // enable bram_patch port b read
    input  wire[11:0]                                                       mem_top_rd_bram_patch_addrb, // bram_patch reading address
    input  wire                                                             mem_top_rd_bram_patch_valid, // bram_patch data valid
    input  wire                                                             mem_top_rd_bram_patch_first,  // last valid bram_patch data
    input  wire                                                             mem_top_rd_bram_patch_last  // last valid bram_patch data
  );

  localparam DATA_WIDTH = EXPONENT+MANTISSA+1;

  wire[K_C*K_H*K_W*(EXPONENT+MANTISSA+1)-1:0]   _mem_top_ker0;
  wire[K_C*K_H*K_W*(EXPONENT+MANTISSA+1)-1:0]   _mem_top_ker1;
  wire[16*16*(EXPONENT+MANTISSA+1)-1:0]         _mem_top_bottom0;
  wire[16*16*(EXPONENT+MANTISSA+1)-1:0]         _mem_top_bottom1;
  assign mem_top_ker    = mem_top_conv_ker0 ? _mem_top_ker0 : (mem_top_conv_ker1 ? _mem_top_ker1 : {(K_C*K_H*K_W*(EXPONENT+MANTISSA+1)){1'b0}});
  assign mem_top_bottom = mem_top_conv_patch0 ? _mem_top_bottom0 : (mem_top_conv_patch1 ? _mem_top_bottom1 : {(16*16*(EXPONENT+MANTISSA+1)){1'b0}});
  //-------------------------------- top --------------------------------{
  mem_data #(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
  ) top_memory(
      .clk(clk),
      .rst_n(rst_n),
  `ifdef sim_ // {{{
      .mem_bias(mem_top_rd_bias),
      .mem_cmp_result(mem_top_cmp_result_en),
      .mem_cmp_top(mem_top_cmp_top),
  `endif //}}}
      .mem_bias_valid(mem_top_rd_ddr_bias_valid),
      .mem_bias_last(mem_top_rd_ddr_bias_valid_last),
      .mem_bias_i(mem_top_rd_ddr_param_i),
      .mem_data_cur_on_first_fm(mem_top_conv_on_first_fm), // operate on first fm, need to add bias when convolve on first fm
      .mem_data_relu_en(mem_top_relu_en), // activiation function
      .mem_data_pooling_en(mem_top_pooling_en), // enable pooling
      .mem_data_last_fm(mem_top_conv_on_last_fm), // operate on last fm, subsample the output
      .mem_data_pooling_last_pos(mem_top_pooling_last_pos), // last pooling position
      .mem_data_cur_ker_set(mem_top_conv_cur_ker_set), // current convolution kernel set, used to select data address
      .mem_data_conv_x(mem_top_conv_x),  // convolution output x position, used to select data address
      .mem_data_conv_y(mem_top_conv_y),  // convolution output y position, used to select data address
      .mem_data_to_conv_x(mem_top_conv_to_x),
      .mem_data_to_conv_y(mem_top_conv_to_y),
      .mem_data_conv_rd_partial_sum(mem_top_rd_partial_sum), // read partial sum data
      .mem_data_conv_partial_sum_valid(mem_top_partial_sum_valid), // partial sum data valid
      .mem_data_conv_valid(mem_top_conv_valid), // convolution output valid
      .mem_data_conv_data_i(mem_top_conv_data_i), // convolution output (+bias, if needed), 1x32
      .mem_data_conv_partial_sum(mem_top_partial_sum), // partial summation
      .mem_data_wr_data_re(mem_top_wr_ddr_en), // write enable
      .mem_data_rd_buffer(mem_top_wr_rd_top_buffer),
      .mem_data_wr_next_channel(mem_top_wr_next_channel), // will write next channel
      .mem_data_wr_next_quarter(mem_top_wr_next_quarter),
      .mem_data_wr_data_valid(mem_top_wr_data_valid),
      .mem_data_wr_done(mem_top_wr_done),
      .mem_data_data(mem_top_data),
      // last layer
      .mem_data_last_layer(mem_top_last_layer),
      .mem_data_last_layer_on(mem_top_last_layer_on),
      .mem_data_conv_data_last_layer_o(mem_top_last_layer_o),
      .mem_data_last_layer_valid(mem_top_last_layer_valid),
      .mem_data_last_layer_last_pos(mem_top_last_layer_last_pos),
      .mem_data_last_layer_first_pos(mem_top_last_layer_first_pos),
      .mem_data_last_layer_ker_set(mem_top_last_layer_ker_set)
  );
  //-------------------------------- top --------------------------------}

  //------------------------------- patch -------------------------------{
  wire [16*(EXPONENT+MANTISSA+1)-1:0] _mem_top_bram_row_o;  // bram row data
  wire [15*(EXPONENT+MANTISSA+1)-1:0] _mem_top_bram_patch_o; // bram patch data
  // patch0
  wire                                _mem_top_patch0_ddr_valid; // patch0 data valid from input
  wire                                _mem_top_patch0_bram_row_valid; // patch0 data valid from input
  wire                                _mem_top_patch0_bram_patch_valid; // patch0 data valid from input
  assign _mem_top_patch0_ddr_valid        = (mem_top_rd_ddr_data_patch0 && mem_top_rd_ddr_data_valid);
  assign _mem_top_patch0_bram_row_valid   = (mem_top_rd_ddr_data_patch0 && mem_top_rd_bram_row_valid);
  assign _mem_top_patch0_bram_patch_valid = (mem_top_rd_ddr_data_patch0 && mem_top_rd_bram_patch_valid);
  // patch1
  wire                                _mem_top_patch1_ddr_valid; // patch1 data valid from input
  wire                                _mem_top_patch1_bram_row_valid; // patch1 data valid from input
  wire                                _mem_top_patch1_bram_patch_valid; // patch1 data valid from input
  assign _mem_top_patch1_ddr_valid        = (mem_top_rd_ddr_data_patch1 && mem_top_rd_ddr_data_valid);
  assign _mem_top_patch1_bram_row_valid   = (mem_top_rd_ddr_data_patch1 && mem_top_rd_bram_row_valid);
  assign _mem_top_patch1_bram_patch_valid = (mem_top_rd_ddr_data_patch1 && mem_top_rd_bram_patch_valid);

  // patch update selection
  wire                                  _mem_top_update_bram_last; // end of mem_update operation
  reg                                   _mem_top_update_patch0; // flags to update patch0
  reg                                   _mem_top_update_patch1; // flags to update patch1
  wire                                  _mem_top_update_bram_patch_ena;  // bram_patch write enable
  wire[11:0]                            _mem_top_update_bram_patch_addr; // bram_patch write address
  wire                                  _mem_top_update_bram_row_ena;  // bram_row write enable
  wire[9:0]                             _mem_top_update_bram_row_addr; // bram_row write address
  wire[16*(EXPONENT+MANTISSA+1)-1:0]    _mem_top_update_bram_row_o; // bottom row data feeds into bram_row module
  wire[15*(EXPONENT+MANTISSA+1)-1:0]    _mem_top_update_bram_patch_o; // right patch data feed into bram_patch module

  wire[16*(EXPONENT+MANTISSA+1)-1:0]    _mem_top_update_bottom_row; // bottom row data feeds into update module
  wire[15*8*(EXPONENT+MANTISSA+1)-1:0]  _mem_top_update_right_patch; // right patch data feed into update module
  wire[16*(EXPONENT+MANTISSA+1)-1:0]    _mem_top_patch0_bottom_row; // bottom row data from patch0
  wire[16*(EXPONENT+MANTISSA+1)-1:0]    _mem_top_patch1_bottom_row; // bottom row data from patch1
  wire[15*8*(EXPONENT+MANTISSA+1)-1:0]  _mem_top_patch0_right_patch; // right patch data from patch0
  wire[15*8*(EXPONENT+MANTISSA+1)-1:0]  _mem_top_patch1_right_patch; // right patch data from patch1
  // patch update switch
  assign _mem_top_update_bottom_row = _mem_top_update_patch0 ? _mem_top_patch0_bottom_row :
                                              (_mem_top_update_patch1 ? _mem_top_patch1_bottom_row : {(16*DATA_WIDTH){1'b0}});
  assign _mem_top_update_right_patch= _mem_top_update_patch0 ? _mem_top_patch0_right_patch :
                                              (_mem_top_update_patch1 ? _mem_top_patch1_right_patch : {(15*8*DATA_WIDTH){1'b0}});

  `ifdef sim_
  // -------------------- simulation --------------------{{{
  assign mem_top_rd_proc_ram= mem_top_rd_ddr_data_patch0 ? _mem_top_bottom0 : _mem_top_bottom1;
  assign mem_top_rd_ker     = mem_top_rd_ddr_ker_ker0 ? _mem_top_ker0 : _mem_top_ker1;

  wire [31:0] _bias_data01,_bias_data02,_bias_data03,_bias_data04,_bias_data05,_bias_data06,_bias_data07,_bias_data08,
              _bias_data09,_bias_data10,_bias_data11,_bias_data12,_bias_data13,_bias_data14,_bias_data15,_bias_data16;
  assign _bias_data01 = mem_top_rd_bias[(511+1)*DATA_WIDTH-1 : 511*DATA_WIDTH];    assign _bias_data02 = mem_top_rd_bias[(510+1)*DATA_WIDTH-1 : 510*DATA_WIDTH];
  assign _bias_data03 = mem_top_rd_bias[(509+1)*DATA_WIDTH-1 : 509*DATA_WIDTH];    assign _bias_data04 = mem_top_rd_bias[(508+1)*DATA_WIDTH-1 : 508*DATA_WIDTH];
  assign _bias_data05 = mem_top_rd_bias[(507+1)*DATA_WIDTH-1 : 507*DATA_WIDTH];    assign _bias_data06 = mem_top_rd_bias[(506+1)*DATA_WIDTH-1 : 506*DATA_WIDTH];
  assign _bias_data07 = mem_top_rd_bias[(505+1)*DATA_WIDTH-1 : 505*DATA_WIDTH];    assign _bias_data08 = mem_top_rd_bias[(504+1)*DATA_WIDTH-1 : 504*DATA_WIDTH];
  assign _bias_data09 = mem_top_rd_bias[(503+1)*DATA_WIDTH-1 : 503*DATA_WIDTH];    assign _bias_data10 = mem_top_rd_bias[(502+1)*DATA_WIDTH-1 : 502*DATA_WIDTH];
  assign _bias_data11 = mem_top_rd_bias[(501+1)*DATA_WIDTH-1 : 501*DATA_WIDTH];    assign _bias_data12 = mem_top_rd_bias[(500+1)*DATA_WIDTH-1 : 500*DATA_WIDTH];
  assign _bias_data13 = mem_top_rd_bias[(499+1)*DATA_WIDTH-1 : 499*DATA_WIDTH];    assign _bias_data14 = mem_top_rd_bias[(498+1)*DATA_WIDTH-1 : 498*DATA_WIDTH];
  assign _bias_data15 = mem_top_rd_bias[(497+1)*DATA_WIDTH-1 : 497*DATA_WIDTH];    assign _bias_data16 = mem_top_rd_bias[(496+1)*DATA_WIDTH-1 : 496*DATA_WIDTH];

  // -------------------- simulation --------------------}}}
  `endif

  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_top_update_patch0 <= 1'b0;
      _mem_top_update_patch1 <= 1'b0;
    end else begin
      if(mem_top_rd_ddr_data_patch0 && mem_top_rd_ddr_data_valid_last) begin
        _mem_top_update_patch0 <= 1'b1;
      end
      if(mem_top_rd_ddr_data_patch1 && mem_top_rd_ddr_data_valid_last) begin
        _mem_top_update_patch1 <= 1'b1;
      end
      if(_mem_top_update_patch0 && _mem_top_update_bram_last) begin
        _mem_top_update_patch0 <= 1'b0;
      end
      if(_mem_top_update_patch1 && _mem_top_update_bram_last) begin
        _mem_top_update_patch1 <= 1'b0;
      end
    end
  end

  mem_patch #(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
  ) patch0_memory(
      .clk(clk),
      .mem_patch_x_eq_zero(mem_top_rd_ddr_data_x_eq_zero),
      .mem_patch_x_eq_end(mem_top_rd_ddr_data_x_eq_end),
      .mem_patch_y_eq_zero(mem_top_rd_ddr_data_y_eq_zero),
      .mem_patch_y_eq_end(mem_top_rd_ddr_data_y_eq_end),
      .mem_patch_ddr_valid(_mem_top_patch0_ddr_valid), // <-
      .mem_patch_ddr_num_valid(mem_top_rd_ddr_data_num_valid),
      .mem_patch_ddr_valid_first(mem_top_rd_ddr_data_valid_first),
      .mem_patch_ddr_valid_last(mem_top_rd_ddr_data_valid_last),
      .mem_patch_ddr_patch_last(mem_top_rd_ddr_data_patch_last),
      .mem_patch_ddr_upper_last(mem_top_rd_ddr_data_upper_valid_last),
      .mem_patch_ddr_i(mem_top_rd_ddr_data_i),
      .mem_patch_bram_row_valid(_mem_top_patch0_bram_row_valid), // <-
      .mem_patch_bram_row_i(_mem_top_bram_row_o), // <-
      .mem_patch_bram_patch_valid(_mem_top_patch0_bram_patch_valid), // <-
      .mem_patch_bram_patch_first(mem_top_rd_bram_patch_first),
      .mem_patch_bram_patch_last(mem_top_rd_bram_patch_last),
      .mem_patch_bram_patch_i(_mem_top_bram_patch_o), // <-
      .mem_patch_bottom_row(_mem_top_patch0_bottom_row), // [16*(EXPONENT+MANTISSA+1)-1:0]
      .mem_patch_right_patch(_mem_top_patch0_right_patch), //[15*8*(EXPONENT+MANTISSA+1)-1:0]
      .mem_patch_proc_ram(_mem_top_bottom0) // [16*16*(EXPONENT+MANTISSA+1)-1:0]
  );

  mem_patch #(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
  ) patch1_memory(
      .clk(clk),
      .mem_patch_x_eq_zero(mem_top_rd_ddr_data_x_eq_zero),
      .mem_patch_x_eq_end(mem_top_rd_ddr_data_x_eq_end),
      .mem_patch_y_eq_zero(mem_top_rd_ddr_data_y_eq_zero),
      .mem_patch_y_eq_end(mem_top_rd_ddr_data_y_eq_end),
      .mem_patch_ddr_valid(_mem_top_patch1_ddr_valid), // <-
      .mem_patch_ddr_num_valid(mem_top_rd_ddr_data_num_valid),
      .mem_patch_ddr_valid_first(mem_top_rd_ddr_data_valid_first),
      .mem_patch_ddr_valid_last(mem_top_rd_ddr_data_valid_last),
      .mem_patch_ddr_patch_last(mem_top_rd_ddr_data_patch_last),
      .mem_patch_ddr_upper_last(mem_top_rd_ddr_data_upper_valid_last),
      .mem_patch_ddr_i(mem_top_rd_ddr_data_i),
      .mem_patch_bram_row_valid(_mem_top_patch1_bram_row_valid), // <-
      .mem_patch_bram_row_i(_mem_top_bram_row_o), // <-
      .mem_patch_bram_patch_valid(_mem_top_patch1_bram_patch_valid), // <-
      .mem_patch_bram_patch_first(mem_top_rd_bram_patch_first),
      .mem_patch_bram_patch_last(mem_top_rd_bram_patch_last),
      .mem_patch_bram_patch_i(_mem_top_bram_patch_o), // <-
      .mem_patch_bottom_row(_mem_top_patch1_bottom_row), // [16*(EXPONENT+MANTISSA+1)-1:0]
      .mem_patch_right_patch(_mem_top_patch1_right_patch), //[15*8*(EXPONENT+MANTISSA+1)-1:0]
      .mem_patch_proc_ram(_mem_top_bottom1) // [16*16*(EXPONENT+MANTISSA+1)-1:0]
  );

  mem_update #(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
  ) update_memory (
      .clk(clk),
      .rst_n(rst_n),
      .mem_update_en(mem_top_rd_ddr_data_valid_last),
      .mem_update_bram_patch_last(mem_top_rd_bram_patch_last),
      .mem_update_first_fm(mem_top_rd_ddr_data_first_fm),
      .mem_update_x_eq_zero(mem_top_rd_ddr_data_x_eq_zero),
      .mem_update_top_row(_mem_top_update_bottom_row), // [16*(EXPONENT+MANTISSA+1)-1:0], data from patch0 or patch1
      .mem_update_right_patch(_mem_top_update_right_patch), // [15*8*(EXPONENT+MANTISSA+1)-1:0], data from patch0 or patch1
      // output port
      .mem_update_bram_patch_ena(_mem_top_update_bram_patch_ena),
      .mem_update_bram_patch_addr(_mem_top_update_bram_patch_addr), // [11:0]
      .mem_update_bram_patch_data(_mem_top_update_bram_patch_o), // [15*(EXPONENT+MANTISSA+1)-1:0], data write to bram_patch
      .mem_update_bram_row_ena(_mem_top_update_bram_row_ena),
      .mem_update_bram_row_addr(_mem_top_update_bram_row_addr), // [9:0]
      .mem_update_bram_row_data(_mem_top_update_bram_row_o), // [16*(EXPONENT+MANTISSA+1)-1:0], data write to bram_row
      .mem_update_bram_last(_mem_top_update_bram_last)
  );

  bram_top_row top_row_memory(
      .clka(clk),     // input wire clka
      .ena(_mem_top_update_bram_row_ena),      // input wire ena
      .wea(_mem_top_update_bram_row_ena),      // input wire [0 : 0] wea
      .addra(_mem_top_update_bram_row_addr),  // input wire [9 : 0] addra
      .dina(_mem_top_update_bram_row_o),    // input wire [511 : 0] dina
      .douta(),  // output wire [511 : 0] douta
      .clkb(clk),     // input wire clkb
      .enb(mem_top_rd_bram_row_enb),      // input wire enb
      .web(1'b0),      // input wire [0 : 0] web
      .addrb(mem_top_rd_bram_row_addrb),  // input wire [9 : 0] addrb
      .dinb({(16*DATA_WIDTH){1'b0}}),    // input wire [511 : 0] dinb
      .doutb(_mem_top_bram_row_o)   // output wire [511 : 0] doutb
  );

  bram_right_patch right_patch_memory(
      .clka(clk),     // input wire clka
      .ena(_mem_top_update_bram_patch_ena),      // input wire ena
      .wea(_mem_top_update_bram_patch_ena),      // input wire [0 : 0] wea
      .addra(_mem_top_update_bram_patch_addr),  // input wire [11 : 0] addra
      .dina(_mem_top_update_bram_patch_o),    // input wire [479 : 0] dina
      .douta(),  // output wire [479 : 0] douta
      .clkb(clk),     // input wire clkb
      .enb(mem_top_rd_bram_patch_enb),      // input wire enb
      .web(1'b0),      // input wire [0 : 0] web
      .addrb(mem_top_rd_bram_patch_addrb),  // input wire [11 : 0] addrb
      .dinb({(15*DATA_WIDTH){1'b0}}),    // input wire [479 : 0] dinb
      .doutb(_mem_top_bram_patch_o)   // output wire [479 : 0] doutb
  );
  //------------------------------- patch -------------------------------}

  //----------------------------- parameter -----------------------------{
  wire _mem_top_ker0_valid;  // kernel set 0 weight valid
  wire _mem_top_ker0_last;
  assign _mem_top_ker0_valid  = (mem_top_rd_ddr_ker_ker0 && mem_top_rd_ddr_ker_valid);
  assign _mem_top_ker0_last   = (mem_top_rd_ddr_ker_ker0 && mem_top_rd_ddr_ker_valid_last);
  wire _mem_top_ker1_valid; // kernel set 1 weight valid
  wire _mem_top_ker1_last;
  assign _mem_top_ker1_valid  = (mem_top_rd_ddr_ker_ker1 && mem_top_rd_ddr_ker_valid);
  assign _mem_top_ker1_last   = (mem_top_rd_ddr_ker_ker1 && mem_top_rd_ddr_ker_valid_last);

//// memory bias
//mem_bias #(
//  .EXPONENT(8),
//  .MANTISSA(23)
//) bias_memory (
//  .clk(clk),
//  .rst_n(rst_n),
//  .mem_bias_valid(mem_top_rd_ddr_bias_valid),
//  .mem_bias_last(mem_top_rd_ddr_bias_valid_last),
//  .mem_bias_i(mem_top_rd_ddr_param_i),
//  .mem_bias_o() // connect to inner summation module
//);
  // kernel set 0
  mem_ker#(
    .EXPONENT(EXPONENT),
    .MANTISSA(MANTISSA),
    .K_C(K_C),
    .K_H(K_H),
    .K_W(K_W)
  ) ker0_memory (
    .clk(clk),
    .rst_n(rst_n),
    .mem_ker_valid(_mem_top_ker0_valid),
    .mem_ker_last(_mem_top_ker0_last),
    .mem_ker_i(mem_top_rd_ddr_param_i),
    .mem_ker_o(_mem_top_ker0)
  );
  // kernel set 1
  mem_ker#(
    .EXPONENT(EXPONENT),
    .MANTISSA(MANTISSA),
    .K_C(K_C),
    .K_H(K_H),
    .K_W(K_W)
  ) ker1_memory (
    .clk(clk),
    .rst_n(rst_n),
    .mem_ker_valid(_mem_top_ker1_valid),
    .mem_ker_last(_mem_top_ker1_last),
    .mem_ker_i(mem_top_rd_ddr_param_i),
    .mem_ker_o(_mem_top_ker1)
  );
  //----------------------------- parameter -----------------------------}

endmodule
