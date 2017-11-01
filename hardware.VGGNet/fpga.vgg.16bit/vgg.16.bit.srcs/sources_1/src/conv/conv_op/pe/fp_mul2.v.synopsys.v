// ---------------------------------------------------
// File       : fp_mul2.v.synopsys.v
//
// Description: 2-operand adder
//
// Version    : 1.0
// ---------------------------------------------------

module fp_mul2 #(
        parameter EXPONENT   = 5,
        parameter MANTISSA   = 10
      ) (
        input  wire                         aclk,
        // input data
        input  wire                         s_axis_a_tvalid,
        input  wire [EXPONENT+MANTISSA : 0] s_axis_a_tdata,
        input  wire                         s_axis_b_tvalid,
        input  wire [EXPONENT+MANTISSA : 0] s_axis_b_tdata,
        // output data
        output wire                         m_axis_result_tvalid,
        output wire [EXPONENT+MANTISSA : 0] m_axis_result_tdata
      );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;
  wire[DATA_WIDTH-1 : 0] _mul2;
  wire[DATA_WIDTH-1 : 0] _mul2_0;
  reg [DATA_WIDTH-1 : 0] _mul2_1;
  reg [DATA_WIDTH-1 : 0] _mul2_2;
  reg [DATA_WIDTH-1 : 0] _mul2_3;
  reg [DATA_WIDTH-1 : 0] _mul2_4;
  reg [DATA_WIDTH-1 : 0] _mul2_5;
  wire                   _valid_0;
  reg                    _valid_1;
  reg                    _valid_2;
  reg                    _valid_3;
  reg                    _valid_4;
  reg                    _valid_5;

  DW_fp_mult #(
        .sig_width(MANTISSA),
        .exp_width(EXPONENT),
        .ieee_compliance(1)
      ) pe_mul_h (
        .a(s_axis_a_tdata),
        .b(s_axis_b_tdata),
        .rnd(3'b000),
        .z(_mul2),
        .status()
      );
  assign _valid_0 = s_axis_a_tvalid && s_axis_b_tvalid;
  assign _mul2_0  = (s_axis_a_tvalid && s_axis_b_tvalid) ? _mul2 : {(DATA_WIDTH){1'b0}};

  assign m_axis_result_tvalid = _valid_4;
  assign m_axis_result_tdata  = _mul2_4;

  // 1 clock delay
  always@(posedge aclk) begin
    _mul2_1 <= _mul2_0;
    _mul2_2 <= _mul2_1;
    _mul2_3 <= _mul2_2;
    _mul2_4 <= _mul2_3;
    _mul2_5 <= _mul2_4;
    _valid_1  <= _valid_0;
    _valid_2  <= _valid_1;
    _valid_3  <= _valid_2;
    _valid_4  <= _valid_3;
    _valid_5  <= _valid_4;
  end

endmodule
