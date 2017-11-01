/*
 * This module make ddr signal syncnous with user signal
 * */
module ddr_sync
#(
	parameter DW = 512
 )
 (
 	input	rstn_i,
	input	clk_i,
	input 					ddr_rd_data_valid_i,
	input 					ddr_rdy_i,
	input	[ DW-1:0 ]		ddr_rd_data_i,

	output	reg				ddr_rd_data_valid_sync_o,
	output	reg				ddr_rdy_sync_o,
	output	reg	[ DW-1:0 ]	ddr_rd_data_sync_o
 );

 always @( negedge rstn_i or posedge clk_i )
 begin
 	if( rstn_i == 1'b0 )
	begin
		ddr_rd_data_valid_sync_o	<= 1'b0;
		ddr_rdy_sync_o				<= 1'b0;
		ddr_rd_data_sync_o			<= { DW{1'b0} };
	end
	else
	begin
		ddr_rd_data_valid_sync_o	<= ddr_rd_data_valid_i;
		ddr_rdy_sync_o				<= ddr_rdy_i;
		ddr_rd_data_sync_o			<= ddr_rd_data_i;
	end
 end

endmodule
