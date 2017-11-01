/*--------------------------------------------------
 * This module is convolution register array buffer
 * for store atom-convolution input.
 *
 * parameter:
 * EW:	exponent width for float
 * MW:	mantisa width for float
 * FW:	float width
 * US:	unit store size
 * DW:	data width from read_op module
 *
 * ports:
 * clk_i			:	input clock
 * en_i				:	module enable
 * rstn_i			:	negative active global reset signal
 * start_trigger_i	:	flag indicates start transfer data
 * first_shot_i		:	flag indicates first fill data to reg matrix
 * sel_ddr_i		:	flag indicates data read from DDR3
 * sel_ram_i		:	flag indicates data read from BRAM
 * sel_top_i		:	flag indicates data read from top BRAM
 * sel_w_i			:	write select signal between conv_reg0/1
 * data_top_i		:	input data from top ram
 * data_ram_i		: 	input data from ram
 * ddr_last_i		:	flag indicates last data package from ddr
 * data_last_i		:	flag indicates last data to reg matrix
 * col_last_i		:	flag indicates last col in feature map
 * row_last_i		:	flag indicates last row in deature map
 * data_valid_num_i	:flag indeicates the number of valid data
 * data_ddr_i		:	input data from ddr
 * sel_r_i			:	read select signal between conv_reg0/1
 * col_last_r_i     :   last col flag in conv read side
 * addr_r_i			:	read address 
 * conv_data_o		:	convolution data output to conv_op	
 * reg_matrix_full_o:	flag indicates reg matrix is full
 *
--------------------------------------------------*/
`timescale 1 ns/ 1 ns
module feature_in_reg_matrix
#(
	parameter EW = 8,
	parameter MW = 23,
	parameter FW = 32,
	parameter US = 7,
	parameter DW = 512
 )
 (
 	//{{{ module port definition
 	input							clk_i,
	input							en_i,
	input							rstn_i,
	
	input							start_trigger_i,
	input							first_shot_i,
	input							sel_w_i,

	input							sel_top_i,
	input	[ (2*US+2)*FW-1:0 ] 	data_top_i,

	input							sel_ram_i,
	input	[ (2*US+1)*FW-1:0 ] 	data_ram_i,

	input							sel_ddr_i,
	input							ddr_last_i,
	input							col_last_i,
	input							row_last_i,
	input	[ 32-1:0]				data_valid_num_i,
	input	[ DW-1:0 ] 				data_ddr_i,

	input							data_last_i,
	
	input							sel_r_i,
    input                           col_last_r_i,
	//input	[ 8-1:0 ]				addr_r_i,
	output	reg [ 2-1:0 ]			reg_matrix_full_o,
	output	[ (2*US+2)*(3*US+1)*FW-1:0 ] update_data_0_o, 
	output	[ (2*US+2)*(3*US+1)*FW-1:0 ] update_data_1_o,
	output	[ (2*US+2)*(2*US+2)*FW-1:0 ] test_data_o 
	//}}}
 );

	//{{{ localparam definition
	localparam	TOP_PACKAGE_LEN = 2*US+2;  // data number in one input data data_top_i
	localparam 	RAM_PACKAGE_LEN = 2*US+1;  // data number in one input data data_ram_i
	localparam	DDR_PACKAGE_LEN = DW / FW; // data number in one input data data_ddr_i
	localparam	MATRIX_COL		= 3*US+1;
	localparam	MATRIX_ROW		= 2*US+2;
	localparam	MATRIX_LEN		= (2*US+2)*(3*US+1); // total convolution register in one convolution matrix(16*22)
	localparam	RAM_DDR_LEN		= (2*US+1)*(3*US+1);
	//localparam	OFFSET1			= (2*US*US) % DDR_PACKAGE_LEN;
	localparam	OFFSET1			= (US*US) % DDR_PACKAGE_LEN;
	localparam	OFFSET2			= (4*US*US) % DDR_PACKAGE_LEN;
	localparam	OFFSET3			= (6*US*US) % DDR_PACKAGE_LEN;
	localparam	OFFSET4			= US;
	localparam	OFFSET5			= DDR_PACKAGE_LEN;
	localparam	SHFT_STRIDE_C0	= US;
	localparam	SHFT_STRIDE_C1	= 3*US;
	localparam	SHFT_STRIDE_C2	= 2*US;
	localparam 	SHFT_STRIDE_C3	= 2*US*US+2*US;
	//}}}

	/*
	 * internel register matrix
	*/
	reg		[ FW-1:0 ] top_sec0_[ 0:MATRIX_COL-1 ];
	reg		[ FW-1:0 ] top_sec1_[ 0:MATRIX_COL-1 ];
	reg		[ FW-1:0 ] ram_ddr_sec0_[ 0:RAM_DDR_LEN-1 ]; 
	reg		[ FW-1:0 ] ram_ddr_sec1_[ 0:RAM_DDR_LEN-1 ]; 
	// virtual memory
	wire	[ FW-1:0 ] conv_reg0_[ 0:MATRIX_LEN-1 ];
	wire	[ FW-1:0 ] conv_reg1_[ 0:MATRIX_LEN-1 ];
	genvar i;
	genvar j;

	reg first_shot_reg;
	always @( negedge rstn_i or posedge clk_i )
	begin
		if( rstn_i == 1'b0 )
		begin
			first_shot_reg	<= 1'b0;
		end
		else
		begin
			first_shot_reg	<= first_shot_i;
		end
	end

	/*
	 * generate complementary data shift stride
	*/
	reg	shft_comp;
	reg	shft_sel;
	reg	[ 2-1:0 ] shft_stride; //00:SHFT_STRIDE_C1, 01:SHFT_STRIDE_C2, 10:SHFT_STRIDE_C3 
	always @( negedge rstn_i or posedge clk_i )
	begin:gen_comp_shft_stride //{{{
		if( rstn_i == 1'b0 )
		begin
			shft_comp	 <= 1'b0;
			shft_stride	 <= 2'd0;
		end
		else 
		begin
			if( col_last_i == 1'b1 && row_last_i == 1'b0 && data_valid_num_i == 32'd7 )
			begin
				shft_comp	<= 1'b1;
				shft_sel	<= sel_w_i;
				shft_stride <= 2'd0;
			end
			if( first_shot_i == 1'b1 && col_last_i == 1'b0 && row_last_i == 1'b1 && ddr_last_i == 1'b1 )
			begin
				shft_comp	<= 1'b1;
				shft_sel	<= sel_w_i;
				shft_stride	<= 2'd1;
			end
			if( first_shot_i == 1'b0 && col_last_i == 1'b0 && row_last_i == 1'b1 && ddr_last_i == 1'b1 )
			begin
				shft_comp	<= 1'b1;
				shft_sel	<= sel_w_i;
				shft_stride	<= 2'd2;
			end
			if( col_last_i == 1'b1 && row_last_i == 1'b1 && ddr_last_i == 1'b1 )
			begin
				shft_comp	<= 1'b1;
				shft_sel	<= sel_w_i;
				shft_stride	<= 2'd3;
			end
			if( shft_comp == 1'b1 )
			begin
				shft_comp	<= 1'b0;
				shft_sel	<= sel_w_i;
				shft_stride	<= 2'd0;
			end
		end
	end //}}}

	/*
	 * receive top_sec0/1
	*/
	reg		first_shot_0,first_shot_1;
	always @( start_trigger_i )
	begin
		if ( start_trigger_i == 1'b1 )
		begin
			if( sel_w_i == 1'b0 )
				first_shot_0	<= first_shot_i;
			else
				first_shot_1	<= first_shot_i;
		end
	end
	generate
		for(j = 0; j < TOP_PACKAGE_LEN; j = j + 1)
		begin:receive_top_data //{{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if ( rstn_i == 1'b0 )
				begin
					top_sec0_[ j ] <= {FW{1'b0}};		
					top_sec1_[ j ] <= {FW{1'b0}};		
				end
				else if( en_i == 1'b1 && sel_top_i == 1'b1 )
				begin
					if( sel_w_i == 1'b0 ) // shift data to top_sec0( little endian, high significant to lower reg address )	
						top_sec0_[ j ] <= data_top_i[ (j+1)*FW-1:j*FW ]; 
					else if( sel_w_i == 1'b1 )
						top_sec1_[ j ] <= data_top_i[ (j+1)*FW-1:j*FW ];
				end
			end
		end // receive_top_data }}}
	endgenerate

	/*
	 * receive and shift ram_ddr_sec0/1
	*/
	generate
		for( i = 0; i < OFFSET1; i = i + 1 ) // 0--1
		begin:receive_ddr_data //{{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 && sel_ddr_i == 1'b1 )
				begin
					case( data_valid_num_i )
						OFFSET1:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET1+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET1+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET2:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET2+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET2+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET3:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET3+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET3+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET4:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET5:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
					endcase
				end
				else if( shft_comp == 1'b1 ) // if shft_comp, reset to 0
				begin
                    if( shft_sel == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
                    else if( shft_sel == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
				end
			end
		end // receive_ddr_data }}}
		for( i = OFFSET1; i < OFFSET2; i = i + 1 ) // 2--3
		begin:rec_or_shft_secdata1 //{{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 ) 
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b0 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 && sel_ddr_i == 1'b1 )
				begin
					case( data_valid_num_i )
						OFFSET1:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i + OFFSET1 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i + OFFSET1];
						end
						OFFSET2:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET2+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET2+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET3:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET3+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET3+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET4:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET5:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
					endcase
				end
				else if( shft_comp == 1'b1 ) // if shft_comp, reset to 0
				begin
                    if( shft_sel == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
                    else if( shft_sel == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
				end
			end // always
		end // rec_or_shft_secdata1 }}}
		for( i = OFFSET2; i < OFFSET3; i = i + 1 ) // 4--5
		begin: rec_or_shft_secdata2 //{{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
				else if( en_i == 1'b1 && sel_ddr_i == 1'b1 )
				begin
					case( data_valid_num_i )
						OFFSET1:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET1 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET1 ];
						end
						OFFSET2:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET2 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET2 ];
						end
						OFFSET3:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET3+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET3+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET4:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET5:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
					endcase
				end
				else if( shft_comp == 1'b1 ) // if shft_comp, reset to 0
				begin
                    if( shft_sel == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
                    else if( shft_sel == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
				end
			end
		end // rec_or_shft_secdata2 }}}
		for( i = OFFSET3; i < OFFSET4; i = i + 1 ) // 6
		begin:rec_or_shft_secdata3 // {{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 && sel_ddr_i == 1'b1 )
				begin
					case( data_valid_num_i )
						OFFSET1:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET1 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET1 ];
						end
						OFFSET2:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET2 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET2 ];
						end
						OFFSET3:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET3 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET3 ];
						end
						OFFSET4:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET4+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
						OFFSET5:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
					endcase
				end
				else if( shft_comp == 1'b1 ) // if shft_comp, reset to 0
				begin
                    if( shft_sel == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
                    else if( shft_sel == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
				end
			end // always 
		end // rec_or_shft_secdata3 }}}
		for( i = OFFSET4; i < OFFSET5; i = i + 1 ) // 7--15
		begin:rec_or_shft_secdata4 /// {{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 && sel_ddr_i == 1'b1 )
				begin
					case( data_valid_num_i)
						OFFSET1:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET1 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET1 ];
						end
						OFFSET2:
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET2 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET2 ];
						OFFSET3:
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET3 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET3 ];
						OFFSET4:
							if( col_last_i == 1'b0 ) // last column do not shift data
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET4 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET4 ];
							end
							else if( col_last_i == 1'b1 ) 
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
							end
						OFFSET5:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-OFFSET5+i ] <= data_ddr_i[ DW-1-i*FW:DW-(i+1)*FW ];
						end
					endcase
				end
				else if( shft_comp == 1'b1 )
				begin
					case( shft_stride )
					2'd0:
					begin
						if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C0 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C0 ];
					end
					2'd1:
					begin
                        if( shft_sel == 1'b0 )
						    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= { FW{1'b0} };
                        else if( shft_sel == 1'b1 )
						    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= { FW{1'b0} };
					end
					2'd2:
					begin
						if( shft_sel == 1'b0 )
							if( i > SHFT_STRIDE_C2-1 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
							else
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= { FW{1'b0} };
						else if( shft_sel == 1'b1 )
							if( i > SHFT_STRIDE_C2-1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
							else
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= { FW{1'b0} };
						/*if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
						*/
					end
					2'd3:
					begin
                        if( shft_sel == 1'b0 )
						    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= { FW{1'b0} };
                        else if( shft_sel == 1'b1 )
						    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= { FW{1'b0} };
						/*if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C3 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C3 ];
						*/
					end
					endcase
				end
			end // always
		end // rec_or_shft_secdata4 }}}
		for( i = OFFSET5; i < (2*US+4*US*US); i = i + 1 )
		begin:ddr_shft //{{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 && sel_ddr_i == 1'b1 )
				begin:normal_ddr_shft //{{{
					case( data_valid_num_i )
						OFFSET1:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET1 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET1 ];
						end
						OFFSET2:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET2 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET2 ];
						end
						OFFSET3:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET3 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET3 ];
						end
						OFFSET4:
						begin
							if( col_last_i == 1'b0 )
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET4 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET4 ];
							end
							else if( col_last_i == 1'b1 ) // to last column in some feature map, need special handle
							begin
								if( sel_w_i == 1'b0 )
									if( i > OFFSET4+2*US*US-1 )
										ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET4+2*US*US ];
									else
										ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
								else if( sel_w_i == 1'b1 )
									if( i > OFFSET4+2*US*US-1 )
										ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET4+2*US*US ];
									else
										ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
							end
						end
						OFFSET5:
						begin
							if( sel_w_i == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET5 ];
							else if( sel_w_i == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET5 ];
						end
					endcase
				end // normal_ddr_shft }}}
				else if( shft_comp == 1'b1 ) 
				begin:comp_ddr_shft //{{{
					case( shft_stride )
						2'd0:
						begin
							if( shft_sel == 1'b0 )
								ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C0 ];
							else if( shft_sel == 1'b1 )
								ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C0 ];
						end
						2'd1:
						begin
							if( shft_sel == 1'b0 )
                                if( i > SHFT_STRIDE_C1-1 )
								    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C1 ];
                                else
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}}; 
							else if( shft_sel == 1'b1 )
                                if( i > SHFT_STRIDE_C1-1 )
								    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C1 ];
                                else
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}}; 
						end
						2'd2:
						begin
							if( shft_sel == 1'b0 )
								if( i > SHFT_STRIDE_C2-1 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
								else
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}}; 
							else if( shft_sel == 1'b1 )
								if( i > SHFT_STRIDE_C2-1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
								else
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}}; 
						end
						2'd3:
						begin
							if( shft_sel == 1'b0 )
								if( i > SHFT_STRIDE_C3-1 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C3 ];
								else
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
							else if( shft_sel == 1'b1 )
								if( i > SHFT_STRIDE_C3-1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C3 ];
								else
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
						end
						default:
						begin
							// no operation
						end
					endcase
				end // comp_ddr_shft }}}
			end
		end // ddr_shft }}}
		for( i = 2*US+4*US*US; i < 2*US+4*US*US+RAM_PACKAGE_LEN; i = i + 1 )
		begin:ddr_shft_or_ram_rec // {{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 )
				begin
					if( sel_ddr_i == 1'b1 && first_shot_i == 1'b1 )
					begin: ddr_shift //{{{
						case( data_valid_num_i )
							OFFSET1:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET1 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET1 ];
							end
							OFFSET2:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET2 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET2 ];
							end
							OFFSET3:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET3 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET3 ];
							end
							OFFSET4:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET4 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET4 ];
							end
							OFFSET5:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET5 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET5 ];
							end
						endcase
					end // ddr_shift }}}
					else if( sel_ram_i == 1'b1 && first_shot_i == 1'b0 ) 
					begin
						if( sel_w_i == 1'b0 )
						begin
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= data_ram_i[ (i-4*US*US-2*US+1)*FW-1:(i-4*US*US-2*US)*FW ];
						end
						else if( sel_w_i == 1'b1 )
						begin
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= data_ram_i[ (i-4*US*US-2*US+1)*FW-1:(i-4*US*US-2*US)*FW ];
						end
					end
				end 
				else if( shft_comp == 1'b1 && first_shot_reg== 1'b1 )
				begin
					if( shft_stride == 2'd1 )
					begin
						if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C1 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C1 ];
					end
					else if( shft_stride == 2'd2 )
					begin
						if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
					end
				end
			end // always
		end // ddr_shft_or_ram_rec }}}
		for( i = 2*US+4*US*US+RAM_PACKAGE_LEN; i < RAM_DDR_LEN; i = i + 1 )
		begin:ddr_shft_or_ram_shft //{{{
			always @( negedge rstn_i or posedge clk_i )
			begin
				if( rstn_i == 1'b0 )
				begin
					ram_ddr_sec0_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
					ram_ddr_sec1_[ RAM_DDR_LEN-1-i ]	<= {FW{1'b0}};
				end
                else if( start_trigger_i == 1'b1 && first_shot_i == 1'b1 )
                begin
                    if( sel_w_i == 1'b0 )
					    ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                    else if( sel_w_i == 1'b1 )
					    ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= {FW{1'b0}};
                end
				else if( en_i == 1'b1 )
				begin
					if( sel_ddr_i == 1'b1 && first_shot_i == 1'b1 )
					begin: ddr_shift //{{{
						case( data_valid_num_i )
							OFFSET1:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET1 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET1 ];
							end
							OFFSET2:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET2 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET2 ];
							end
							OFFSET3:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET3 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET3 ];
							end
							OFFSET4:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET4 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET4 ];
							end
							OFFSET5:
							begin
								if( sel_w_i == 1'b0 )
									ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+OFFSET5 ];
								else if( sel_w_i == 1'b1 )
									ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+OFFSET5 ];
							end
						endcase
					end // ddr_shift }}}
					else if( sel_ram_i == 1'b1 && first_shot_i == 1'b0 ) 
					begin:ram_shft //{{{
						if( sel_w_i == 1'b0 )
						begin
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i + RAM_PACKAGE_LEN ];
						end
						else if( sel_w_i == 1'b1 )
						begin
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i + RAM_PACKAGE_LEN ];
						end
					end // ram_shft }}}
				end //
				else if( shft_comp == 1'b1 && first_shot_reg == 1'b1 )
				begin
					if( shft_stride == 2'd1 )
					begin
						if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C1 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C1 ];
					end
					else if( shft_stride == 2'd2 )
					begin
						if( shft_sel == 1'b0 )
							ram_ddr_sec0_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec0_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
						else if( shft_sel == 1'b1 )
							ram_ddr_sec1_[ RAM_DDR_LEN-1-i ] <= ram_ddr_sec1_[ RAM_DDR_LEN-1-i+SHFT_STRIDE_C2 ];
					end
				end
			end // always
		end // ddr_shft_or_ram_shft }}}
	endgenerate

	/*
	 * connect virtual memory to real internel register matrix 
	*/
	// connect top_sec0/1 with virtual memory
	generate
		for( j = 0; j < MATRIX_COL; j = j + 1 )
		begin:connect_top_sec
			assign conv_reg0_[ j ] = top_sec0_[ j ];
			assign conv_reg1_[ j ] = top_sec1_[ j ];
		end // connect_top_sec
	endgenerate

	// connect ram_ddr_sec0/1 with virtual memory
	generate
		for( i = 1; i < US+1; i = i + 1 ) // row 2 to row US+1
		begin:connect_ram_ddr_sec //{{{
			for( j = 0; j < ( US+1 ); j = j + 1 )
			begin
				if( j == 0 )
				begin 
					assign conv_reg0_[ i*MATRIX_COL+j ] = ram_ddr_sec0_[ i-1 ];
					assign conv_reg1_[ i*MATRIX_COL+j ] = ram_ddr_sec1_[ i-1 ];
				end 
				else if( j != 0 )
				begin
					assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 ? ram_ddr_sec0_[ MATRIX_ROW-2 + (i-1)*US+j ]
																			   : ram_ddr_sec0_[ (i-1)+j*(2*US+1) ];
					assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 ? ram_ddr_sec1_[ MATRIX_ROW-2 + (i-1)*US+j ]
																			   : ram_ddr_sec1_[ (i-1)+j*(2*US+1) ];
                    /*
					begin
						assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 ? ram_ddr_sec0_[ (MATRIX_ROW-2) + (6*US*US) + j ]
																				   : ram_ddr_sec0_[ (i-1)+j*(2*US+1) ];
						assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 ? ram_ddr_sec1_[ (MATRIX_ROW-2) + (6*US*US) + j ]
																				   : ram_ddr_sec1_[ (i-1)+j*(2*US+1) ];
					end
                    */
				end
			end
		end // connect_ram_ddr_sec }}}
        for( i = US+1; i < 2*US+1; i = i + 1) // row US+2 to row 2*US+1
        begin:row_US_8 // {{{
            for( j = 0; j < (US+1); j = j + 1 )
            begin
                if( j == 0 )
				begin 
					assign conv_reg0_[ i*MATRIX_COL+j ] = ram_ddr_sec0_[ i-1 ];
					assign conv_reg1_[ i*MATRIX_COL+j ] = ram_ddr_sec1_[ i-1 ];
				end 
                else
                begin
					assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 ? ram_ddr_sec0_[ MATRIX_ROW-2 + (3*US*US) + (i-US-1)*US+j ]
																			   : ram_ddr_sec0_[ (i-1)+j*(2*US+1) ];
					assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 ? ram_ddr_sec1_[ MATRIX_ROW-2 + (3*US*US) + (i-US-1)*US+j ]
																			   : ram_ddr_sec1_[ (i-1)+j*(2*US+1) ];
                end
            end
        end // }}}
        for( i = 2*US+1; i < MATRIX_ROW; i = i + 1)
        begin:row_US_16 // {{{
            for( j = 0; j < (US+1); j = j + 1)
            begin
                if( j == 0 )
				begin 
					assign conv_reg0_[ i*MATRIX_COL+j ] = ram_ddr_sec0_[ i-1 ];
					assign conv_reg1_[ i*MATRIX_COL+j ] = ram_ddr_sec1_[ i-1 ];
				end 
                else
                begin
			    	assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 ? ram_ddr_sec0_[ (MATRIX_ROW-2) + (6*US*US) + j ]
																		       : ram_ddr_sec0_[ (i-1)+j*(2*US+1) ];
			    	assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 ? ram_ddr_sec1_[ (MATRIX_ROW-2) + (6*US*US) + j ]
																			   : ram_ddr_sec1_[ (i-1)+j*(2*US+1) ];
                end
            end
        end // }}}
	endgenerate

	// connect ddr_sec0/1 with virtual memory
	generate
		for( i = 1; i < US+1; i = i + 1 ) // row 1 to row US+1
		begin:connect_ddr_sec_1 // {{{
			for( j = US+1; j < 2*US+1; j = j + 1)
			begin
				assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 
													  ? ram_ddr_sec0_[ (MATRIX_ROW-1)+(US*US)+(i-1)*US+(j-US-1) ]
													  : ram_ddr_sec0_[ (MATRIX_ROW-1)+(2*US*US+US)+(i-1)*US+(j-US-1) ];
				assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 
													  ? ram_ddr_sec1_[ (MATRIX_ROW-1)+(US*US)+(i-1)*US+(j-US-1) ]
													  : ram_ddr_sec1_[ (MATRIX_ROW-1)+(2*US*US+US)+(i-1)*US+(j-US-1) ];
			end
			for( j = 2*US+1; j < MATRIX_COL; j = j + 1 )
			begin
				assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 
													  ? ram_ddr_sec0_[ (MATRIX_ROW-1)+(2*US*US)+(i-1)*US+(j-2*US-1) ]
													  : ( (col_last_r_i == 1'b1 && sel_r_i == 1'b0) 
													      ? ram_ddr_sec0_[ (MATRIX_ROW-1)+(4*US*US+US)+(i-1)*US+(j-2*US-1)]
													      : ram_ddr_sec0_[ (MATRIX_ROW-1)+(3*US*US+US)+(i-1)*US+(j-2*US-1)]
                                                        );
				assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 
													  ? ram_ddr_sec1_[ (MATRIX_ROW-1)+(2*US*US)+(i-1)*US+(j-2*US-1) ]
													  : ( (col_last_r_i == 1'b1 && sel_r_i == 1'b1) 
													      ? ram_ddr_sec1_[ (MATRIX_ROW-1)+(4*US*US+US)+(i-1)*US+(j-2*US-1)]
													      : ram_ddr_sec1_[ (MATRIX_ROW-1)+(3*US*US+US)+(i-1)*US+(j-2*US-1)]
                                                        );
			end
		end // connect_ddr_sec }}}
        for( i = US+1; i < 2*US+1; i = i + 1 )
<<<<<<< HEAD
        begin // {{{
=======
        begin:connect_ddr_sec_2// {{{
>>>>>>> dev
            for( j = US+1; j < 2*US+1; j = j + 1 )
            begin
				assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 
													  ? ram_ddr_sec0_[ (MATRIX_ROW-1) + (4*US*US) + (i-US-1)*US + (j-US-1) ]
													  : ( (col_last_r_i == 1'b1 && sel_r_i == 1'b0) 
													      ? ram_ddr_sec0_[ (MATRIX_ROW-1) + (3*US*US+US) + (i-US-1)*US + (j-US-1) ]
                                                          : ram_ddr_sec0_[ (MATRIX_ROW-1) + (4*US*US+US) + (i-US-1)*US + (j-US-1) ]
                                                        );
				assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 
													  ? ram_ddr_sec1_[ (MATRIX_ROW-1) + (4*US*US) + (i-US-1)*US + (j-US-1) ]
													  : ( (col_last_r_i == 1'b1  && sel_r_i == 1'b1)
													      ? ram_ddr_sec1_[ (MATRIX_ROW-1) + (3*US*US+US) + (i-US-1)*US + (j-US-1) ]
                                                          : ram_ddr_sec1_[ (MATRIX_ROW-1) + (4*US*US+US) + (i-US-1)*US + (j-US-1) ]
                                                        );
            end
            for( j = 2*US+1; j < MATRIX_COL; j = j + 1 )
            begin
				assign conv_reg0_[ i*MATRIX_COL+j ] = first_shot_0 == 1'b1 
													  ? ram_ddr_sec0_[ (MATRIX_ROW-1) + (5*US*US) + (i-US-1)*US + (j-2*US-1) ]
													  : ram_ddr_sec0_[ (MATRIX_ROW-1) + (5*US*US+US) + (i-US-1)*US + (j-2*US-1)];
				assign conv_reg1_[ i*MATRIX_COL+j ] = first_shot_1 == 1'b1 
													  ? ram_ddr_sec1_[ (MATRIX_ROW-1) + (5*US*US) + (i-US-1)*US + (j-2*US-1) ]
													  : ram_ddr_sec1_[ (MATRIX_ROW-1) + (5*US*US+US) + (i-US-1)*US + (j-2*US-1)];
            end
        end // }}}
        for( i = 2*US+1; i < MATRIX_ROW; i = i + 1 )
        begin:connect_ddr_sec_3 // {{{
			for( j = US+1; j < MATRIX_COL; j = j + 1 )
			begin
				assign conv_reg0_[ i*MATRIX_COL+j ] = ram_ddr_sec0_[ (MATRIX_ROW-1)+(6*US*US+US) + (j-US-1) ];
				assign conv_reg1_[ i*MATRIX_COL+j ] = ram_ddr_sec1_[ (MATRIX_ROW-1)+(6*US*US+US) + (j-US-1) ];
			end
        end // }}}
	endgenerate

	// generate test_data_o
	generate
		for( i = 0; i < (2*US+2)*(3*US+1); i = i + 1 )
		begin
			//assign test_data_o[ (i+1)*FW-1:i*FW ] = sel_r_i == 1'b0 ? conv_reg0_[ i ] : conv_reg1_[ i ];
			assign update_data_0_o[ (i+1)*FW-1:i*FW ] = conv_reg0_[ i ];
			assign update_data_1_o[ (i+1)*FW-1:i*FW ] = conv_reg1_[ i ];
		end
	endgenerate
    generate
        for( i = 0; i < (2*US+2); i = i + 1 )
        begin
            for( j = 0; j < (2*US+2); j = j + 1 )
            begin
                assign test_data_o[ (i*(2*US+2)+j+1)*FW-1:(i*(2*US+2)+j)*FW] = sel_r_i == 1'b0 ?
                       conv_reg0_[ MATRIX_LEN - (US-1)-1 -(i*(3*US+1)+j) ] :
                       conv_reg1_[ MATRIX_LEN - (US-1)-1 -(i*(3*US+1)+j) ];
            end
        end
    endgenerate

	/*
	 * generate output control signal 
	 * */
	always @( negedge rstn_i or posedge clk_i )
	begin
		if( rstn_i == 1'b0 )
			reg_matrix_full_o	<= 2'b0;
		else if( data_last_i == 1'b1 )
		begin
			if( sel_w_i == 1'b0 )
				reg_matrix_full_o 	<= 2'b01;
			else if( sel_w_i == 1'b1 )
				reg_matrix_full_o	<= 2'b10;
		end
		else
			reg_matrix_full_o		<= 2'b00;
	end

endmodule
