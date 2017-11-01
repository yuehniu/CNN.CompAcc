// ---------------------------------------------------
// File       : pe_array1x3_bias.v.synopsys.v
//
// Description: 1 dim(1x3) processing element array
//
// Version    : 1.0
// ---------------------------------------------------

//`define sim_

`ifdef sim_ // {{{
  extern void     convertFpH2Fp(input bit [16*3-1:0] FpH, output bit [32*3-1:0] Fp, input bit [31:0] arrayNum);
`endif // }}}

module pe_array1x3_bias#(
          parameter EXPONENT = 5,
          parameter MANTISSA = 10
      )(
        input  wire [3*(1+MANTISSA+EXPONENT)-1:0] pe_ker3_i,
        input  wire [MANTISSA+EXPONENT:0]         pe_bias_i,
        input  wire [3*(1+MANTISSA+EXPONENT)-1:0] pe_data3_i,
        input  wire                               clk,
        input  wire                               pe_en, // start calculation
        output wire                               pe_next_partial_sum, // require next partial sum
        output wire [MANTISSA+EXPONENT:0]         pe_data_o,
        output wire                               pe_data_valid
      );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  reg   [3*DATA_WIDTH-1:0]  pe_ker3_i_reg;
  reg   [3*DATA_WIDTH-1:0]  pe_data3_i_reg;
  wire  [DATA_WIDTH-1 : 0]  _mul_h;
  wire  [DATA_WIDTH-1 : 0]  _mul_m;
  wire  [DATA_WIDTH-1 : 0]  _mul_l;
  wire  [DATA_WIDTH-1 : 0]  _adder3;
  wire                      _mul_valid;
  wire                      _sum3_valid;
  reg                       _pe_en, _req_1, _req_2, _req_3, _req_4,
                            _req_5, _req_6, _req_7, _req_8, _req_9,
                            _req_10, _req_11, _req_12, _req_13, _req_14;
  assign pe_next_partial_sum = _req_8;

  always@(posedge clk) begin
    if(pe_en) begin
      _pe_en          <= pe_en;
      pe_ker3_i_reg   <= pe_ker3_i;
      pe_data3_i_reg  <= pe_data3_i;
    end else begin
      _pe_en          <= 1'b0;
    //pe_ker3_i_reg   <= {(3*DATA_WIDTH){1'b1}};
    //pe_data3_i_reg  <= {(3*DATA_WIDTH){1'b1}};
    end
  end

  always@(posedge clk) begin
    _req_1 <= _pe_en; _req_2 <= _req_1; _req_3 <= _req_2;
    _req_4 <= _req_3; _req_5 <= _req_4; _req_6 <= _req_5;
    _req_7 <= _req_6; _req_8 <= _req_7; _req_9 <= _req_8;
    _req_10<= _req_9;
  end

  `ifdef sim_ // {{{
  shortreal _pe_data_float;
  reg  [31:0] _pe_float;
  always@(pe_data_o) begin
    convertFpH2Fp(pe_data_o, _pe_float, 32'd1);
  end
  always@(_pe_float) begin
    _pe_data_float = $bitstoshortreal(_pe_float);
  end
  `endif // }}}

  // 3 multiply
  fp_mul2 pe_mul_h(
        .aclk(clk),
        .s_axis_a_tvalid(_pe_en),
        .s_axis_a_tdata(pe_data3_i_reg[3*(1+MANTISSA+EXPONENT)-1:2*(1+MANTISSA+EXPONENT)]),
        .s_axis_b_tvalid(_pe_en),
        .s_axis_b_tdata(pe_ker3_i_reg[3*(1+MANTISSA+EXPONENT)-1:2*(1+MANTISSA+EXPONENT)]),
        .m_axis_result_tvalid(_mul_valid),
        .m_axis_result_tdata(_mul_h)
      );

  fp_mul2 pe_mul_m(
        .aclk(clk),
        .s_axis_a_tvalid(_pe_en),
        .s_axis_a_tdata(pe_data3_i_reg[2*(1+MANTISSA+EXPONENT)-1: 1+MANTISSA+EXPONENT]),
        .s_axis_b_tvalid(_pe_en),
        .s_axis_b_tdata(pe_ker3_i_reg[2*(1+MANTISSA+EXPONENT)-1: 1+MANTISSA+EXPONENT]),
        .m_axis_result_tvalid(),
        .m_axis_result_tdata(_mul_m)
      );

  fp_mul2 pe_mul_l(
        .aclk(clk),
        .s_axis_a_tvalid(_pe_en),
        .s_axis_a_tdata(pe_data3_i_reg[MANTISSA+EXPONENT:0]),
        .s_axis_b_tvalid(_pe_en),
        .s_axis_b_tdata(pe_ker3_i_reg[MANTISSA+EXPONENT:0]),
        .m_axis_result_tvalid(),
        .m_axis_result_tdata(_mul_l)
      );

  // alignment synchronization in fp_adder3
  // sum 3
  fp_adder3#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) pe_adder3(
        .clk(clk),
        .en(_mul_valid),
        .a1(_mul_h),
        .a2(_mul_m),
        .a3(_mul_l),
        .valid(_sum3_valid),
        .adder_o(_adder3)
      );

  // add bias
  fp_adder2 pe_add_bias(
        .aclk(clk),
        .s_axis_a_tvalid(_sum3_valid),
        .s_axis_a_tdata(_adder3),
        .s_axis_b_tvalid(_sum3_valid),
        .s_axis_b_tdata(pe_bias_i),
        .m_axis_result_tvalid(pe_data_valid),
        .m_axis_result_tdata(pe_data_o)
      );

endmodule
