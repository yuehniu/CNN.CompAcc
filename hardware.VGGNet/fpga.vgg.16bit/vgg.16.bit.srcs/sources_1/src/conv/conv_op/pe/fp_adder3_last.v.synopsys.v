// ---------------------------------------------------
// File       : fp_adder3_last.v.synopsys.v
//
// Description: 3-operand adder
//
// Version    : 1.0
// ---------------------------------------------------

module fp_adder3_last#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23
      )(
        input  wire                         clk,
        // input data
        input  wire                         en,
        input  wire [EXPONENT+MANTISSA : 0] a1,
        input  wire [EXPONENT+MANTISSA : 0] a2,
        input  wire [EXPONENT+MANTISSA : 0] a3,
        // output data
        output wire                         valid,
        output wire [EXPONENT+MANTISSA : 0] adder_o
      );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  wire[DATA_WIDTH-1 : 0] _sum2;
  wire[DATA_WIDTH-1 : 0] _sum3;
  wire                   _sum2_valid;

  fp_adder2_6 sum_2_value (
    .aclk(clk),
    .s_axis_a_tvalid(en),
    .s_axis_a_tdata(a1),
    .s_axis_b_tvalid(en),
    .s_axis_b_tdata(a2),
    .m_axis_result_tvalid(_sum2_valid),
    .m_axis_result_tdata(_sum2)
  );

  reg [DATA_WIDTH-1 : 0] _a3_1;
  reg [DATA_WIDTH-1 : 0] _a3_2;
  reg [DATA_WIDTH-1 : 0] _a3_3;
  reg [DATA_WIDTH-1 : 0] _a3_4;
  reg [DATA_WIDTH-1 : 0] _a3_5;
  reg [DATA_WIDTH-1 : 0] _a3_6;
  reg [DATA_WIDTH-1 : 0] _a3_7;
  wire[DATA_WIDTH-1 : 0] _a3;
  always@(posedge clk) begin
    // delay for a3
    if(en) begin
      _a3_1 <= a3;
  //end else begin
  //  _a3_1 <= {(DATA_WIDTH){1'b0}};
    end
  end
  always@(posedge clk) begin
    _a3_2   <= _a3_1;
    _a3_3   <= _a3_2;
    _a3_4   <= _a3_3;
    _a3_5   <= _a3_4;
    _a3_6   <= _a3_5;
    _a3_7   <= _a3_6;
  end
  assign _a3 = _a3_6;

  fp_adder2_6 sum_3rd (
    .aclk(clk),
    .s_axis_a_tvalid(_sum2_valid),
    .s_axis_a_tdata(_sum2),
    .s_axis_b_tvalid(_sum2_valid),
    .s_axis_b_tdata(_a3),
    .m_axis_result_tvalid(valid),
    .m_axis_result_tdata(adder_o)
  );

endmodule
