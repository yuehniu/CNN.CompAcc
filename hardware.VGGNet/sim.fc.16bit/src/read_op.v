/*
 * This is read_op top module
 *
 * parameter
 * FW:	float width
 * US:	Unit storage block size
 * DW:	data width from ddr
 * */
`timescale 1 ns/1 ns
module read_op
#(
	parameter	FW = 32,
	parameter	US = 7,
	parameter	DW = 512
 )
 (
	// port definition {{{
	input	clk_i,
	input	rstn_i,

	// interface with top ram
	input				rd_top_en_i,	
	input	[ 12:0 ]	rd_top_offset_i,
	output				rd_top_en_o,
	output				rd_top_valid_o,
	output				rd_top_last_o,
	output	[ 12:0 ]	rd_top_addr_o,

	// interface with side ram
	input				rd_side_en_i,
	input	[ 12:0 ]	rd_side_offset_i,
	output				rd_side_en_o,
	output				rd_side_valid_o,
	output				rd_side_last_o,
	output	[ 12:0 ]	rd_side_addr_o,

	// interface with ddr
	input				ddr_rd_valid_i,
	input				ddr_rdy_i,
	input	[ DW-1:0 ]	ddr_rd_data_i,
	output	[ 29:0 ]	ddr_rd_addr_o,
	output	[ 2:0 ]		ddr_rd_cmd_o,
	output				ddr_rd_en_o,

	input				rd_ddr_en_i,
    input  	[8:0]     	rd_ddr_endX_i,
    input  	[8:0]     	rd_ddr_endY_i,
    input  	[8:0]     	rd_ddr_x_i,
    input  	[8:0]     	rd_ddr_y_i,
    input  				rd_ddr_first_fm_i,
	input	[29:0]		rd_ddr_bottom_addr_i,
    input  	[29:0]    	rd_ddr_bottom_ith_offset_i,
    input  	[29:0]    	rd_ddr_bar_offset_i,
    output 	[511:0]   	rd_ddr_data_o,
    output 	[4:0]     	rd_ddr_num_valid_o,
    output 				rd_ddr_valid_o,
  	output 				rd_ddr_first_valid_o,
    output 				rd_ddr_full_o,

	input				rd_ddr_param_en_i,
	input				rd_param_ker_only_i,
	input	[ 6-1:0 ]	rd_param_bias_burst_num_i,

	input	[ 30-1:0 ]	rd_param_addr_i,
	output				rd_param_valid_o,
	output				rd_param_bias_valid_o,
    output              bias_last_o,
	output				rd_param_full_o
	// }}}
 );

    wire                ddr_rd_data_valid;
    wire                ddr_rd_data_rdy;
	wire	[ 30-1:0 ]	ddr_rd_data_addr;
	wire	[ 3-1:0 ]	ddr_rd_data_cmd;
	wire				ddr_rd_data_en;
	wire	[ 512-1:0 ]	ddr_rd_data_data;
    wire                ddr_rd_param_valid;
    wire                ddr_rd_param_rdy;
	wire	[ 30-1:0 ]	ddr_rd_param_addr;
	wire	[ 3-1:0 ]	ddr_rd_param_cmd;
	wire				ddr_rd_param_en;
	wire	[ 512-1:0 ]	ddr_rd_param_data;

    assign ddr_rd_data_valid  = rd_ddr_en_i ? ddr_rd_valid_i : 1'b0;
    assign ddr_rd_data_rdy    = rd_ddr_en_i ? ddr_rdy_i : 1'b0;
    assign ddr_rd_param_valid = rd_ddr_param_en_i ? ddr_rd_valid_i : 1'b0;
    assign ddr_rd_param_rdy   = rd_ddr_param_en_i ? ddr_rdy_i : 1'b0;
	assign ddr_rd_addr_o = rd_ddr_param_en_i ? ddr_rd_param_addr : ( rd_ddr_en_i ? ddr_rd_data_addr : 30'd0 );
	assign ddr_rd_cmd_o  = rd_ddr_param_en_i ? ddr_rd_param_cmd : ( rd_ddr_en_i ? ddr_rd_data_cmd : 3'd0 );
	assign ddr_rd_en_o   = rd_ddr_param_en_i ? ddr_rd_param_en : ( rd_ddr_en_i ? ddr_rd_data_en : 1'b0 );
	assign rd_ddr_data_o = rd_ddr_valid_o ? ddr_rd_data_data : ( (rd_param_valid_o || rd_param_bias_valid_o) ? ddr_rd_param_data : {DW{1'b0}});
 	// top ram {{{
	rd_bram_row
	rd_bram_row_U
	(
		.clk	( clk_i  ),
		.rst_n	( rstn_i ),

		.rd_data_bottom				( rd_top_en_i 		),
		.rd_data_bram_row_ith_offset( rd_top_offset_i 	),
    	.rd_data_bram_row_enb		( rd_top_en_o		),   
    	.rd_data_bram_row_valid		( rd_top_valid_o 	), 
    	.rd_data_bram_row_last		( rd_top_last_o 	),  
     	.rd_data_bram_row_addrb		( rd_top_addr_o 	)
	);
	// }}}
	
	// side ram {{{
	rd_bram_patch
	rd_bram_patch_U
	(
		.clk	( clk_i 	),
		.rst_n	( rstn_i 	),
    	.rd_data_bottom					( rd_side_en_i 		),   
    	.rd_data_bram_patch_ith_offset	( rd_side_offset_i	), 
    	.rd_data_bram_patch_enb			( rd_side_en_o		),   
    	.rd_data_bram_patch_valid		( rd_side_valid_o	), 
    	.rd_data_bram_patch_last		( rd_side_last_o	),  
    	.rd_data_bram_patch_addrb		( rd_side_addr_o	) 
	);
	// }}}

	// ddr data {{{
	rd_ddr_data
	rd_ddr_data_U
	(
    .clk	( clk_i  ),
    .rst_n	( rstn_i ),
    // ddr
    .ddr_rd_data_valid			( ddr_rd_data_valid				),
    .ddr_rdy					( ddr_rd_data_rdy 				),
    .ddr_rd_data				( ddr_rd_data_i 				),
    .ddr_addr					( ddr_rd_data_addr				),
    .ddr_cmd					( ddr_rd_data_cmd 				),
    .ddr_en						( ddr_rd_data_en				),
    //
    .rd_data_bottom				( rd_ddr_en_i 					),
    .rd_data_end_of_x			( rd_ddr_endX_i 				),
    .rd_data_end_of_y			( rd_ddr_endY_i 				),
    .rd_data_x					( rd_ddr_x_i 					),
    .rd_data_y					( rd_ddr_y_i 					),
    .rd_data_first_fm			( rd_ddr_first_fm_i 			),
	.rd_data_bottom_addr		( rd_ddr_bottom_addr_i			),
    .rd_data_bottom_ith_offset	( rd_ddr_bottom_ith_offset_i 	),
    .rd_data_bar_offset			( rd_ddr_bar_offset_i 			),
    .rd_data_half_bar_offset    ( 30'h400                       ),
    .rd_data_data				( ddr_rd_data_data 				),
    .rd_data_num_valid			( rd_ddr_num_valid_o 			),
    .rd_data_valid				( rd_ddr_valid_o 				),
  	.rd_data_valid_first		( rd_ddr_first_valid_o 			),
    .rd_data_full				( rd_ddr_full_o 				)
	);
	// }}}
	
	// ddr param {{{
	rd_ddr_param
	rd_ddr_param_U
	(
		.clk	( clk_i  ),
		.rst_n	( rstn_i ),

		.ddr_rdy					( ddr_rd_param_rdy          ),
		.ddr_rd_data_valid			( ddr_rd_param_valid        ),
		.ddr_addr					( ddr_rd_param_addr         ),
		.ddr_cmd					( ddr_rd_param_cmd          ),
		.ddr_en						( ddr_rd_param_en           ),

		.rd_param					( rd_ddr_param_en_i         ),
		.rd_param_ker_only			( rd_param_ker_only_i       ),
		.rd_param_bias_burst_num	( rd_param_bias_burst_num_i ),
		.rd_param_addr				( rd_param_addr_i           ),
		.rd_param_valid				( rd_param_valid_o          ),
		.rd_param_bias_valid		( rd_param_bias_valid_o     ),
        .rd_bias_last               ( bias_last_o               ),
		.ddr_rd_data				( ddr_rd_data_i             ),
		.rd_param_data				( ddr_rd_param_data         ),
		.rd_param_full				( rd_param_full_o           )
	);
	// }}}

endmodule
