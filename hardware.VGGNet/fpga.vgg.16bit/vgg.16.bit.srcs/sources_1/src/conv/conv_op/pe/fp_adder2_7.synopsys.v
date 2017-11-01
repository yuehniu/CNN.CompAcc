// ---------------------------------------------------
// File       : fp_adder2_7.synopsys.v
//
// Description: 2-operand adder
//
// Version    : 1.0
// ---------------------------------------------------

module fp_adder2_7 #(
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
        output reg                          m_axis_result_tvalid,
        output reg  [EXPONENT+MANTISSA : 0] m_axis_result_tdata
      );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  wire[DATA_WIDTH-1 : 0] _sum;

  DW_fp_add #(
        .sig_width(MANTISSA),
        .exp_width(EXPONENT),
        .ieee_compliance(1)
      ) sum_2_value (
        .a(s_axis_a_tdata),
        .b(s_axis_b_tdata),
        .rnd(3'b000),
        .z(_sum),
        .status()
      );

  // 4 clock delay
  wire[DATA_WIDTH-1 : 0]  _sum_0;
  reg [DATA_WIDTH-1 : 0]  _sum_1;
  reg [DATA_WIDTH-1 : 0]  _sum_2;
  reg [DATA_WIDTH-1 : 0]  _sum_3;
  reg [DATA_WIDTH-1 : 0]  _sum_4;
  reg [DATA_WIDTH-1 : 0]  _sum_5;
  reg [DATA_WIDTH-1 : 0]  _sum_6;
  reg [DATA_WIDTH-1 : 0]  _sum_7;
  wire                    _en_0;
  reg                     _en_1;
  reg                     _en_2;
  reg                     _en_3;
  reg                     _en_4;
  reg                     _en_5;
  reg                     _en_6;
  reg                     _en_7;
  assign _sum_0 = (s_axis_a_tvalid && s_axis_b_tvalid) ? _sum : {(DATA_WIDTH){1'b0}};
  assign _en_0  = s_axis_a_tvalid && s_axis_b_tvalid;

  assign m_axis_result_tvalid = _en_7;
  assign m_axis_result_tdata  = _sum_7;

  always@(posedge aclk) begin
    _sum_1  <= _sum_0;
    _sum_2  <= _sum_1;
    _sum_3  <= _sum_2;
    _sum_4  <= _sum_3;
    _sum_5  <= _sum_4;
    _sum_6  <= _sum_5;
    _sum_7  <= _sum_6;
    _en_1   <= _en_0;
    _en_2   <= _en_1;
    _en_3   <= _en_2;
    _en_4   <= _en_3;
    _en_5   <= _en_4;
    _en_6   <= _en_5;
    _en_7   <= _en_6;
  end

endmodule
