// ---------------------------------------------------
// File       : bram_conv_wr.v
//
// Description: write into bram
//
// Version    : 1.0
// ---------------------------------------------------

module bram_conv_wr #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter PORT_ADDR_WIDTH = 12
  ) (
    input  wire                                 clk,
    input  wire                                 rst_n,
    // addr
    input  wire[3:0]                            bram_wr_ker_set,
    input  wire[3:0]                            bram_wr_y,//conv_y in [0:14]
    input  wire[3:0]                            bram_wr_x,//conv_x in [0:14]
    output reg [32*PORT_ADDR_WIDTH-1 : 0]       bram_wr_addr,
    // enable
    input  wire                                 bram_wr_conv_valid,   //in conv, port a write enable
    output reg                                  bram_wr_en,
    // data
    input  wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_wr_conv_i,
    output reg [32*(EXPONENT+MANTISSA+1)-1:0]   bram_wr_data
  );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  wire                                _bram_wr_x_quarter; // 0~1
  wire                                _bram_wr_y_quarter; // 0~1
  wire[2:0]                           _bram_wr_qpos_x; // x coordinate in 7x7
  wire[2:0]                           _bram_wr_qpos_y; // y coordinate in 7x7
  wire[3:0]                           _bram_wr_x_minus7;
  wire[3:0]                           _bram_wr_y_minus7;
  wire[5:0]                           _bram_wr_quarter_addr; // address in 7x7
  reg [4:0]                           _bram_wr_shift;
  wire[PORT_ADDR_WIDTH-1 : 0]         _bram_wr_addr;
  reg [63*(EXPONENT+MANTISSA+1)-1:0]  _bram_wr_conv_data;

  assign _bram_wr_x_minus7  = bram_wr_x - 4'd7;
  assign _bram_wr_y_minus7  = bram_wr_y - 4'd7;
  assign _bram_wr_x_quarter = _bram_wr_x_minus7[3] ? 1'b0 : 1'b1;
  assign _bram_wr_y_quarter = _bram_wr_y_minus7[3] ? 1'b0 : 1'b1;
  assign _bram_wr_qpos_x    = _bram_wr_x_quarter ? _bram_wr_x_minus7[2:0] : bram_wr_x[2:0];
  assign _bram_wr_qpos_y    = _bram_wr_y_quarter ? _bram_wr_y_minus7[2:0] : bram_wr_y[2:0];
  assign _bram_wr_quarter_addr  = _bram_wr_qpos_y*4'd7 + {1'b0,_bram_wr_qpos_x};
  assign _bram_wr_addr      = {bram_wr_ker_set, _bram_wr_y_quarter, _bram_wr_x_quarter}*6'd49 + _bram_wr_quarter_addr;

  // enable
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_wr_en <= 1'b0;
    end else begin
      bram_wr_en <= bram_wr_conv_valid;
    end
  end
  // address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_wr_addr <= {(32*PORT_ADDR_WIDTH){1'b0}};
    end else begin
      if(bram_wr_conv_valid) begin
        bram_wr_addr  <= {32{_bram_wr_addr}};
      end
    end
  end
  // data
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _bram_wr_conv_data <= {(63*(EXPONENT+MANTISSA+1)){1'b0}};
    end else begin
      if(bram_wr_conv_valid) begin
        _bram_wr_conv_data[32*(EXPONENT+MANTISSA+1)-1 :  0*(EXPONENT+MANTISSA+1)] <= bram_wr_conv_i;
        _bram_wr_conv_data[63*(EXPONENT+MANTISSA+1)-1 : 32*(EXPONENT+MANTISSA+1)] <= bram_wr_conv_i[31*(EXPONENT+MANTISSA+1)-1: 0];
      end
    end
  end
  always@(posedge clk) begin
    _bram_wr_shift <= _bram_wr_quarter_addr[4:0];
  end
  always@(_bram_wr_shift or _bram_wr_conv_data or bram_wr_en) begin
    if(bram_wr_en) begin
      bram_wr_data = {(32*DATA_WIDTH){1'b0}};
      case(_bram_wr_shift)
        5'd0 : bram_wr_data = _bram_wr_conv_data[32*DATA_WIDTH-1 :  0*DATA_WIDTH];
        5'd1 : bram_wr_data = _bram_wr_conv_data[33*DATA_WIDTH-1 :  1*DATA_WIDTH];
        5'd2 : bram_wr_data = _bram_wr_conv_data[34*DATA_WIDTH-1 :  2*DATA_WIDTH];
        5'd3 : bram_wr_data = _bram_wr_conv_data[35*DATA_WIDTH-1 :  3*DATA_WIDTH];
        5'd4 : bram_wr_data = _bram_wr_conv_data[36*DATA_WIDTH-1 :  4*DATA_WIDTH];
        5'd5 : bram_wr_data = _bram_wr_conv_data[37*DATA_WIDTH-1 :  5*DATA_WIDTH];
        5'd6 : bram_wr_data = _bram_wr_conv_data[38*DATA_WIDTH-1 :  6*DATA_WIDTH];
        5'd7 : bram_wr_data = _bram_wr_conv_data[39*DATA_WIDTH-1 :  7*DATA_WIDTH];
        5'd8 : bram_wr_data = _bram_wr_conv_data[40*DATA_WIDTH-1 :  8*DATA_WIDTH];
        5'd9 : bram_wr_data = _bram_wr_conv_data[41*DATA_WIDTH-1 :  9*DATA_WIDTH];
        5'd10: bram_wr_data = _bram_wr_conv_data[42*DATA_WIDTH-1 : 10*DATA_WIDTH];
        5'd11: bram_wr_data = _bram_wr_conv_data[43*DATA_WIDTH-1 : 11*DATA_WIDTH];
        5'd12: bram_wr_data = _bram_wr_conv_data[44*DATA_WIDTH-1 : 12*DATA_WIDTH];
        5'd13: bram_wr_data = _bram_wr_conv_data[45*DATA_WIDTH-1 : 13*DATA_WIDTH];
        5'd14: bram_wr_data = _bram_wr_conv_data[46*DATA_WIDTH-1 : 14*DATA_WIDTH];
        5'd15: bram_wr_data = _bram_wr_conv_data[47*DATA_WIDTH-1 : 15*DATA_WIDTH];
        5'd16: bram_wr_data = _bram_wr_conv_data[48*DATA_WIDTH-1 : 16*DATA_WIDTH];
        5'd17: bram_wr_data = _bram_wr_conv_data[49*DATA_WIDTH-1 : 17*DATA_WIDTH];
        5'd18: bram_wr_data = _bram_wr_conv_data[50*DATA_WIDTH-1 : 18*DATA_WIDTH];
        5'd19: bram_wr_data = _bram_wr_conv_data[51*DATA_WIDTH-1 : 19*DATA_WIDTH];
        5'd20: bram_wr_data = _bram_wr_conv_data[52*DATA_WIDTH-1 : 20*DATA_WIDTH];
        5'd21: bram_wr_data = _bram_wr_conv_data[53*DATA_WIDTH-1 : 21*DATA_WIDTH];
        5'd22: bram_wr_data = _bram_wr_conv_data[54*DATA_WIDTH-1 : 22*DATA_WIDTH];
        5'd23: bram_wr_data = _bram_wr_conv_data[55*DATA_WIDTH-1 : 23*DATA_WIDTH];
        5'd24: bram_wr_data = _bram_wr_conv_data[56*DATA_WIDTH-1 : 24*DATA_WIDTH];
        5'd25: bram_wr_data = _bram_wr_conv_data[57*DATA_WIDTH-1 : 25*DATA_WIDTH];
        5'd26: bram_wr_data = _bram_wr_conv_data[58*DATA_WIDTH-1 : 26*DATA_WIDTH];
        5'd27: bram_wr_data = _bram_wr_conv_data[59*DATA_WIDTH-1 : 27*DATA_WIDTH];
        5'd28: bram_wr_data = _bram_wr_conv_data[60*DATA_WIDTH-1 : 28*DATA_WIDTH];
        5'd29: bram_wr_data = _bram_wr_conv_data[61*DATA_WIDTH-1 : 29*DATA_WIDTH];
        5'd30: bram_wr_data = _bram_wr_conv_data[62*DATA_WIDTH-1 : 30*DATA_WIDTH];
        5'd31: bram_wr_data = _bram_wr_conv_data[63*DATA_WIDTH-1 : 31*DATA_WIDTH];
      endcase
    end else begin
      bram_wr_data = {(32*DATA_WIDTH){1'b0}};
    end
  end

endmodule
