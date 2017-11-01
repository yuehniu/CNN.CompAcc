// ---------------------------------------------------
// File       : bram_pooling_rd.v
//
// Description: read from bram(pooling mode)
//
// Version    : 1.0
// ---------------------------------------------------

module bram_pooling_rd #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter PORT_ADDR_WIDTH = 12
  ) (
    input  wire                                 clk,
    input  wire                                 rst_n,
    // addr
    input  wire[3:0]                            bram_rd_pooling_ker_set,
    input  wire[2:0]                            bram_rd_pooling_y,
    input  wire[2:0]                            bram_rd_pooling_x,
    output reg [32*PORT_ADDR_WIDTH-1 : 0]       bram_rd_pooling_addr,
    // enable
    input  wire                                 bram_rd_pooling_pre_en,   //in conv, port b read enable
    output reg                                  bram_rd_pooling_en,
    output reg                                  bram_rd_pooling_bram_valid,
    // data
    input  wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_pooling_pre,
    output reg                                  bram_rd_pooling_data_valid,
    output reg [32*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_pooling_data
  );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  wire[5:0]                   _bram_rd_pooling_quarter_addr;
  reg [4:0]                   _bram_rd_pooling_shift;
  reg [4:0]                   _bram_rd_pooling_shift1;
  reg [4:0]                   _bram_rd_pooling_shift2;
  reg                         _bram_rd_pooling_data_valid_0;
  wire[PORT_ADDR_WIDTH-1 : 0] _bram_rd_pooling_addr;
  reg [63*DATA_WIDTH-1:0]     _bram_rd_pooling_pre_data;
  reg [32*DATA_WIDTH-1:0]     _bram_rd_pooling_data_0;
  assign _bram_rd_pooling_quarter_addr = bram_rd_pooling_y*4'd7 + {1'b0,bram_rd_pooling_x};
  assign _bram_rd_pooling_addr = {bram_rd_pooling_ker_set,2'd0}*6'd49 + _bram_rd_pooling_quarter_addr;

  // enable
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_rd_pooling_en <= 1'b0;
    end else begin
      bram_rd_pooling_en            <= bram_rd_pooling_pre_en;
      bram_rd_pooling_bram_valid    <= bram_rd_pooling_en;
      _bram_rd_pooling_data_valid_0 <= bram_rd_pooling_bram_valid;
      bram_rd_pooling_data_valid    <= _bram_rd_pooling_data_valid_0;
    end
  end
  // address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_rd_pooling_addr <= {(32*PORT_ADDR_WIDTH){1'b0}};
    end else begin
      bram_rd_pooling_addr <= {32{_bram_rd_pooling_addr}};
    end
  end
  // data
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _bram_rd_pooling_pre_data <=  {(63*(EXPONENT+MANTISSA+1)){1'b0}};
    end else begin
      if(bram_rd_pooling_bram_valid) begin
        _bram_rd_pooling_pre_data[63*(EXPONENT+MANTISSA+1)-1 : 31*(EXPONENT+MANTISSA+1)] <= bram_rd_pooling_pre;
        _bram_rd_pooling_pre_data[31*(EXPONENT+MANTISSA+1)-1 : 0]                        <= bram_rd_pooling_pre[32*(EXPONENT+MANTISSA+1)-1:(EXPONENT+MANTISSA+1)];
      end
    end
  end
  always@(posedge clk) begin
    _bram_rd_pooling_shift1 <= _bram_rd_pooling_quarter_addr[4:0];
    _bram_rd_pooling_shift2 <= _bram_rd_pooling_shift1;
    _bram_rd_pooling_shift  <= _bram_rd_pooling_shift2;
    bram_rd_pooling_data    <= _bram_rd_pooling_data_0;
  end
  always@(_bram_rd_pooling_shift or _bram_rd_pooling_pre_data or _bram_rd_pooling_data_valid_0) begin
    if(_bram_rd_pooling_data_valid_0) begin
      _bram_rd_pooling_data_0 = {(32*DATA_WIDTH){1'b0}};
      case(_bram_rd_pooling_shift)
        5'd0 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[63*DATA_WIDTH-1 : 31*DATA_WIDTH];
        5'd1 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[62*DATA_WIDTH-1 : 30*DATA_WIDTH];
        5'd2 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[61*DATA_WIDTH-1 : 29*DATA_WIDTH];
        5'd3 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[60*DATA_WIDTH-1 : 28*DATA_WIDTH];
        5'd4 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[59*DATA_WIDTH-1 : 27*DATA_WIDTH];
        5'd5 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[58*DATA_WIDTH-1 : 26*DATA_WIDTH];
        5'd6 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[57*DATA_WIDTH-1 : 25*DATA_WIDTH];
        5'd7 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[56*DATA_WIDTH-1 : 24*DATA_WIDTH];
        5'd8 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[55*DATA_WIDTH-1 : 23*DATA_WIDTH];
        5'd9 : _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[54*DATA_WIDTH-1 : 22*DATA_WIDTH];
        5'd10: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[53*DATA_WIDTH-1 : 21*DATA_WIDTH];
        5'd11: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[52*DATA_WIDTH-1 : 20*DATA_WIDTH];
        5'd12: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[51*DATA_WIDTH-1 : 19*DATA_WIDTH];
        5'd13: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[50*DATA_WIDTH-1 : 18*DATA_WIDTH];
        5'd14: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[49*DATA_WIDTH-1 : 17*DATA_WIDTH];
        5'd15: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[48*DATA_WIDTH-1 : 16*DATA_WIDTH];
        5'd16: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[47*DATA_WIDTH-1 : 15*DATA_WIDTH];
        5'd17: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[46*DATA_WIDTH-1 : 14*DATA_WIDTH];
        5'd18: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[45*DATA_WIDTH-1 : 13*DATA_WIDTH];
        5'd19: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[44*DATA_WIDTH-1 : 12*DATA_WIDTH];
        5'd20: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[43*DATA_WIDTH-1 : 11*DATA_WIDTH];
        5'd21: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[42*DATA_WIDTH-1 : 10*DATA_WIDTH];
        5'd22: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[41*DATA_WIDTH-1 :  9*DATA_WIDTH];
        5'd23: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[40*DATA_WIDTH-1 :  8*DATA_WIDTH];
        5'd24: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[39*DATA_WIDTH-1 :  7*DATA_WIDTH];
        5'd25: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[38*DATA_WIDTH-1 :  6*DATA_WIDTH];
        5'd26: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[37*DATA_WIDTH-1 :  5*DATA_WIDTH];
        5'd27: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[36*DATA_WIDTH-1 :  4*DATA_WIDTH];
        5'd28: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[35*DATA_WIDTH-1 :  3*DATA_WIDTH];
        5'd29: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[34*DATA_WIDTH-1 :  2*DATA_WIDTH];
        5'd30: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[33*DATA_WIDTH-1 :  1*DATA_WIDTH];
        5'd31: _bram_rd_pooling_data_0 = _bram_rd_pooling_pre_data[32*DATA_WIDTH-1 :  0*DATA_WIDTH];
      endcase
    end else begin
      _bram_rd_pooling_data_0 = {(32*DATA_WIDTH){1'b0}};
    end
  end

endmodule
