// ---------------------------------------------------
// File       : fp_align3.v
//
// Description: align mantissa part of 3 float point input
//
// Version    : 1.0
// ---------------------------------------------------

module fp_align3#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        // input data
        input  wire [EXPONENT+MANTISSA : 0] a1,
        input  wire [EXPONENT+MANTISSA : 0] a2,
        input  wire [EXPONENT+MANTISSA : 0] a3,
        // mantissa of a1, append 2 bit to the end, unsigned value
        output reg  [MANTISSA+2 : 0]        a1_mantissa_unsigned,
        output reg  [MANTISSA+2 : 0]        a2_mantissa_unsigned,
        output reg  [MANTISSA+2 : 0]        a3_mantissa_unsigned,
        output wire [EXPONENT-1 : 0]        max_exp,
        // sign bit of a1
        output wire                         a1_sign,
        output wire                         a2_sign,
        output wire                         a3_sign
      );

  // DesignWare function
  parameter num_inputs  = 3;
  parameter width       = EXPONENT;
  `include "DW_minmax_function.inc"

  // sign bit
  assign a1_sign = a1[EXPONENT+MANTISSA];
  assign a2_sign = a2[EXPONENT+MANTISSA];
  assign a3_sign = a3[EXPONENT+MANTISSA];

  // mantissa alignment
  wire [EXPONENT-1:0] _shift_a1;
  wire [EXPONENT-1:0] _shift_a2;
  wire [EXPONENT-1:0] _shift_a3;
  // maximum exponent
  assign max_exp  = DWF_max_uns({a1[EXPONENT+MANTISSA-1 : MANTISSA], a2[EXPONENT+MANTISSA-1 : MANTISSA], a3[EXPONENT+MANTISSA-1 : MANTISSA]});
  assign _shift_a1 = max_exp - a1[EXPONENT+MANTISSA-1:MANTISSA];
  assign _shift_a2 = max_exp - a2[EXPONENT+MANTISSA-1:MANTISSA];
  assign _shift_a3 = max_exp - a3[EXPONENT+MANTISSA-1:MANTISSA];
  // right shift to align
  fp_rshift#(
          .SHIFTWIDTH(EXPONENT),
          .DATAWIDTH(MANTISSA+1)
      ) rshift_a1(
          .val({1'b1,a1[MANTISSA-1:0]}),
          .count(_shift_a1),
          .val_o(a1_mantissa_unsigned)
      );

  fp_rshift#(
          .SHIFTWIDTH(EXPONENT),
          .DATAWIDTH(MANTISSA+1)
      ) rshift_a2(
          .val({1'b1,a2[MANTISSA-1:0]}),
          .count(_shift_a2),
          .val_o(a2_mantissa_unsigned)
      );

  fp_rshift#(
          .SHIFTWIDTH(EXPONENT),
          .DATAWIDTH(MANTISSA+1)
      ) rshift_a3(
          .val({1'b1,a3[MANTISSA-1:0]}),
          .count(_shift_a3),
          .val_o(a3_mantissa_unsigned)
      );


endmodule
