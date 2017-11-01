/*------------------------------------------------
 * This module update conv buffer data to 
 * top ram bram and side bram.
 * We can read neccessary data from bram instead of
 * DDR next conv time.
 *
 * parameter:
 * FW		:	float data widtj
 * US		:	unit store block size
 *
 * ports:
 * clk_i				:	input clock
 * rstn_i				:	global reset signal
 * feature_index_i		:	current feature map index
 * conv_layer_index_i	:	current convolution layer index
 * update_trigger_i		:	update trigger signal to activiate updating
 * update_data_0/1_i	:	update data
 * x_pos_i				:	convolution position in x direction for feature
 * top_ram_en_o			:	top_ram enbale signal
 * top_ram_wren_o		:	top_ram write enable signal
 * top_ram_addr_o		:	top_ram	write address
 * top_ram_data_o		:	top_ram write data
 *
 * side_ram_en_o		: 	side_ram enbale signal
 * side_ram_wren_o		:	side_ram write enbale signal
 * side_ram_addr_o		:	side_ram write address
 * side_ram_data_o		:	side_ram write data
 *
 * ----------------------------------------------*/
module update_op
#(
	parameter FW = 32,
	parameter US = 7
 )
 (
 	input			clk_i,
	input			rstn_i,

	input	[ 9-1:0 ]						feature_index_i,
	input	[ 3-1:0 ]						conv_layer_index_i,
    input                                   sel_r_i,
    input                                   update_en_i,
	input	[ 2-1:0 ]						update_trigger_i,
	input	[ (2*US+2)*(3*US+1)*FW-1:0 ] 	update_data_0_i,
	input	[ (2*US+2)*(3*US+1)*FW-1:0 ] 	update_data_1_i,

	input	   [ 5-1:0 ]						x_pos_i,
	output reg									top_ram_en_o,
	output reg									top_ram_wren_o,
	output reg [ 10-1:0 ]						top_ram_addr_o,
	output reg [ (2*US+2)*FW-1:0 ]				top_ram_data_o,

	output reg									side_ram_en_o,
	output reg									side_ram_wren_o,
	output reg [ 12-1:0 ]						side_ram_addr_o,
	output reg [ (2*US+1)*FW-1:0 ]				side_ram_data_o
 );


	/*
	 * address-related process
	 * */
	wire	[ 10-1:0 ]	top_ram_addr_offset;
	reg		[ 10-1:0 ]	top_ram_addr_offset_0;
	reg		[ 10-1:0 ]	top_ram_addr_offset_1;
	reg		[ 10-1:0 ]	top_ram_addr_offset_2;
	reg		[ 10-1:0 ]	top_ram_addr_offset_3;
	reg		[ 10-1:0 ]	top_ram_addr_offset_4;
	reg		[ 10-1:0 ]	top_ram_addr_offset_5;
	reg		[ 10-1:0 ]	top_ram_addr_offset_6;
	reg		[ 10-1:0 ]	top_ram_addr_offset_7;
	reg		[ 10-1:0 ]	top_ram_addr_offset_8;

	wire	[ 12-1:0 ]	side_ram_addr_offset;
	reg		[ 12-1:0 ]	side_ram_addr_offset_0;
	reg		[ 12-1:0 ]	side_ram_addr_offset_1;
	reg		[ 12-1:0 ]	side_ram_addr_offset_2;
	reg		[ 12-1:0 ]	side_ram_addr_offset_3;
	reg		[ 12-1:0 ]	side_ram_addr_offset_4;
	reg		[ 12-1:0 ]	side_ram_addr_offset_5;
	reg		[ 12-1:0 ]	side_ram_addr_offset_6;
	reg		[ 12-1:0 ]	side_ram_addr_offset_7;
	reg		[ 12-1:0 ]	side_ram_addr_offset_8;

	reg		[ 2-1:0 ]	update_sel;

	assign top_ram_addr_offset = top_ram_addr_offset_0 + top_ram_addr_offset_1 + top_ram_addr_offset_2 +
								 top_ram_addr_offset_3 + top_ram_addr_offset_4 + top_ram_addr_offset_5 +
								 top_ram_addr_offset_6 + top_ram_addr_offset_7 + top_ram_addr_offset_8;
	always @( conv_layer_index_i or feature_index_i )
	begin
		case( conv_layer_index_i ) // top_ram write address is decided by feature index and feature size {{{
			3'd0:
			begin
				top_ram_addr_offset_2		<= 10'd0;
				top_ram_addr_offset_3		<= 10'd0;
				top_ram_addr_offset_4		<= 10'd0;
				top_ram_addr_offset_5		<= 10'd0;
				top_ram_addr_offset_6		<= 10'd0;
				top_ram_addr_offset_7		<= 10'd0;
				top_ram_addr_offset_8		<= 10'd0;
				if( feature_index_i[ 0 ] == 1'b1 )
					top_ram_addr_offset_0	<= 10'd16;
				else
					top_ram_addr_offset_0	<= 10'd0;
				if( feature_index_i[ 1 ] == 1'b1 )
					top_ram_addr_offset_1	<= 10'd32;
				else
					top_ram_addr_offset_1	<= 10'd0;
			end
			3'd1:
			begin
				top_ram_addr_offset_6		<= 10'd0;
				top_ram_addr_offset_7		<= 10'd0;
				top_ram_addr_offset_8		<= 10'd0;
				if( feature_index_i[ 0 ] == 1'b1 )
					top_ram_addr_offset_0	<= 10'd16;
				else
					top_ram_addr_offset_0	<= 10'd0;
				if( feature_index_i[ 1 ] == 1'b1 )
					top_ram_addr_offset_1	<= 10'd32;
				else
					top_ram_addr_offset_1	<= 10'd0;
				if( feature_index_i[ 2] == 1'b1 )
					top_ram_addr_offset_2	<= 10'd64;
				else
					top_ram_addr_offset_2	<= 10'd0;
				if( feature_index_i[ 3] == 1'b1 )
					top_ram_addr_offset_3	<= 10'd128;
				else
					top_ram_addr_offset_3	<= 10'd0;
				if( feature_index_i[ 4] == 1'b1 )
					top_ram_addr_offset_4	<= 10'd256;
				else
					top_ram_addr_offset_4	<= 10'd0;
				if( feature_index_i[ 5] == 1'b1 )
					top_ram_addr_offset_5	<= 10'd512;
				else
					top_ram_addr_offset_5	<= 10'd0;
			end
			3'd2:
			begin
				top_ram_addr_offset_7		<= 10'd0;
				top_ram_addr_offset_8		<= 10'd0;
				if( feature_index_i[ 0 ] == 1'b1 )
					top_ram_addr_offset_0	<= 10'd8;
				else
					top_ram_addr_offset_0	<= 10'd0;
				if( feature_index_i[ 1 ] == 1'b1 )
					top_ram_addr_offset_1	<= 10'd16;
				else
					top_ram_addr_offset_1	<= 10'd0;
				if( feature_index_i[ 2] == 1'b1 )
					top_ram_addr_offset_2	<= 10'd32;
				else
					top_ram_addr_offset_2	<= 10'd0;
				if( feature_index_i[ 3] == 1'b1 )
					top_ram_addr_offset_3	<= 10'd64;
				else
					top_ram_addr_offset_3	<= 10'd0;
				if( feature_index_i[ 4] == 1'b1 )
					top_ram_addr_offset_4	<= 10'd128;
				else
					top_ram_addr_offset_4	<= 10'd0;
				if( feature_index_i[ 5] == 1'b1 )
					top_ram_addr_offset_5	<= 10'd256;
				else
					top_ram_addr_offset_5	<= 10'd0;
				if( feature_index_i[ 6] == 1'b1 )
					top_ram_addr_offset_6	<= 10'd512;
				else
					top_ram_addr_offset_6	<= 10'd0;
			end
			3'd3:
			begin
				top_ram_addr_offset_8	<= 10'd0;
				if( feature_index_i[ 0 ] == 1'b1 )
					top_ram_addr_offset_0	<= 10'd4;
				else
					top_ram_addr_offset_0	<= 10'd0;
				if( feature_index_i[ 1 ] == 1'b1 )
					top_ram_addr_offset_1	<= 10'd8;
				else
					top_ram_addr_offset_1	<= 10'd0;
				if( feature_index_i[ 2] == 1'b1 )
					top_ram_addr_offset_2	<= 10'd16;
				else
					top_ram_addr_offset_2	<= 10'd0;
				if( feature_index_i[ 3] == 1'b1 )
					top_ram_addr_offset_3	<= 10'd32;
				else
					top_ram_addr_offset_3	<= 10'd0;
				if( feature_index_i[ 4] == 1'b1 )
					top_ram_addr_offset_4	<= 10'd64;
				else
					top_ram_addr_offset_4	<= 10'd0;
				if( feature_index_i[ 5] == 1'b1 )
					top_ram_addr_offset_5	<= 10'd128;
				else
					top_ram_addr_offset_5	<= 10'd0;
				if( feature_index_i[ 6] == 1'b1 )
					top_ram_addr_offset_6	<= 10'd256;
				else
					top_ram_addr_offset_6	<= 10'd0;
				if( feature_index_i[ 7] == 1'b1 )
					top_ram_addr_offset_7	<= 10'd512;
				else
					top_ram_addr_offset_7	<= 10'd0;
			end
			3'd4:
			begin
				if( feature_index_i[ 0 ] == 1'b1 )
					top_ram_addr_offset_0	<= 10'd2;
				else
					top_ram_addr_offset_0	<= 10'd2;
				if( feature_index_i[ 1 ] == 1'b1 )
					top_ram_addr_offset_1	<= 10'd4;
				else
					top_ram_addr_offset_1	<= 10'd0;
				if( feature_index_i[ 2] == 1'b1 )
					top_ram_addr_offset_2	<= 10'd8;
				else
					top_ram_addr_offset_2	<= 10'd0;
				if( feature_index_i[ 3] == 1'b1 )
					top_ram_addr_offset_3	<= 10'd16;
				else
					top_ram_addr_offset_3	<= 10'd0;
				if( feature_index_i[ 4] == 1'b1 )
					top_ram_addr_offset_4	<= 10'd32;
				else
					top_ram_addr_offset_4	<= 10'd0;
				if( feature_index_i[ 5] == 1'b1 )
					top_ram_addr_offset_5	<= 10'd64;
				else
					top_ram_addr_offset_5	<= 10'd0;
				if( feature_index_i[ 6] == 1'b1 )
					top_ram_addr_offset_6	<= 10'd128;
				else
					top_ram_addr_offset_6	<= 10'd0;
				if( feature_index_i[ 7] == 1'b1 )
					top_ram_addr_offset_7	<= 10'd256;
				else
					top_ram_addr_offset_7	<= 10'd0;
				if( feature_index_i[ 8] == 1'b1 )
					top_ram_addr_offset_8	<= 10'd512;
				else
					top_ram_addr_offset_8	<= 10'd0;
			end
			3'd5:
			begin
				if( feature_index_i[ 0 ] == 1'b1 )
					top_ram_addr_offset_0	<= 10'd1;
				else
					top_ram_addr_offset_0	<= 10'd1;
				if( feature_index_i[ 1 ] == 1'b1 )
					top_ram_addr_offset_1	<= 10'd2;
				else
					top_ram_addr_offset_1	<= 10'd0;
				if( feature_index_i[ 2] == 1'b1 )
					top_ram_addr_offset_2	<= 10'd4;
				else
					top_ram_addr_offset_2	<= 10'd0;
				if( feature_index_i[ 3] == 1'b1 )
					top_ram_addr_offset_3	<= 10'd8;
				else
					top_ram_addr_offset_3	<= 10'd0;
				if( feature_index_i[ 4] == 1'b1 )
					top_ram_addr_offset_4	<= 10'd16;
				else
					top_ram_addr_offset_4	<= 10'd0;
				if( feature_index_i[ 5] == 1'b1 )
					top_ram_addr_offset_5	<= 10'd32;
				else
					top_ram_addr_offset_5	<= 10'd0;
				if( feature_index_i[ 6] == 1'b1 )
					top_ram_addr_offset_6	<= 10'd64;
				else
					top_ram_addr_offset_6	<= 10'd0;
				if( feature_index_i[ 7] == 1'b1 )
					top_ram_addr_offset_7	<= 10'd128;
				else
					top_ram_addr_offset_7	<= 10'd0;
				if( feature_index_i[ 8] == 1'b1 )
					top_ram_addr_offset_8	<= 10'd256;
				else
					top_ram_addr_offset_8	<= 10'd0;
			end
			default:
			begin
				top_ram_addr_offset_0		<= 10'd0;
				top_ram_addr_offset_1		<= 10'd0;
				top_ram_addr_offset_2		<= 10'd0;
				top_ram_addr_offset_3		<= 10'd0;
				top_ram_addr_offset_4		<= 10'd0;
				top_ram_addr_offset_5		<= 10'd0;
				top_ram_addr_offset_6		<= 10'd0;
				top_ram_addr_offset_7		<= 10'd0;
				top_ram_addr_offset_8		<= 10'd0;
			end
		endcase // }}}
	end

	assign side_ram_addr_offset = side_ram_addr_offset_0 + side_ram_addr_offset_1 + side_ram_addr_offset_2 +
								  side_ram_addr_offset_3 + side_ram_addr_offset_4 + side_ram_addr_offset_5 +
								  side_ram_addr_offset_6 + side_ram_addr_offset_7 + side_ram_addr_offset_8;
	always @( feature_index_i ) // side_ram address offset is only decided by feature map index {{{
	begin
		if( feature_index_i [ 0 ] )
			side_ram_addr_offset_0	<= 12'd8; 
		else
			side_ram_addr_offset_0	<= 12'd0; 
		if( feature_index_i [ 1 ] )
			side_ram_addr_offset_1	<= 12'd16; 
		else
			side_ram_addr_offset_1	<= 12'd0; 
		if( feature_index_i [ 2 ] )
			side_ram_addr_offset_2	<= 12'd32; 
		else
			side_ram_addr_offset_2	<= 12'd0; 
		if( feature_index_i [ 3 ] )
			side_ram_addr_offset_3	<= 12'd64; 
		else
			side_ram_addr_offset_3	<= 12'd0; 
		if( feature_index_i [ 4 ] )
			side_ram_addr_offset_4	<= 12'd128; 
		else
			side_ram_addr_offset_4	<= 12'd0; 
		if( feature_index_i [ 5 ] )
			side_ram_addr_offset_5	<= 12'd256; 
		else
			side_ram_addr_offset_5	<= 12'd0; 
		if( feature_index_i [ 6 ] )
			side_ram_addr_offset_6	<= 12'd512; 
		else
			side_ram_addr_offset_6	<= 12'd0; 
		if( feature_index_i [ 7 ] )
			side_ram_addr_offset_7	<= 12'd1024; 
		else
			side_ram_addr_offset_7	<= 12'd0; 
		if( feature_index_i [ 8 ] )
			side_ram_addr_offset_8	<= 12'd2048; 
		else
			side_ram_addr_offset_8	<= 12'd0; 
	end // }}}
	/*
	 * update top_ram  and side_ram bram 
	 * */
	reg	[ 5-1:0 ]	x_pos_delay;
	reg	[ 5-1:0 ]	x_pos_delay2;
	reg	[ 2-1:0 ]	update_trigger_delay;
	always @( negedge rstn_i or posedge clk_i )
	begin
		if( rstn_i == 1'b0 )
		begin
			x_pos_delay				<= 5'd0;
			x_pos_delay2			<= 5'd0;
			update_trigger_delay	<= 2'b00;
		end
		else
		begin
			x_pos_delay				<= x_pos_i;
			x_pos_delay2			<= x_pos_delay;
			update_trigger_delay	<= update_trigger_i;
		end
	end
	always @( negedge rstn_i or posedge clk_i ) // {{{
	begin
		if( rstn_i == 1'b0 )
		begin
			top_ram_en_o	<= 1'b0;
			top_ram_wren_o	<= 1'b0;
			top_ram_addr_o	<= 10'd0;
			top_ram_data_o	<= {(2*US+2)*FW{1'b0}};
		end
		else if( update_en_i == 1'b1 && sel_r_i == 1'b0 /*update_trigger_delay == 2'b01*/ )
		begin
			top_ram_en_o	<= 1'b1;
			top_ram_wren_o	<= 1'b1;

			top_ram_addr_o	<= top_ram_addr_offset + { 5'd0, x_pos_i };
			top_ram_data_o	<= update_data_0_i[ ((2*US)*(3*US+1)+(2*US+2))*FW-1:(2*US)*(3*US+1)*FW ]; 
		end
		else if( update_en_i == 1'b1 && sel_r_i == 1'b1 /*update_trigger_delay == 2'b10*/ )
		begin
			top_ram_en_o	<= 1'b1;
			top_ram_wren_o	<= 1'b1;

			top_ram_addr_o	<= top_ram_addr_offset + { 5'd0, x_pos_i };
			top_ram_data_o	<= update_data_1_i[ ((2*US)*(3*US+1)+(2*US+2))*FW-1:(2*US)*(3*US+1)*FW ]; 
		end
		else
		begin
			top_ram_en_o	<= 1'b0;
			top_ram_wren_o	<= 1'b0;

			top_ram_addr_o	<= 10'd0;
			top_ram_data_o	<= {(2*US+2)*FW{1'b0}};
		end
	end // }}}

	/*
	 * update side_ram bram 
	 * */
	genvar i;
	reg	[ 12-1:0 ] addr_partial;
	generate // {{{
		always @( negedge rstn_i or posedge clk_i )
		begin
			if( rstn_i == 1'b0 )
			begin
				addr_partial	<= 12'd0;

				side_ram_en_o	<= 1'b0;
				side_ram_wren_o	<= 1'b0;
				side_ram_addr_o	<= 12'd0;

				update_sel		<= 2'b00;
			end
			else if( update_en_i == 1'b1 /*(update_trigger_delay==2'b01 || update_trigger_delay == 2'b10)*/ && side_ram_en_o == 1'b0 )
			begin
				addr_partial	<= addr_partial + 12'd1;

				update_sel		<= sel_r_i==1'b0 ? 2'b01 : 2'b10 /*update_trigger_delay*/;
				side_ram_en_o	<= 1'b1;
				side_ram_wren_o	<= 1'b1;
				side_ram_addr_o	<= side_ram_addr_offset + addr_partial;
			end
			else if( side_ram_en_o == 1'b1 )
			begin
				if( addr_partial < 12'd8 )	
				begin
					addr_partial	<= addr_partial + 12'd1;

					side_ram_wren_o	<= 1'b1;
					side_ram_addr_o	<= side_ram_addr_offset + addr_partial;
				end
				else
				begin
					addr_partial <= 12'd0;

					update_sel		<= sel_r_i==1'b0 ? 2'b01: 2'b10 /*update_trigger_delay*/;
					side_ram_en_o	<= 1'b0;
					side_ram_wren_o	<= 1'b0;
					side_ram_addr_o	<= 12'd0;
				end
			end
		end
		for( i = 0; i < 2*US+1; i = i + 1 )
		begin:ram_data_ouput
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
					side_ram_data_o <= {(2*US+1)*FW{1'b0}};
				else if( update_en_i /*(update_trigger_delay==2'b01 || update_trigger_delay==2'b10)*/ 
                         && side_ram_en_o == 1'b0 )
				begin
					side_ram_data_o[ (i+1)*FW-1:i*FW ] <= sel_r_i == 1'b0/*update_trigger_delay == 2'b01*/ 
                                                          ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+1)*FW-1:((2*US+1-i)*(3*US+1)+2*US)*FW ]
														  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+1)*FW-1:((2*US+1-i)*(3*US+1)+2*US)*FW ];
				end
				else if( side_ram_en_o == 1'b1 )
				begin
					case( addr_partial )
						12'd1:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+2)*FW-1:((2*US+1-i)*(3*US+1)+2*US+1)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+2)*FW-1:((2*US+1-i)*(3*US+1)+2*US+1)*FW ];
						end
						12'd2:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+3)*FW-1:((2*US+1-i)*(3*US+1)+2*US+2)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+3)*FW-1:((2*US+1-i)*(3*US+1)+2*US+2)*FW ];
						end
						12'd3:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+4)*FW-1:((2*US+1-i)*(3*US+1)+2*US+3)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+4)*FW-1:((2*US+1-i)*(3*US+1)+2*US+3)*FW ];
						end
						12'd4:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+5)*FW-1:((2*US+1-i)*(3*US+1)+2*US+4)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+5)*FW-1:((2*US+1-i)*(3*US+1)+2*US+4)*FW ];
						end
						12'd5:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+6)*FW-1:((2*US+1-i)*(3*US+1)+2*US+5)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+6)*FW-1:((2*US+1-i)*(3*US+1)+2*US+5)*FW ];
						end
						12'd6:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+7)*FW-1:((2*US+1-i)*(3*US+1)+2*US+6)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+7)*FW-1:((2*US+1-i)*(3*US+1)+2*US+6)*FW ];
						end
						12'd7:
						begin
							side_ram_data_o[ (i+1)*FW-1:i*FW ] <= update_sel == 2'b01 ? update_data_0_i[ ((2*US+1-i)*(3*US+1)+2*US+8)*FW-1:((2*US+1-i)*(3*US+1)+2*US+7)*FW ]
																				   	  : update_data_1_i[ ((2*US+1-i)*(3*US+1)+2*US+8)*FW-1:((2*US+1-i)*(3*US+1)+2*US+7)*FW ];
						end
					endcase
				end
			end // always
		end // ram_data_ouput
	endgenerate // }}}

endmodule
