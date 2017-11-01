// ---------------------------------------------------
// File       : fp_mul2.v
//
// Description: float point multiplication, comply with
//              IEEE 754 standard
//              09/13: extend 2 bit to the end of signifcand;
//                     extend 1 bit to the MSB of _sigC_round
//                     to avoid adding overflow
//
// Version    : 1.1
// ---------------------------------------------------

module fp_mul2 #(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        input  wire [EXPONENT+MANTISSA : 0] A,
        input  wire [EXPONENT+MANTISSA : 0] B,
        /*
        output                       _expOutput,
         */
        output reg  [EXPONENT+MANTISSA : 0] C
      );

  wire [EXPONENT:0]     _expSum;
  wire [EXPONENT:0]     _expBias;
  wire [EXPONENT:0]     _expC;
  wire [MANTISSA+2:0]   _sigA;
  wire [MANTISSA+2:0]   _sigB;
  wire [MANTISSA+1+1:0] _sigC_round;
  wire [MANTISSA:0]     _sigC;
  wire                  _sign;
  wire [(MANTISSA+3)*2-1:0] _sigMul;  // expand 2 bit to the end

  // sign bit
  assign _sign = A[EXPONENT+MANTISSA] ^ B[EXPONENT+MANTISSA];
  // mantissa(significand)
  assign _sigA = {1'b1, A[MANTISSA-1:0], 2'b0};
  assign _sigB = {1'b1, B[MANTISSA-1:0], 2'b0};
  assign _sigMul = _sigA * _sigB;
  // expand 1 bit to the MSB of _sigC_round
  assign _sigC_round = (_sigMul[MANTISSA*2+5]) ? {1'b0,_sigMul[MANTISSA*2+5:MANTISSA+4]} + 1'b1 : {1'b0,_sigMul[MANTISSA*2+4:MANTISSA+3]} + 1'b1;
  assign _sigC = (_sigC_round[MANTISSA+2] == 1'b0) ? _sigC_round[MANTISSA+1:1] : _sigC_round[MANTISSA+2:2];

  /*
    wire [MANTISSA:0] _expOutput; //[(MANTISSA+3)*2-1:0]
    assign _expOutput = _sigC;
   */
  // exponent
  // expA + expB
  assign _expSum = {1'b0, A[EXPONENT+MANTISSA-1:MANTISSA]} + {1'b0, B[EXPONENT+MANTISSA-1:MANTISSA]};
  // _expSum - {1'b0, (EXPONENT-1){1'b1}}
  assign _expBias= _expSum + {2'b11, {(EXPONENT-2){1'b0}}, 1'b1};
  // _expBias + carrier from multiplication of mantissa
  assign _expC   = _expBias + {{(EXPONENT){1'b0}}, _sigMul[MANTISSA*2+5]} + {{(EXPONENT){1'b0}}, _sigC_round[MANTISSA+2]};

  always@( A or B or _sign or _expC or _sigC) begin
    // out of range
    if( (A[EXPONENT+MANTISSA-1] == 1'b0) && (B[EXPONENT+MANTISSA-1] == 1'b0)
        && (_expC[EXPONENT-1] == 1'b1) ) begin

      C = {_sign, {(EXPONENT+MANTISSA){1'b0}}};

    end else if( (A[EXPONENT+MANTISSA-1] == 1'b1) && (B[EXPONENT+MANTISSA-1] == 1'b1)
                 && (_expC[EXPONENT-1] == 1'b0) ) begin

      C = {_sign, {(EXPONENT+MANTISSA){1'b1}}};

    end else begin
      C = {_sign, _expC[EXPONENT-1:0], _sigC[MANTISSA-1:0]};
    end
  end

endmodule
