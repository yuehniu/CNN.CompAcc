// ---------------------------------------------------
// File       : mem_1x32_max.v
//
// Description: compare two 1x32 float number vectors
//
// Version    : 1.0
// ---------------------------------------------------

module mem_1x32_max#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter KER_C    = 32 // number of kernels at each conv operation
  ) (
    // input data
    input  wire                                     clk,
    input  wire [KER_C*(EXPONENT+MANTISSA+1)-1 : 0] mem_max_v1,
    input  wire [KER_C*(EXPONENT+MANTISSA+1)-1 : 0] mem_max_v2,
    input  wire                                     mem_max_en,
    // output data
    output wire [KER_C*(EXPONENT+MANTISSA+1)-1 : 0] mem_max_o
  );

  localparam DATA_WIDTH = EXPONENT+MANTISSA+1;
  localparam CMP_WIDTH  = 8; // comparison output data width
  genvar i;
  generate
    for(i=0; i<KER_C; i=i+1) begin : max_32
      fp_max #(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
      ) max1x32 (
        .a1(mem_max_v1[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),
        .a2(mem_max_v2[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),
        .en(mem_max_en),
        .max_o(mem_max_o[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH])
      );
    //fp_max max1x32(
    //  .aclk(clk),
    //  .s_axis_a_tvalid(mem_max_en),            // input wire s_axis_a_tvalid
    //  .s_axis_a_tdata(mem_max_v1[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),              // input wire [15 : 0] s_axis_a_tdata
    //  .s_axis_b_tvalid(mem_max_en),            // input wire s_axis_b_tvalid
    //  .s_axis_b_tdata(mem_max_v2[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),              // input wire [15 : 0] s_axis_b_tdata
    //  .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
    //  .m_axis_result_tdata(_mem_max_o[(i+1)*CMP_WIDTH-1 : i*CMP_WIDTH])    // output wire [7 : 0] m_axis_result_tdata
    //);
    //assign mem_max_o[i] = _mem_max_o[i*CMP_WIDTH];
    end
  endgenerate

endmodule
