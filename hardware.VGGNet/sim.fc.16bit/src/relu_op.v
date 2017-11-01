// relu operaion module
// see details in README.md
module relu_op
#(
  parameter FW = 32,
  parameter US = 7,
  parameter MS = 32,
  parameter KN = 512
 )
 (
  input [MS*(4*US*US)*FW - 1:0] conv_data_0_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_1_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_2_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_3_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_4_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_5_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_6_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_7_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_8_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_9_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_10_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_11_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_12_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_13_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_14_i,
  input [MS*(4*US*US)*FW - 1:0] conv_data_15_i,
  output [KN*(4*US*US)*FW - 1:0] relu_data_o
 );
  localparam SEC_NUM = KN / MS;

  wire [KN*(4*US*US)*FW-1:0] conv2relu_data; 
  assign conv2relu_data = {conv_data_0_i, conv_data_1_i, conv_data_2_i, conv_data_3_i,
                           conv_data_4_i, conv_data_5_i, conv_data_6_i, conv_data_7_i,
                           conv_data_8_i, conv_data_9_i, conv_data_10_i, conv_data_11_i,
                           conv_data_12_i, conv_data_13_i, conv_data_14_i, conv_data_15_i
                          };
  genvar i;
  generate
    for(i = 0; i < SEC_NUM; i = i + 1)
    begin:relu_op
      relu_unit
      #(
         .FW(FW),
         .US(US),
         .MS(MS)
       )
       relu_unit_U
       (
         .conv_data_i ( conv2relu_data[(i+1)*MS*(4*US*US)*FW-1 : i*MS*(4*US*US)*FW]),
         .relu_data_o ( relu_data_o[ (i+1)*MS*(4*US*US)*FW-1 : i*MS*(4*US*US)*FW] )
       );
    end
  endgenerate

endmodule
