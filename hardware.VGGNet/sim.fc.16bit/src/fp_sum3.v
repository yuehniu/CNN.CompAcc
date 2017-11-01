// ---------------------------------------------------
// File       : fp_sum3.v
//
// Description: add up mantissa part of three float
//              point input.
//
// Version    : 1.0
// ---------------------------------------------------
module fp_sum3#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        // unsigned input, (absolute value)
        input  wire [MANTISSA+2 : 0] a1_mantissa_unsigned,
        input  wire [MANTISSA+2 : 0] a2_mantissa_unsigned,
        input  wire [MANTISSA+2 : 0] a3_mantissa_unsigned,
        input  wire                  a1_sign,
        input  wire                  a2_sign,
        input  wire                  a3_sign,
        // expand 2 bit to the beginning of the result
        output wire [MANTISSA+4 : 0] sum_unsigned,
        output wire                  sum_sign
      );

  // signed value
  wire [MANTISSA+5:0] _a1_signed;
  wire [MANTISSA+5:0] _a2_signed;
  wire [MANTISSA+5:0] _a3_signed;
  reg  [MANTISSA+5:0] _sum_signed;
  // 2's complement
  assign _a1_signed = (a1_sign == 1'b0) ? {3'b0,a1_mantissa_unsigned} : (({3'b0,a1_mantissa_unsigned} ^ {(MANTISSA+6){1'b1}}) + 1'b1);
  assign _a2_signed = (a2_sign == 1'b0) ? {3'b0,a2_mantissa_unsigned} : (({3'b0,a2_mantissa_unsigned} ^ {(MANTISSA+6){1'b1}}) + 1'b1);
  assign _a3_signed = (a3_sign == 1'b0) ? {3'b0,a3_mantissa_unsigned} : (({3'b0,a3_mantissa_unsigned} ^ {(MANTISSA+6){1'b1}}) + 1'b1);

  // add up three values
  always@( _a1_signed or _a2_signed or _a3_signed) begin
    _sum_signed = _a1_signed + _a2_signed + _a3_signed;
  end

  assign sum_sign     = _sum_signed[MANTISSA+5];
  assign sum_unsigned = (sum_sign == 1'b0) ? _sum_signed[MANTISSA+4:0] : ((_sum_signed[MANTISSA+4:0] ^ {(MANTISSA+5){1'b1}}) + 1'b1);

endmodule
