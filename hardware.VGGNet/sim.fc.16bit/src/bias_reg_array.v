/*--------------------------------------------------
 * This module is bias reg array buffer for storing
 * current convolution bias.
 *
 * parameter:
 * FW: float width
 * DW: data width from read_op module
 * DL: register array len
 *
 * ports:
 * clk_i	:	input clock
 * rstn_i	:	negative actice global reset
 * en_i		:	shift enable
 * data_i	:	input bias data from read_op
 * bias_o	:	bias output
--------------------------------------------------*/
`timescale 1 ns/1 ns
module bias_reg_array
#( 	
	parameter FW = 32,
	parameter DW = 512,
	parameter RL = 512
 )
 (
	input	 				clk_i,
	input					rstn_i,
 	input					en_i,
	input					last_data_i,
	input 	[ DW-1:0 ]		data_i,

	output	[ RL*FW-1:0 ]	bias_o
 );

	localparam	PACKAGE_LEN = DW / FW; // data number in one input data data_i
	localparam 	PACKAGE_NUM = RL / PACKAGE_LEN;

	/*
	 * internal register and wire
	*/
	reg	[ FW-1:0 ] 			bias_[ 0:RL-1 ]; // bias register array
	reg	[ PACKAGE_NUM-1:0 ]	receive_en;
	
	always @( negedge rstn_i or posedge clk_i )
	begin
		if( rstn_i == 1'b0 )
		begin
			receive_en <= {1'b1,{(PACKAGE_NUM-1){1'b0}} };
		end
		else if( last_data_i == 1'b1 )
		begin
			receive_en <= { en_i, {(PACKAGE_NUM-1){1'b0}} };
		end
		else if( en_i == 1'b1 )
		begin
			receive_en <= receive_en >> 1;
		end
	end
	genvar i;
	generate
		for( i = 0; i < PACKAGE_NUM; i = i + 1)
		begin
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					bias_[ i*PACKAGE_LEN + 0 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 1 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 2 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 3 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 4 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 5 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 6 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 7 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 8 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 9 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 10 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 11 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 12 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 13 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 14 ] <= {FW{1'b0}};
					bias_[ i*PACKAGE_LEN + 15 ] <= {FW{1'b0}};
				end
				else if( receive_en[ i ] == 1'b1 && en_i == 1'b1 )
				begin
					bias_[ i*PACKAGE_LEN + 0 ] <= data_i[ 1*FW-1:0*FW ];
					bias_[ i*PACKAGE_LEN + 1 ] <= data_i[ 2*FW-1:1*FW ];
					bias_[ i*PACKAGE_LEN + 2 ] <= data_i[ 3*FW-1:2*FW ];
					bias_[ i*PACKAGE_LEN + 3 ] <= data_i[ 4*FW-1:3*FW ];
					bias_[ i*PACKAGE_LEN + 4 ] <= data_i[ 5*FW-1:4*FW ];
					bias_[ i*PACKAGE_LEN + 5 ] <= data_i[ 6*FW-1:5*FW ];
					bias_[ i*PACKAGE_LEN + 6 ] <= data_i[ 7*FW-1:6*FW ];
					bias_[ i*PACKAGE_LEN + 7 ] <= data_i[ 8*FW-1:7*FW ];
					bias_[ i*PACKAGE_LEN + 8 ] <= data_i[ 9*FW-1:8*FW ];
					bias_[ i*PACKAGE_LEN + 9 ] <= data_i[ 10*FW-1:9*FW ];
					bias_[ i*PACKAGE_LEN + 10 ] <= data_i[ 11*FW-1:10*FW ];
					bias_[ i*PACKAGE_LEN + 11 ] <= data_i[ 12*FW-1:11*FW ];
					bias_[ i*PACKAGE_LEN + 12 ] <= data_i[ 13*FW-1:12*FW ];
					bias_[ i*PACKAGE_LEN + 13 ] <= data_i[ 14*FW-1:13*FW ];
					bias_[ i*PACKAGE_LEN + 14 ] <= data_i[ 15*FW-1:14*FW ];
					bias_[ i*PACKAGE_LEN + 15 ] <= data_i[ 16*FW-1:15*FW ];
				end
			end
		end
	endgenerate

	/*
	 * output
	*/
	generate
		for( i = 0; i < RL; i = i + 1)
		begin:pack_out
			assign bias_o[ (i+1)*FW-1:i*FW ] = bias_[ i ];
		end // end pack_out
	endgenerate

endmodule
