/*----------------------------------------------------
 * cnn_AVS project top file
----------------------------------------------------*/
`timescale 1 ns / 1 ns
module cnn_AVS_top
#(
    parameter EW = 8,
    parameter MW = 23,
    parameter FW = 32,
    parameter US = 7,
    parameter DW = 512,
    parameter MS = 32,
    parameter KN = 512,
    parameter KS = 3,
    parameter RL = 512
 )
 (
    // {{{ ports definition
    input                            clk_i,
    input                            rstn_i,
    
    // ddr ports
    input   [ DW-1:0 ]               ddr_rd_data_i,
    input                            ddr_rd_data_valid_i,
    input                            ddr_rdy_i,
    output  [ 30-1:0 ]               ddr_addr_o,
    output  [ 3-1:0  ]               ddr_cmd_o,
    output                           ddr_en_o,

    output  [ 2-1:0 ]                reg_matrix_full_o,

    // simulation ports
    input                    tb_load_done_i,
    input                    rd_data_load_ddr_done_rising_edge_i,
    // simulation test port
    output                   conv_en_o,
    output                   feature_proc_sel_o,
    output  [ 9-1:0 ]                   feature_index_proc_o,
    output  [ 9-1:0 ]                   rd_ddr_x_proc_o,
    output  [ 9-1:0 ]                   rd_ddr_y_proc_o,
    output  [ 32-1:0 ]                    x_pos_ddr_o,
    output  [ 32-1:0 ]                    y_pos_ddr_o,
    output  [ 9-1:0 ]                    feature_index_o,
    output  [ (2*US+2)*(2*US+2)*FW-1:0 ] test_data_o,

    output                                last_bias_flag_o,
    output  [ RL*FW-1:0 ]               test_bias_o,
    output  [ 12-1:0 ]                  weight_sec_count_o,
    output  [ MS*KS*KS*FW-1:0 ]         test_weight_o,
    output                                  weight_proc_sel_o,

    
    output  [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data0_o,
    output  [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data1_o,
    output                                  cnn_conv_output_last_o, // tmp add
    output                                  wr_ddr_en_o
    // }}}
 );


    // cnn_AVS_control connection {{{
    wire    rd_data_full;
    wire    rd_data_bottom;
    wire                        weight_wr_sel;
    wire                        feature_wr_sel;
    wire                        weight_proc_sel;
    wire                        feature_proc_sel;
    reg                            conv_finish;
    wire                        conv_en;
    wire                        rd_param_full;
    wire    [ 2-1:0 ]            feature_reg_full;
    wire    [ 2-1:0 ]            weight_reg_full;
    wire                        rd_kernel_only;
    wire                        rd_param_en;
    wire    [ 30-1:0 ]            rd_param_addr;
    wire    [ 6-1:0  ]            rd_bias_burst_num;

    wire    [ 9-1:0 ]            rd_data_endX;
    wire    [ 9-1:0 ]            rd_data_endY;
    wire    [ 9-1:0 ]            rd_data_x;
    wire    [ 9-1:0 ]            rd_data_y;
    wire                        rd_ddr_first_fm;
    wire    [ 30-1:0 ]            rd_ddr_bottom_addr;
    wire    [ 30-1:0 ]            rd_ddr_bottom_ith_offset;
    wire    [ 30-1:0 ]            rd_ddr_bar_offset;
    wire                        switch_trigger;
    wire    [ 9-1:0 ]            feature_index;
    wire    [ 9-1:0 ]            feature_index_update;
    wire    [ 3-1:0 ]            conv_layer_index;
    // }}}

    // connection between memory module and update_op {{{
    wire    top_ram_en;
    wire    top_ram_wren;
    wire    [ 10-1:0 ]            top_ram_waddr;
    wire    [ (2*US+2)*FW-1:0 ]    top_ram_wdata;
    wire    side_ram_en;
    wire    side_ram_wren;
    wire    [ 12-1:0 ]            side_ram_waddr;
    wire    [ (2*US+1)*FW-1:0 ]    side_ram_wdata;

    wire    [ 5-1:0    ]            x_pos;
    // }}}
    
    // connection between memory module and read_op // {{{
    wire                                     mem_en;
    wire                                     start_trigger;
    reg                                         start_trigger_reg;
    wire                                     first_shot;
    reg                                          sel_w;

    wire                                     rden_top;
    wire        [ 13-1:0 ]                     raddr_top;
    wire        [ (2*US+2)*FW-1:0 ]             data_top2read;
    wire                                     sel_top;
    wire        [ (2*US+2)*FW-1:0 ]          data_top2mem;

    wire                                     rden_side;
    wire        [ 13-1:0 ]                     raddr_side;
    wire        [ (2*US+1)*FW-1:0 ]             data_side2read;
    wire                                     sel_side;
    wire        [ (2*US+1)*FW-1:0 ]          data_side2mem;

    wire                                     sel_ddr;
    wire                                     ddr_last;
    wire                                     data_last;
    wire                                     col_last;
    wire                                     row_last;
    wire        [ 5-1:0]                     data_valid_num;
    wire        [ DW-1:0 ]                      data_ddr;
    wire                                     read_finish;

    wire                                     weight_valid;
    wire                                     bias_valid;
    wire                                     bias_last;
    
    wire                                     sel_r;
    //wire        [ 2-1:0 ]                     reg_matrix_full;
    // }}}

    
    // connection between memory module and conv_op {{{
    wire  [ MS*KS*KS*FW-1:0 ]          weight_data;
    wire  [ RL*FW-1:0 ]                bias_data;
    wire  [ (2*US+2)*(2*US+2)*FW-1:0 ] feature_data_in;
    wire  [ 4-1:0 ]                    cnn_conv_x;
    wire  [ 4-1:0 ]                    cnn_conv_y;
    wire  [ MS*FW-1:0 ]                feature_data_out;
    wire                               cnn_conv_output_last;
    wire                               cnn_conv_output_valid;
    // }}}

    // connection between memory module and cnn control module
    wire [ 5-1:0 ]                     grp_sel;

    // connection between memory module and write_op {{{
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data0;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data1;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data2;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data3;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data4;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data5;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data6;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data7;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data8;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data9;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data10;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data11;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data12;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data13;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data14;
    //wire [ MS*(2*US*2*US)*FW-1:0 ]    feature_out_data15;
    // }}}

    // connection between control module and write op
    wire wr_ddr_en;
    wire wr_ddr_done;
    
    
    /*----------------------------------------------------------
     * cnn_AVS_control module
    ----------------------------------------------------------*/
    wire            rd_top_last;
    wire             rd_top_en_ctrl;
    wire [ 13-1:0 ]    rd_top_offset_ctrl;
    wire            rd_side_last;
    wire            rd_side_en_ctrl;
    wire [ 13-1:0 ] rd_side_offset_ctrl;
    assign x_pos_ddr_o           = rd_data_x << 1;
    assign y_pos_ddr_o           = rd_data_y << 1;
    assign feature_index_o       = feature_index;
    assign conv_en_o          = conv_en;
    assign feature_proc_sel_o = feature_proc_sel;
    assign wr_ddr_en_o        = wr_ddr_en;
    assign cnn_conv_output_last_o = cnn_conv_output_last; // tmp add
    always @( negedge rstn_i or posedge clk_i )
    begin
        if( rstn_i == 1'b0 ) conv_finish <= 1'b0;
        else                 conv_finish <= cnn_conv_output_last;
    end
    cnn_control
    cnn_control_U 
    (
        // {{{
        .clk_i    ( clk_i     ),
        .rstn_i    ( rstn_i     ),

        .tb_load_done_i                            ( tb_load_done_i                         ),
        .rd_data_load_ddr_done_rising_edge_i    ( rd_data_load_ddr_done_rising_edge_i     ),

        .weight_wr_sel_o                        ( weight_wr_sel                            ),
        .feature_wr_sel_o                        ( feature_wr_sel                        ),
        .weight_proc_index_o                    ( weight_proc_sel                        ),
        .feature_proc_index_o                    ( feature_proc_sel                        ),

        .conv_finish_i                            ( conv_finish                            ),
        .conv_en_o                                ( conv_en                                ),

        .rd_param_full_i                        ( rd_param_full                            ),
        .rd_kernel_only_o                        ( rd_kernel_only                        ),
        .rd_param_en_o                            ( rd_param_en                            ),
        .rd_param_addr_o                        ( rd_param_addr                            ),
        .rd_bias_burst_num_o                    ( rd_bias_burst_num                        ),

        .rd_data_full_i                            ( ddr_last                                 ),
        .rd_ddr_en_o                            ( rd_data_bottom                        ),
        .rd_ddr_endX_o                            ( rd_data_endX                            ),
        .rd_ddr_endY_o                            ( rd_data_endY                            ),
        .rd_ddr_x_o                                ( rd_data_x                             ),
        .rd_ddr_y_o                                ( rd_data_y                             ),
        .rd_ddr_first_fm_o                        ( rd_ddr_first_fm                        ),
        .rd_ddr_bottom_addr_o                    ( rd_ddr_bottom_addr                    ),
        .rd_ddr_bottom_ith_offset_o                ( rd_ddr_bottom_ith_offset                ),
        .rd_ddr_bar_offset_o                    ( rd_ddr_bar_offset                        ),
        .switch_trigger_o                        ( switch_trigger                        ),

        .rd_top_last_i                            ( rd_top_last                            ),
        .rd_top_en_o                            ( rd_top_en_ctrl                        ),
        .rd_top_offset_o                        ( rd_top_offset_ctrl                    ),

        .rd_side_last_i                            ( rd_side_last                            ),
        .rd_side_en_o                            ( rd_side_en_ctrl                        ),
        .rd_side_offset_o                        ( rd_side_offset_ctrl                    ),
    
        .feature_index_o                        ( feature_index                            ),
        .feature_index_update_o                    ( feature_index_update                    ),
        .conv_layer_index_o                        ( conv_layer_index                        ),

        .weight_sec_count_o                     ( weight_sec_count_o                    ),
        .feature_index_proc_o                   ( feature_index_proc_o                  ),
        .rd_ddr_x_proc_o                        ( rd_ddr_x_proc_o                       ),
        .rd_ddr_y_proc_o                        ( rd_ddr_y_proc_o                       ),
        .grp_sel_o                              ( grp_sel                               ),

        // control write_op
        .wr_ddr_done_i                          ( wr_ddr_done                           ),
        .wr_ddr_en_o                            ( wr_ddr_en                             )
        // }}}
    );
    /*----------------------------------------------------------
     * read_op module
    ----------------------------------------------------------*/
    wire                ddr_rd_data_valid_sync;
    wire                ddr_rdy_sync;
    wire    [ DW-1:0 ]    ddr_rd_data_sync;
    always @( negedge rstn_i or posedge clk_i )
    begin
        if( rstn_i == 1'b0 )
        begin
            sel_w                <= 1'b1;
            start_trigger_reg    <= 1'b0;
        end
        else 
        begin
            start_trigger_reg     <= switch_trigger;
            if( switch_trigger == 1'b1 )
                sel_w    <= ~sel_w;
        end
    end
    ddr_sync
    #(
        .DW( DW )
     )
     ddr_sync_U
     (
        // {{{
        .clk_i        ( clk_i  ),
         .rstn_i        ( rstn_i ),
         .ddr_rd_data_valid_i        ( ddr_rd_data_valid_i         ),
        .ddr_rdy_i                    ( ddr_rdy_i                 ),
        .ddr_rd_data_i                ( ddr_rd_data_i             ),
        .ddr_rd_data_valid_sync_o    ( ddr_rd_data_valid_sync     ),
        .ddr_rdy_sync_o                ( ddr_rdy_sync                 ),
        .ddr_rd_data_sync_o            ( ddr_rd_data_sync             )
        // }}}
     );
    read_op
    #(
        .FW( FW ),
        .US( US ),
        .DW( DW )
     )
     read_op_U
     (
         // {{{
         .clk_i    ( clk_i     ),
        .rstn_i    ( rstn_i     ),

        .rd_top_en_i                ( rd_top_en_ctrl             ),
        .rd_top_offset_i            ( rd_top_offset_ctrl         ),
        .rd_top_en_o                ( rden_top                     ),
        .rd_top_valid_o                ( sel_top                     ),
        .rd_top_last_o                ( rd_top_last                ),
        .rd_top_addr_o                ( raddr_top                 ),

        // interface with side ram
        .rd_side_en_i                ( rd_side_en_ctrl             ),
        .rd_side_offset_i            ( rd_side_offset_ctrl         ),
        .rd_side_en_o                ( rden_side                 ),
        .rd_side_valid_o            ( sel_side                     ),
        .rd_side_last_o                ( rd_side_last                ),
        .rd_side_addr_o                ( raddr_side                 ),

        // interface with ddr
        .ddr_rd_valid_i                ( ddr_rd_data_valid_sync    ),
        .ddr_rdy_i                    ( ddr_rdy_i                 ),
        .ddr_rd_data_i                ( ddr_rd_data_sync             ),
        .ddr_rd_addr_o                ( ddr_addr_o                 ),
        .ddr_rd_cmd_o                ( ddr_cmd_o                 ),
        .ddr_rd_en_o                ( ddr_en_o                     ),

        .rd_ddr_en_i                ( rd_data_bottom             ),
        .rd_ddr_endX_i                ( rd_data_endX                ),
        .rd_ddr_endY_i                ( rd_data_endX                ),
        .rd_ddr_x_i                    ( rd_data_x                 ),
        .rd_ddr_y_i                    ( rd_data_y                 ),
        .rd_ddr_first_fm_i            ( rd_ddr_first_fm            ),  
        .rd_ddr_bottom_addr_i        ( rd_ddr_bottom_addr        ),
        .rd_ddr_bottom_ith_offset_i    ( rd_ddr_bottom_ith_offset    ),  
        .rd_ddr_bar_offset_i        ( rd_ddr_bar_offset            ), 
        .rd_ddr_data_o                ( data_ddr                     ), 
        .rd_ddr_num_valid_o            ( data_valid_num             ), 
        .rd_ddr_valid_o                ( sel_ddr                     ),
          .rd_ddr_first_valid_o        ( start_trigger             ),
        .rd_ddr_full_o                ( ddr_last                     ),

        .rd_ddr_param_en_i            ( rd_param_en                ),
        .rd_param_ker_only_i        ( rd_kernel_only            ),
        .rd_param_bias_burst_num_i    ( rd_bias_burst_num            ),
        .rd_param_addr_i            ( rd_param_addr                ),
        .rd_param_valid_o            ( weight_valid                    ),
        .rd_param_bias_valid_o        ( bias_valid            ),
        .bias_last_o                ( bias_last                 ),
        .rd_param_full_o            ( rd_param_full                )
        // }}}
     );

    /*----------------------------------------------------------
     * memory module
    ----------------------------------------------------------*/
    wire    [ (2*US+2)*(3*US+1)*FW-1:0 ] update_data_0;
    wire    [ (2*US+2)*(3*US+1)*FW-1:0 ] update_data_1;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data0;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data1;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data2;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data3;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data4;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data5;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data6;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data7;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data8;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data9;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data10;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data11;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data12;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data13;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data14;
    wire    [ MS*(2*US*2*US)*FW-1:0 ]     conv_out_data15;
    assign test_data_o = feature_data_in;
    cnn_mem #
    (
        .FW( FW ),
        .US( US ),
        .DW( DW ),
        .MS( MS ),
        .KS( KS ),
        .RL( RL )
    )
    cnn_mem_U
    (
        // {{{
        .clk_i        ( clk_i ),
        .rstn_i        ( rstn_i ),

        // feature_in reg matrix
        .en_i                ( weight_valid||bias_valid||sel_ddr||sel_top||sel_side ),
        .start_trigger_i    ( start_trigger_reg             ),
        .first_shot_i        ( rd_data_x==9'd0                 ),
        .sel_w_i            ( feature_wr_sel                  ),

        .sel_top_i            ( sel_top                          ),
        .data_top_i            ( data_top2read                    ),

        .sel_ram_i            ( sel_side                             ),
        .data_ram_i            ( data_side2read                ),

        .sel_ddr_i            ( sel_ddr                             ),
        .ddr_last_i            ( ddr_last                          ),
        .data_last_i        ( ddr_last                        ),
        .col_last_i            ( rd_data_x==9'd15                ),
        .row_last_i            ( rd_data_y==9'd15                ),
        .data_valid_num_i    ( data_valid_num                 ),
        .data_ddr_i            ( data_ddr                          ),
        
        .sel_r_i            ( /*sel_r*/feature_proc_sel        ),
        .col_last_r_i       ( rd_ddr_x_proc_o == 8'd30      ),
        .update_data_0_o    ( update_data_0                    ),
        .update_data_1_o    ( update_data_1                    ),
        .test_data_o        ( feature_data_in                  ),
        .reg_matrix_full_o    ( reg_matrix_full_o                ),

        // top_ram
        .top_ram_en_i        ( top_ram_en                    ),
        .top_ram_wren_i        ( top_ram_wren                    ),
        .top_ram_waddr_i    ( top_ram_waddr                 ),
        .top_ram_wdata_i    ( top_ram_wdata                    ),
        .top_ram_rden_i        ( rden_top                        ),
        .top_ram_raddr_i    ( raddr_top                        ),
        .top_ram_rdata_o    ( data_top2read                    ),

        // side_ram
        .side_ram_en_i        ( side_ram_en                    ),
        .side_ram_wren_i    ( side_ram_wren                    ),
        .side_ram_waddr_i    ( side_ram_waddr                ),
        .side_ram_wdata_i    ( side_ram_wdata                ),
        .side_ram_rden_i    ( rden_side                        ),
        .side_ram_raddr_i    ( raddr_side                    ),
        .side_ram_rdata_o    ( data_side2read                ),
        
        // weight buffer
        .weight_valid_i     ( weight_valid    ),
        .sel_weight_w_i     ( weight_wr_sel   ),
        .sel_weight_r_i     ( weight_proc_sel ),
        .weight_o           ( weight_data     ),
        
        // bias buffer
        .bias_valid_i       ( bias_valid      ),
        .last_bias_i        ( bias_last       ),
        .bias_o             ( bias_data       ),

        // feature out buffer
        .accum_en_i          ( cnn_conv_output_valid ),
        .accum_data_i        ( feature_data_out      ),
        .addr_x_i            ( cnn_conv_x            ),
        .addr_y_i            ( cnn_conv_y            ),
        .grp_sel_i           ( grp_sel               ),
        .bias_full_i         ( bias_last             ),
        .bias_data_i         ( bias_data             ),
        .wr_done_i           ( wr_ddr_done           ),
        .wr_en_i             ( wr_ddr_en             ),
        .feature_out_data0_o ( conv_out_data0        ),
        .feature_out_data1_o ( conv_out_data1        ),
        .feature_out_data2_o ( conv_out_data2        ),
        .feature_out_data3_o ( conv_out_data3        ),
        .feature_out_data4_o ( conv_out_data4        ),
        .feature_out_data5_o ( conv_out_data5        ),
        .feature_out_data6_o ( conv_out_data6        ),
        .feature_out_data7_o ( conv_out_data7        ),
        .feature_out_data8_o ( conv_out_data8        ),
        .feature_out_data9_o ( conv_out_data9        ),
        .feature_out_data10_o( conv_out_data10       ),
        .feature_out_data11_o( conv_out_data11       ),
        .feature_out_data12_o( conv_out_data12       ),
        .feature_out_data13_o( conv_out_data13       ),
        .feature_out_data14_o( conv_out_data14       ),
        .feature_out_data15_o( conv_out_data15       )
        // }}}
    );
     assign last_bias_flag_o   = bias_last;
     assign test_bias_o        = bias_data;
     assign test_weight_o      = weight_data;
     assign weight_proc_sel_o  = weight_proc_sel;

    /*----------------------------------------------------------
     * update_op module
    ----------------------------------------------------------*/
    wire [9-1:0] update_x;
    assign update_x = rd_ddr_x_proc_o >> 1;
    update_op #
    (
        .FW( FW ),
        .US( US )
    )
    update_op_U
    (
        // {{{
        .clk_i        ( clk_i ),
        .rstn_i        ( rstn_i ),

        .feature_index_i        ( feature_index_proc_o     ),
        .conv_layer_index_i        ( conv_layer_index        ),
        .sel_r_i                ( feature_proc_sel      ),
        .update_en_i            ( conv_en               ),
        .update_trigger_i        ( reg_matrix_full_o     ),
        .update_data_0_i        ( update_data_0         ),
        .update_data_1_i        ( update_data_1         ),
        .x_pos_i                ( update_x[4:0]            ), // new feature
        
        .top_ram_en_o            ( top_ram_en            ),
        .top_ram_wren_o            ( top_ram_wren            ),
        .top_ram_addr_o            ( top_ram_waddr            ),
        .top_ram_data_o            ( top_ram_wdata         ),

        .side_ram_en_o            ( side_ram_en             ),
        .side_ram_wren_o        ( side_ram_wren         ),
        .side_ram_addr_o        ( side_ram_waddr         ),
        .side_ram_data_o        ( side_ram_wdata         )
        // }}}
    );

    /*----------------------------------------------------------
     * simlated conv_op module
    ----------------------------------------------------------*/
    /*
    conv_op_sim #
    (
        .EW( EW ),
        .MW( MW ),
        .FW( FW )
    )
    conv_op_sim_U
    (
        // {{{
        .clk_i    ( clk_i ),
        .rstn_i    ( rstn_i ),
        .conv_en_i        ( conv_en         ),
        .conv_finish_o    ( conv_finish     )
        // }}}
    );
    */
    cnn_conv_op #
    (
        .EXPONENT( EW ),
        .MANTISSA( MW ),
        .K_C( MS ),
        .K_H( KS ),
        .K_W( KS ),
        .DATA_H( 2*US+2),
        .DATA_W( 2*US+2)
    )
    cnn_conv_op_U
    (
        // {{{
        .cnn_conv_rst_n                     ( rstn_i ),
        .cnn_conv_clk                       ( clk_i  ),
        .cnn_conv_start                     ( conv_en               ),
        .cnn_conv_next_ker_valid_at_next_clk( 1'b0                  ),
        .cnn_conv_ker                       ( weight_data           ),
        .cnn_conv_bottom                    ( feature_data_in       ),
        .cnn_conv_top                       ( feature_data_out      ),
        .cnn_conv_output_valid              ( cnn_conv_output_valid ),
        .cnn_conv_output_last               ( cnn_conv_output_last  ),
        .cnn_conv_x                         ( cnn_conv_x            ),
        .cnn_conv_y                         ( cnn_conv_y            ),
        .cnn_conv_busy                      ()
        // }}}
    );

    /*----------------------------------------------------------
     * relu_op module
    ----------------------------------------------------------*/
    wire [KN*(4*US*US)*FW-1:0] conv2relu_data; 
    relu_op #
    (
      .FW(FW),
      .US(US),
      .MS(MS),
      .KN(KN)
    )
    relu_op_U
    (
      .conv_data_0_i(conv_out_data0),
      .conv_data_1_i(conv_out_data1),
      .conv_data_2_i(conv_out_data2),
      .conv_data_3_i(conv_out_data3),
      .conv_data_4_i(conv_out_data4),
      .conv_data_5_i(conv_out_data5),
      .conv_data_6_i(conv_out_data6),
      .conv_data_7_i(conv_out_data7),
      .conv_data_8_i(conv_out_data8),
      .conv_data_9_i(conv_out_data9),
      .conv_data_10_i(conv_out_data10),
      .conv_data_11_i(conv_out_data11),
      .conv_data_12_i(conv_out_data12),
      .conv_data_13_i(conv_out_data13),
      .conv_data_14_i(conv_out_data14),
      .conv_data_15_i(conv_out_data15),
      .relu_data_o   (conv2relu_data)
    );
    assign feature_out_data0_o = conv2relu_data[KN*(4*US*US)*FW-1 : (KN-MS)*(4*US*US)*FW];
    assign feature_out_data1_o = conv2relu_data[(KN-MS)*(4*US*US)*FW-1 : (KN-2*MS)*(4*US*US)*FW];

    write_op
    write_op_U
    (
        .rstn_i( rstn_i ),
        .clk_i ( clk_i  ),

        .wr_ddr_en_i  ( wr_ddr_en   ),
        .wr_ddr_done_o( wr_ddr_done )
    );
endmodule
