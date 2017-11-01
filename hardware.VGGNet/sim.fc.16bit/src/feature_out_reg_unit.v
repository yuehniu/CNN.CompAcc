/*--------------------------------------------------
 * This module is convolution register array buffer
 * for store atom-convolution output.
 * 
 * parameter:
 * EW:	exponent width for float
 * MW:	mantisa width for float
 * FW:	float width
 * US:	unit store size
 * MS:	feature out reg matrix size
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
 * bias_full_i			:	flag indicate bias reg is full
 * bias_data_i			:	bias input data
 * prev_buf_data_o		:	previous buf data, need read first
 * wr_en_i				:	ddr write enable signal
 * feature_out_data_o	:	ddr write output data
--------------------------------------------------*/
`timescale 1 ns/1 ns
module feature_out_reg_unit
#(
	parameter FW = 32,
	parameter US = 7,
	parameter MS = 32
 )
 (
	// port definition {{{
 	input		clk_i,
	input		rstn_i,
	
	input									accum_en_i,
	input		[ MS*FW-1:0 ]				accum_data_i,
	input		[ 4-1:0 ]					addr_x_i,
	input		[ 4-1:0 ]					addr_y_i,

	input									bias_full_i,
	input		[ MS*FW-1:0 ]				bias_data_i,

	output reg	[ MS*FW-1:0 ]				prev_buf_data_o,

    input                                   wr_done_i,
	input									wr_en_i,
	output		[ MS*(2*US*2*US)*FW-1:0 ]	feature_out_data_o
	// }}}
 );

	localparam	BUF_DATA_WIDTH = MS*FW;
	
	// internel register matrix
	reg		[ BUF_DATA_WIDTH-1:0 ]		feature_data_[ 0:4*US*US-1 ];
    wire    [ MS*FW-1:0 ]               bias_data_rotate;

	reg		[ 4*US*US-1:0]				wr_sel_flag;
    reg                                 bias_full_delay;


	always @( rstn_i or addr_x_i or addr_y_i or feature_data_[ 0 ] or feature_data_[ 4*US*US-1 ] )
	begin
		if( rstn_i == 1'b0 )
		begin
			wr_sel_flag		<= {4*US*US{1'b0}};
			prev_buf_data_o	<= {BUF_DATA_WIDTH{1'b0}};
		end
		else
		begin // located buf data by x and y position{{{ 
			wr_sel_flag	= {4*US*US{1'b0}};
			case( addr_y_i )
				4'd0:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 0 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 0 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 1 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 1 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 2 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 2 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 3 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 3 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 4 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 4 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 5 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 5 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 6 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 6 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 7 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 7 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 8 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 8 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 9 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 9 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 10 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 10 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 11 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 11 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 12 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 12 ];
						end
						default:
						begin
							wr_sel_flag[ 13 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 13 ];
						end
					endcase // }}}
				end
				4'd1:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 14 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 14 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 15 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 15 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 16 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 16 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 17 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 17 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 18 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 18 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 19 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 19 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 20 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 20 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 21 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 21 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 22 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 22 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 23 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 23 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 24 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 24 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 25 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 25 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 26 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 26 ];
						end
						default:
						begin
							wr_sel_flag[ 27 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 27 ];
						end
					endcase // }}}
				end
				4'd2:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 28 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 28 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 29 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 29 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 30 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 30 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 31 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 31 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 32 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 32 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 33 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 33 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 34 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 34 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 35 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 35 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 36 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 36 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 37 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 37 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 38 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 38 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 39 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 39 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 40 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 40 ];
						end
						default:
						begin
							wr_sel_flag[ 41 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 41 ];
						end
					endcase // }}}
				end
				4'd3:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 42 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 42 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 43 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 43 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 44 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 44 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 45 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 45 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 46 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 46 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 47 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 47 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 48 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 48 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 49 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 49 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 50 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 50 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 51 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 51 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 52 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 52 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 53 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 53 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 54 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 54 ];
						end
						default:
						begin
							wr_sel_flag[ 55 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 55 ];
						end
					endcase // }}}
				end
				4'd4:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 56 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 56 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 57 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 57 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 58 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 58 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 59 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 59 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 60 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 60 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 61 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 61 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 62 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 62 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 63 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 63 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 64 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 64 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 65 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 65 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 66 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 66 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 67 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 67 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 68 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 68 ];
						end
						default:
						begin
							wr_sel_flag[ 69 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 69 ];
						end
					endcase // }}}
				end
				4'd5:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 70 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 70 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 71 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 71 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 72 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 72 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 73 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 73 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 74 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 74 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 75 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 75 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 76 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 76 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 77 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 77 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 78 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 78 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 79 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 79 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 80 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 80 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 81 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 81 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 82 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 82 ];
						end
						default:
						begin
							wr_sel_flag[ 83 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 83 ];
						end
					endcase // }}}
				end
				4'd6:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 84 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 84 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 85 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 85 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 86 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 86 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 87 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 87 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 88 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 88 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 89 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 89 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 90 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 90 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 91 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 91 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 92 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 92 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 93 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 93 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 94 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 94 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 95 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 95 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 96 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 96 ];
						end
						default:
						begin
							wr_sel_flag[ 97 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 97 ];
						end
					endcase // }}}
				end
				4'd7:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 98 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 98 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 99 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 99 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 100 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 100 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 101 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 101 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 102 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 102 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 103 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 103 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 104 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 104 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 105 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 105 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 106 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 106 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 107 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 107 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 108 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 108 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 109 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 109 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 110 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 110 ];
						end
						default:
						begin
							wr_sel_flag[ 111 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 111 ];
						end
					endcase // }}}
				end
				4'd8:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 112 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 112 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 113 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 113 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 114 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 114 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 115 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 115 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 116 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 116 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 117 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 117 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 118 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 118 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 119 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 119 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 120 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 120 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 121 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 121 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 122 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 122 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 123 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 123 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 124 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 124 ];
						end
						default:
						begin
							wr_sel_flag[ 125 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 125 ];
						end
					endcase // }}}
				end
				4'd9:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 126 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 126 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 127 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 127 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 128 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 128 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 129 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 129 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 130 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 130 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 131 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 131 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 132 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 132 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 133 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 133 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 134 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 134 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 135 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 135 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 136 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 136 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 137 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 137 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 138 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 138 ];
						end
						default:
						begin
							wr_sel_flag[ 139 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 139 ];
						end
					endcase // }}}
				end
				4'd10:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 140 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 140 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 141 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 141 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 142 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 142 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 143 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 143 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 144 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 144 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 145 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 145 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 146 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 146 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 147 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 147 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 148 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 148 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 149 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 149 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 150 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 150 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 151 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 151 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 152 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 152 ];
						end
						default:
						begin
							wr_sel_flag[ 153 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 153 ];
						end
					endcase // }}}
				end
				4'd11:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 154 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 154 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 155 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 155 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 156 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 156 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 157 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 157 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 158 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 158 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 159 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 159 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 160 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 160 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 161 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 161 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 162 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 162 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 163 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 163 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 164 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 164 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 165 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 165 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 166 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 166 ];
						end
						default:
						begin
							wr_sel_flag[ 167 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 167 ];
						end
					endcase // }}}
				end
				4'd12:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 168 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 168 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 169 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 169 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 170 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 170 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 171 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 171 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 172 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 172 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 173 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 173 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 174 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 174 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 175 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 175 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 176 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 176 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 177 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 177 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 178 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 178 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 179 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 179 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 180 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 180 ];
						end
						default:
						begin
							wr_sel_flag[ 181 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 181 ];
						end
					endcase // }}}
				end
				4'd13:
				begin
					case( addr_x_i ) // {{{
						4'd0:
						begin
							wr_sel_flag[ 182 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 182 ];
						end
						4'd1:
						begin
							wr_sel_flag[ 183 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 183 ];
						end
						4'd2:
						begin
							wr_sel_flag[ 184 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 184 ];
						end
						4'd3:
						begin
							wr_sel_flag[ 185 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 185 ];
						end
						4'd4:
						begin
							wr_sel_flag[ 186 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 186 ];
						end
						4'd5:
						begin
							wr_sel_flag[ 187 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 187 ];
						end
						4'd6:
						begin
							wr_sel_flag[ 188 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 188 ];
						end
						4'd7:
						begin
							wr_sel_flag[ 189 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 189 ];
						end
						4'd8:
						begin
							wr_sel_flag[ 190 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 190 ];
						end
						4'd9:
						begin
							wr_sel_flag[ 191 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 191 ];
						end
						4'd10:
						begin
							wr_sel_flag[ 192 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 192 ];
						end
						4'd11:
						begin
							wr_sel_flag[ 193 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 193 ];
						end
						4'd12:
						begin
							wr_sel_flag[ 194 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 194 ];
						end
						default:
						begin
							wr_sel_flag[ 195 ]	<= 1'b1;
							prev_buf_data_o		<= feature_data_[ 195 ];
						end
					endcase // }}}
				end
				default:
				begin
					wr_sel_flag		<= { 4*US*US{1'b0} };
					prev_buf_data_o	<= {BUF_DATA_WIDTH{1'b0}};
				end
			endcase
		end //}}}
	end

	// store accumulated feature data {{{
    always @( posedge clk_i )
    begin
        if( rstn_i == 1'b0 )
        begin
            bias_full_delay <= 1'b0;
        end
        else
        begin
            bias_full_delay <= bias_full_i;
        end
    end
	genvar i;
    generate
        for( i = 0; i < MS; i = i + 1 )
        begin
            assign bias_data_rotate[ (i+1)*FW-1:i*FW ] = bias_data_i[ (MS-i)*FW-1:(MS-i-1)*FW ];
        end
    endgenerate
	generate
		for( i = 0; i < 4*US*US; i = i + 1 )
		begin
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					feature_data_[ i ]	<= {BUF_DATA_WIDTH{1'b0}};	
				end
				else if( bias_full_delay == 1'b1 )
				begin
					feature_data_[ i ]	<= bias_data_rotate;
				end
                else if( wr_done_i == 1'b1 )
                begin
					feature_data_[ i ]	<= bias_data_rotate;
                end
				else if( accum_en_i == 1'b1 )
				begin
					if( wr_sel_flag[ i ] == 1'b1 )
						feature_data_[ i ]	<= accum_data_i;
				end
			end
		end
	endgenerate
	// }}}

	// map reg matrix {{{
	generate
		for( i = 0; i < 4*US*US; i = i + 1 )
		begin
			assign feature_out_data_o[ (0*4*US*US+i+1)*FW-1:(0*4*US*US+i)*FW ] 	= feature_data_[ i ][ 1*FW-1:0*FW ];
			assign feature_out_data_o[ (1*4*US*US+i+1)*FW-1:(1*4*US*US+i)*FW ] 	= feature_data_[ i ][ 2*FW-1:1*FW ];
			assign feature_out_data_o[ (2*4*US*US+i+1)*FW-1:(2*4*US*US+i)*FW ] 	= feature_data_[ i ][ 3*FW-1:2*FW ];
			assign feature_out_data_o[ (3*4*US*US+i+1)*FW-1:(3*4*US*US+i)*FW ] 	= feature_data_[ i ][ 4*FW-1:3*FW ];
			assign feature_out_data_o[ (4*4*US*US+i+1)*FW-1:(4*4*US*US+i)*FW ] 	= feature_data_[ i ][ 5*FW-1:4*FW ];
			assign feature_out_data_o[ (5*4*US*US+i+1)*FW-1:(5*4*US*US+i)*FW ] 	= feature_data_[ i ][ 6*FW-1:5*FW ];
			assign feature_out_data_o[ (6*4*US*US+i+1)*FW-1:(6*4*US*US+i)*FW ] 	= feature_data_[ i ][ 7*FW-1:6*FW ];
			assign feature_out_data_o[ (7*4*US*US+i+1)*FW-1:(7*4*US*US+i)*FW ] 	= feature_data_[ i ][ 8*FW-1:7*FW ];
			assign feature_out_data_o[ (8*4*US*US+i+1)*FW-1:(8*4*US*US+i)*FW ] 	= feature_data_[ i ][ 9*FW-1:8*FW ];
			assign feature_out_data_o[ (9*4*US*US+i+1)*FW-1:(9*4*US*US+i)*FW ] 	= feature_data_[ i ][ 10*FW-1:9*FW ];
			assign feature_out_data_o[ (10*4*US*US+i+1)*FW-1:(10*4*US*US+i)*FW ] 	= feature_data_[ i ][ 11*FW-1:10*FW ];
			assign feature_out_data_o[ (11*4*US*US+i+1)*FW-1:(11*4*US*US+i)*FW ] 	= feature_data_[ i ][ 12*FW-1:11*FW ];
			assign feature_out_data_o[ (12*4*US*US+i+1)*FW-1:(12*4*US*US+i)*FW ] 	= feature_data_[ i ][ 13*FW-1:12*FW ];
			assign feature_out_data_o[ (13*4*US*US+i+1)*FW-1:(13*4*US*US+i)*FW ] 	= feature_data_[ i ][ 14*FW-1:13*FW ];
			assign feature_out_data_o[ (14*4*US*US+i+1)*FW-1:(14*4*US*US+i)*FW ] 	= feature_data_[ i ][ 15*FW-1:14*FW ];
			assign feature_out_data_o[ (15*4*US*US+i+1)*FW-1:(15*4*US*US+i)*FW ] 	= feature_data_[ i ][ 16*FW-1:15*FW ];
			assign feature_out_data_o[ (16*4*US*US+i+1)*FW-1:(16*4*US*US+i)*FW ] 	= feature_data_[ i ][ 17*FW-1:16*FW ];
			assign feature_out_data_o[ (17*4*US*US+i+1)*FW-1:(17*4*US*US+i)*FW ] 	= feature_data_[ i ][ 18*FW-1:17*FW ];
			assign feature_out_data_o[ (18*4*US*US+i+1)*FW-1:(18*4*US*US+i)*FW ] 	= feature_data_[ i ][ 19*FW-1:18*FW ];
			assign feature_out_data_o[ (19*4*US*US+i+1)*FW-1:(19*4*US*US+i)*FW ] 	= feature_data_[ i ][ 20*FW-1:19*FW ];
			assign feature_out_data_o[ (20*4*US*US+i+1)*FW-1:(20*4*US*US+i)*FW ] 	= feature_data_[ i ][ 21*FW-1:20*FW ];
			assign feature_out_data_o[ (21*4*US*US+i+1)*FW-1:(21*4*US*US+i)*FW ] 	= feature_data_[ i ][ 22*FW-1:21*FW ];
			assign feature_out_data_o[ (22*4*US*US+i+1)*FW-1:(22*4*US*US+i)*FW ] 	= feature_data_[ i ][ 23*FW-1:22*FW ];
			assign feature_out_data_o[ (23*4*US*US+i+1)*FW-1:(23*4*US*US+i)*FW ] 	= feature_data_[ i ][ 24*FW-1:23*FW ];
			assign feature_out_data_o[ (24*4*US*US+i+1)*FW-1:(24*4*US*US+i)*FW ] 	= feature_data_[ i ][ 25*FW-1:24*FW ];
			assign feature_out_data_o[ (25*4*US*US+i+1)*FW-1:(25*4*US*US+i)*FW ] 	= feature_data_[ i ][ 26*FW-1:25*FW ];
			assign feature_out_data_o[ (26*4*US*US+i+1)*FW-1:(26*4*US*US+i)*FW ] 	= feature_data_[ i ][ 27*FW-1:26*FW ];
			assign feature_out_data_o[ (27*4*US*US+i+1)*FW-1:(27*4*US*US+i)*FW ] 	= feature_data_[ i ][ 28*FW-1:27*FW ];
			assign feature_out_data_o[ (28*4*US*US+i+1)*FW-1:(28*4*US*US+i)*FW ] 	= feature_data_[ i ][ 29*FW-1:28*FW ];
			assign feature_out_data_o[ (29*4*US*US+i+1)*FW-1:(29*4*US*US+i)*FW ] 	= feature_data_[ i ][ 30*FW-1:29*FW ];
			assign feature_out_data_o[ (30*4*US*US+i+1)*FW-1:(30*4*US*US+i)*FW ] 	= feature_data_[ i ][ 31*FW-1:30*FW ];
			assign feature_out_data_o[ (31*4*US*US+i+1)*FW-1:(31*4*US*US+i)*FW ] 	= feature_data_[ i ][ 32*FW-1:31*FW ];
		end
	endgenerate
	// }}}

endmodule
