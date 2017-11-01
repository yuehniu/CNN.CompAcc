/*--------------------------------------------------
 * This is top memory module, which consists of all
 * associated momery used in cnn project:
 * top and side ram buffer
 * feature in data buffer
 * feature out data buffer
 * weight and bias buffer
 *
 * parameter:
 * FW    :    float data width
 * US    :    unit storage size
 * DW    :    ddr data widt
 * KN    :    total max kernel number
 *
 * ports:
 * clk_i               : input clock
 * en_i                : module enable
 * rstn_i              : negative active global reset signal
 * start_trigger_i     : flag indicates start transfer data
 * first_shot_i        : flag indicates first fill data to reg matrix
 * sel_ddr_i           : flag indicates data read from DDR3
 * sel_ram_i           : flag indicates data read from BRAM
 * sel_top_i           : flag indicates data read from top BRAM
 * sel_w_i             : write select signal between conv_reg0/1
 * data_last_i         : flag indicates last data to feature
 * data_top_i          : input data from top ram
 * data_ram_i          : input data from ram
 * ddr_last_i          : flag indicates last data package from ddr
 * col_last_i          : flag indicates last col in feature map
 * row_last_i          : flag indicates last row in deature map
 * data_valid_num_i    : flag indeicates the number of valid data
 * data_ddr_i          : input data from ddr
 * sel_r_i             : read select signal between conv_reg0/1
 * addr_r_i            : read address 
 * conv_data_o         : convolution data output to conv_op    
 * reg_matrix_full_o   : flag indicates reg matrix is full,current
 *                       reg_matrix_full is decide by last_ddr_data flag,
 * update_data_0_o     : output feature to update_op
 * update_data_1_o     :
 * top_ram_en_i        : enable read top ram signal
 * top_ram_wren_i      : enable write ram signal
 * top_ram_waddr_i     : input write top ram address
 * top_ram_wdata_i     : input write top ram data
 * top_ram_rden_i      : top ram read enable signal
 * top_ram_raddr_i     : top ram read address
 * top_ram_rdata_o     : top ram read data output
 *
 * side_
 *
--------------------------------------------------*/
module cnn_mem
#(
    parameter EW = 8,
    parameter MW = 23,
    parameter FW = 32,
    parameter US = 7,
    parameter DW = 512,
    parameter MS = 32,
    parameter KS = 3,
    parameter KN = 512,
    parameter RL = 512
 )
 (
    // port definition {{{
    input clk_i,
    input rstn_i,
    
    // feature in reg matrix
    input                               en_i,
    input                               start_trigger_i,
    input                               first_shot_i,
    input                               sel_w_i,
    input                               data_last_i,

    input                               sel_top_i,
    input  [ (2*US+2)*FW-1:0 ]          data_top_i,

    input                               sel_ram_i,
    input  [ (2*US+1)*FW-1:0 ]          data_ram_i,

    input                               sel_ddr_i,
    input                               ddr_last_i,
    input                               col_last_i,
    input                               row_last_i,
    input  [ 5-1:0 ]                    data_valid_num_i,
    input  [ DW-1:0 ]                   data_ddr_i,
    
    input                               sel_r_i,
    input                               col_last_r_i,
    input  [ 8-1:0  ]                   addr_r_i,
    output [ 2-1:0  ]                   reg_matrix_full_o,
    output [ 3*FW-1:0 ]                 conv_data_o,
    output [ (2*US+2)*(3*US+1)*FW-1:0 ] update_data_0_o,
    output [ (2*US+2)*(3*US+1)*FW-1:0 ] update_data_1_o,

    // top_ram
    input                               top_ram_en_i,
    input                               top_ram_wren_i,
    input  [ 10-1:0 ]                   top_ram_waddr_i,
    input  [ (2*US+2)*FW-1:0 ]          top_ram_wdata_i,
    input                               top_ram_rden_i,
    input  [ 13-1:0 ]                   top_ram_raddr_i,
    output [ (2*US+2)*FW-1:0 ]          top_ram_rdata_o,    

    // side_ram
    input                               side_ram_en_i,
    input                               side_ram_wren_i,
    input  [ 12-1:0 ]                   side_ram_waddr_i,
    input  [ (2*US+1)*FW-1:0 ]          side_ram_wdata_i,
    input                               side_ram_rden_i,
    input  [ 13-1:0 ]                   side_ram_raddr_i,
    output [ (2*US+1)*FW-1:0 ]          side_ram_rdata_o,

    // weight buffer
    input                               weight_valid_i,
    input                               sel_weight_w_i,
    input                               sel_weight_r_i,
    output [ MS*KS*KS*FW-1:0 ]          weight_o,

    // bias buffer
    input                               bias_valid_i,
    input                               last_bias_i,
    output [ RL*FW-1:0 ]                bias_o,    

    output [ (2*US+2)*(2*US+2)*FW-1:0 ] test_data_o ,

    // feature out buffer
	input								accum_en_i,
	input  [ MS*FW-1:0 ]				accum_data_i,
	input  [ 4-1:0 ]					addr_x_i,
	input  [ 4-1:0 ]					addr_y_i,
	input  [ 4-1:0 ]					grp_sel_i,

	input								bias_full_i,
	input  [ KN*FW-1:0 ]				bias_data_i,

	input								wr_en_i,
    input                               wr_done_i,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data0_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data1_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data2_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data3_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data4_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data5_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data6_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data7_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data8_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data9_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data10_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data11_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data12_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data13_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data14_o,
	output [ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data15_o
    // }}}
 );

    /*---------------------------------------------
     * convolution buffer
    ---------------------------------------------*/
    
    // connect convlolution buffer data to update_op module
    feature_in_reg_matrix #
    (
        .FW( FW ),
        .US( US ),
        .DW( DW )
    )
    feature_in_reg_matrix_U
    ( //{{{
        .clk_i  ( clk_i  ),
        .rstn_i ( rstn_i ),

        .en_i            ( en_i                     ),
        .start_trigger_i ( start_trigger_i          ),
        .first_shot_i    ( first_shot_i             ),
        .sel_w_i         ( sel_w_i                  ),
        .data_last_i     ( data_last_i              ),

        .sel_top_i       ( sel_top_i                ),
        .data_top_i      ( data_top_i               ),

        .sel_ram_i       ( sel_ram_i                ),
        .data_ram_i      ( data_ram_i               ),

        .sel_ddr_i       ( sel_ddr_i                ),
        .ddr_last_i      ( ddr_last_i               ),
        .col_last_i      ( col_last_i               ),
        .row_last_i      ( row_last_i               ),
        .data_valid_num_i( {27'd0,data_valid_num_i} ),
        .data_ddr_i      ( data_ddr_i               ),
        
        .sel_r_i         ( sel_r_i                  ),
        .col_last_r_i    ( col_last_r_i             ),
        .update_data_0_o ( update_data_0_o          ),
        .update_data_1_o ( update_data_1_o          ),
        .test_data_o     ( test_data_o              ),
        .reg_matrix_full_o( reg_matrix_full_o       )
    ); //}}}

    /*---------------------------------------------
     * top_ram buffer
    ---------------------------------------------*/
    top_bram top_bram_U
    ( //{{{
        .clka   ( clk_i ),
        .ena    ( top_ram_en_i         ),
        .wea    ( top_ram_wren_i       ),
        .addra  ( top_ram_waddr_i      ),
        .dina   ( top_ram_wdata_i      ),

        .clkb   ( clk_i ),
        .enb    ( top_ram_rden_i       ),
        .addrb  ( top_ram_raddr_i[9:0] ),
        .doutb  ( top_ram_rdata_o      )
    ); //}}}

    /*---------------------------------------------
     * side_ram buffer
    ---------------------------------------------*/
    side_bram side_bram_U
    ( // {{{
        .clka   ( clk_i ),
        .ena    ( side_ram_en_i          ),
        .wea    ( side_ram_wren_i        ),
        .addra  ( side_ram_waddr_i       ),
        .dina   ( side_ram_wdata_i       ),

        .clkb   ( clk_i ),
        .enb    ( side_ram_rden_i        ),
        .addrb  ( side_ram_raddr_i[11:0] ),
        .doutb  ( side_ram_rdata_o       )
    ); // }}}

    /*---------------------------------------------
     * weight buffer
    ---------------------------------------------*/
    weight_reg_matrix
    #(
        .FW( FW ),
        .DW( DW ),
        .MS( MS ),
        .KS( KS )
     )
     weight_reg_matrix_U
     (
        // {{{
        .clk_i ( clk_i ),
        .rstn_i( rstn_i ),

        .en_i    ( weight_valid_i ),
        .sel_w_i ( sel_weight_w_i ),
        .data_i  ( data_ddr_i     ),
        .sel_r_i ( sel_weight_r_i ),
        .weight_o( weight_o       )
        // }}}
     );

    /*---------------------------------------------
     * bias buffer
    ---------------------------------------------*/
    bias_reg_array
    #(
        .FW( FW ),
        .DW( DW ),
        .RL( RL )
     ) 
     (
        // {{{
        .clk_i  ( clk_i ),
        .rstn_i ( rstn_i ),
        .en_i        ( bias_valid_i ),
        .last_data_i ( last_bias_i  ),
        .data_i      ( data_ddr_i   ),
        .bias_o      ( bias_o       )
        // }}}
     );

    /*---------------------------------------------
     * feature out buffer
    ---------------------------------------------*/
    feature_out_reg_matrix #
    (
        .EW( EW ),
        .MW( MW ),
        .FW( FW ),
        .US( US ),
        .MS( MS ),
        .KN( KN ),
        .DW( DW )
    )
    feature_out_reg_matrix_U
    (
        .rstn_i              ( rstn_i               ),
        .clk_i               ( clk_i                ),
        .accum_en_i          ( accum_en_i           ),
        .accum_data_i        ( accum_data_i         ),
        .addr_x_i            ( addr_x_i             ),
        .addr_y_i            ( addr_y_i             ),
        .grp_sel_i           ( grp_sel_i            ),
        .bias_full_i         ( bias_full_i          ),
        .bias_data_i         ( bias_data_i          ),
        .wr_done_i           ( wr_done_i            ),
        .wr_en_i             ( wr_en_i              ),
        .feature_out_data0_o ( feature_out_data0_o  ),
        .feature_out_data1_o ( feature_out_data1_o  ),
        .feature_out_data2_o ( feature_out_data2_o  ),
        .feature_out_data3_o ( feature_out_data3_o  ),
        .feature_out_data4_o ( feature_out_data4_o  ),
        .feature_out_data5_o ( feature_out_data5_o  ),
        .feature_out_data6_o ( feature_out_data6_o  ),
        .feature_out_data7_o ( feature_out_data7_o  ),
        .feature_out_data8_o ( feature_out_data8_o  ),
        .feature_out_data9_o ( feature_out_data9_o  ),
        .feature_out_data10_o( feature_out_data10_o ),
        .feature_out_data11_o( feature_out_data11_o ),
        .feature_out_data12_o( feature_out_data12_o ),
        .feature_out_data13_o( feature_out_data13_o ),
        .feature_out_data14_o( feature_out_data14_o ),
        .feature_out_data15_o( feature_out_data15_o )
    );
endmodule
