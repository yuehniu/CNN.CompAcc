/*
 * This module is a incremental control module for CNN.
 * read,update,cnn_mem,conv,write operation are all
 * depend on this control module to control.
 * It will be amend if need.
 *
 * parameter:
 * US:	unit block size
 *
 * ports:
 * clk_i:		global user clock
 * rstn_i:		global user reset signal
 *
 * tb_load_done_i:						flag indicate write data to ddr done in simulation
 * rd_data_load_ddr_done_rising_edge_i:	rising edge for tb_load_done_i 
 * feature_proc_index_o:				feature index being current processing
 * weight_proc_index_o:					weight index being current processing
 * conv_finish_i:						flag indicate 16x16 conv operation finished
 * conv_en_o:							conv_op enable signal
 * rd_param_full_i:						flag indicate first time param reading finished
 * rd_kernel_only_o:					flag indicate only read kernel parameter
 * rd_param_en_o:						read parameter enable signal
 * rd_param_addr_o:						read prameter ddr address
 * rd_bias_burst_num_o:					bias burst number for one conv layer
 * rd_data_full_i:						flag indicate feature in matrix is full
 * rd_ddr_en_o:							read ddr process enable signal
 * rd_ddr_endX_o:						max X position index for read feature map
 * rd_ddr_endY_o:						max Y position index for read feature map 
 * rd_ddr_x_o:							current x position index for read feature map
 * rd_ddr_y_o:							current y position index for read feature map
 * rd_ddr_first_fm_o:					flag indicate read first feature map
 * rd_ddr_bottom_addr_o:				read ddr start address from some conv layer
 * rd_ddr_bottom_ith_offset_o:			offset for switch feature map
 * rd_ddr_bar_offset_o:					offset for reading last row,related to
 *                                      feature map size
 * rd_top_last_i:						flag indicate read last top data
 * rd_top_en_o:							read top ram enable signal
 * rd_top_offset_o:						offset for read top ram
 * rd_side_last_i:						flag indicate read last side data
 * rd_side_en_o:						read side ram enable signal
 * rd_side_offset_o:					offset for read side ram
 * feature_index_o:						feature index output to update_op
 * conv_layer_index_o:					conv layer index output to update_op 
 * */

module cnn_control
#(
	parameter US = 7
 )
 (
 	// {{{ port definition
 	input	clk_i,
	input	rstn_i,

	// simulation control
	input						tb_load_done_i,
	input 						rd_data_load_ddr_done_rising_edge_i,

	// memory output control
	output						feature_wr_sel_o,
	output						weight_wr_sel_o,
	output						feature_proc_index_o,
	output						weight_proc_index_o,
	
	// conv flag signal
	input						conv_finish_i,
	output  reg					conv_en_o,
	
	// read_op control
	input						rd_param_full_i,
	output	reg					rd_kernel_only_o,
	output	reg					rd_param_en_o,
	output		[ 30-1:0]		rd_param_addr_o,
	output	reg	[ 6-1:0 ]		rd_bias_burst_num_o,

	input						rd_data_full_i,
	output	reg					rd_ddr_en_o,
	output	reg	[ 9-1:0 ]		rd_ddr_endX_o,
	output	reg	[ 9-1:0 ]		rd_ddr_endY_o,
	output		[ 9-1:0 ]		rd_ddr_x_o,
	output		[ 9-1:0 ]		rd_ddr_y_o,
	output	reg					rd_ddr_first_fm_o,
	output	reg	[ 30-1:0 ]		rd_ddr_bottom_addr_o,
	output 	reg	[ 30-1:0 ]		rd_ddr_bottom_ith_offset_o,
	output	reg	[ 30-1:0 ]		rd_ddr_bar_offset_o,

	input						rd_top_last_i,
	output	reg					rd_top_en_o,
	output	reg	[ 13-1:0 ]		rd_top_offset_o,

	input						rd_side_last_i,
	output	reg					rd_side_en_o,
	output	reg	[ 13-1:0 ]		rd_side_offset_o,
	output	reg					switch_trigger_o,
	
	// update_op control
	output		[ 9-1:0 ]		feature_index_o,
	output		[ 9-1:0 ]		feature_index_update_o,
	output		[ 3-1:0 ]		conv_layer_index_o,

    // feature out reg control
    output      [ 5-1:0 ]       grp_sel_o,

    // write_op control
    input                       wr_ddr_done_i,
    output reg                  wr_ddr_en_o,

    // simulation test port
    output      [ 12-1:0 ]      weight_sec_count_o,
    output      [ 9-1:0 ]       feature_index_proc_o,
    output      [ 9-1:0 ]       rd_ddr_x_proc_o,
    output      [ 9-1:0 ]       rd_ddr_y_proc_o
	// }}}	
 );

 // state
 localparam	CTRL_IDLE			= 4'd0;
 localparam CTRL_READ_FTR_INIT	= 4'd1; // first read feature data
 localparam	CTRL_READ_PRM_INIT	= 4'd2; // first read param data, contains weight and all  need bias param
 localparam	CTRL_PROC_CNV_STG	= 4'd3; // process convolution operation
 localparam CTRL_READ_FTR_STG1 	= 4'd4; // read feature data stage1
 localparam CTRL_READ_FTR_STG2	= 4'd5; // read feature data stage2
 localparam	CTRL_READ_PRM_STG	= 4'd6; // read kernel param 
 localparam	CTRL_READ_WAT_STG	= 4'd7; // conv wait stage for reading operation is not done
 localparam CTRL_WRTE_FTR_STG  = 4'd8;  // write data out stage to control write operation
 localparam CTRL_DONE			= 4'd9; // control done
 reg	[ 4-1:0 ]	STATE;

 // internel reg for switch conv layer and feature index
 reg	[ 3-1:0 ]	conv_layer_index;
 reg	[ 9-1:0 ]	feature_index;
 reg	[ 30-1:0 ]	rd_bias_burst_range;
 reg	[ 30-1:0 ]	rd_ddr_bottom_addr;
 reg	[ 30-1:0 ]	rd_param_addr;             // read ddr address output to ddr
 reg	[ 30-1:0 ]	param_addr_stride;         // param read len for current read, 
                                               // different between (bias,weight) reading and weight-only reading
 reg	[ 30-1:0 ]	rd_ddr_bottom_ith_offset;  // base offset for reading current frame data
 reg	[ 30-1:0 ]	rd_ddr_bottom_addr_stride; // 1 frame data storage length
 wire	[ 13-1:0 ]	top_offset;                // top ram reading base offset address
 wire	[ 13-1:0 ]	side_offset;               // side ram reading base offset address
 reg	[ 9-1:0 ] 	feature_index_range;
 reg				feature_to_begin;          // flag indicate feature-reading switch to beggin
 reg	[ 2-1:0 ]	feature_reg_full;          // state register to indicate feature reg buffer is full or used
 reg	[ 2-1:0 ]	weight_reg_full;           // state register to indicate weight reg buffer is full or used
 reg	[ 2-1:0 ]	feature_reg_finish;        // flag to indicate which feature buffer is finish in convolution
 reg	[ 2-1:0 ]	weight_reg_finish;         // flag to indicate wheich weight buffer is finish in convolution
 reg	[ 5-1:0 ]	weight_sec_count;          // counter for weight sector(32*3*3) used
 reg	[ 5-1:0 ]	weight_sec_range;          // total range in 1 feature for weight sector
                                               // (eq: 2(64/32)for first conv layer)
 reg    [ 12-1:0 ]  weight_sec_rd_range;       // total range in all feature for weight sector
                                               // (eq: 6(64*3/32) for first conv layer)
 reg    [ 12-1:0 ]  weight_sec_rd_count;
 reg                weight_to_begin;           // flag indicate weight-reading switch to begin
 reg				feature_finish_index;      // flag to indicate which feature reg buffer is finish in convolution
 reg				weight_finish_index;       // flag to indicate which feature reg buffer is finish in convolution
 reg				feature_wr_sel;            // flag to indicate write ddr data to which feature buffer
 reg				weight_wr_sel;             // flag to indicate write ddr weight to which feature buffer

 reg  [ 9-1:0 ] rd_ddr_x;
 reg  [ 9-1:0 ] rd_ddr_y;
 reg  [ 9-1:0 ] rd_ddr_endX;                   // rd_ddr x and y range based on 14x14
 reg  [ 9-1:0 ] rd_ddr_endY;

 // reg for simulation test
 reg  [ 9-1:0 ] feature_index_0;               // feature index(eq:0,1,2 in first layer) in 0th feature buffer
 reg  [ 9-1:0 ] feature_index_1;
 reg  [ 9-1:0 ] rd_ddr_x_0;                    // ddr address in 0th feature buffer
 reg  [ 9-1:0 ] rd_ddr_y_0;
 reg  [ 9-1:0 ] rd_ddr_x_1;
 reg  [ 9-1:0 ] rd_ddr_y_1;
 wire [ 12-1:0 ] weight_sec_count_proc;
 reg  [ 12-1:0 ] weight_sec_count_proc_delay;
 reg  [ 12-1:0 ] weight_sec_count0;
 reg  [ 12-1:0 ] weight_sec_count1;

 assign feature_proc_index_o		= feature_finish_index;
 assign weight_proc_index_o			= weight_finish_index;
 assign rd_ddr_x_o 					= rd_ddr_x;
 assign rd_ddr_y_o 					= rd_ddr_y;
 assign rd_ddr_endX_o				= rd_ddr_endX;
 assign rd_ddr_endY_o				= rd_ddr_endY;
 assign feature_index_o				= feature_index;
 assign feature_index_update_o		= feature_index == 9'd0 ? feature_index_range-9'd1 : feature_index - 9'd1;
 assign conv_layer_index_o 			= conv_layer_index;
 assign rd_ddr_bottom_addr_o		= rd_ddr_bottom_addr;
 assign rd_param_addr_o				= rd_param_addr;
 assign rd_ddr_bottom_ith_offset_o	= rd_ddr_bottom_ith_offset;
 assign feature_wr_sel_o			= feature_wr_sel;
 assign weight_wr_sel_o				= weight_wr_sel;
 assign grp_sel_o                   = weight_sec_count;

 assign feature_index_proc_o        = feature_finish_index == 1'b1 ? feature_index_1 : feature_index_0;
 assign rd_ddr_x_proc_o             = feature_finish_index == 1'b1 
                                      ? rd_ddr_x_1<<1 : rd_ddr_x_0<<1;
 assign rd_ddr_y_proc_o             = feature_finish_index == 1'b1 
                                      ? rd_ddr_y_1<<1 : rd_ddr_y_0<<1;
 assign weight_sec_count_proc       = weight_finish_index == 1'b1
                                      ? weight_sec_count1 : weight_sec_count0;
 assign weight_sec_count_o          = weight_sec_count_proc;

 always @( negedge rstn_i or posedge clk_i )
 begin
    if( rstn_i == 1'b0 )
    begin
        weight_sec_count_proc_delay <= 12'd0;
    end
    else
    begin
        weight_sec_count_proc_delay <= weight_sec_count_proc;
    end
 end
 always @( posedge clk_i or negedge rstn_i )
 begin
 	if( rstn_i == 1'b0 )
	begin
		// control logic {{{
		rd_param_en_o				<= 1'b0;
		rd_kernel_only_o			<= 1'b0;
		rd_param_addr				<= 30'd0;
		param_addr_stride			<= 30'd0;
		rd_bias_burst_num_o			<= 6'd0;

		rd_ddr_en_o					<= 1'b0;
		rd_ddr_endX					<= 9'd0;
		rd_ddr_endY					<= 9'd0;
		rd_ddr_bottom_addr			<= 30'd0;
		rd_ddr_bar_offset_o			<= 30'd0;
        rd_ddr_first_fm_o           <= 1'b0;

		rd_top_en_o					<= 1'b0;
		//rd_top_offset_o				<= 13'd0;

		rd_side_en_o				<= 1'b0;
		//rd_side_offset_o			<= 13'd0;
	
		feature_wr_sel				<= 1'b0;
		weight_wr_sel				<= 1'b0;
		switch_trigger_o			<= 1'b0;

		conv_layer_index			<= 3'd0;

		conv_en_o					<= 1'b0;
        
        wr_ddr_en_o                 <= 1'b0;
		// }}}

		STATE	<= CTRL_IDLE;
	end
	else
	begin
		case( STATE ) // {{{ 
			CTRL_IDLE:
			begin
				if( tb_load_done_i == 1'b1 && rd_data_load_ddr_done_rising_edge_i == 1'b1 )
				begin
					// control logic {{{
					rd_ddr_en_o					<= 1'b1;	
					rd_ddr_endX					<= 9'd15;   // This need revise in future extension desin
					rd_ddr_endY					<= 9'd15;
					rd_ddr_bottom_addr			<= 30'd0;   // This need revise in future extension design 
					rd_ddr_bar_offset_o			<= 30'h800; // This need revise in future extension desin 620 in compact design
                    rd_ddr_first_fm_o           <= 1'b1;

					rd_top_en_o					<= 1'b0;
					rd_side_en_o				<= 1'b0;

					feature_wr_sel				<= 1'b0;
					weight_wr_sel				<= 1'b0;

					switch_trigger_o			<= 1'b1;
					conv_layer_index			<= 3'd0;   // This need revise in future extension desin
					// }}}

					STATE	<= CTRL_READ_FTR_INIT;         // reading first 16x16 feature
				end
				else
				begin
					// control logic {{{
					rd_param_en_o				<= 1'b0;
					rd_kernel_only_o			<= 1'b0;
					rd_param_addr				<= 30'd0;
					rd_bias_burst_num_o			<= 6'd0;
					
					rd_ddr_en_o					<= 1'b0;
					rd_ddr_endX					<= 9'd0;
					rd_ddr_endY					<= 9'd0;
					rd_ddr_bottom_addr			<= 30'd0;
					rd_ddr_bar_offset_o			<= 30'd0;
                    rd_ddr_first_fm_o           <= 1'b0;

					rd_top_en_o					<= 1'b0;
					//rd_top_offset_o				<= 13'd0;

					rd_side_en_o				<= 1'b0;
					//rd_side_offset_o			<= 13'd0;
					switch_trigger_o			<= 1'b0;

					conv_layer_index			<= 3'd0;

					conv_en_o					<= 1'b0;
					// }}}

					STATE	<= CTRL_IDLE;
				end
			end
			CTRL_READ_FTR_INIT:
			begin
                switch_trigger_o <= 1'b0;
				if( rd_data_full_i == 1'b1 )
				begin
					// control logic {{{
					rd_ddr_en_o					<= 1'b0;

					rd_param_en_o				<= 1'b1;
					rd_kernel_only_o			<= 1'b0;
					rd_param_addr				<= 30'd100000; // This need revise,80000 in compact design
					param_addr_stride			<= 30'd144 + (rd_bias_burst_range << 3); // 144: 32*3*3*32/64
					rd_bias_burst_num_o			<= rd_bias_burst_range[ 5:0 ];
					// }}}
					STATE	<= CTRL_READ_PRM_INIT;  // reading first 32*3*3 weight and all bias data
				end
				else if( rd_data_full_i == 1'b0 )
				begin
					STATE	<= CTRL_READ_FTR_INIT;
				end
			end
			CTRL_READ_PRM_INIT:
			begin
                switch_trigger_o    <= 1'b0;
				if( rd_param_full_i == 1'b1 )
				begin
					// control logic {{{
					rd_ddr_en_o			<= 1'b0;
					rd_param_en_o		<= 1'b0;
					rd_kernel_only_o	<= 1'b1;

					conv_en_o			<= 1'b1;
					// }}}
					STATE	<= CTRL_PROC_CNV_STG;
				end
				else if( rd_param_full_i == 1'b0 )
				begin
					STATE	<= CTRL_READ_PRM_INIT;
				end
			end
			CTRL_PROC_CNV_STG:
			begin
                if( conv_finish_i == 1'b1 && weight_reg_full != 2'b00 && feature_reg_full != 2'b00 )
                    conv_en_o <= 1'b1; // conv_en is set only when conv start
                else
                    conv_en_o <= 1'b0;
                if( conv_finish_i == 1'b1 && weight_sec_count_proc_delay == weight_sec_rd_range-12'd1 )
                // when all kernel in finished in one 14x14 position,
                // start write operaion
                begin
                    conv_en_o     <= 1'b0;
                    rd_ddr_en_o   <= 1'b0;
                    rd_param_en_o <= 1'b0;

                    wr_ddr_en_o   <= 1'b1;

                    STATE   <= CTRL_WRTE_FTR_STG;
                end
				else if( weight_reg_full != 2'b11 )
                // weight buffer has empty buffer sector
                // start read weight operation
				begin
					// control logic {{{
					rd_param_en_o		<= 1'b1;
					rd_kernel_only_o	<= 1'b1;
                    if(  weight_to_begin == 1'b1 )
                        rd_param_addr   <= 30'd100032;
                    else
                        rd_param_addr   <= rd_param_addr + param_addr_stride; // This need revise
					param_addr_stride	<= 30'd144;
					rd_bias_burst_num_o	<= 6'd0;
					weight_wr_sel		<= ~weight_wr_sel;
					// }}}
					STATE	<= CTRL_READ_PRM_STG;
				end
				else if( feature_reg_full != 2'b11 )
                // feature buffer has empty buffer sector
                // start read feature operation
				begin
					// control logic {{{
					rd_ddr_en_o					<= 1'b1;
					rd_ddr_endX					<= 9'd15;
					rd_ddr_endY					<= 9'd15;
					rd_ddr_bar_offset_o			<= 30'h800;
					rd_ddr_bottom_addr			<= 30'd0;
					feature_wr_sel				<= ~feature_wr_sel;

					switch_trigger_o			<= 1'b1;

					conv_layer_index			<= 3'd0;
                    
                    if( feature_index == 9'd0 )
                        rd_ddr_first_fm_o           <= 1'b1;
                    else if( feature_index != 9'd0 )
                        rd_ddr_first_fm_o           <= 1'b0;


                    // decide whether read data from block ram
                    // according to rd_ddr_x and rd_ddr_y
					if( rd_ddr_x != 9'd0 )
					begin
						rd_side_en_o				<= 1'b1;
					end
					else if( rd_ddr_x == 9'd0 )
					begin
						rd_side_en_o				<= 1'b0;
						//rd_side_offset_o			<= 13'd0;
					end
					if( rd_ddr_y != 9'd0 )
					begin
						rd_top_en_o					<= 1'b1;
					end
					else if( rd_ddr_y == 9'd0 )
					begin
						rd_top_en_o					<= 1'b0;
						//rd_top_offset_o				<= 13'd0;
					end
					// }}}
					STATE	<= CTRL_READ_FTR_STG1;
				end
				else
				begin
					STATE	<= CTRL_PROC_CNV_STG;
				end
			end
			CTRL_READ_PRM_STG:
			begin
				if( conv_finish_i == 1'b1 && rd_param_full_i == 1'b0 )
                // if conv finish in reading param circle,
                // let convolution wait util reading is done
				begin
					conv_en_o	<= 1'b0;

					STATE	<= CTRL_READ_WAT_STG;
				end
				else if( rd_param_full_i == 1'b1 )
				begin
					rd_param_en_o	<= 1'b0;

					STATE	<= CTRL_PROC_CNV_STG;
				end
				else
				begin
					STATE	<= CTRL_READ_PRM_STG;
				end
			end
            // reading feature consists of read from ddr and ram,
            // in STG1: we enable read from ddr and ram
            // in STG2: we disable read from ram if ram-reading is done
			CTRL_READ_FTR_STG1:
			begin
				// state transition
				switch_trigger_o	<= 1'b0;
				rd_ddr_en_o			<= 1'b1;

				STATE	<= CTRL_READ_FTR_STG2;
			end
			CTRL_READ_FTR_STG2:
			begin
				// control logic {{{
				if( rd_side_last_i == 1'b1 )
				begin
					rd_side_en_o		<= 1'b0;
					//rd_side_offset_o	<= side_offset;
				end
				if( rd_top_last_i == 1'b1 )
				begin
					rd_top_en_o			<= 1'b0;
					//rd_top_offset_o		<= top_offset + { 4'd0, rd_ddr_x };
				end
				// }}}

				// state transition {{{
				if( conv_finish_i == 1'b1 && rd_data_full_i == 1'b0 )
                // if conv if finish in read feature circle
                // let conv operation wait util feature-reading is done
				begin
					conv_en_o	<= 1'b0;

					STATE	<= CTRL_READ_WAT_STG;
				end
				else if( rd_data_full_i==1'b1 ) 
				begin
					rd_ddr_en_o = 1'b0;

					STATE	<= CTRL_PROC_CNV_STG;
                end
				else if( rd_data_full_i == 1'b0 )
				begin
					STATE	<= CTRL_READ_FTR_STG2;
				end
				// }}}
			end
			CTRL_READ_WAT_STG:
			begin
				// conntrol logic {{{
				// do not change things keeped in last state
                // conv_en instead
				conv_en_o	<= 1'b0;
				// }}}
				// state transition {{{
				if( rd_data_full_i == 1'b1 || rd_param_full_i==1'b1 )
				begin
                    conv_en_o <= 1'b1;

					STATE	<= CTRL_PROC_CNV_STG;
				end
				else
				begin
					STATE	<= CTRL_READ_WAT_STG;
				end
				// }}}
			end
            CTRL_WRTE_FTR_STG:
            begin
                if( wr_ddr_done_i == 1'b1 )
                begin
                    wr_ddr_en_o <= 1'b0;
                    conv_en_o   <= 1'b1;

                    STATE <= CTRL_PROC_CNV_STG;
                end
                else
                begin
                    STATE <= CTRL_WRTE_FTR_STG;
                end
            end
			CTRL_DONE:
            begin
				// control logic {{{
				rd_ddr_en_o					<= 1'b0;
				rd_ddr_endX					<= 9'd0;
				rd_ddr_endY					<= 9'd0;
				rd_ddr_bottom_addr			<= 30'd0;
				rd_ddr_bar_offset_o			<= 30'd0;

				switch_trigger_o			<= 1'b0;

				rd_top_en_o					<= 1'b0;
				//rd_top_offset_o				<= 13'd0;

				rd_side_en_o				<= 1'b0;
				//rd_side_offset_o			<= 13'd0;

				conv_layer_index			<= 3'd0;
				// }}}

				STATE	<= CTRL_IDLE;
			end 
		endcase // }}}
	end
 end


 // The following logic are related to signal, 
 // rather than control state
 
 // different conv layer has different feature index range {{{
 always @( conv_layer_index )
 begin
 	case( conv_layer_index )
		3'd0:		
		begin
			feature_index_range 		= 9'd3;
			rd_bias_burst_range			= 30'd4;
			rd_ddr_bottom_addr_stride	= 30'h8000; // 64*4*16*16*32/64 
			//rd_ddr_bottom_addr_stride	= 30'd25088; // 224*224*32/64 

			weight_sec_range			= 5'd2;
            weight_sec_rd_range         = 12'd6;
		end
		default:	// this need revise in future extention design
		begin
			feature_index_range 		= 9'd0; 
			rd_bias_burst_range			= 30'd0;
			rd_ddr_bottom_addr_stride	= 30'd0;

			weight_sec_range			= 5'd0;
            weight_sec_rd_range         = 12'd0;
		end
	endcase
 end

 always @( negedge rstn_i or posedge rd_data_full_i )
 begin
 	if( rstn_i == 1'b0 )
	begin
		feature_index		<= 9'd0;
		feature_to_begin	<= 1'b0;

        feature_index_0     <= 9'd0;
        feature_index_1     <= 9'd0;
	end
	else
	begin
        if( feature_wr_sel == 1'b0 )      feature_index_0 <= feature_index;
        else if( feature_wr_sel == 1'b1 ) feature_index_1 <= feature_index;
		if( feature_index == feature_index_range-9'd1 )
		begin
			feature_index		<= 9'd0;
			feature_to_begin	<= 1'b1;
		end
		else
		begin
			feature_index		<= feature_index + 9'd1;
			feature_to_begin	<= 1'b0;
		end
	end
 end
 // }}}
 

 // decide ram offset according to feature index and conv layer index {{{
 always @( negedge rstn_i or posedge rd_side_en_o )
 begin
 	if( rstn_i == 1'b0 )
		rd_side_offset_o	<= 13'd0;
	else
		rd_side_offset_o	<= side_offset;
 end
 always @( negedge rstn_i or posedge rd_top_en_o )
 begin
 	if( rstn_i == 1'b0 )
		rd_top_offset_o		<= 13'd0;
	else
		rd_top_offset_o		<= top_offset + { 4'd0, rd_ddr_x };
 end
 ram_offset
 ram_offset_U
 (
 	.feature_index_i	( feature_index 	),
	.conv_layer_index_i ( conv_layer_index 	),

	.top_offset_o		( top_offset		),
	.side_offset_o		( side_offset		)
 );
 // }}}
 
    // update (x,y) {{{
    // update reading x and y address from ddr
    // according to read finish signal
    always @( negedge rstn_i or posedge clk_i )
    begin
        if( rstn_i == 1'b0 )
        begin
            rd_ddr_x                 <= 9'd0;
            rd_ddr_y                 <= 9'd0;
            rd_ddr_bottom_ith_offset <= 30'd0;

            rd_ddr_x_0               <= 9'd0;
            rd_ddr_y_0               <= 9'd0;
            rd_ddr_x_1               <= 9'd0;
            rd_ddr_y_1               <= 9'd0;
        end
        else if( rd_data_full_i == 1'b1 )
        begin
            //rd_ddr_en_o			<= 1'b1;
            if( feature_wr_sel == 1'b0 ) 
            begin
                rd_ddr_x_0  <= rd_ddr_x;
                rd_ddr_y_0  <= rd_ddr_y;
            end
            else if( feature_wr_sel == 1'b1 )
            begin
                rd_ddr_x_1  <= rd_ddr_x;
                rd_ddr_y_1  <= rd_ddr_y;
            end

            if( feature_to_begin ==1'b1 )
            begin
                if( rd_ddr_x == rd_ddr_endX ) // this need revise in future extention design
                begin
                    rd_ddr_x	<= 9'd0;
                    if( rd_ddr_y == rd_ddr_endY ) // this need revise in future extention design 
                        rd_ddr_y	<= 9'd0;
                    else
                        rd_ddr_y	<= rd_ddr_y + 9'd1;
                end
                else
                    rd_ddr_x	<= rd_ddr_x + 9'd1;
            end
            else if( feature_to_begin == 1'b0 )
            begin
                rd_ddr_x = rd_ddr_x;
                rd_ddr_y = rd_ddr_y;
            end
            
            if( feature_index == 9'd0 )
            begin
                rd_ddr_bottom_ith_offset	<= 30'd0;
            end
            else if( feature_index != 9'd0 )
            begin
                rd_ddr_bottom_ith_offset	<= rd_ddr_bottom_ith_offset + rd_ddr_bottom_addr_stride;
            end
        end
    end
    // }}}
 
 	// decide reg matrix is empty or not {{{
    // two state register is stored in cnn_control
    // feature state register and 
    // weight state register
    // state register is used to indicate corresponding
    // buffer is empty or full,
    // and is updated by read data finish and
    // conv finish signal
	always @( rstn_i or conv_finish_i )
	begin
		if( rstn_i == 1'b0 )
		begin
			feature_finish_index 	<= 1'b0;
			weight_finish_index	 	<= 1'b0;
			weight_sec_count		<= 5'd0;

			weight_reg_finish		<= 2'b00;
		end
		else if( conv_finish_i == 1'b1 )
		begin
			weight_finish_index		<= weight_finish_index + 1'b1;
			weight_sec_count		<= weight_sec_count + 5'd1;
			if( weight_sec_count == weight_sec_range-5'd1 )
			begin
				feature_finish_index	<= feature_finish_index + 1'b1;
				weight_sec_count		<= 5'd0;

				if( feature_finish_index == 1'b0 )		feature_reg_finish <= 2'b01;
				else if( feature_finish_index == 1'b1 )	feature_reg_finish <= 2'b10;
			end

			if( weight_finish_index == 1'b0 ) weight_reg_finish <= 2'b01;
			else if( weight_finish_index == 1'b1 ) weight_reg_finish <= 2'b10;
		end
		else
		begin
			weight_reg_finish  <= 2'b00;
			feature_reg_finish <= 2'b00;
		end
	end
	always @( negedge rstn_i or posedge clk_i )	
	begin
		if( rstn_i == 1'b0 )
		begin
			feature_reg_full		<= 2'b00;
			weight_reg_full			<= 2'b00;

            weight_sec_rd_count     <= 12'd0;
            weight_to_begin         <= 1'b0;
            weight_sec_count0       <= 12'd0;
            weight_sec_count1       <= 12'd0;
        end
		else
		begin
			if( rd_data_full_i )
			begin
				if( feature_wr_sel == 1'b0 )        feature_reg_full[ 0 ]   <= 1'b1;
				else if( feature_wr_sel == 1'b1 )   feature_reg_full[ 1 ]   <= 1'b1;
			end	
			if( feature_reg_finish == 2'b01 )		feature_reg_full[ 0 ]	<= 1'b0;
			else if( feature_reg_finish == 2'b10 )	feature_reg_full[ 1 ]	<= 1'b0;

			if( rd_param_full_i )
			begin
                if( weight_wr_sel == 1'b0 )
                begin
                    weight_sec_count0 <= weight_sec_rd_count;
                end
                else if( weight_wr_sel == 1'b1 )
                begin
                    weight_sec_count1 <= weight_sec_rd_count;
                end
                if( weight_sec_rd_count == weight_sec_rd_range-12'd1 )
                begin
                    weight_sec_rd_count <= 12'd0;
                    weight_to_begin     <= 1'b1;
                end
                else
                begin
                    weight_sec_rd_count  <= weight_sec_rd_count + 12'd1;
                    weight_to_begin      <= 1'b0;
                end
				if( weight_wr_sel==1'b0 )		weight_reg_full[ 0 ]	<= 1'b1;
				else if( weight_wr_sel==1'b1 )	weight_reg_full[ 1 ]	<= 1'b1;
			end
			if( weight_reg_finish == 2'b01 )		weight_reg_full[ 0 ]	<= 1'b0;
			else if( weight_reg_finish == 2'b10 )	weight_reg_full[ 1 ]	<= 1'b0;
		end

	end
	// }}}

endmodule
