/*
 * simple write op just for test
 * */
module write_op
 (
     input rstn_i,
     input clk_i,

     input      wr_ddr_en_i,
     output reg wr_ddr_done_o
 );

 reg [ 4-1:0 ] test_count; // juest for control when to finish write

 always @( negedge rstn_i  or posedge clk_i )
 begin
    if( rstn_i == 1'b0 )
    begin
        test_count    <= 4'd0;
        wr_ddr_done_o <= 1'b0;
    end
    else if( wr_ddr_en_i == 1'b1 )
    begin
        if( test_count == 4'd15 )
        begin
            test_count    <= 4'd0;
            wr_ddr_done_o <= 1'b1;
        end
        else
        begin
            test_count    <= test_count + 4'd1;
            wr_ddr_done_o <= 1'b0;
        end
    end
 end

endmodule
