/*
 * This module prcess exponent matching in
 * float add/sub operation.
 * 
 * parameter
 * EW:	float exponent width
 * MW:	float mantisa width
 * FW:	float width
 *
 * ports:
 * float0_i:	
 * float1_i:	two input float data
 * exp_o:		exponent after exponent matching
 * close_o:		flag indicates exponen are same
 * sgn_big_o:	sgn for absolute bigger float
 * mantisa0_o:
 * mantisa1_o:	two mantisa after exponent matching
 *
 * */
`timescale 1 ns/1 ns
module exp_match
#(
	parameter	EW = 8,
	parameter	MW = 23,
	parameter	FW = 32
 )
 (
 	input	[ FW-1:0 ]	float0_i,
	input	[ FW-1:0 ]	float1_i,

	output	[ EW:0 ]	exp_o,
	output				close_o,
	output				equal_o,
	output				round_1_o,
	output				sgn_big_o,
	output	[ MW:0 	 ]	mantisa0_o,
	output	[ MW:0 	 ]	mantisa1_o
 );
`include "misc.v" 

localparam	MWE = MW+2;		// mantisa extend width
localparam	MAX_SHFT = min( log(MW+2), EW );
localparam	MSW = MAX_SHFT*(MW+2); // mantisa_shft array width
	// {{{ exp diff
	wire	[ EW:0 ]	exp0;
	wire	[ EW:0 ]	exp1;
	wire	[ EW:0 ]	exp_diff;
	wire	[ EW-1:0 ]	exp_diff_abs;
	wire				exp_sign;
	wire	[ EW-1:0 ]	exp_sign_ext;

	assign exp0 = { 1'b0, float0_i[ FW-2:MW] };
	assign exp1 = { 1'b0, float1_i[ FW-2:MW] };

	assign equal_o = exp0[ EW:0 ] == exp1[ EW:0 ];

	assign exp_diff 	= exp0 - exp1;
	assign exp_sign		= exp_diff[ EW ];
	assign exp_sign_ext = {EW{exp_sign}};
	assign exp_diff_abs = (exp_diff[ EW-1:0 ] ^ exp_sign_ext) + exp_sign;
	assign close_o 		= (exp_diff_abs == { {(EW-1){1'b0}}, 1'b1 }) || ( exp_diff_abs == { EW{1'b0} } );
	assign exp_o		= exp_sign == 1'b0 ? exp0 : exp1;
	assign sgn_big_o	= exp_sign == 1'b0 ? float0_i[ FW-1 ] : float1_i[ FW-1 ];
	// }}}
	
	// {{{ mantisa shift 
	wire	[ MW:0 ]	mantisa0;
	wire	[ MW:0 ]	mantisa1;
	reg		[ MSW-1:0 ]	mantisa_shft;
	wire	[ MWE-1:0 ]	mantisa_round;
	wire	[ EW-1:0 ]	exp_diff_trunk;
	wire				shft2zero;

	assign exp_diff_trunk = { { (EW-MAX_SHFT){1'b1}}, {MAX_SHFT{1'b0}} } & exp_diff_abs;
	assign shft2zero	  = exp_diff_trunk != { EW{1'b0} };
	
	assign	mantisa0 = exp_sign == 1'b0 ? { 1'b1, float0_i[ MW-1:0 ] } : { 1'b1, float1_i[ MW-1:0 ] }; 
	assign	mantisa1 = exp_sign == 1'b0 ? { 1'b1, float1_i[ MW-1:0 ] } : { 1'b1, float0_i[ MW-1:0 ] }; 

	always @( exp_diff_abs[ 0 ] or mantisa1 )
	begin
		if( exp_diff_abs[ 0 ] == 1'b0 )
			mantisa_shft[ MSW-1:MSW-MWE ] = { mantisa1, 1'b0 };
		else if( exp_diff_abs[ 0 ] == 1'b1 )
			mantisa_shft[ MSW-1:MSW-MWE ] = { 1'b0, mantisa1 };
	end

	genvar i;
	generate
		for( i = 1; i < MAX_SHFT; i = i + 1 )
		begin // {{{
			always @( exp_diff_abs[ i ] or mantisa_shft[ MSW-1-(i-1)*MWE:MSW-i*MWE ])
			if( exp_diff_abs[ i ] == 1'b1 )
			begin
				mantisa_shft[ MSW-1-i*MWE:MSW-(i+1)*MWE ] = { {(2**i){1'b0}}, mantisa_shft[ MSW-1-(i-1)*MWE:MSW-i*MWE +(2**i)] };
			end
			else if( exp_diff_abs[ i ] == 1'b0 )
			begin
				mantisa_shft[ MSW-1-i*MWE:MSW-(i+1)*MWE ] = { mantisa_shft[ MSW-1-(i-1)*MWE:MSW-i*MWE ] };
			end
		end // }}}
	endgenerate
	assign mantisa_round = exp_diff=={EW{1'b0}}	? (mantisa_shft[ MWE-1:0 ]) : (mantisa_shft[ MWE-1:0 ]+1'b1);

	assign mantisa0_o = mantisa0;
	assign mantisa1_o = shft2zero == 1'b1 ? { (MW+1){1'b0} } : mantisa_round[ MWE-1:1 ];
	assign round_1_o  = exp_diff == { EW{1'b0} } ? 1'b0 : mantisa1[ 0 ];
	// }}}
endmodule
