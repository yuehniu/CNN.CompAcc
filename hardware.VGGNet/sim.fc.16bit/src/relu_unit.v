module relu_unit
#(
  parameter FW = 32,
  parameter US = 32,
  parameter MS = 32
 )
 (
  input [ MS*(4*US*US)*FW-1:0] conv_data_i,
  output [ MS*(4*US*US)*FW-1:0 ] relu_data_o
 );

  genvar i;
  generate
    for( i = 0; i < MS*4*US*US; i = i +1 )
    begin:relu_unit
      assign relu_data_o[ (i+1)*FW-1 : i*FW ] = conv_data_i[ (i+1)*FW-1 ] == 1'b1 ? {FW{1'b0}} : conv_data_i[ (i+1)*FW-1 : i*FW ];
    end
  endgenerate

endmodule
