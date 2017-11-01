// ---------------------------------------------------
// File       : fsm.v
//
// Description: finite state machine of convolution layer
//              no patch prefetching
//              no convolution
//              using directC to debug
//              isolate fsm module -- 1.7
//              check -- 1.8
//              compatible with mem_top -- 1.9
//              wr_op added -- 1.10
//              the last convolution position -- 1.11
//              delay last_fm -- 1.12
//              x/y_eq_zero -- 1.13
//
// Version    : 1.13
// ---------------------------------------------------

//`define sim_
module fsm(
    `ifdef sim_ // {{{
    output wire           fsm_decision,
    `endif // }}}
    input  wire           clk,
    input  wire           rst_n,
    output wire           fsm_ddr_req,
    // conv, top layer
    input  wire           fsm_data_ready, // bottom data and kernel data is ready on ddr -> convolution start
    input  wire           fsm_start, // conv layer operation start signal
    output reg            fsm_done, // conv layer operation have finished, write data to ddr sdram
    // pooling
    input  wire           fsm_pooling_en,
    input  wire           fsm_pooling_last_pos, // write operation shall not be started until the last pooling pos if pooling is enabled
    // conv_op
    input  wire           fsm_conv_start_at_next_clk, // fsm_conv_at_first_pos
    input  wire           fsm_conv_at_last_pos,
    input  wire           fsm_conv_busy,
    input  wire           fsm_conv_last_valid,
    output reg            fsm_conv_start,
  //output wire           fsm_conv_next_ker_full, // next conv ker_set full
    output wire           fsm_conv_on_patch0, // operate on patch0
    output wire           fsm_conv_on_patch1, // operate on patch1
    output reg            fsm_conv_on_ker0, // operate on ker0
    output reg            fsm_conv_on_ker1, // operate on ker1
    output wire           fsm_conv_on_first_fm, // convolve on first fm
    output wire           fsm_conv_on_last_fm, // convolve on last fm
    output reg  [9:0]     fsm_conv_cur_ker_num, // current operation output kernel num
    // wr_ddr_op
    input  wire           fsm_wr_data_done, // write operation finished
    input  wire           fsm_last_layer, // 
    output reg            fsm_wr_data_top, // start writing to ddr
    output reg            fsm_wr_data_sw_on, // on data writing
    output wire           fsm_wr_data_x_eq_0, // current convolution output patch position
    output wire           fsm_wr_data_y_eq_0,
    output wire           fsm_wr_data_x_eq_end, // end poistion of output fm 
    output wire           fsm_wr_data_y_eq_end,

    // rd_ddr_data
    input  wire           fsm_rd_data_full,
    input  wire [29:0]    fsm_rd_data_bottom_ddr_addr,
    input  wire [9:0]     fsm_rd_data_bottom_channels, // num of bottom data channels
    input  wire [8:0]     fsm_rd_data_fm_width,
    input  wire [8:0]     fsm_rd_data_fm_height,
    input  wire [29:0]    fsm_rd_data_fm_size,
    output reg            fsm_rd_data_bottom, // start reading data from ddr
    output reg  [8:0]     fsm_rd_data_x,
    output reg  [8:0]     fsm_rd_data_y,
    output reg            fsm_rd_data_x_eq_0,
    output reg            fsm_rd_data_y_eq_0,
    output reg            fsm_rd_data_x_eq_end,
    output reg            fsm_rd_data_y_eq_end,
    output wire [8:0]     fsm_rd_data_end_of_x,
    output wire [8:0]     fsm_rd_data_end_of_y,
    output wire           fsm_rd_data_first_fm,
    output reg  [29:0]    fsm_rd_data_ith_offset,
    output reg            fsm_rd_data_sw_on,
    output wire           fsm_rd_data_patch0, // read patch 0
    output wire           fsm_rd_data_patch1, // read patch 1
    // rd_ddr_param
    input  wire           fsm_rd_param_full,
    input  wire [29:0]    fsm_rd_param_ker_ddr_addr,
    input  wire [9:0]     fsm_rd_param_bias_num, // num of top data channels
    input  wire [8:0]     fsm_rd_param_bias_offset, // address occupied by bias data
    output reg            fsm_rd_param,
    output reg            fsm_rd_param_ker_only,
    output reg  [29:0]    fsm_rd_param_addr,
    output reg            fsm_rd_param_sw_on,
    output wire           fsm_rd_param_ker0, // read ker_set 0
    output wire           fsm_rd_param_ker1, // read ker_set 1
    // rd_bram_patch
    input  wire           fsm_rd_bram_patch_last_valid,
    output reg            fsm_rd_bram_patch_en,
    output reg  [11:0]    fsm_rd_bram_patch_addr,
    // rd_bram_row
    input  wire           fsm_rd_bram_row_valid,
    output reg            fsm_rd_bram_row_en,
    output reg  [09:0]    fsm_rd_bram_row_addr
  );

  localparam ATOMIC_WIDTH     = 14;
  localparam ATOMIC_HEIGHT    = 14;
  localparam FLOAT_DATA_WIDTH = 16;
  localparam DDR_DATA_WIDTH   = 64;
  localparam KER_CHANNELS     = 32;
  localparam KER_HEIGHT       = 3;
  localparam KER_WIDTH        = 3;
  localparam DDR_PARAM_OFFSET = KER_CHANNELS * KER_HEIGHT * KER_WIDTH * FLOAT_DATA_WIDTH / DDR_DATA_WIDTH;

  // boundary
  assign      fsm_rd_data_end_of_x = fsm_rd_data_fm_width - 9'b1;
  assign      fsm_rd_data_end_of_y = fsm_rd_data_fm_height - 9'b1;
  reg [9:0]   _fsm_cur_conv_out_ith; // current operation output fm
  (*mark_debug="TRUE"*)reg [9:0]   _fsm_cur_conv_ope_ith; // current operation fm <-x Dec.10
  (*mark_debug="TRUE"*)reg [9:0]   _fsm_cur_conv_ope_ker_num; // current operation kernel num <-x Dec.10
  reg [8:0]   _fsm_x;
  reg [8:0]   _fsm_y;
  reg         _fsm_last_fm; // current operation, last bottom feature map
  reg         _fsm_last_layer;
  reg         _fsm_end; // current layer convlution on the last patch position
  reg [9:0]   _fsm_rd_param_bias_num;
  wire        _fsm_last_ker_set; // last ker_set on current position, current operation output is on the last ker_set
  assign      _fsm_last_ker_set = (_fsm_rd_param_bias_num == (fsm_conv_cur_ker_num + 10'd32));
  wire        _fsm_last_ope_fm; // <-x Dec.10
  assign      _fsm_last_ope_fm = ((_fsm_cur_conv_ope_ith + 1'b1)==fsm_rd_data_bottom_channels);
  wire        _fsm_last_ope_ker_set; // <-x Dec.10
  assign      _fsm_last_ope_ker_set = (_fsm_rd_param_bias_num == (_fsm_cur_conv_ope_ker_num+10'd32));
//wire        _fsm_sec_last_ker_set;
//assign      _fsm_sec_last_ker_set = (_fsm_rd_param_bias_num == (fsm_conv_cur_ker_num + 10'd64));
  wire        _fsm_sec_last_ope_ker_set;
  assign      _fsm_sec_last_ope_ker_set = (_fsm_rd_param_bias_num == (_fsm_cur_conv_ope_ker_num + 10'd64));
  reg         _fsm_need_wr_out; // current patch is the last channel, current ker_set is the last one
//assign      _fsm_need_wr_out = (_fsm_last_ker_set && _fsm_last_fm);
  wire        _fsm_cur_patch_conv_done;
  assign      _fsm_cur_patch_conv_done=(fsm_conv_last_valid && _fsm_last_ker_set && _fsm_last_fm);
  // patch
  reg [29:0]  _fsm_ith_offset; // ith bottom feature map address offset
  reg         _fsm_patch_full[0:1];
  reg         _fsm_next_conv_patch;
  reg         _fsm_rd_patch_index; // current patch index on reading, in simple fsm implementation, it's equivalent as _fsm_next_conv_patch
  reg         _fsm_conv_patch_index;
  // param
  reg [29:0]  _fsm_rd_ker_ith_offset; // ith ker_set address offset
  reg         _fsm_ker_full[0:1];
  reg         _fsm_next_conv_ker;
  reg         _fsm_rd_ker_index; // current ker index on reading, in simple fsm implementation, it's equivalent as _fsm_next_conv_ker
  reg         _fsm_conv_ker_index;
  // bram
  reg [11:0]  _fsm_rd_bram_patch_ith_offset;
  reg [09:0]  _fsm_rd_bram_row_ith_offset;
  reg         _fsm_rd_bram_patch_last_valid;
  wire        _fsm_no_bram_patch;
  assign      _fsm_no_bram_patch = (_fsm_x == 9'h0);
  // wr_op
  reg [8:0]   _fsm_wr_x; // current convolution position x
  reg [8:0]   _fsm_wr_y; // current convolution position y
  assign      fsm_wr_data_x_eq_0 = (_fsm_wr_x == 9'h0);
  assign      fsm_wr_data_x_eq_end = (_fsm_wr_x == fsm_rd_data_end_of_x);
  assign      fsm_wr_data_y_eq_0 = (_fsm_wr_y == 9'h0);
  assign      fsm_wr_data_y_eq_end = (_fsm_wr_y == fsm_rd_data_end_of_y);
  `ifdef sim_ // {{{
//wire        _fsm_decision;
  assign      fsm_decision = (_fsm_patch_full[_fsm_next_conv_patch] && (_fsm_no_bram_patch || (!_fsm_no_bram_patch && _fsm_rd_bram_patch_last_valid)));
  `endif // }}}

  always@(posedge clk) begin
    _fsm_rd_param_bias_num  <= fsm_rd_param_bias_num;
    _fsm_last_layer         <= fsm_last_layer;
  end
//wire        _fsm_last_fm; // current operation, last bottom feature map
//assign      _fsm_last_fm = ((_fsm_cur_conv_out_ith + 1'b1) == fsm_rd_data_bottom_channels);
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_last_fm <= 1'b0;
    end else begin
      if(((_fsm_cur_conv_out_ith + 1'b1) == fsm_rd_data_bottom_channels) ||
         (((_fsm_cur_conv_out_ith + 2'd2) == fsm_rd_data_bottom_channels) && (_fsm_last_ker_set && fsm_conv_last_valid))
        ) begin
        _fsm_last_fm <= 1'b1;
      end else begin
        _fsm_last_fm <= 1'b0;
      end
    end
  end

  // patch/ker_set selection
  wire _fsm_conv_on_ker0;
  wire _fsm_conv_on_ker1;
  assign fsm_conv_on_patch0 = (_fsm_conv_patch_index == 1'b0) ? 1'b1 : 1'b0;
  assign fsm_conv_on_patch1 = (_fsm_conv_patch_index == 1'b1) ? 1'b1 : 1'b0;
  assign _fsm_conv_on_ker0  = (_fsm_conv_ker_index == 1'b0) ? 1'b1 : 1'b0;
  assign _fsm_conv_on_ker1  = (_fsm_conv_ker_index == 1'b1) ? 1'b1 : 1'b0;
  assign fsm_rd_data_patch0 = (_fsm_rd_patch_index == 1'b0) ? 1'b1 : 1'b0;
  assign fsm_rd_data_patch1 = (_fsm_rd_patch_index == 1'b1) ? 1'b1 : 1'b0;
  assign fsm_rd_param_ker0  = (_fsm_rd_ker_index == 1'b0) ? 1'b1 : 1'b0;
  assign fsm_rd_param_ker1  = (_fsm_rd_ker_index == 1'b1) ? 1'b1 : 1'b0;

  always@(posedge clk) begin
    fsm_conv_on_ker0  <= _fsm_conv_on_ker0;
    fsm_conv_on_ker1  <= _fsm_conv_on_ker1;
  end

  // -------------------- simulation -------------------- {{{
`ifdef sim_
  wire  _fsm_ker0_full, _fsm_ker1_full, _fsm_patch0_full, _fsm_patch1_full;
//wire  _fsm_rd_ker_condition;
//wire  _fsm_rd_patch_condition;
  assign _fsm_ker0_full = _fsm_ker_full[0];
  assign _fsm_ker1_full = _fsm_ker_full[1];
  assign _fsm_patch0_full = _fsm_patch_full[0];
  assign _fsm_patch1_full = _fsm_patch_full[1];
//assign _fsm_rd_ker_condition = (fsm_conv_busy && _fsm_ker_full[_fsm_next_conv_ker] &&
//                                !_fsm_patch_full[_fsm_next_conv_patch]);
//assign _fsm_rd_patch_condition  = (fsm_conv_busy && _fsm_ker_full[_fsm_next_conv_ker] &&
//                                   !_fsm_patch_full[_fsm_next_conv_patch] );
`endif
  // -------------------- simulation --------------------  }}}

  //
  localparam FSM_RST          = 3'h0;
  localparam FSM_INIT_PATCH   = 3'h1;
  localparam FSM_INIT_PARAM   = 3'h2;
  localparam FSM_CONV_OP      = 3'h3;
  localparam FSM_FETCH_PATCH  = 3'h4;
  localparam FSM_FETCH_KER    = 3'h5;
  localparam FSM_WAIT         = 3'h6;
  localparam FSM_WR_DATA      = 3'h7;


  reg  [2:0] _fsm_state;
  reg  [2:0] _fsm_next_state;

  //
  assign      fsm_rd_data_first_fm = (_fsm_last_fm || (_fsm_state==FSM_INIT_PATCH)) ? 1'b1 : 1'b0; // convolve on the last feature map
  assign      fsm_conv_on_first_fm = (_fsm_cur_conv_out_ith == 10'h0) ? 1'b1 : 1'b0;
  assign      fsm_conv_on_last_fm  = _fsm_last_fm;

  // ddr request
  assign fsm_ddr_req = fsm_rd_data_bottom || fsm_rd_param || fsm_wr_data_top;

  // flip-flop
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_state <= FSM_RST;
    end else begin
      _fsm_state <= _fsm_next_state;
    end
  end
  // state transition
  always@(_fsm_state or fsm_data_ready or fsm_start or _fsm_patch_full[0] or
          _fsm_patch_full[1] or _fsm_ker_full[0] or _fsm_ker_full[1] or
          _fsm_next_conv_patch or _fsm_next_conv_ker or fsm_done or _fsm_last_layer or
          fsm_conv_busy or fsm_wr_data_done or _fsm_cur_patch_conv_done or
          _fsm_last_ope_ker_set or _fsm_need_wr_out or fsm_pooling_en or
          fsm_pooling_last_pos or _fsm_last_ope_fm or fsm_wr_data_x_eq_end or
          fsm_wr_data_y_eq_end or _fsm_no_bram_patch or _fsm_rd_bram_patch_last_valid
          ) begin
    _fsm_next_state = FSM_RST;
    case(_fsm_state)
      FSM_RST: begin
        if(fsm_data_ready && fsm_start) begin
          _fsm_next_state = FSM_INIT_PATCH;
        end else begin
          _fsm_next_state = FSM_RST;
        end
      end
      // filling first patch buffer
      FSM_INIT_PATCH: begin
        if(_fsm_patch_full[0]) begin
          _fsm_next_state = FSM_INIT_PARAM;
        end else begin
          _fsm_next_state = FSM_INIT_PATCH;
        end
      end
      // filling first ker set
      FSM_INIT_PARAM: begin
        if(_fsm_ker_full[0]) begin
          _fsm_next_state = FSM_CONV_OP;
        end else begin
          _fsm_next_state = FSM_INIT_PARAM;
        end
      end
      // convolution operation
      FSM_CONV_OP: begin
        if(fsm_done) begin
          _fsm_next_state = FSM_RST;
          `ifdef sim_
            $display("[%t], in FSM_CONV_OP", $realtime);
          //$display("[%t], in FSM_CONV_OP", $realtime);
          //$display("[%t], in FSM_CONV_OP", $realtime);
          //$display("[%t], in FSM_CONV_OP", $realtime);
          `endif
        end else if(!fsm_conv_busy) begin
          _fsm_next_state = FSM_CONV_OP;
        end else begin
          if(_fsm_last_ope_fm && _fsm_last_ope_ker_set &&
              fsm_wr_data_x_eq_end && fsm_wr_data_y_eq_end) begin // the last conv of current conv layer
            _fsm_next_state = FSM_WAIT;
          end else if(_fsm_last_ope_ker_set) begin // convolve on last ker set, read patch first
            _fsm_next_state = FSM_FETCH_PATCH;
          end else begin
            _fsm_next_state = FSM_FETCH_KER;
          end
        end
      end
      // fetch patch data, read bram (top row and right patch)
      FSM_FETCH_PATCH: begin
      //if(_fsm_patch_full[_fsm_next_conv_patch]) begin
        if(_fsm_patch_full[_fsm_next_conv_patch] &&
            (_fsm_no_bram_patch || (!_fsm_no_bram_patch && _fsm_rd_bram_patch_last_valid))) begin
          _fsm_next_state = FSM_FETCH_KER; // then, fetch kernel set
        end else begin
          _fsm_next_state = FSM_FETCH_PATCH;
        end
      end
      // fetch ker data (without bias)
      FSM_FETCH_KER: begin
        if(_fsm_ker_full[_fsm_next_conv_ker]) begin
          _fsm_next_state = FSM_WAIT;
        end else begin
          _fsm_next_state = FSM_FETCH_KER;
        end
      end
      // wait for current ker_set finishes convolution
      FSM_WAIT: begin
        if(_fsm_need_wr_out) begin
          if(_fsm_cur_patch_conv_done) begin
            if(fsm_pooling_en) begin // <-x added on Dec.13
              if(fsm_pooling_last_pos) begin
                _fsm_next_state = FSM_WR_DATA;
              end else begin
                _fsm_next_state = FSM_WAIT;
              end
            end else begin
              _fsm_next_state = FSM_WR_DATA;
            end
          end else begin
            _fsm_next_state = FSM_WAIT;
          end
        end else begin
          if(_fsm_last_layer && _fsm_cur_patch_conv_done) begin
            `ifdef sim_
              $display("[%t], in FSM_WAIT, data has written into bram", $realtime);
            //$display("[%t], in FSM_WAIT, data has written into bram", $realtime);
            //$display("[%t], in FSM_WAIT, data has written into bram", $realtime);
            //$display("[%t], in FSM_WAIT, data has written into bram", $realtime);
            `endif
            _fsm_next_state = FSM_CONV_OP;
          end else if(!fsm_conv_busy) begin
            _fsm_next_state = FSM_CONV_OP;
          end else begin
            _fsm_next_state = FSM_WAIT;
          end
        end
      end
      FSM_WR_DATA: begin
        if(fsm_wr_data_done) begin // <-x current convolution patch output has been written
          _fsm_next_state = FSM_CONV_OP;
        end else begin
          _fsm_next_state = FSM_WR_DATA;
        end
      end
    endcase
  end
  // logic
  always@(_fsm_state or _fsm_next_conv_patch or fsm_rd_data_full or fsm_rd_param_full or
          _fsm_next_conv_ker or _fsm_next_conv_patch or fsm_rd_param_bias_offset or
          fsm_rd_param_ker_ddr_addr or fsm_conv_busy or _fsm_rd_ker_ith_offset or
          _fsm_x or _fsm_y or _fsm_ith_offset or fsm_rd_bram_patch_last_valid or
          _fsm_rd_bram_patch_last_valid or _fsm_no_bram_patch or _fsm_rd_bram_patch_ith_offset or
          fsm_rd_bram_row_valid or _fsm_rd_bram_row_ith_offset
          ) begin
    // default
    fsm_rd_data_bottom = 1'b0;
    fsm_rd_data_x = 9'h0;
    fsm_rd_data_y = 9'h0;
    fsm_rd_data_sw_on = 1'b0;
    fsm_rd_data_ith_offset = 30'h0;
    fsm_rd_param = 1'b0;
    fsm_rd_param_ker_only = 1'b1;
    fsm_rd_param_addr = 30'h0;
    fsm_rd_param_sw_on = 1'b0;
    fsm_conv_start = 1'b0;
    fsm_rd_bram_patch_en = 1'b0;
    fsm_rd_bram_patch_addr = 12'h0;
    fsm_rd_bram_row_en = 1'b0;
    fsm_rd_bram_row_addr = 10'h0;
    fsm_wr_data_top = 1'b0;
    fsm_wr_data_sw_on = 1'b0;

    case(_fsm_state)
      FSM_RST: begin
        // reset all register for conv layer
        fsm_rd_data_bottom    = 1'b0;
        fsm_rd_param          = 1'b0;
        fsm_rd_param_ker_only = 1'b0;
      end
      // read from bottom data starting address
      FSM_INIT_PATCH: begin
        // read patch
        if(fsm_rd_data_full || _fsm_patch_full[_fsm_next_conv_patch]) begin
          fsm_rd_data_bottom = 1'b0;
          fsm_rd_data_x = 9'h0;
          fsm_rd_data_y = 9'h0;
        end else begin
          fsm_rd_data_bottom  = 1'b1;
          fsm_rd_data_x       = 9'h0;
          fsm_rd_data_y       = 9'h0;
          fsm_rd_data_sw_on   = 1'b1;
          fsm_rd_data_ith_offset = 30'h0;
        end
      end
      // read from param data starting address
      FSM_INIT_PARAM: begin
        // read bias and ker
        // could be the last data address output to ddr, need not to wait
        // for last valid data read out from ddr
        if(fsm_rd_param_full || _fsm_ker_full[_fsm_next_conv_ker]) begin
          fsm_rd_param      = 1'b0;
          fsm_rd_param_addr = fsm_rd_param_ker_ddr_addr -{21'h0,fsm_rd_param_bias_offset};
          fsm_rd_param_ker_only = 1'b1;
        end else begin
          fsm_rd_param      = 1'b1;
          fsm_rd_param_addr = fsm_rd_param_ker_ddr_addr -{21'h0,fsm_rd_param_bias_offset};
          fsm_rd_param_ker_only = 1'b0;
          fsm_rd_param_sw_on = 1'b1;
        end
      end

      FSM_CONV_OP: begin
        if(_fsm_patch_full[_fsm_next_conv_patch] && _fsm_ker_full[_fsm_next_conv_ker]) begin
          if(fsm_conv_busy) begin
            fsm_conv_start = 1'b0;
          end else begin
            fsm_conv_start = 1'b1;
          end
        end else begin
          fsm_conv_start = 1'b0;
          // simulation {{{
        `ifdef sim_
          $display("_fsm_patch or _fsm_ker not full");
        `endif
          // simulation }}}
        end
      end
      // update patch reading address, position, ith feature map
      FSM_FETCH_PATCH: begin
        // read patch
        if(fsm_rd_data_full || _fsm_patch_full[_fsm_next_conv_patch]) begin
          fsm_rd_data_bottom = 1'b0;
          fsm_rd_data_x = _fsm_x;
          fsm_rd_data_y = _fsm_y;
        end else begin
          fsm_rd_data_bottom = 1'b1;
          fsm_rd_data_x = _fsm_x;
          fsm_rd_data_y = _fsm_y;
          fsm_rd_data_ith_offset = _fsm_ith_offset;
          fsm_rd_data_sw_on = 1'b1;
        end
        // basically, bram data should be retrieved before fsm_rd_data_full is valid
        // read bram (right patch and top row)
        if(_fsm_no_bram_patch) begin
            fsm_rd_bram_patch_en  = 1'b0;
            fsm_rd_bram_patch_addr= 12'h0;
        end else begin
          if(fsm_rd_bram_patch_last_valid || _fsm_rd_bram_patch_last_valid) begin
            fsm_rd_bram_patch_en  = 1'b0;
            fsm_rd_bram_patch_addr= _fsm_rd_bram_patch_ith_offset;
          end else begin
            fsm_rd_bram_patch_en  = 1'b1;
            fsm_rd_bram_patch_addr= _fsm_rd_bram_patch_ith_offset; // ith fm right patch on bram_patch
          end
        end
        if(_fsm_y == 9'h0) begin
            fsm_rd_bram_row_en  = 1'b0;
            fsm_rd_bram_row_addr= 10'h0;
        end else begin
          if(fsm_rd_bram_row_valid) begin
            fsm_rd_bram_row_en  = 1'b0;
            fsm_rd_bram_row_addr= _fsm_rd_bram_row_ith_offset;
          end else begin
            fsm_rd_bram_row_en  = 1'b1;
            fsm_rd_bram_row_addr= _fsm_rd_bram_row_ith_offset; // ith fm top row on bram_row
          end
        end
      end
      FSM_FETCH_KER: begin
        if(fsm_rd_param_full || _fsm_ker_full[_fsm_next_conv_ker]) begin
          fsm_rd_param      = 1'b0;
          fsm_rd_param_addr = fsm_rd_param_ker_ddr_addr + _fsm_rd_ker_ith_offset;
        end else begin
          // read ker only
          fsm_rd_param      = 1'b1;
          fsm_rd_param_addr = fsm_rd_param_ker_ddr_addr + _fsm_rd_ker_ith_offset;
          fsm_rd_param_sw_on = 1'b1;
        end
      end
      FSM_WR_DATA: begin
        fsm_wr_data_top   = 1'b1;
        fsm_wr_data_sw_on = 1'b1;
      end
    endcase
  end

  // bram patch is full
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_rd_bram_patch_last_valid <= 1'b0;
    end else begin
      if(_fsm_state == FSM_FETCH_PATCH) begin
        if(fsm_rd_bram_patch_last_valid) begin
          _fsm_rd_bram_patch_last_valid <= 1'b1;
        end
      end else begin
        _fsm_rd_bram_patch_last_valid <= 1'b0;
      end
    end
  end

  // current patch convolution finished, need to write data out
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_need_wr_out <= 1'b0;
    end else begin
      if(_fsm_last_ope_ker_set && _fsm_last_ope_fm && (_fsm_state==FSM_WAIT) && (!_fsm_last_layer)) begin
      // should be out of CONV_OP state
        _fsm_need_wr_out <= 1'b1;
        `ifdef sim_
        //$display("[%t], _fsm_need_wr_out == 1", $realtime);
        //$display("[%t], _fsm_need_wr_out == 1", $realtime);
        //$display("[%t], _fsm_need_wr_out == 1", $realtime);
        //$display("[%t], _fsm_need_wr_out == 1", $realtime);
        `endif
      end
      if(fsm_wr_data_done && (_fsm_state == FSM_WR_DATA)) begin
        _fsm_need_wr_out <= 1'b0;
      end
    end
  end

  // ker_set and fm counter, current convolution
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      fsm_conv_cur_ker_num   <= 10'h0;
      _fsm_cur_conv_out_ith  <= 10'h0;
      _fsm_cur_conv_ope_ith  <= 10'h0;
      _fsm_cur_conv_ope_ker_num <= 10'h0;
    end else begin
      if(fsm_start && (_fsm_state==FSM_RST)) begin // prepare data, initializing
        fsm_conv_cur_ker_num  <= 10'h0;
        _fsm_cur_conv_out_ith <= 10'h0;
        _fsm_cur_conv_ope_ith <= 10'h0;
        _fsm_cur_conv_ope_ker_num <= 10'h3e0; // 10'h0 - 10'd32;
      end else begin
        // ker_set
        if(fsm_conv_start_at_next_clk) begin
          if(_fsm_last_ope_ker_set) begin
            _fsm_cur_conv_ope_ker_num <= 10'h0; // <-x reset when last data has been writen into top data memory
          end else begin
            _fsm_cur_conv_ope_ker_num <= _fsm_cur_conv_ope_ker_num + 10'd32;
          end
        end
        if(fsm_conv_last_valid) begin
          if(_fsm_last_ker_set) begin
            fsm_conv_cur_ker_num <= 10'h0;
          end else begin
            fsm_conv_cur_ker_num <= fsm_conv_cur_ker_num + 10'd32;
          end
        end

        // fm counter
        if(fsm_conv_start_at_next_clk) begin
          if(_fsm_last_ope_ker_set) begin
            if(_fsm_last_ope_fm) begin
              _fsm_cur_conv_ope_ith <= 10'h0;
            end else begin
              _fsm_cur_conv_ope_ith <= _fsm_cur_conv_ope_ith + 10'h1;
              `ifdef sim_
              $display("*%t current convolution operate on %d-th fm", $realtime, _fsm_cur_conv_ope_ith);
              `endif
            end
          end
        end
        if(fsm_conv_last_valid) begin
          if(_fsm_last_ker_set) begin
            if(_fsm_last_fm) begin
              _fsm_cur_conv_out_ith <= 10'h0;
            end else begin
              _fsm_cur_conv_out_ith <= _fsm_cur_conv_out_ith + 10'h1;
            end
          end
        end
      end
    end
  end

  // patch/ker_set full/conv index
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_next_conv_patch  <= 1'b0;
      _fsm_next_conv_ker    <= 1'b0;
      _fsm_conv_patch_index <= 1'b0;
      _fsm_conv_ker_index   <= 1'b0;
      _fsm_rd_patch_index   <= 1'b0;
      _fsm_rd_ker_index     <= 1'b0;
    end else begin
      // reset all index
      if(_fsm_next_state==FSM_RST) begin
        _fsm_next_conv_patch  <= 1'b0;
        _fsm_next_conv_ker    <= 1'b0;
        _fsm_conv_patch_index <= 1'b0;
        _fsm_conv_ker_index   <= 1'b0;
        _fsm_rd_patch_index   <= 1'b0;
        _fsm_rd_ker_index     <= 1'b0;
      end
      if(fsm_conv_start_at_next_clk) begin
      // increase next conv patch/ker_set index after conv started
        _fsm_next_conv_ker <= _fsm_next_conv_ker + 1'b1;
        _fsm_rd_ker_index  <= _fsm_rd_ker_index + 1'b1;
        if(_fsm_sec_last_ope_ker_set) begin
        // operation is on second last ker_set, next clk it goes to last ker_set
          _fsm_next_conv_patch <= _fsm_next_conv_patch + 1'b1;
          _fsm_rd_patch_index  <= _fsm_rd_patch_index + 1'b1;
        end
      end
      // increase current conv patch/ker_set index after last valid output
      if(fsm_conv_last_valid) begin
        _fsm_conv_ker_index <= _fsm_conv_ker_index + 1'b1;
        if(_fsm_last_ker_set) begin
          _fsm_conv_patch_index <= _fsm_conv_patch_index + 1'b1;
        end
      end
    end
  end
  // patch/ker_set full flags
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_patch_full[0] <= 1'b0;
      _fsm_patch_full[1] <= 1'b0;
      _fsm_ker_full[0] <= 1'b0;
      _fsm_ker_full[1] <= 1'b0;
    end else begin
      if(fsm_rd_data_full) begin // last valid patch data
        _fsm_patch_full[_fsm_next_conv_patch] <= 1'b1;
      end
      if(fsm_rd_param_full) begin // last valid param data
        _fsm_ker_full[_fsm_next_conv_ker] <= 1'b1;
      end
      if(fsm_conv_at_last_pos) begin // last convolution position, or fsm_conv_last_valid ?
        _fsm_ker_full[_fsm_conv_ker_index] <= 1'b0; // clear flags
        if(_fsm_last_ker_set) begin
          _fsm_patch_full[_fsm_conv_patch_index] <= 1'b0; // clear flags
        end
      end
      // clear all flags
      if(_fsm_next_state==FSM_RST) begin
        _fsm_patch_full[0] <= 1'b0;
        _fsm_patch_full[1] <= 1'b0;
        _fsm_ker_full[0]   <= 1'b0;
        _fsm_ker_full[1]   <= 1'b0;
      end
    end
  end
  // next conv ker is filled
//assign fsm_conv_next_ker_full = 1'b0; // ((_fsm_ker_full[_fsm_next_conv_ker] == 1'b1) ? 1'b1 : 1'b0);

  //prefetch strategy:
  //  polling through all _fm_patch_full reg, if one is empty, prefetch patch
  //  data into corresponding patch memory, update _fm_x, _fm_y

  //non-prefetch way:
  //  patch position
  wire _fsm_rd_data_x_eq_0;
  wire _fsm_rd_data_y_eq_0;
  wire _fsm_rd_data_x_eq_end;
  wire _fsm_rd_data_y_eq_end;
  assign _fsm_rd_data_x_eq_0  = (fsm_rd_data_x == 9'h0);
  assign _fsm_rd_data_y_eq_0  = (fsm_rd_data_y == 9'h0);
  assign _fsm_rd_data_x_eq_end  = (fsm_rd_data_x == fsm_rd_data_end_of_x);
  assign _fsm_rd_data_y_eq_end  = (fsm_rd_data_y == fsm_rd_data_end_of_y);
  always@(posedge clk) begin
    fsm_rd_data_x_eq_0 <= _fsm_rd_data_x_eq_0;
    fsm_rd_data_y_eq_0 <= _fsm_rd_data_y_eq_0;
    fsm_rd_data_x_eq_end  <= _fsm_rd_data_x_eq_end;
    fsm_rd_data_y_eq_end  <= _fsm_rd_data_y_eq_end;
  end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_x <= 9'h0;
      _fsm_y <= 9'h0;
      _fsm_wr_x <= 9'h0;
      _fsm_wr_y <= 9'h0;
    end else begin
      // update _fsm_x and _fsm_y immediately after the convolution started
      if(fsm_conv_start_at_next_clk && _fsm_sec_last_ope_ker_set) begin
    //if(fsm_conv_start_at_next_clk && _fsm_sec_last_ker_set) begin
        if(_fsm_last_fm) begin
        // start conv operation of the last ker_set of las_fm at next clk
          // x coordinate
          if(_fsm_x == fsm_rd_data_end_of_x) begin
            _fsm_x <= 9'h0;
          end else begin
            _fsm_x <= _fsm_x + 1'b1;
          end
          // y coordinate
          if(_fsm_x == fsm_rd_data_end_of_x) begin
            if(_fsm_y == fsm_rd_data_end_of_y) begin
              _fsm_y <= 9'h0;
            end else begin
              _fsm_y <= _fsm_y + 1'b1;
            end
          end
          // convolution on the last patch
          if(_fsm_x == fsm_rd_data_end_of_x) begin
            if(_fsm_y == fsm_rd_data_end_of_y) begin
              _fsm_end <= 1'b1;
            end
          end else begin
            _fsm_end <= 1'b0;
          end
  // -------------------- simulation -------------------- {{{
        `ifdef sim_
          $display("*********************************************************************");
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("**%t, read (x, y): (%.2d, %.2d)", $realtime, _fsm_x, _fsm_y);
          $display("*********************************************************************");
        `endif
  // -------------------- simulation -------------------- }}}
        end
      end
      // data writing, update position after last data has been written
      if(fsm_wr_data_done && (_fsm_state==FSM_WR_DATA)) begin
        // x coordinate
        if(_fsm_wr_x == fsm_rd_data_end_of_x) begin
          _fsm_wr_x <= 9'h0;
        end else begin
          _fsm_wr_x <= _fsm_wr_x + 1'b1;
        end
        // y coordinate
        if(_fsm_wr_x == fsm_rd_data_end_of_x) begin
          if(_fsm_wr_y == fsm_rd_data_end_of_y) begin
            _fsm_wr_y <= 9'h0;
          end else begin
            _fsm_wr_y <= _fsm_wr_y + 1'b1;
          end
        end
      end
    end
  end

  // patch address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_ith_offset <= 30'h0;
    end else begin
    //if(_fsm_state == FSM_RST) begin
    //  _fsm_ith_offset <= fsm_rd_data_bottom_ddr_addr;
    //end else if(_fsm_sec_last_ker_set && _fsm_last_fm && fsm_conv_start_at_next_clk) begin
    //  _fsm_ith_offset <= fsm_rd_data_bottom_ddr_addr;
    //end else if(fsm_conv_start_at_next_clk && _fsm_last_ker_set) begin // next patch
    //  _fsm_ith_offset <= _fsm_ith_offset + fsm_rd_data_fm_size;
    //end
      if(fsm_start && (_fsm_state == FSM_RST)) begin
        _fsm_ith_offset <= 30'h0; // fsm_rd_data_bottom_ddr_addr; // <-x used in read 14x14 z-scanning order, Jan.3
      end else if(_fsm_sec_last_ope_ker_set && fsm_conv_start_at_next_clk) begin
    //end else if(_fsm_sec_last_ker_set && fsm_conv_start_at_next_clk) begin
        if(_fsm_last_fm) begin
          _fsm_ith_offset <= 30'h0; // fsm_rd_data_bottom_ddr_addr; // <-x used in read 14x14 z-scanning order, Jan.3
        end else begin
          _fsm_ith_offset <= _fsm_ith_offset + fsm_rd_data_fm_size;
        end
      end
    end
  end

  // param address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_rd_ker_ith_offset <= 30'h0;
    end else begin
      if(fsm_start && (_fsm_state == FSM_RST)) begin // initialization
        _fsm_rd_ker_ith_offset <= 30'h0;
      end else begin
        if(fsm_conv_start_at_next_clk) begin
          if(_fsm_sec_last_ope_ker_set && _fsm_last_ope_fm) begin
            _fsm_rd_ker_ith_offset <= 30'h0;
          end else begin
            _fsm_rd_ker_ith_offset <= _fsm_rd_ker_ith_offset + DDR_PARAM_OFFSET;
          end
        end
      end
    end
  end
  // bram patch/row address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _fsm_rd_bram_patch_ith_offset <= 12'h0;
      _fsm_rd_bram_row_ith_offset   <= 10'h0;
    end else begin
      if(fsm_conv_start_at_next_clk) begin
        // patch address
        if(_fsm_sec_last_ope_ker_set && _fsm_last_ope_fm) begin
          _fsm_rd_bram_patch_ith_offset <= 12'h0; // reset bram_patch address
        end else if(_fsm_sec_last_ope_ker_set) begin
          _fsm_rd_bram_patch_ith_offset <= _fsm_rd_bram_patch_ith_offset + 12'h8;
        end
        // row address
        if(_fsm_sec_last_ope_ker_set && _fsm_last_ope_fm && (_fsm_x == fsm_rd_data_end_of_x)) begin
          _fsm_rd_bram_row_ith_offset   <= 10'h0;
        end else if(_fsm_sec_last_ope_ker_set) begin
          _fsm_rd_bram_row_ith_offset   <= _fsm_rd_bram_row_ith_offset +10'h1;
        end
      end
    end
  end

  // current layer convolution done
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      fsm_done <= 1'b0;
    end else begin
    //if(fsm_conv_last_valid) begin
    //  if(_fsm_last_fm && _fsm_last_ker_set && _fsm_end) begin
    //    fsm_done <= 1'b1;
    //  end else begin
    //    fsm_done <= 1'b0;
    //  end
    //end
      if(_fsm_last_layer && (_fsm_state==FSM_WAIT) && _fsm_cur_patch_conv_done) begin
        fsm_done <= 1'b1;
        `ifdef sim_
          $display("[%t], fsm_done == 1", $realtime);
        //$display("[%t], fsm_done == 1", $realtime);
        //$display("[%t], fsm_done == 1", $realtime);
        //$display("[%t], fsm_done == 1", $realtime);
        `endif
      end else if(fsm_wr_data_done && (_fsm_state==FSM_WR_DATA)) begin
        if(fsm_wr_data_x_eq_end && fsm_wr_data_y_eq_end) begin
          fsm_done <= 1'b1;
        end else begin
          fsm_done <= 1'b0;
        end
      end else begin
        fsm_done <= 1'b0;
      end
    end
  end

endmodule
