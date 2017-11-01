// ---------------------------------------------------
// File       : pe_array1x3.v
//
// Description: 1 dim(1x3) processing element array
//
// Version    : 1.0
// ---------------------------------------------------
module pe_array1x3#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        input  wire [3*(1+MANTISSA+EXPONENT)-1:0] pe_ker3_i,
        input  wire [MANTISSA+EXPONENT:0]         pe_bias_i,
        input  wire [3*(1+MANTISSA+EXPONENT)-1:0] pe_data3_i,
        input  wire                               clk,
        input  wire                               pe_on_3mul_pe_en,
        input  wire                               pe_on_align3,
        input  wire                               pe_on_sum3,
        input  wire                               pe_on_bias,
        output reg  [MANTISSA+EXPONENT:0]         pe_data_o
      );

  wire [MANTISSA+EXPONENT:0] _mul_h;
  wire [MANTISSA+EXPONENT:0] _mul_m;
  wire [MANTISSA+EXPONENT:0] _mul_l;
  reg  [MANTISSA+EXPONENT:0] _mul_h_sync;
  reg  [MANTISSA+EXPONENT:0] _mul_m_sync;
  reg  [MANTISSA+EXPONENT:0] _mul_l_sync;
  wire [MANTISSA+EXPONENT:0] _adder3;
  reg  [MANTISSA+EXPONENT:0] _adder3_sync;
  wire [MANTISSA+EXPONENT:0] _add_bias;

  // 3 multiply
  fp_mul2#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) pe_mul_h(
        .A(pe_data3_i[3*(1+MANTISSA+EXPONENT)-1:2*(1+MANTISSA+EXPONENT)]),
        .B(pe_ker3_i[3*(1+MANTISSA+EXPONENT)-1:2*(1+MANTISSA+EXPONENT)]),
        .C(_mul_h)
      );

  fp_mul2#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) pe_mul_m(
        .A(pe_data3_i[2*(1+MANTISSA+EXPONENT)-1: 1+MANTISSA+EXPONENT]),
        .B(pe_ker3_i[2*(1+MANTISSA+EXPONENT)-1: 1+MANTISSA+EXPONENT]),
        .C(_mul_m)
      );

  fp_mul2#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) pe_mul_l(
        .A(pe_data3_i[MANTISSA+EXPONENT:0]),
        .B(pe_ker3_i[MANTISSA+EXPONENT:0]),
        .C(_mul_l)
      );

  always@(posedge clk) begin
    if(pe_on_3mul_pe_en) begin
      _mul_h_sync <= _mul_h;
      _mul_m_sync <= _mul_m;
      _mul_l_sync <= _mul_l;
    end else begin
      _mul_h_sync <= {(1+MANTISSA+EXPONENT){1'b0}};  //_mul_h;
      _mul_m_sync <= {(1+MANTISSA+EXPONENT){1'b0}};  //_mul_m;
      _mul_l_sync <= {(1+MANTISSA+EXPONENT){1'b0}};  //_mul_l;
    end
  end

  // alignment synchronization in fp_adder3
  // sum 3
  fp_adder3#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) pe_adder3(
        .clk(clk),
        .sync(pe_on_align3),
        .a1(_mul_h_sync),
        .a2(_mul_m_sync),
        .a3(_mul_l_sync),
        .adder_o(_adder3)
      );

  always@(posedge clk) begin
    if(pe_on_sum3) begin
      _adder3_sync <= _adder3;
    end else begin
      _adder3_sync <= {(1+MANTISSA+EXPONENT){1'b0}};
    end
  end

  // add bias
  fp_adder2#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) pe_add_bias(
        .a1(_adder3_sync),
        .a2(pe_bias_i),
        .adder_o(_add_bias)
      );

  always@(posedge clk) begin
    if(pe_on_bias) begin
      pe_data_o <= _add_bias;
    end else begin
      pe_data_o <= {(1+MANTISSA+EXPONENT){1'b0}};
    end
  end

endmodule
