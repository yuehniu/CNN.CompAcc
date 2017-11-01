// ---------------------------------------------------
// File       : fp_adder3.v
//
// Description: 3-operand adder
//
// Version    : 1.0
// ---------------------------------------------------

module fp_adder3#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        input  wire clk,
        input  wire sync,
        // input data
        input  wire [EXPONENT+MANTISSA : 0] a1,
        input  wire [EXPONENT+MANTISSA : 0] a2,
        input  wire [EXPONENT+MANTISSA : 0] a3,
        // output data
        output reg  [EXPONENT+MANTISSA : 0] adder_o
      );

  wire [MANTISSA+2 : 0]   _a1_man_un;
  wire [MANTISSA+2 : 0]   _a2_man_un;
  wire [MANTISSA+2 : 0]   _a3_man_un;
  wire [EXPONENT-1 : 0]   _exp;
  wire                    _a1_sign;
  wire                    _a2_sign;
  wire                    _a3_sign;
  // sych
  reg  [MANTISSA+2 : 0]   _a1_man_un_sync;
  reg  [MANTISSA+2 : 0]   _a2_man_un_sync;
  reg  [MANTISSA+2 : 0]   _a3_man_un_sync;
  reg  [EXPONENT-1 : 0]   _exp_sync;
  reg                     _a1_sign_sync;
  reg                     _a2_sign_sync;
  reg                     _a3_sign_sync;
  // sum 3 number
  wire [MANTISSA+4 : 0]   _sum_man_un;
  wire                    _sum_sign;

  // alignment
  fp_align3#(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
    ) align3num(
      .a1(a1),
      .a2(a2),
      .a3(a3),
      .a1_mantissa_unsigned(_a1_man_un),
      .a2_mantissa_unsigned(_a2_man_un),
      .a3_mantissa_unsigned(_a3_man_un),
      .a1_sign(_a1_sign),
      .a2_sign(_a2_sign),
      .a3_sign(_a3_sign),
      .max_exp(_exp)
    );

  // synchronize/enable
  always@(posedge clk) begin
    if(sync) begin
      _a1_man_un_sync <= _a1_man_un;
      _a2_man_un_sync <= _a2_man_un;
      _a3_man_un_sync <= _a3_man_un;
      _exp_sync       <= _exp;
      _a1_sign_sync   <= _a1_sign;
      _a2_sign_sync   <= _a2_sign;
      _a3_sign_sync   <= _a3_sign;
    end else begin
      _a1_man_un_sync <= {(MANTISSA+3){1'b0}};  //_a1_man_un;
      _a2_man_un_sync <= {(MANTISSA+3){1'b0}};  //_a2_man_un;
      _a3_man_un_sync <= {(MANTISSA+3){1'b0}};  //_a3_man_un;
      _exp_sync       <= {EXPONENT{1'b0}};  //_exp;
      _a1_sign_sync   <= 1'b0;  //_a1_sign;
      _a2_sign_sync   <= 1'b0;  //_a2_sign;
      _a3_sign_sync   <= 1'b0;  //_a3_sign;
    end
  end

  // sum 3 number
  fp_sum3#(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
    ) sum3num(
      .a1_mantissa_unsigned(_a1_man_un_sync),
      .a2_mantissa_unsigned(_a2_man_un_sync),
      .a3_mantissa_unsigned(_a3_man_un_sync),
      .a1_sign(_a1_sign_sync),
      .a2_sign(_a2_sign_sync),
      .a3_sign(_a3_sign_sync),
      .sum_unsigned(_sum_man_un),
      .sum_sign(_sum_sign)
    );

  // normalization
  fp_norm#(
      .EXPONENT(EXPONENT),
      .MANTISSA(MANTISSA)
    ) norm3num(
      .sum_sign(_sum_sign),
      .sum_unsigned(_sum_man_un),
      .sum_exp(_exp_sync),
      .sum_o(adder_o)
    );

endmodule
