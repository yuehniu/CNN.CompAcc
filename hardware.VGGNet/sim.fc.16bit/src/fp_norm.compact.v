// ---------------------------------------------------
// File       : fp_norm.v
//
// Description: normalize output
//
// Version    : 1.0
// ---------------------------------------------------

module fp_norm#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        // sign
        input  wire                         sum_sign,
        // mantissa
        input  wire [MANTISSA+4 : 0]        sum_unsigned,
        // exponent
        input  wire [EXPONENT-1  : 0]       sum_exp,
        output reg  [MANTISSA+EXPONENT : 0] sum_o
      );

  localparam a_width    = MANTISSA+1+2; // width of sum after rounding (_sum)
  // addr_width should be less than EXPONENT
  localparam addr_width = log(a_width);
  `include "misc.v"
  `include "DW_lzd_function.inc"

  wire [MANTISSA+4:0] _sum_round; // subject to round
  wire [MANTISSA+2:0] _sum_shift; // subject to shift
  wire [MANTISSA+2:0] _sum;
  wire [addr_width:0] num_zeros;
  wire [EXPONENT : 0] _exp_sum; // expand 1 bit to the left
  wire [EXPONENT : 0] _exp; // expand 1 bit to the left

  // sign bit
  //sum_o[MANTISSA+EXPONENT] = sum_sign;

  // mantissa
  // rounding, add 2'b2 to mantissa, roundTieToAway, round to larger magnitude
  assign _sum_round = sum_unsigned[MANTISSA+4:0] + 2'b10;
  assign _sum_shift = _sum_round[MANTISSA+4:2];
  // leading zero check
  assign num_zeros = DWF_lzd_enc(_sum_shift);
  // left shift
  fp_lshift#(
      .DATAWIDTH(a_width),
      .SHIFTWIDTH(addr_width)
    ) sum_lshift(
    .val(_sum_shift),
    .count(num_zeros[addr_width-1:0]),
    .val_o(_sum)
  );

  // exponent
  generate
    if(EXPONENT >= addr_width) begin
      // exponent overflow
      assign _exp_sum = {1'b0,sum_exp} + {{(EXPONENT-1){1'b0}},2'b10};
      // exponent underflow
      assign _exp     = _exp_sum - {{(EXPONENT-addr_width+1){1'b0}},num_zeros[addr_width-1:0]};
    end else begin
      wire [addr_width:0] _diff; // difference of sum_exp and num_zeros
      reg                 _zero;
      assign _diff = num_zeros - {{(addr_width-EXPONENT+1){1'b0}},sum_exp};
      always@(_diff) begin
        if(_diff[addr_width] == 1'b1) begin
          _zero = 1'b0;
        end else begin
          // underflow
          _zero = 1'b1;
        end
      end
      assign _exp_sum = (_zero == 1'b0) ? {1'b0,sum_exp} + {{(EXPONENT-1){1'b0}},2'b10} : {(EXPONENT+1){1'b0}};
      assign _exp     = (_zero == 1'b0) ? _exp_sum - num_zeros[EXPONENT:0] : {(EXPONENT+1){1'b0}};
    end
  endgenerate

  // exception handling
  always@(_exp or _sum or _exp_sum or sum_sign) begin
    if((_exp_sum[EXPONENT] == 1'b1) && (_exp[EXPONENT]==1'b1)) begin // inf
      sum_o[MANTISSA+EXPONENT]            = sum_sign;
      sum_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b1}};
      sum_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
    end else if((_exp_sum[EXPONENT] == 1'b0) && (_exp[EXPONENT]==1'b1)) begin // zero
      sum_o[MANTISSA+EXPONENT]            = sum_sign;
      sum_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b0}};
      sum_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
    end else begin
      sum_o[MANTISSA+EXPONENT]            = sum_sign;
      sum_o[MANTISSA+EXPONENT-1:MANTISSA] = _exp[EXPONENT-1:0];
      sum_o[MANTISSA-1:0]                 = _sum[MANTISSA+1:2];
    end
  end

endmodule
