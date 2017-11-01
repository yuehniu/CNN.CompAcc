// ---------------------------------------------------
// File       : rd_ddr_param.v
//
// Description: read weight and bias parameter
//              add bias valid signal
//
// Version    : 1.1
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
    output              rd_bias_last, // niuyue add
    input  wire [511:0] ddr_rd_data, // <-x added on Oct.31
    output wire [511:0] rd_param_data, // <-x added on Oct.31
    output reg          rd_param_full
  );

  localparam RD_PARAM_RST   = 3'd0;
  localparam RD_PARAM_BIAS  = 3'd1;
  localparam RD_PARAM_KER   = 3'd2;
  localparam FLOAT_NUM_WIDTH  = 32;
  localparam RD_KER_DATA_NUM  = 288;
  localparam DDR_DATA_WIDTH   = 64;
  localparam DDR_BURST_LEN  = 8;
  // kernel set: 3*3*32 * float_num_bits / ddr_data_width
  localparam RD_KER_DATA_SIZE = RD_KER_DATA_NUM*FLOAT_NUM_WIDTH/DDR_DATA_WIDTH;
  localparam RD_KER_BURST_NUM = (RD_KER_DATA_SIZE+7) / DDR_BURST_LEN; // ceiling, burst num start from 0;
  localparam RD_ADDR_STRIDE = 8;

  reg [2:0]  _rd_param_state;
  reg [2:0]  _rd_param_next_state;
  reg [29:0] _rd_param_addr;
  reg        _rd_param_next_burst;
  reg [6:0]  _rd_param_burst_cnt;
  reg [6:0]  _rd_param_valid_cnt;
  reg        _rd_param_next_valid;
  reg        _rd_param_on_ker;
  wire       _rd_bias_last;
  wire       _rd_ker_last;
  wire       _rd_param_output_last;
  wire       _rd_bias_valid_last;

  assign _rd_bias_last = ((rd_param_bias_burst_num-1'b1) == _rd_param_burst_cnt[5:0]);
  assign rd_bias_last  = _rd_bias_valid_last; // niuyue add
  assign _rd_ker_last  = ((_rd_param_burst_cnt-{1'b0,rd_param_bias_burst_num}) == 7'h12); //RD_KER_BURST_NUM);
  assign _rd_param_output_last = (_rd_param_valid_cnt == (RD_KER_BURST_NUM + rd_param_bias_burst_num )); // niuyue revise
  assign _rd_bias_valid_last = (_rd_param_valid_cnt == ({1'b0,rd_param_bias_burst_num}-1'b1));
  assign rd_param_data = ddr_rd_data; // <-x added on Oct.31

  // FF
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_param_state <= RD_PARAM_RST;
    end else begin
      _rd_param_state <= _rd_param_next_state;
    end
  end
  // state transition
  always@(_rd_param_state or rd_param or _rd_bias_last or _rd_param_output_last or
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
        if(_rd_bias_last)
          _rd_param_next_state = RD_PARAM_KER;
        else
          _rd_param_next_state = RD_PARAM_BIAS;
      end
      RD_PARAM_KER: begin
        if(_rd_param_output_last)
          _rd_param_next_state = RD_PARAM_RST;
        else
          _rd_param_next_state = RD_PARAM_KER;
      end
    endcase
  end
  // logic
  always@(_rd_param_state or ddr_rdy or ddr_rd_data_valid or _rd_ker_last or 
          _rd_param_addr or _rd_param_output_last or _rd_param_on_ker) begin
    ddr_en    = 1'b0;
    ddr_addr  = 30'h0;
    ddr_cmd   = 3'b1; // read
    rd_param_valid       = 1'b0;
    rd_param_bias_valid  = 1'b0;
    rd_param_full        = 1'b0;
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
          rd_param_valid = 1'b1;
          // bias valid
          rd_param_bias_valid = 1'b1;
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
          rd_param_valid = 1'b1;
          if(!_rd_param_on_ker) begin
            rd_param_bias_valid = 1'b1;
          end
        end
        if(_rd_param_output_last) begin
          rd_param_full = 1'b1;
        end
      end
    endcase
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
    end
  end
  // bias valid
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_param_on_ker <= 1'b0;
    end else begin
      if(!rd_param_ker_only) begin
        if(_rd_bias_valid_last) begin
          _rd_param_on_ker <= 1'b1;
        end else if(_rd_param_output_last) begin
          _rd_param_on_ker <= 1'b0;
        end
      end else begin
        _rd_param_on_ker <= 1'b1;
      end
    end
  end

endmodule
