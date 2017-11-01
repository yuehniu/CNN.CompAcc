// read and write operation
module rd_wr_op
#(
	parameter ADDR_WIDTH = 30,
	parameter DATA_WIDTH = 512,
	parameter DATA_NUM_BITS = 16
)
(
	input clk_i,
	input rst_i,

    // control
    input                          init_calib_complete_i,
	// write
	output reg                     wr_en_o,
	output reg [DATA_NUM_BITS-1:0] wr_burst_num_o,
	input                          fetch_data_en_i,
	output reg [ADDR_WIDTH-1:0]    wr_start_addr_o,
	output reg [DATA_WIDTH-1:0]    wr_data_o,
	input                          wr_ddr_done_i,

	// read
	output reg                     rd_en_o,
	output reg [DATA_NUM_BITS-1:0] rd_burst_num_o,
	output reg [ADDR_WIDTH-1:0]    rd_start_addr_o,
	input                          rd_data_valid_i,
	input  [DATA_WIDTH-1:0]        rd_data_i,
	input                          rd_ddr_done_i
);
	`define SEEK_SET 0
	`define SEEK_CUR 1
	`define SEEK_END 2

	localparam DATA_NUM      = {DATA_NUM_BITS{1'b1}};

    localparam IDLE = 3'd0;
    localparam WR_PROC = 3'd1;
    localparam RD_PROC = 3'd2;
    localparam DONE = 3'd3;
    reg [3-1:0] _cs_;

    integer FILE_HANDLE;
    integer r;


    always @(posedge rst_i or posedge clk_i) begin
    	if(rst_i || ~init_calib_complete_i) begin
    	    _cs_ <= IDLE;

    	    wr_start_addr_o <= {ADDR_WIDTH{1'b0}};
    	    wr_data_o       <= {DATA_WIDTH{1'b0}};

    	    rd_start_addr_o <= {ADDR_WIDTH{1'b0}};
    	end
    	else if(init_calib_complete_i) begin
    		case(_cs_)
    		IDLE: begin
    		    _cs_ <= WR_PROC;

    		    wr_start_addr_o <= {ADDR_WIDTH{1'b0}};
    		    wr_data_o       <= {DATA_WIDTH{1'b0}};
    		    // wr_burst_num_o  <= {DATA_NUM_BITS{1'b1}};
    		    wr_burst_num_o  <= 20'd854622;

    	        FILE_HANDLE     = $fopen("ddr_test_data.bin", "r");
    		end
    		WR_PROC: begin
    			if(wr_ddr_done_i) begin
    			    _cs_ <= RD_PROC;

    			    rd_start_addr_o <= {ADDR_WIDTH{1'b0}};  
    			    // rd_burst_num_o  <= {DATA_NUM_BITS{1'b1}};	
    			    rd_burst_num_o  <= 20'd854622;	
    			end
    			else begin
    				_cs_ <= WR_PROC;

    				if(fetch_data_en_i) begin
    					r = $fread(wr_data_o, FILE_HANDLE);
    					// wr_data_o         <= {64{wr_data_burst_cnt}};
    				end
    			end
    		end
    		RD_PROC: begin
    			if(rd_ddr_done_i) begin
    				_cs_ <= DONE;

    			end
    			else begin
    				_cs_ <= RD_PROC;
    			end
    		end
    		DONE: begin
    			_cs_ <= DONE;
    		end
    		endcase
    	end
    end

    always @(_cs_ or wr_ddr_done_i or rd_ddr_done_i) begin
    	case(_cs_)
    	WR_PROC: begin
    		if(wr_ddr_done_i) begin
    			wr_en_o <= 1'b0;
    		end
    		else begin
    			wr_en_o <= 1'b1;
    		end
    	end
    	RD_PROC: begin
    		if(rd_ddr_done_i) begin
    			rd_en_o <= 1'b0;
    		end
    		else begin
    			rd_en_o <= 1'b1;
    		end
    	end
    	default: begin
    		wr_en_o <= 1'b0;
    		rd_en_o <= 1'b0;
    	end
    	endcase
    end

    // receive data
    reg [DATA_NUM_BITS-1:0] rc_data_burst_cnt;
    reg [DATA_WIDTH-1:0] ref_data;
    integer LOG_HANDLE;
    always @(posedge rst_i or posedge clk_i) begin
        if(rst_i) begin
        	LOG_HANDLE = $fopen("simv_log.txt", "wt");
        end
    	if(rst_i || ~init_calib_complete_i) begin
    		rc_data_burst_cnt <= {DATA_NUM_BITS{1'b0}};
    		ref_data <= {DATA_WIDTH{1'b0}};
    	end
    	else if(rd_data_valid_i) begin
    		rc_data_burst_cnt <= rc_data_burst_cnt + 1'b1;
    		r = $fseek(FILE_HANDLE, rc_data_burst_cnt*DATA_WIDTH/8, `SEEK_SET);
    		r = $fread(ref_data, FILE_HANDLE);
    		// ref_data = {64{rc_data_burst_cnt}};
    		if (ref_data == rd_data_i) begin
    			$fdisplay(LOG_HANDLE, "write data to ddr at position: %d passed -> [ref: %x----ddr: %x].", rc_data_burst_cnt, ref_data, rd_data_i);
    		end
    		else begin
    			$fdisplay(LOG_HANDLE, "write data to ddr at position: %d failed -> [ref: %x----ddr: %x].", rc_data_burst_cnt, ref_data, rd_data_i);    			
    		end

    		if(rc_data_burst_cnt == {DATA_NUM_BITS{1'b1}})
    		    $finish;
    	end
    end
endmodule