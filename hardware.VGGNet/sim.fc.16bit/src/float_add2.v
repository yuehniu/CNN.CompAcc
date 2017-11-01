/* 
 * This module is a unit 2-path float add module
 *
 * parameter
 * EW:	float exponent width
 * MW:	float mantisa width
 * FW:	float width
 *
 * ports:
 * data_f0_i:	
 * data_f1_i:	two input float data
 * data_f_o:	output for sum of the float
 *
 * */
`timescale 1 ns/1 ns
module float_add2
#(
	parameter	EW = 8,
	parameter	MW = 23,
	parameter	FW = 32
 )
 (
 	input	[ FW-1:0 ]	data_f0_i,
	input	[ FW-1:0 ]	data_f1_i,

	output	[ FW-1:0 ]	data_f_o
 );
//`include "DW_lzd_function.inc"
`include "misc.v"

localparam	MAX_SHFT = min( log(MW+2), EW );


	// exponent matching {{{
	wire	[ EW:0 ]	exp;
	wire				equal;
	wire				close;
	wire				round_1;
	wire				sgn_big;
	wire	[ MW:0 ]	mantisa0;
	wire	[ MW:0 ]	mantisa1;
	exp_match
	#(
		.EW( EW ),
		.MW( MW ),
		.FW( FW )
	 )
	 (
	 	.float0_i( data_f0_i ),
		.float1_i( data_f1_i ),
		
		.exp_o		( exp 		),
		.equal_o	( equal		),
		.close_o	( close		),
		.sgn_big_o	( sgn_big	),
		.round_1_o	( round_1 	),
		.mantisa0_o	( mantisa0 	),
		.mantisa1_o	( mantisa1 	)
	 );
	// }}}
	
	// add mantisa {{{
	wire	add_or_sub;	
	wire	[ MW+2:0 ]			mantisa_result_;
	wire	[ MW+2:0 ] 			mantisa_result;
	reg		[ EW:0 ] 			exp_round;
	reg		[ MW+1:0 ] 			mantisa_ext_round; 
	reg		[ MW:0 ] 			mantisa_round; 

	wire	[ EW:0 ]			exp_close;
	wire	[ MW+1:0 ]			mantisa_close;

	assign 	add_or_sub 		= data_f0_i[ FW-1 ] ^ data_f1_i[ FW-1 ];
	assign	mantisa_result_ = add_or_sub == 1'b1 ? ( {2'b00,mantisa0} - {2'b00,mantisa1} ) : ( {2'b00,mantisa0} + {2'b00,mantisa1} );
	assign	mantisa_result 	= mantisa_result_[ MW+2 ] == 1'b1 ? { {MW{1'b0}},2'b0 } - mantisa_result_[ MW+1:0 ] : mantisa_result_;  

	float_fine_tune
	#(
		.EW( EW ),
		.MW( MW ),
		.FW( FW )
	 )
	 (
	 	.exp_i		( exp 			 ),
		.mantisa_i	( mantisa_result ),
		.round_1_i	( round_1 		 ),

		.exp_o		( exp_close 	 ),
		.mantisa_o	( mantisa_close  )
	 );
	always @( mantisa_result or exp )
	begin
		case( mantisa_result[ MW+1:MW ] )	
			2'b00:
			begin
				exp_round			=	exp - 1'b1; 
				mantisa_round		= { mantisa_result[ MW-1:0 ],1'b0 };
			end
			2'b01:
			begin
				exp_round			= exp;
				mantisa_round		= mantisa_result[ MW:0 ];
			end
			default:
			begin
				exp_round			= exp + 1'b1;
				mantisa_ext_round	= mantisa_result + 1'b1;
				mantisa_round		= { 1'b1, mantisa_ext_round[ MW:1 ]};
			end
		endcase
	end
	// }}}
	
	assign data_f_o[ FW-1 	 ] = ( add_or_sub == 1'b1 && equal == 1'b1 ) ? mantisa_result_[ MW+2 ] ^ sgn_big : sgn_big;  
	assign data_f_o[ FW-2:MW ] = ( add_or_sub == 1'b1 && close == 1'b1 ) ? ( exp_close[EW] == 1'b1 ? {EW{1'b0}} : exp_close[ EW-1:0 ] ) 
																		 : exp_round [ EW-1:0 ]; 
	assign data_f_o[ MW-1:0  ] = ( add_or_sub == 1'b1 && close == 1'b1 ) ? mantisa_close[ MW-1:0 ] : mantisa_round[ MW-1:0 ];

endmodule
