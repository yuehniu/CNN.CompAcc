/*
 * This module fine-tune exponent and mantisa
 * if two closed float do subtractin operation
 *
 * parameter
 * EW:	float exponent width
 * MW:	float mantisa width
 * FW:	float width
 *
 * ports:
 * exp_i		:	input exponent
 * mantisa_i	:	input mantisa
 * exp_o		:	fine-tuned exponent
 * mantisa_o	:	fine-tuned mantisa
 * */
module float_fine_tune
#(
	parameter	EW = 8,
	parameter	MW = 23,
	parameter	FW = 32
 )
 (
 	input	[ EW:0 ]	exp_i,
	input	[ MW+2:0 ]	mantisa_i,
	input				round_1_i,

	output	[ EW:0 ]	exp_o,
	output	[ MW+1:0 ]	mantisa_o
 );
localparam	a_width		= MW+1;
localparam	MAX_SHFT 	= min( log(MW+1), EW );
localparam	ARRAY_WIDTH = MAX_SHFT*( MW+2 ); 
localparam	addr_width	= MAX_SHFT;
`include "DW_lzd_function.inc"
`include "misc.v"


	// get zeros count for input mantisa{{{
	wire	[ MAX_SHFT-1:0 ]	zeros_count;

	assign	zeros_count = DWF_lzd_enc( mantisa_i[ MW:0] );
	// }}}
	
	// fine-tune exponent {{{
	assign exp_o = exp_i - zeros_count;
	// }}}
	
	// fine-tune mantisa {{{
	reg	[ ARRAY_WIDTH-1:0 ]	mantisa_shft_array;
	genvar i;
	generate
		always @( mantisa_i or zeros_count[ 0 ] )
		begin
			if( zeros_count[ 0 ] == 1'b1 )
			begin
				mantisa_shft_array[ ARRAY_WIDTH-1:ARRAY_WIDTH-(MW+2) ] = { mantisa_i[ MW:0 ], round_1_i };
			end
			else if( zeros_count[ 0 ] == 1'b0 )
			begin
				mantisa_shft_array[ ARRAY_WIDTH-1:ARRAY_WIDTH-(MW+2) ] = mantisa_i[ MW+1:0 ];
			end
		end

		for( i = 1; i < MAX_SHFT; i = i + 1 )
		begin
			always @( mantisa_shft_array[ ARRAY_WIDTH-1-(i-1)*(MW+2):ARRAY_WIDTH-i*(MW+2)] or zeros_count[ i ] )
			begin
				if( zeros_count[ i ] == 1'b1 )
				begin
					if( zeros_count[ i-1:0 ] != {i{1'b0}} )
						mantisa_shft_array[ ARRAY_WIDTH-1-i*(MW+2):ARRAY_WIDTH-(i+1)*(MW+2)] = 
						{ mantisa_shft_array[ ARRAY_WIDTH-1-(i-1)*(MW+2)-(2**i):ARRAY_WIDTH-i*(MW+2)],{{2**i}{1'b0}} };
					else if( zeros_count[ i-1:0 ] == {i{1'b0}} )
						mantisa_shft_array[ ARRAY_WIDTH-1-i*(MW+2):ARRAY_WIDTH-(i+1)*(MW+2)] = 
						{ mantisa_shft_array[ ARRAY_WIDTH-1-(i-1)*(MW+2)-(2**i):ARRAY_WIDTH-i*(MW+2)],{round_1_i,{(2**i-1){1'b0}}} };
				end
				else if( zeros_count[ i ] == 1'b0 )
				begin
					mantisa_shft_array[ ARRAY_WIDTH-1-i*(MW+2):ARRAY_WIDTH-(i+1)*(MW+2)] = 
					mantisa_shft_array[ ARRAY_WIDTH-1-(i-1)*(MW+2):ARRAY_WIDTH-i*(MW+2)];
				end
			end
		end

	endgenerate
	// }}}
	assign mantisa_o = mantisa_shft_array[ MW+1:0 ];
endmodule
