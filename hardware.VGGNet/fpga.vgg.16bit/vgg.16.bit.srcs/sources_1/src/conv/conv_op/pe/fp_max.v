// ---------------------------------------------------
// File       : fp_max.v
//
// Description: compare two float number
//
// Version    : 1.0
// ---------------------------------------------------

module fp_max#(
          parameter EXPONENT = 5,
          parameter MANTISSA = 10 
      )(
        // input data
        input  wire [EXPONENT+MANTISSA : 0] a1,
        input  wire [EXPONENT+MANTISSA : 0] a2,
        input  wire                         en,
        // output data
        output wire [EXPONENT+MANTISSA : 0] max_o
      );

  localparam DATA_WIDTH = EXPONENT+MANTISSA+1;

  reg  _m; // larger data index, 0 -- a1, 1 -- a2
  assign max_o = _m ? a2 : a1;
  wire [DATA_WIDTH-1:0] _diff; // result of a minus b
  assign _diff = {1'b0,a1[DATA_WIDTH-2:0]} - {1'b0,a2[DATA_WIDTH-2:0]};

  always@(a1 or a2 or _diff or en) begin
    if(en) begin
      if(a1[DATA_WIDTH-1] == a2[DATA_WIDTH-1]) begin
        if(a1[DATA_WIDTH-1] == 1'b0) begin
        // positive values
          if(_diff[DATA_WIDTH-1] == 1'b0) begin
            _m = 1'b0;
          end else begin
            _m = 1'b1;
          end
        end else begin
        // negative values
          if(_diff[DATA_WIDTH-1] == 1'b1) begin
            _m = 1'b0;
          end else begin
            _m = 1'b1;
          end
        end
      end else begin
        if(a1[DATA_WIDTH-1] == 1'b0) begin
        // a1 is positive
          _m = 1'b0;
        end else begin
          _m = 1'b1;
        end
      end
    end else begin
      _m = 1'b0;
    end
  end

endmodule
