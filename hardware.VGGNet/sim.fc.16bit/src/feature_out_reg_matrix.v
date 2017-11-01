/*--------------------------------------------------
 * This module is convolution register array buffer
 * for store atom-convolution output.
 * 
 * parameter:
 * EW:	exponent width for float
 * MW:	mantisa width for float
 * FW:	float width
 * US:	unit store size
 * MS:	conv matrix size
 * KN:	total max kernel number
 * DW:	data width to write_op module
 *
 * ports：
 *
 * clk_i				:	input clock
 * rstn_i				:	negative active global reset signal
 * accum_en_i			:	accumulate data enable signal
 * accum_data_i			:	accumulate input data
 * addr_x_i				:	write x address for input data
 * addr_y_i				:	write y address for input data
 * grp_sel_i			:	group select for feature register
 * bias_full_i			:	flag indicate bias reg is full
 * bias_data_i			:	bias input data
 * wr_en_i				:	ddr write enable signal
 * feature_out_data_o	:	ddr write output data
--------------------------------------------------*/
`timescale 1 ns/1 ns
module feature_out_reg_matrix
#(
	parameter EW = 8,
	parameter MW = 23,
	parameter FW = 32,
	parameter US = 7,
	parameter MS = 32,
	parameter KN = 512,
	parameter DW = 512
 )
 (
	// port definition {{{
 	input		clk_i,
	input		rstn_i,
	
	input									accum_en_i,
	input		[ MS*FW-1:0 ]				accum_data_i,
	input		[ 4-1:0 ]					addr_x_i,
	input		[ 4-1:0 ]					addr_y_i,
	input		[ 4-1:0 ]					grp_sel_i,

	input									bias_full_i,
	input		[ KN*FW-1:0 ]				bias_data_i,

    input                                   wr_done_i,
	input									wr_en_i,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data0_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data1_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data2_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data3_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data4_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data5_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data6_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data7_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data8_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data9_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data10_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data11_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data12_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data13_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data14_o,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data15_o
	// }}}
 );

	localparam	BUF_DATA_WIDTH = MS*FW;
	localparam	BUF_SEC_NUM	   = KN / MS;
	
	// internel register matrix
	reg		[ BUF_SEC_NUM*BUF_DATA_WIDTH-1:0 ]	prev_buf_data;
	reg		[ BUF_DATA_WIDTH-1:0 ]				prev_buf_data_sel_g; // data sel by group index
	reg		[ BUF_SEC_NUM-1:0	 ]				accum_en_unit; // unit accumulation enable signal
	wire	[ BUF_DATA_WIDTH-1:0 ]				accumed_buf_data;

	always @( rstn_i or accum_en_i or grp_sel_i or prev_buf_data )
	begin // {{{ select buf data according to grp_sel_i
		if( rstn_i == 1'b0 )
		begin
			accum_en_unit = {BUF_SEC_NUM{1'b0} };
		end
		else if( accum_en_i == 1'b0 )
			accum_en_unit = { BUF_SEC_NUM{1'b0} };
		else if( accum_en_i == 1'b1 )
		begin
			accum_en_unit = { BUF_SEC_NUM{1'b0} };
			case( grp_sel_i )
				4'd0:
				begin
					accum_en_unit[ 0 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 1*BUF_DATA_WIDTH-1:0*BUF_DATA_WIDTH ];
				end
				4'd1:
				begin
					accum_en_unit[ 1 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 2*BUF_DATA_WIDTH-1:1*BUF_DATA_WIDTH ];
				end
				4'd2:
				begin
					accum_en_unit[ 2 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 3*BUF_DATA_WIDTH-1:2*BUF_DATA_WIDTH ];
				end
				4'd3:
				begin
					accum_en_unit[ 3 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 4*BUF_DATA_WIDTH-1:3*BUF_DATA_WIDTH ];
				end
				4'd4:
				begin
					accum_en_unit[ 4 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 5*BUF_DATA_WIDTH-1:4*BUF_DATA_WIDTH ];
				end
				4'd5:
				begin
					accum_en_unit[ 5 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 6*BUF_DATA_WIDTH-1:5*BUF_DATA_WIDTH ];
				end
				4'd6:
				begin
					accum_en_unit[ 6 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 7*BUF_DATA_WIDTH-1:6*BUF_DATA_WIDTH ];
				end
				4'd7:
				begin
					accum_en_unit[ 7 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 8*BUF_DATA_WIDTH-1:7*BUF_DATA_WIDTH ];
				end
				4'd8:
				begin
					accum_en_unit[ 8 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 9*BUF_DATA_WIDTH-1:8*BUF_DATA_WIDTH ];
				end
				4'd9:
				begin
					accum_en_unit[ 9 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 10*BUF_DATA_WIDTH-1:9*BUF_DATA_WIDTH ];
				end
				4'd10:
				begin
					accum_en_unit[ 10 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 11*BUF_DATA_WIDTH-1:10*BUF_DATA_WIDTH ];
				end
				4'd11:
				begin
					accum_en_unit[ 11 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 12*BUF_DATA_WIDTH-1:11*BUF_DATA_WIDTH ];
				end
				4'd12:
				begin
					accum_en_unit[ 12 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 13*BUF_DATA_WIDTH-1:12*BUF_DATA_WIDTH ];
				end
				4'd13:
				begin
					accum_en_unit[ 13 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 14*BUF_DATA_WIDTH-1:13*BUF_DATA_WIDTH ];
				end
				4'd14:
				begin
					accum_en_unit[ 14 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 15*BUF_DATA_WIDTH-1:14*BUF_DATA_WIDTH ];
				end
				4'd15:
				begin
					accum_en_unit[ 15 ]	= 1'b1;
					prev_buf_data_sel_g = prev_buf_data[ 16*BUF_DATA_WIDTH-1:15*BUF_DATA_WIDTH ];
				end
			endcase
		end
	end // }}}


	genvar i;
	// initialize feature_out_reg unit memory {{{
	wire		[ KN*(2*US*2*US)*FW-1:0 ]	feature_out_data;
	generate
		for( i = 0; i < BUF_SEC_NUM; i = i + 1 )
		begin
			feature_out_reg_unit
			#(
				.FW( FW ),
				.US( US ),
				.MS( MS )
			 )
            feature_out_reg_unit_U
			 (
			 	.clk_i	( clk_i  ),
				.rstn_i	( rstn_i ),

				.accum_en_i			( accum_en_unit[ i ] 											),
				.accum_data_i		( accumed_buf_data 												),
				.addr_x_i			( addr_x_i 														),
				.addr_y_i			( addr_y_i 														),
				.bias_full_i		( bias_full_i 													),
				.bias_data_i		( bias_data_i[ (BUF_SEC_NUM-i)*MS*FW-1:(BUF_SEC_NUM-1-i)*MS*FW] ),
				.prev_buf_data_o	( prev_buf_data[ (i+1)*BUF_DATA_WIDTH-1:i*BUF_DATA_WIDTH] 		),
                .wr_done_i          ( wr_done_i                                                     ),
				.wr_en_i			( wr_en_i 														),
				.feature_out_data_o	( feature_out_data[ (i+1)*MS*4*US*US*FW-1:i*MS*4*US*US*FW ] 	)
			 );
		end
	endgenerate
	// }}}
	// calculate accumulared feature data {{{
	generate
		for( i = 0; i < MS; i = i + 1 )
		begin
			float_add2
			#(
				.EW( EW ),
				.MW( MW ),
				.FW( FW )
			 )
			 float_add2_U
			 (
			 	.data_f0_i	( prev_buf_data_sel_g[ (i+1)*FW-1:i*FW ] 	),
				.data_f1_i	( accum_data_i[ (MS-i)*FW-1:(MS-i-1)*FW ]	),
				.data_f_o	( accumed_buf_data[ (i+1)*FW-1:i*FW ]		)
			 );
			/*
			fpadd_2path
			#(
				.wE( EW ),
				.wF( MW )
			 )
			 float_add2_U
			 (
			 	.nA	( prev_buf_data[ (i+1)*FW-1:i*FW ] 		),
				.nB	( accum_data_i[ (MS-i)*FW-1:(MS-i-1)*FW ]),
				.nR	( accumed_buf_data[ (i+1)*FW-1:i*FW ]	)
			 );
			 */
			/*
			fp_adder2
			#(
				.EXPONENT( EW ),
				.MANTISSA( MW )
			 )
			 float_add2_U
			 (
			 	.a1			( prev_buf_data[ (i+1)*FW-1:i*FW ] 		),
				.a2			( accum_data_i[ (MS-i)*FW-1:(MS-i-1)*FW ]),
				.adder_o	( accumed_buf_data[ (i+1)*FW-1:i*FW ]	)
			 );
			 */
		end
	endgenerate
	// }}}
	
	assign feature_out_data0_o = feature_out_data[ 1*MS*4*US*US*FW-1:0*MS*4*US*US*FW ];
	assign feature_out_data1_o = feature_out_data[ 2*MS*4*US*US*FW-1:1*MS*4*US*US*FW ];
	assign feature_out_data2_o = feature_out_data[ 3*MS*4*US*US*FW-1:2*MS*4*US*US*FW ];
	assign feature_out_data3_o = feature_out_data[ 4*MS*4*US*US*FW-1:3*MS*4*US*US*FW ];
	assign feature_out_data4_o = feature_out_data[ 5*MS*4*US*US*FW-1:4*MS*4*US*US*FW ];
	assign feature_out_data5_o = feature_out_data[ 6*MS*4*US*US*FW-1:5*MS*4*US*US*FW ];
	assign feature_out_data6_o = feature_out_data[ 7*MS*4*US*US*FW-1:6*MS*4*US*US*FW ];
	assign feature_out_data7_o = feature_out_data[ 8*MS*4*US*US*FW-1:7*MS*4*US*US*FW ];
	assign feature_out_data8_o = feature_out_data[ 9*MS*4*US*US*FW-1:8*MS*4*US*US*FW ];
	assign feature_out_data9_o = feature_out_data[ 10*MS*4*US*US*FW-1:9*MS*4*US*US*FW ];
	assign feature_out_data10_o = feature_out_data[ 11*MS*4*US*US*FW-1:10*MS*4*US*US*FW ];
	assign feature_out_data11_o = feature_out_data[ 12*MS*4*US*US*FW-1:11*MS*4*US*US*FW ];
	assign feature_out_data12_o = feature_out_data[ 13*MS*4*US*US*FW-1:12*MS*4*US*US*FW ];
	assign feature_out_data13_o = feature_out_data[ 14*MS*4*US*US*FW-1:13*MS*4*US*US*FW ];
	assign feature_out_data14_o = feature_out_data[ 15*MS*4*US*US*FW-1:14*MS*4*US*US*FW ];
	assign feature_out_data15_o = feature_out_data[ 16*MS*4*US*US*FW-1:15*MS*4*US*US*FW ];

endmodule
