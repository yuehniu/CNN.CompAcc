// ---------------------------------------------------
// File       : bram_conv_rd.v
//
// Description: read from bram
//
// Version    : 1.0
// ---------------------------------------------------

module bram_conv_rd #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter PORT_ADDR_WIDTH = 12
  ) (
    input  wire                                 clk,
    input  wire                                 rst_n,
    // addr
    input  wire[3:0]                            bram_rd_ker_set,
    input  wire[3:0]                            bram_rd_x,
    input  wire[3:0]                            bram_rd_y,
    output reg [32*PORT_ADDR_WIDTH-1 : 0]       bram_rd_addr,
    // enable
    input  wire                                 bram_rd_conv_en,   //in conv, port b read enable
    output reg                                  bram_rd_bram_valid,
    output reg                                  bram_rd_en,
    // data
    input  wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_partial_sum,
    output reg                                  bram_rd_data_valid,
    output reg [32*(EXPONENT+MANTISSA+1)-1:0]   bram_rd_data
  );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  wire                                _bram_rd_x_quarter;
  wire                                _bram_rd_y_quarter;
  wire[3:0]                           _bram_rd_x_minux7;
  wire[3:0]                           _bram_rd_y_minux7;
  wire[2:0]                           _bram_rd_qpos_x; // x coordinate in 7x7
  wire[2:0]                           _bram_rd_qpos_y; // y coordinate in 7x7
  wire[5:0]                           _bram_rd_quarter_addr; // address in 7x7
  reg [4:0]                           _bram_rd_shift1; // address in 7x7
  reg [4:0]                           _bram_rd_shift2; // address in 7x7
  reg [4:0]                           _bram_rd_shift; // address in 7x7
  wire[PORT_ADDR_WIDTH-1 : 0]         _bram_rd_addr;
  reg [63*(EXPONENT+MANTISSA+1)-1:0]  _bram_rd_data;

  assign _bram_rd_x_minux7  = bram_rd_x - 4'd7;
  assign _bram_rd_y_minux7  = bram_rd_y - 4'd7;
  assign _bram_rd_x_quarter = _bram_rd_x_minux7[3] ? 1'b0 : 1'b1;
  assign _bram_rd_y_quarter = _bram_rd_y_minux7[3] ? 1'b0 : 1'b1;
  assign _bram_rd_qpos_x    = _bram_rd_x_quarter ? _bram_rd_x_minux7[2:0] : bram_rd_x[2:0];
  assign _bram_rd_qpos_y    = _bram_rd_y_quarter ? _bram_rd_y_minux7[2:0] : bram_rd_y[2:0];
  assign _bram_rd_quarter_addr  = _bram_rd_qpos_y*4'd7 + {1'd0,_bram_rd_qpos_x};
  assign _bram_rd_addr      = {bram_rd_ker_set,_bram_rd_y_quarter,_bram_rd_x_quarter}*6'd49 + _bram_rd_quarter_addr;

  // enable
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_rd_en <= 1'b0;
    end else begin
      bram_rd_en          <= bram_rd_conv_en;
      bram_rd_bram_valid  <= bram_rd_en;
      bram_rd_data_valid  <= bram_rd_bram_valid;
    end
  end
  // address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      bram_rd_addr    <= {(32*PORT_ADDR_WIDTH){1'b0}};
    end else begin
      if(bram_rd_conv_en) begin
        bram_rd_addr  <= {32{_bram_rd_addr}};
      end
    end
  end
  // data
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _bram_rd_data <= {(63*(EXPONENT+MANTISSA+1)){1'b0}};
    end else begin
      if(bram_rd_bram_valid) begin
        _bram_rd_data[63*(EXPONENT+MANTISSA+1)-1 : 31*(EXPONENT+MANTISSA+1)] <= bram_rd_partial_sum;
        _bram_rd_data[31*(EXPONENT+MANTISSA+1)-1 : 0]                        <= bram_rd_partial_sum[32*(EXPONENT+MANTISSA+1)-1:(EXPONENT+MANTISSA+1)];
      end
    end
  end
  always@(posedge clk) begin
    _bram_rd_shift1<= _bram_rd_quarter_addr[4:0];
    _bram_rd_shift2<= _bram_rd_shift1;
    _bram_rd_shift <= _bram_rd_shift2;
  end
  always@(_bram_rd_shift or _bram_rd_data or bram_rd_data_valid) begin
    if(bram_rd_data_valid) begin
      bram_rd_data = {(32*DATA_WIDTH){1'b0}};
      case(_bram_rd_shift)
        5'd0 : bram_rd_data = _bram_rd_data[63*DATA_WIDTH-1 : 31*DATA_WIDTH];
        5'd1 : bram_rd_data = _bram_rd_data[62*DATA_WIDTH-1 : 30*DATA_WIDTH];
        5'd2 : bram_rd_data = _bram_rd_data[61*DATA_WIDTH-1 : 29*DATA_WIDTH];
        5'd3 : bram_rd_data = _bram_rd_data[60*DATA_WIDTH-1 : 28*DATA_WIDTH];
        5'd4 : bram_rd_data = _bram_rd_data[59*DATA_WIDTH-1 : 27*DATA_WIDTH];
        5'd5 : bram_rd_data = _bram_rd_data[58*DATA_WIDTH-1 : 26*DATA_WIDTH];
        5'd6 : bram_rd_data = _bram_rd_data[57*DATA_WIDTH-1 : 25*DATA_WIDTH];
        5'd7 : bram_rd_data = _bram_rd_data[56*DATA_WIDTH-1 : 24*DATA_WIDTH];
        5'd8 : bram_rd_data = _bram_rd_data[55*DATA_WIDTH-1 : 23*DATA_WIDTH];
        5'd9 : bram_rd_data = _bram_rd_data[54*DATA_WIDTH-1 : 22*DATA_WIDTH];
        5'd10: bram_rd_data = _bram_rd_data[53*DATA_WIDTH-1 : 21*DATA_WIDTH];
        5'd11: bram_rd_data = _bram_rd_data[52*DATA_WIDTH-1 : 20*DATA_WIDTH];
        5'd12: bram_rd_data = _bram_rd_data[51*DATA_WIDTH-1 : 19*DATA_WIDTH];
        5'd13: bram_rd_data = _bram_rd_data[50*DATA_WIDTH-1 : 18*DATA_WIDTH];
        5'd14: bram_rd_data = _bram_rd_data[49*DATA_WIDTH-1 : 17*DATA_WIDTH];
        5'd15: bram_rd_data = _bram_rd_data[48*DATA_WIDTH-1 : 16*DATA_WIDTH];
        5'd16: bram_rd_data = _bram_rd_data[47*DATA_WIDTH-1 : 15*DATA_WIDTH];
        5'd17: bram_rd_data = _bram_rd_data[46*DATA_WIDTH-1 : 14*DATA_WIDTH];
        5'd18: bram_rd_data = _bram_rd_data[45*DATA_WIDTH-1 : 13*DATA_WIDTH];
        5'd19: bram_rd_data = _bram_rd_data[44*DATA_WIDTH-1 : 12*DATA_WIDTH];
        5'd20: bram_rd_data = _bram_rd_data[43*DATA_WIDTH-1 : 11*DATA_WIDTH];
        5'd21: bram_rd_data = _bram_rd_data[42*DATA_WIDTH-1 : 10*DATA_WIDTH];
        5'd22: bram_rd_data = _bram_rd_data[41*DATA_WIDTH-1 :  9*DATA_WIDTH];
        5'd23: bram_rd_data = _bram_rd_data[40*DATA_WIDTH-1 :  8*DATA_WIDTH];
        5'd24: bram_rd_data = _bram_rd_data[39*DATA_WIDTH-1 :  7*DATA_WIDTH];
        5'd25: bram_rd_data = _bram_rd_data[38*DATA_WIDTH-1 :  6*DATA_WIDTH];
        5'd26: bram_rd_data = _bram_rd_data[37*DATA_WIDTH-1 :  5*DATA_WIDTH];
        5'd27: bram_rd_data = _bram_rd_data[36*DATA_WIDTH-1 :  4*DATA_WIDTH];
        5'd28: bram_rd_data = _bram_rd_data[35*DATA_WIDTH-1 :  3*DATA_WIDTH];
        5'd29: bram_rd_data = _bram_rd_data[34*DATA_WIDTH-1 :  2*DATA_WIDTH];
        5'd30: bram_rd_data = _bram_rd_data[33*DATA_WIDTH-1 :  1*DATA_WIDTH];
        5'd31: bram_rd_data = _bram_rd_data[32*DATA_WIDTH-1 :  0*DATA_WIDTH];
      endcase
    end else begin
      bram_rd_data = {(32*DATA_WIDTH){1'b0}};
    end
  end

endmodule
