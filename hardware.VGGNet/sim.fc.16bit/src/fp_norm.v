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
        /*-------------------------------------------------
        output num_zeros, // simulation
        //-------------------------------------------------
         */
        output reg  [MANTISSA+EXPONENT : 0] sum_o
      );

  localparam a_width    = MANTISSA+1+2; // width of sum after rounding (_sum)
  // addr_width should be less than EXPONENT
  localparam addr_width = log(a_width)-1;
  `include "misc.v"
  `include "DW_lzd_function.inc"

  wire [MANTISSA+4:0]   _sum_round; // rounded value
  wire [MANTISSA+4:0]   _sum_shift; // shifted value
  wire [MANTISSA+2:0]   _sum;
  wire                  _sum_is_zero;
  wire [addr_width:0]   num_zeros;

  // sign bit
  //sum_o[MANTISSA+EXPONENT] = sum_sign;

  // mantissa
  // leading zero check
  assign num_zeros = DWF_lzd_enc(sum_unsigned[MANTISSA+4:2]);
  // left shift
  fp_lshift#(
      .DATAWIDTH(a_width+2),
      .SHIFTWIDTH(addr_width+1) // log(a_width)
    ) sum_lshift(
    .val(sum_unsigned),
    .count(num_zeros),
    .val_o(_sum_shift)
  );
  // rounding, add 2'b10 to mantissa, roundTieToAway, round to larger magnitude
  assign _sum_round = _sum_shift + 2'b10;
  assign _sum = _sum_round[MANTISSA+4:2];

  assign _sum_is_zero = (_sum[MANTISSA+2] == 1'b0);

  // exponent
  generate
    if(EXPONENT >= (addr_width+1)) begin
      wire [EXPONENT : 0] _exp_sum; // expand 1 bit to the left
      wire [EXPONENT : 0] _exp; // expand 1 bit to the left
      // exponent overflow
      assign _exp_sum = {1'b0,sum_exp} + {{(EXPONENT-1){1'b0}},2'b10};
      // exponent underflow
      assign _exp     = _exp_sum - {{(EXPONENT-addr_width){1'b0}},num_zeros[addr_width:0]};
      // exception handling
      always@(_exp or _sum or _exp_sum or sum_sign or _sum_is_zero) begin
        // overflow
        if((_exp_sum[EXPONENT] == 1'b1) && (_exp[EXPONENT]==1'b1)) begin // inf
          sum_o[MANTISSA+EXPONENT]            = sum_sign;
          sum_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b1}};
          sum_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
        // underflow
        end else if(((_exp_sum[EXPONENT] == 1'b0) && (_exp[EXPONENT]==1'b1)) || _sum_is_zero) begin // zero
          sum_o[MANTISSA+EXPONENT]            = sum_sign;
          sum_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b0}};
          sum_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
        end else begin // exp={EXP{1'b0}}, man={1'b1,{MAN{1'b0}}} is also considered zero
          sum_o[MANTISSA+EXPONENT]            = sum_sign;
          sum_o[MANTISSA+EXPONENT-1:MANTISSA] = _exp[EXPONENT-1:0];
          sum_o[MANTISSA-1:0]                 = _sum[MANTISSA+1:2];
        end
      end
    end else begin
      wire [addr_width:0] _diff; // difference of sum_exp and num_zeros
      reg                 _zero;
      wire [EXPONENT : 0] _exp_sum; // expand 1 bit to the left
      wire [EXPONENT : 0] _exp; // expand 1 bit to the left
      assign _diff = num_zeros - {{(addr_width+1-EXPONENT){1'b0}},sum_exp};
      always@(_diff) begin
        if((_diff[addr_width] == 1'b1) && (num_zeros[addr_width]!=1'b1)) begin
          _zero = 1'b0;
        end else begin
          // underflow
          _zero = 1'b1;
        end
      end
      assign _exp_sum = (_zero == 1'b0) ? {1'b0,sum_exp} + {{(EXPONENT-1){1'b0}},2'b10} : {(EXPONENT+1){1'b0}};
      assign _exp     = (_zero == 1'b0) ? _exp_sum - num_zeros[EXPONENT:0] : {(EXPONENT+1){1'b0}};
      // exception handling
      always@(_exp or _sum or _exp_sum or sum_sign or _sum_is_zero) begin
        if((_exp_sum[EXPONENT] == 1'b1) && (_exp[EXPONENT]==1'b1)) begin // inf
          sum_o[MANTISSA+EXPONENT]            = sum_sign;
          sum_o[MANTISSA+EXPONENT-1:MANTISSA] = {EXPONENT{1'b1}};
          sum_o[MANTISSA-1:0]                 = {MANTISSA{1'b0}};
        end else begin
          sum_o[MANTISSA+EXPONENT]            = sum_sign;
          if((_zero == 1'b1) || _sum_is_zero) begin
            sum_o[MANTISSA+EXPONENT-1:MANTISSA] = {EXPONENT{1'b0}};
            sum_o[MANTISSA-1:0] = {MANTISSA{1'b0}};
          end else begin
            sum_o[MANTISSA-1:0] = _sum[MANTISSA+1:2];
            sum_o[MANTISSA+EXPONENT-1:MANTISSA] = _exp[EXPONENT-1:0];
          end
        end
      end
    end
  endgenerate

endmodule
