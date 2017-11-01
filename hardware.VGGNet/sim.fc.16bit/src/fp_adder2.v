// ---------------------------------------------------
// File       : fp_adder2.v
//
// Description: 2-operand adder
//
// Version    : 1.0
// ---------------------------------------------------

module fp_adder2#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        // input data
        input  wire [EXPONENT+MANTISSA : 0] a1,
        input  wire [EXPONENT+MANTISSA : 0] a2,

        /* ----------------------
        output wire                         add_sign,
        // ----------------------
        */

        // output data
        output reg  [EXPONENT+MANTISSA : 0] adder_o
      );

  localparam a_width    = MANTISSA+1+2; // width of sum after rounding (_sum)
  // addr_width should be less than EXPONENT
  localparam addr_width = log(a_width)-1;
  `include "misc.v"
  `include "DW_lzd_function.inc"
  wire [addr_width:0]   num_zeros;

  wire [EXPONENT+MANTISSA : 0] _large; // magnitude is larger
  wire [EXPONENT+MANTISSA : 0] _small;
  wire [MANTISSA+5:0] _large_expand_signed;
  wire [MANTISSA+5:0] _small_expand_signed;
  wire [MANTISSA+2:0] _small_expand;
  wire [MANTISSA+5:0] _sum_signed;
  wire [MANTISSA+4:0] _sum_shift; // shifted value
  wire [MANTISSA+4:0] _sum_round; // rounded value
  wire [MANTISSA+4:0] _sum_unsigned; // unsigned value
  wire [MANTISSA+2:0] _sum;
  wire                _sum_is_zero;
  wire                _sum_sign;
  // compare exponent
  wire [EXPONENT:0] _exp_a1;
  wire [EXPONENT:0] _exp_a2;
  wire [EXPONENT:0] _exp_diff;
  wire [EXPONENT:0] _max_exp;
  wire [EXPONENT-1:0] _exp_shift;
  assign _exp_a1 = {1'b0, a1[MANTISSA+EXPONENT-1:MANTISSA]};
  assign _exp_a2 = {1'b0, a2[MANTISSA+EXPONENT-1:MANTISSA]};
  assign _exp_diff = _exp_a1 - _exp_a2;
  assign _large  = (_exp_diff[EXPONENT] == 1'b1) ? a2 : a1;
  assign _small  = (_exp_diff[EXPONENT] == 1'b1) ? a1 : a2;
  assign _max_exp  = {1'b0, _large[MANTISSA+EXPONENT-1:MANTISSA]}; //(_exp_diff[EXPONENT] == 1'b1) ? {1'b0,a2[MANTISSA+EXPONENT-1:MANTISSA]} : {1'b0,a1[MANTISSA+EXPONENT-1:MANTISSA]};
  assign _exp_shift= (_exp_diff[EXPONENT] == 1'b1) ? (_exp_diff[EXPONENT-1:0] ^ {EXPONENT{1'b1}}) + 1'b1 : _exp_diff[EXPONENT-1:0];
  // alignment
  fp_rshift#(
      .SHIFTWIDTH(EXPONENT),
      .DATAWIDTH(MANTISSA+1)
    ) rshift(
      .val({1'b1,_small[MANTISSA-1:0]}),
      .count(_exp_shift),
      .val_o(_small_expand)
    );
  // sum 2
  assign _large_expand_signed = (_large[MANTISSA+EXPONENT] == 1'b0) ? {4'b0001,_large[MANTISSA-1:0],2'b0} : ({4'b0001,_large[MANTISSA-1:0],2'b0} ^ {(MANTISSA+6){1'b1}}) + 1'b1;
  assign _small_expand_signed = (_small[MANTISSA+EXPONENT] == 1'b0) ? {3'b0,_small_expand} : ({3'b0,_small_expand} ^ {(MANTISSA+6){1'b1}}) + 1'b1;
  assign _sum_signed   = _large_expand_signed + _small_expand_signed;

  // normalize
  assign _sum_sign     = _sum_signed[MANTISSA+5];
  assign _sum_unsigned = (_sum_signed[MANTISSA+5] == 1'b0) ? _sum_signed[MANTISSA+4:0] : (_sum_signed[MANTISSA+4:0] ^ {(MANTISSA+5){1'b1}}) + 1'b1;
  assign num_zeros = DWF_lzd_enc(_sum_unsigned[MANTISSA+4:2]);
  fp_lshift#(
      .DATAWIDTH(a_width+2),
      .SHIFTWIDTH(addr_width+1) // log(a_width)
    ) lshift(
      .val(_sum_unsigned),
      .count(num_zeros),
      .val_o(_sum_shift)
    );
  // + 2'b10 rounding
  assign _sum_round   = _sum_shift + 2'b10;
  assign _sum         = _sum_round[MANTISSA+4:2];
  assign _sum_is_zero = (_sum[MANTISSA+2]==1'b0);

  // exponent
  generate
    if(EXPONENT >= (addr_width+1)) begin
      wire [EXPONENT : 0] _exp_sum; // expand 1 bit to the left
      wire [EXPONENT : 0] _exp; // expand 1 bit to the left
      // exponent overflow
      assign _exp_sum = _max_exp + {{(EXPONENT-1){1'b0}},2'b10};
      // exponent underflow
      assign _exp     = _exp_sum - {{(EXPONENT-addr_width){1'b0}},num_zeros[addr_width:0]};
      // exception handling
      always@(_exp or _sum or _exp_sum or _sum_sign or _sum_is_zero) begin
        // overflow
        if((_exp_sum[EXPONENT] == 1'b1) && (_exp[EXPONENT]==1'b1)) begin // inf
          adder_o[MANTISSA+EXPONENT]            = _sum_sign;
          adder_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b1}};
          adder_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
        // underflow
        end else if(((_exp_sum[EXPONENT] == 1'b0) && (_exp[EXPONENT]==1'b1)) || _sum_is_zero) begin // zero
          adder_o[MANTISSA+EXPONENT]            = _sum_sign;
          adder_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b0}};
          adder_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
        end else begin // exp={EXP{1'b0}}, man={1'b1,{MAN{1'b0}}} is also considered zero
          adder_o[MANTISSA+EXPONENT]            = _sum_sign;
          adder_o[MANTISSA+EXPONENT-1:MANTISSA] = _exp[EXPONENT-1:0];
          adder_o[MANTISSA-1:0]                 = _sum[MANTISSA+1:2];
        end
      end

    end else begin
      wire [addr_width:0] _diff; // difference of _max_exp and num_zeros
      reg                 _zero;
      wire [EXPONENT : 0] _exp_sum; // expand 1 bit to the left
      wire [EXPONENT : 0] _exp; // expand 1 bit to the left
      assign _diff = num_zeros - {{(addr_width-EXPONENT){1'b0}},_max_exp};
      always@(_diff) begin
        if((_diff[addr_width] == 1'b1) && (num_zeros[addr_width]!=1'b1)) begin
          _zero = 1'b0;
        end else begin
          // underflow
          _zero = 1'b1;
        end
      end
      assign _exp_sum = (_zero == 1'b0) ? {1'b0,_max_exp} + {{(EXPONENT-1){1'b0}},2'b10} : {(EXPONENT+1){1'b0}};
      assign _exp     = (_zero == 1'b0) ? _exp_sum - num_zeros[EXPONENT:0] : {(EXPONENT+1){1'b0}};
      // exception handling
      always@(_exp or _sum or _exp_sum or _sum_sign or _sum_is_zero) begin
        if((_exp_sum[EXPONENT] == 1'b1) && (_exp[EXPONENT]==1'b1)) begin // inf
          adder_o[MANTISSA+EXPONENT]            = _sum_sign;
          adder_o[MANTISSA+EXPONENT-1:MANTISSA] = {(EXPONENT){1'b1}};
          adder_o[MANTISSA-1:0]                 = {(MANTISSA){1'b0}};
        end else begin
          adder_o[MANTISSA+EXPONENT]            = _sum_sign;
          if((_zero == 1'b1) || _sum_is_zero) begin
            adder_o[MANTISSA-1:0] = {MANTISSA{1'b0}};
            adder_o[MANTISSA+EXPONENT-1:MANTISSA] = {EXPONENT{1'b0}};
          end else begin
            adder_o[MANTISSA-1:0] = _sum[MANTISSA+1:2];
            adder_o[MANTISSA+EXPONENT-1:MANTISSA] = _exp[EXPONENT-1:0];
          end
        end
      end
    end
  endgenerate

endmodule
