/*--------------------------------------------------
 * This module is weight register matrix buffer for
 * store current convolution weight kernel.
 *
 * parameter:
 * FW:  float width
 * DW:  data width from read_op module
 * MS:  weight reg maxtrix size
 * KS:  convolution kernel size
 *
 * ports:
 * clk_i    :   input clock
 * rstn_i   :   global reset signal
 * en_i     :   shift enable
 * sel_w_i  :   write select between weight0_ and weight1_
 * data_i   :   input data from read_op module
 * sel_r_i  :   read select between weight0_ and weight1_
 * weight_o :   output weight( weight0_ or weight1_ )
--------------------------------------------------*/
module weight_reg_matrix
#(
    parameter   FW = 32,
    parameter   DW = 512,
    parameter   MS = 32,
    parameter   KS = 3
 )
 (
    input                           clk_i,
    input                           rstn_i,
    input                           en_i,

    input                           sel_w_i,
    input   [ DW-1:0 ]              data_i,

    input                           sel_r_i,

    output  [ (MS*KS*KS)*FW-1:0 ]   weight_o    
 );

    localparam  PACKAGE_LEN = DW / FW; // data number in one input data data_i
    localparam  MATRIX_LEN  = MS*KS*KS; // total kernel parameter in one weight matrix
    localparam  PACKAGE_NUM = MATRIX_LEN / PACKAGE_LEN;

    /*
     * internel register matrix
    */
    reg [ FW-1:0 ]  weight0_[ 0:MATRIX_LEN-1 ];
    reg [ FW-1:0 ]  weight1_[ 0:MATRIX_LEN-1 ];

    /*
     * internel operation
    */
    generate
        genvar i;
        genvar j;
        for( j = 0; j < PACKAGE_LEN; j = j +1 )
        begin:receive_input
            always @( negedge rstn_i or posedge clk_i )
            begin
                if( rstn_i == 1'b0 )
                begin
                    weight0_[ j ] <= {FW{1'b0}};
                    weight1_[ j ] <= {FW{1'b0}};
                end
                else if( en_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 ) // select weight0_
                        weight0_[ j ] <= data_i[ (j+1)*FW-1:j*FW ];
                    else if( sel_w_i == 1'b1 ) // select weight1_
                        weight1_[ j ] <= data_i[ (j+1)*FW-1:j*FW ];
                end
            end
        end // end receive_input
        for( i = PACKAGE_NUM-1; i > 0; i = i -1 )
        begin: shift_weight_matrix
            for( j = 0; j < PACKAGE_LEN; j = j + 1 )
            begin
                always @( negedge rstn_i or posedge clk_i )
                begin
                    if ( rstn_i == 1'b0 )
                    begin
                        weight0_[ i*PACKAGE_LEN+j ] <= {FW{1'b0}};  
                        weight1_[ i*PACKAGE_LEN+j ] <= {FW{1'b0}};
                    end
                    else if( en_i == 1'b1 )
                    begin
                        if( sel_w_i == 1'b0 ) // select weight0_
                            weight0_[ i*PACKAGE_LEN+j ] <= weight0_[ (i-1)*PACKAGE_LEN+j ];
                        else if( sel_w_i == 1'b1 ) // select weight1_
                            weight1_[ i*PACKAGE_LEN+j ] <= weight1_[ (i-1)*PACKAGE_LEN+j ];
                    end
                end
            end
        end // end shift_weight_matrix
    endgenerate

    /*
     * output
    */
    generate
        for( i = 0; i < MATRIX_LEN; i = i + 1 )
        begin:pack_out
            assign weight_o[ (i+1)*FW-1:i*FW ]  = sel_r_i==1'b0 ? weight0_[ i ] : weight1_[ i ];
        end // end pack_out
    endgenerate

endmodule
