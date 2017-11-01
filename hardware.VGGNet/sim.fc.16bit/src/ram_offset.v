/*
 * This module calculate ram offset for side and top ram
 * accoding to feature index and convolution index.
 * */
module ram_offset
(
	input 	[ 9-1:0 ] 	feature_index_i,
	input	[ 3-1:0 ]	conv_layer_index_i,

	output	[ 13-1:0 ]	top_offset_o,
	output	[ 13-1:0 ]	side_offset_o
);

	wire	[ 13-1:0 ]	top_ram_addr_offset;
	reg		[ 13-1:0 ]	top_ram_addr_offset_0;
	reg		[ 13-1:0 ]	top_ram_addr_offset_1;
	reg		[ 13-1:0 ]	top_ram_addr_offset_2;
	reg		[ 13-1:0 ]	top_ram_addr_offset_3;
	reg		[ 13-1:0 ]	top_ram_addr_offset_4;
	reg		[ 13-1:0 ]	top_ram_addr_offset_5;
	reg		[ 13-1:0 ]	top_ram_addr_offset_6;
	reg		[ 13-1:0 ]	top_ram_addr_offset_7;
	reg		[ 13-1:0 ]	top_ram_addr_offset_8;

	wire	[ 13-1:0 ]	side_ram_addr_offset;
	reg		[ 13-1:0 ]	side_ram_addr_offset_0;
	reg		[ 13-1:0 ]	side_ram_addr_offset_1;
	reg		[ 13-1:0 ]	side_ram_addr_offset_2;
	reg		[ 13-1:0 ]	side_ram_addr_offset_3;
	reg		[ 13-1:0 ]	side_ram_addr_offset_4;
	reg		[ 13-1:0 ]	side_ram_addr_offset_5;
	reg		[ 13-1:0 ]	side_ram_addr_offset_6;
	reg		[ 13-1:0 ]	side_ram_addr_offset_7;
	reg		[ 13-1:0 ]	side_ram_addr_offset_8;

	assign top_offset_o	 = top_ram_addr_offset_0 + top_ram_addr_offset_1 + top_ram_addr_offset_2 +
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

	assign side_offset_o = side_ram_addr_offset_0 + side_ram_addr_offset_1 + side_ram_addr_offset_2 +
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

endmodule
