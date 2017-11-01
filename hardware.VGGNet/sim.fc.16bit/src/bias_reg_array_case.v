/*--------------------------------------------------
 * This module is bias reg array buffer for storing
 * current convolution bias.
 *
 * parameter:
 * EW: exponent width for float
 * MW: mantisa width for float
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
module bias_reg_array_case
#( 	
	parameter EW = 8,
	parameter MW = 23,
	parameter FW = 32,
	parameter DW = 512,
	parameter RL = 512
 )
 (
	input	 				clk_i,
	input					rstn_i,
 	input					en_i,
	input	[ 5-1:0 ]		addr_i,
	input 	[ DW-1:0 ]		data_i,

	output	[ RL*FW-1:0 ]	bias_o
 );

	localparam	PACKAGE_LEN = DW / FW; // data number in one input data data_i
	localparam 	PACKAGE_NUM = RL / PACKAGE_LEN;

	/*
	 * internal register and wire
	*/
	reg	[ DW-1:0 ] bias_[ 0:PACKAGE_NUM-1 ]; // bias register array

	always @( negedge rstn_i or posedge clk_i )
	begin
		if( rstn_i == 1'b0 )
		begin
			bias_[ 0 ] <= {DW{1'b0}};
			bias_[ 1 ] <= {DW{1'b0}};
			bias_[ 2 ] <= {DW{1'b0}};
			bias_[ 3 ] <= {DW{1'b0}};
			bias_[ 4 ] <= {DW{1'b0}};
			bias_[ 5 ] <= {DW{1'b0}};
			bias_[ 6 ] <= {DW{1'b0}};
			bias_[ 7 ] <= {DW{1'b0}};
			bias_[ 8 ] <= {DW{1'b0}};
			bias_[ 9 ] <= {DW{1'b0}};
			bias_[ 10 ] <= {DW{1'b0}};
			bias_[ 11 ] <= {DW{1'b0}};
			bias_[ 12 ] <= {DW{1'b0}};
			bias_[ 13 ] <= {DW{1'b0}};
			bias_[ 14 ] <= {DW{1'b0}};
			bias_[ 15 ] <= {DW{1'b0}};
			bias_[ 16 ] <= {DW{1'b0}};
			bias_[ 17 ] <= {DW{1'b0}};
			bias_[ 18 ] <= {DW{1'b0}};
			bias_[ 19 ] <= {DW{1'b0}};
			bias_[ 20 ] <= {DW{1'b0}};
			bias_[ 21 ] <= {DW{1'b0}};
			bias_[ 22 ] <= {DW{1'b0}};
			bias_[ 23 ] <= {DW{1'b0}};
			bias_[ 24 ] <= {DW{1'b0}};
			bias_[ 25 ] <= {DW{1'b0}};
			bias_[ 26 ] <= {DW{1'b0}};
			bias_[ 27 ] <= {DW{1'b0}};
			bias_[ 28 ] <= {DW{1'b0}};
			bias_[ 29 ] <= {DW{1'b0}};
			bias_[ 30 ] <= {DW{1'b0}};
			bias_[ 31 ] <= {DW{1'b0}};
		end
		else if( en_i == 1'b1 )	
		case( addr_i )
			5'd0:
			begin
				bias_[ 0 ] <= data_i;
			end
			5'd1:
			begin
				bias_[ 1 ] <= data_i;
			end
			5'd2:
			begin
				bias_[ 2 ] <= data_i;
			end
			5'd3:
			begin
				bias_[ 3 ] <= data_i;
			end
			5'd4:
			begin
				bias_[ 4 ] <= data_i;
			end
			5'd5:
			begin
				bias_[ 5 ] <= data_i;
			end
			5'd6:
			begin
				bias_[ 6 ] <= data_i;
			end
			5'd7:
			begin
				bias_[ 7 ] <= data_i;
			end
			5'd8:
			begin
				bias_[ 8 ] <= data_i;
			end
			5'd9:
			begin
				bias_[ 9 ] <= data_i;
			end
			5'd10:
			begin
				bias_[ 10 ] <= data_i;
			end
			5'd11:
			begin
				bias_[ 11 ] <= data_i;
			end
			5'd12:
			begin
				bias_[ 12 ] <= data_i;
			end
			5'd13:
			begin
				bias_[ 13 ] <= data_i;
			end
			5'd14:
			begin
				bias_[ 14 ] <= data_i;
			end
			5'd15:
			begin
				bias_[ 15 ] <= data_i;
			end
			5'd16:
			begin
				bias_[ 16 ] <= data_i;
			end
			5'd17:
			begin
				bias_[ 17 ] <= data_i;
			end
			5'd18:
			begin
				bias_[ 18 ] <= data_i;
			end
			5'd19:
			begin
				bias_[ 19 ] <= data_i;
			end
			5'd20:
			begin
				bias_[ 20 ] <= data_i;
			end
			5'd21:
			begin
				bias_[ 21 ] <= data_i;
			end
			5'd22:
			begin
				bias_[ 22 ] <= data_i;
			end
			5'd23:
			begin
				bias_[ 23 ] <= data_i;
			end
			5'd24:
			begin
				bias_[ 24 ] <= data_i;
			end
			5'd25:
			begin
				bias_[ 25 ] <= data_i;
			end
			5'd26:
			begin
				bias_[ 26 ] <= data_i;
			end
			5'd27:
			begin
				bias_[ 27 ] <= data_i;
			end
			5'd28:
			begin
				bias_[ 28 ] <= data_i;
			end
			5'd29:
			begin
				bias_[ 29 ] <= data_i;
			end
			5'd30:
			begin
				bias_[ 30 ] <= data_i;
			end
			5'd31:
			begin
				bias_[ 31 ] <= data_i;
			end
		endcase
	end

	/*
	 * output
	*/
	genvar i;
	generate
		for( i = 0; i < PACKAGE_NUM; i = i + 1)
		begin:pack_out
			assign bias_o[ (i+1)*DW-1:i*DW ] = bias_[ i ];
		end // end pack_out
	endgenerate

endmodule
