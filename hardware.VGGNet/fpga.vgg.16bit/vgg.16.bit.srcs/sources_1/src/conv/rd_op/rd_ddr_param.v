// ---------------------------------------------------
// File       : rd_ddr_param.v
//
// Description: read weight and bias parameter
//              add bias valid signal -- 1.1
//              fit mem module -- 1.2
//              get clear output -- 1.3
//
// Version    : 1.3
// ---------------------------------------------------

module rd_ddr_param(
    input  wire         clk,
    input  wire         rst_n,
    // ddr
    input  wire         ddr_rdy,
    input  wire         ddr_rd_data_valid,
    output reg  [29:0]  ddr_addr,
    output reg  [2:0]   ddr_cmd,
    output reg  [0:0]   ddr_en,
    //
    input  wire         rd_param,
    input  wire         rd_param_ker_only,
    input  wire [5:0]   rd_param_bias_burst_num, // number of conv layer bias data,
                                           // max burst num: 32 (512 bias with 32 bit float number)
    input  wire [29:0]  rd_param_addr,
    output reg          rd_param_valid,
    output reg          rd_param_bias_valid, // bias valid if not read_kernel_only
    output reg          rd_param_bias_valid_last, // last valid bias data
    input  wire [511:0] ddr_rd_data, // <-x added on Oct.31
    output reg  [511:0] rd_param_data, // <-x added on Oct.31
    output reg          rd_param_full
  );

  localparam RD_PARAM_RST   = 3'd0;
  localparam RD_PARAM_BIAS  = 3'd1;
  localparam RD_PARAM_KER   = 3'd2;

  localparam FLOAT_NUM_WIDTH  = 16;
  localparam DATA_WIDTH       = FLOAT_NUM_WIDTH;
  localparam RD_KER_DATA_NUM  = 288;
  localparam DDR_DATA_WIDTH   = 64;
  localparam DDR_BURST_LEN  = 8;
  // kernel set: 3*3*32 * float_num_bits / ddr_data_width
  localparam RD_KER_DATA_SIZE = RD_KER_DATA_NUM*FLOAT_NUM_WIDTH/DDR_DATA_WIDTH;
  localparam RD_KER_BURST_NUM = (RD_KER_DATA_SIZE+7) / DDR_BURST_LEN; // ceiling, burst num start from 0;
  localparam RD_ADDR_STRIDE = 8;

  reg [2:0]   _rd_param_state;
  reg [2:0]   _rd_param_next_state;
  reg [29:0]  _rd_param_addr;
  reg         _rd_param_next_burst;
  reg [6:0]   _rd_param_burst_cnt;
  reg [6:0]   _rd_param_valid_cnt;
  reg         _rd_param_next_valid;
  reg         _rd_param_valid_on_bias;
  reg         _rd_param_has_bias;
  wire        _rd_param_bias_last;
  wire        _rd_ker_last;
  wire        _rd_param_last;
  reg         _rd_param_valid;
  reg         _rd_param_bias_valid;
  wire        _rd_param_bias_valid_last;
  wire[511:0] _rd_param_data;
  reg         _rd_param_full;

  always@(posedge clk) begin
    rd_param_full       <= _rd_param_full;
    rd_param_valid      <= _rd_param_valid;
    rd_param_bias_valid <= _rd_param_bias_valid;
    rd_param_bias_valid_last  <= _rd_param_bias_valid_last;
  //rd_param_data       <= _rd_param_data;
    rd_param_data[ 1*DATA_WIDTH - 1 :  0*DATA_WIDTH] <= _rd_param_data[32*DATA_WIDTH - 1: 31*DATA_WIDTH];
    rd_param_data[ 2*DATA_WIDTH - 1 :  1*DATA_WIDTH] <= _rd_param_data[31*DATA_WIDTH - 1: 30*DATA_WIDTH];
    rd_param_data[ 3*DATA_WIDTH - 1 :  2*DATA_WIDTH] <= _rd_param_data[30*DATA_WIDTH - 1: 29*DATA_WIDTH];
    rd_param_data[ 4*DATA_WIDTH - 1 :  3*DATA_WIDTH] <= _rd_param_data[29*DATA_WIDTH - 1: 28*DATA_WIDTH];
    rd_param_data[ 5*DATA_WIDTH - 1 :  4*DATA_WIDTH] <= _rd_param_data[28*DATA_WIDTH - 1: 27*DATA_WIDTH];
    rd_param_data[ 6*DATA_WIDTH - 1 :  5*DATA_WIDTH] <= _rd_param_data[27*DATA_WIDTH - 1: 26*DATA_WIDTH];
    rd_param_data[ 7*DATA_WIDTH - 1 :  6*DATA_WIDTH] <= _rd_param_data[26*DATA_WIDTH - 1: 25*DATA_WIDTH];
    rd_param_data[ 8*DATA_WIDTH - 1 :  7*DATA_WIDTH] <= _rd_param_data[25*DATA_WIDTH - 1: 24*DATA_WIDTH];
    rd_param_data[ 9*DATA_WIDTH - 1 :  8*DATA_WIDTH] <= _rd_param_data[24*DATA_WIDTH - 1: 23*DATA_WIDTH];
    rd_param_data[10*DATA_WIDTH - 1 :  9*DATA_WIDTH] <= _rd_param_data[23*DATA_WIDTH - 1: 22*DATA_WIDTH];
    rd_param_data[11*DATA_WIDTH - 1 : 10*DATA_WIDTH] <= _rd_param_data[22*DATA_WIDTH - 1: 21*DATA_WIDTH];
    rd_param_data[12*DATA_WIDTH - 1 : 11*DATA_WIDTH] <= _rd_param_data[21*DATA_WIDTH - 1: 20*DATA_WIDTH];
    rd_param_data[13*DATA_WIDTH - 1 : 12*DATA_WIDTH] <= _rd_param_data[20*DATA_WIDTH - 1: 19*DATA_WIDTH];
    rd_param_data[14*DATA_WIDTH - 1 : 13*DATA_WIDTH] <= _rd_param_data[19*DATA_WIDTH - 1: 18*DATA_WIDTH];
    rd_param_data[15*DATA_WIDTH - 1 : 14*DATA_WIDTH] <= _rd_param_data[18*DATA_WIDTH - 1: 17*DATA_WIDTH];
    rd_param_data[16*DATA_WIDTH - 1 : 15*DATA_WIDTH] <= _rd_param_data[17*DATA_WIDTH - 1: 16*DATA_WIDTH];
    rd_param_data[17*DATA_WIDTH - 1 : 16*DATA_WIDTH] <= _rd_param_data[16*DATA_WIDTH - 1: 15*DATA_WIDTH];
    rd_param_data[18*DATA_WIDTH - 1 : 17*DATA_WIDTH] <= _rd_param_data[15*DATA_WIDTH - 1: 14*DATA_WIDTH];
    rd_param_data[19*DATA_WIDTH - 1 : 18*DATA_WIDTH] <= _rd_param_data[14*DATA_WIDTH - 1: 13*DATA_WIDTH];
    rd_param_data[20*DATA_WIDTH - 1 : 19*DATA_WIDTH] <= _rd_param_data[13*DATA_WIDTH - 1: 12*DATA_WIDTH];
    rd_param_data[21*DATA_WIDTH - 1 : 20*DATA_WIDTH] <= _rd_param_data[12*DATA_WIDTH - 1: 11*DATA_WIDTH];
    rd_param_data[22*DATA_WIDTH - 1 : 21*DATA_WIDTH] <= _rd_param_data[11*DATA_WIDTH - 1: 10*DATA_WIDTH];
    rd_param_data[23*DATA_WIDTH - 1 : 22*DATA_WIDTH] <= _rd_param_data[10*DATA_WIDTH - 1:  9*DATA_WIDTH];
    rd_param_data[24*DATA_WIDTH - 1 : 23*DATA_WIDTH] <= _rd_param_data[ 9*DATA_WIDTH - 1:  8*DATA_WIDTH];
    rd_param_data[25*DATA_WIDTH - 1 : 24*DATA_WIDTH] <= _rd_param_data[ 8*DATA_WIDTH - 1:  7*DATA_WIDTH];
    rd_param_data[26*DATA_WIDTH - 1 : 25*DATA_WIDTH] <= _rd_param_data[ 7*DATA_WIDTH - 1:  6*DATA_WIDTH];
    rd_param_data[27*DATA_WIDTH - 1 : 26*DATA_WIDTH] <= _rd_param_data[ 6*DATA_WIDTH - 1:  5*DATA_WIDTH];
    rd_param_data[28*DATA_WIDTH - 1 : 27*DATA_WIDTH] <= _rd_param_data[ 5*DATA_WIDTH - 1:  4*DATA_WIDTH];
    rd_param_data[29*DATA_WIDTH - 1 : 28*DATA_WIDTH] <= _rd_param_data[ 4*DATA_WIDTH - 1:  3*DATA_WIDTH];
    rd_param_data[30*DATA_WIDTH - 1 : 29*DATA_WIDTH] <= _rd_param_data[ 3*DATA_WIDTH - 1:  2*DATA_WIDTH];
    rd_param_data[31*DATA_WIDTH - 1 : 30*DATA_WIDTH] <= _rd_param_data[ 2*DATA_WIDTH - 1:  1*DATA_WIDTH];
    rd_param_data[32*DATA_WIDTH - 1 : 31*DATA_WIDTH] <= _rd_param_data[ 1*DATA_WIDTH - 1:  0*DATA_WIDTH];
  end

  assign _rd_param_bias_last = ((rd_param_bias_burst_num-1'b1) == _rd_param_burst_cnt[5:0]);
  assign _rd_ker_last  = _rd_param_has_bias ? ((_rd_param_burst_cnt-{1'b0,rd_param_bias_burst_num}) == RD_KER_BURST_NUM) :
                                              (_rd_param_burst_cnt == RD_KER_BURST_NUM);
  assign _rd_param_last = _rd_param_has_bias ? ((_rd_param_valid_cnt == (RD_KER_BURST_NUM + rd_param_bias_burst_num - 1'b1)) && ddr_rd_data_valid) :
                                              ((_rd_param_valid_cnt == (RD_KER_BURST_NUM - 1)) && ddr_rd_data_valid);
  assign _rd_param_bias_valid_last = (_rd_param_valid_cnt == ({1'b0,rd_param_bias_burst_num}-1'b1));
  assign _rd_param_data = _rd_param_valid ? ddr_rd_data : {512{1'b0}}; // <-x added on Oct.31

  // FF
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_param_state <= RD_PARAM_RST;
    end else begin
      _rd_param_state <= _rd_param_next_state;
    end
  end
  // state transition
  always@(_rd_param_state or rd_param or _rd_param_bias_last or _rd_param_last or
          rd_param_ker_only) begin
    _rd_param_next_state = RD_PARAM_RST;
    case(_rd_param_state)
      RD_PARAM_RST: begin
        if(rd_param) begin
          if(rd_param_ker_only)
            _rd_param_next_state = RD_PARAM_KER;
          else
            _rd_param_next_state = RD_PARAM_BIAS;
        end else begin
          _rd_param_next_state = RD_PARAM_RST;
        end
      end
      RD_PARAM_BIAS: begin
        if(_rd_param_bias_last)
          _rd_param_next_state = RD_PARAM_KER;
        else
          _rd_param_next_state = RD_PARAM_BIAS;
      end
      RD_PARAM_KER: begin
        if(_rd_param_last)
          _rd_param_next_state = RD_PARAM_RST;
        else
          _rd_param_next_state = RD_PARAM_KER;
      end
    endcase
  end
  // logic
  always@(_rd_param_state or ddr_rdy or ddr_rd_data_valid or _rd_ker_last or 
          _rd_param_addr or _rd_param_last or _rd_param_valid_on_bias) begin
    ddr_en    = 1'b0;
    ddr_addr  = 30'h0;
    ddr_cmd   = 3'b1; // read
    _rd_param_valid      = 1'b0;
    _rd_param_bias_valid = 1'b0;
    _rd_param_full       = 1'b0;
    _rd_param_next_burst = 1'b0;
    _rd_param_next_valid = 1'b0;
    case(_rd_param_state)
      RD_PARAM_RST: begin
        ddr_en = 1'b0;
      end

      RD_PARAM_BIAS: begin
        if(ddr_rdy) begin
          ddr_en  = 1'b1;
          ddr_cmd = 3'b1;
          ddr_addr= _rd_param_addr;
          _rd_param_next_burst = 1'b1;
        end
        if(ddr_rd_data_valid) begin
          _rd_param_next_valid = 1'b1;
          _rd_param_valid      = 1'b1;
          // bias valid
          _rd_param_bias_valid = 1'b1;
        end
      end

      RD_PARAM_KER: begin
        if(ddr_rdy) begin
          ddr_cmd = 3'b1;
          ddr_addr= _rd_param_addr;
          if(_rd_ker_last) begin
            ddr_en = 1'b0;
            _rd_param_next_burst = 1'b0;
          end else begin
            ddr_en = 1'b1;
            _rd_param_next_burst = 1'b1;
          end
        end
        if(ddr_rd_data_valid) begin
          _rd_param_next_valid = 1'b1;
          _rd_param_valid      = 1'b1;
          if(_rd_param_valid_on_bias) begin
            _rd_param_bias_valid = 1'b1;
          end
        end
        if(_rd_param_last) begin
          _rd_param_full = 1'b1;
        end
      end
    endcase
  end
  // need to read bias, record rd_param_ker_only in case it is transient
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_param_has_bias <= 1'b0;
    end else begin
      if(rd_param_ker_only) begin
        _rd_param_has_bias <= 1'b0;
      end else begin
        _rd_param_has_bias <= 1'b1;
      end
      if(_rd_param_last) begin
        _rd_param_has_bias <= 1'b0;
      end
    end
  end
  // read addr
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_param_addr <= 30'h0;
      _rd_param_burst_cnt <= 7'h0;
      _rd_param_valid_cnt <= 7'h0;
    end else begin
      // initialization
      if(rd_param && (_rd_param_state == RD_PARAM_RST)) begin
        _rd_param_addr <= rd_param_addr;
        _rd_param_burst_cnt <= 7'h0;
        _rd_param_valid_cnt <= 7'h0;
      end
      // increment
      if(_rd_param_next_burst) begin
        _rd_param_addr <= _rd_param_addr + 4'h8;
        _rd_param_burst_cnt <= _rd_param_burst_cnt + 1'b1;
      end
      if(_rd_param_next_valid) begin
        _rd_param_valid_cnt <= _rd_param_valid_cnt + 1'b1;
      end
      // reset to zero
      if(_rd_param_last) begin
        _rd_param_addr <= 30'h0;
        _rd_param_burst_cnt <= 7'h0;
        _rd_param_valid_cnt <= 7'h0;
      end
    end
  end
  // bias valid
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_param_valid_on_bias <= 1'b0;
    end else begin
      if(_rd_param_next_state == RD_PARAM_BIAS) begin
        _rd_param_valid_on_bias <= 1'b1;
      end
      if(_rd_param_bias_valid_last) begin
        _rd_param_valid_on_bias <= 1'b0;
      end
    end
  end

endmodule
