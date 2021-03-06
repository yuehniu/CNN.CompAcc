// read and write interface with mig
`include "common.v"
module rd_wr_path
#(
    parameter ADDR_WIDTH = 30,
    parameter DATA_WIDTH = 512,
    parameter DATA_NUM_BITS = 16
)
(
    input clk_i,
    input rst_i,
    //-- control
    input  wr_en_i,
    input  rd_en_i,
    input  init_calib_complete_i,
    (*mark_debug="TRUE"*)input  app_rdy_i,
    (*mark_debug="TRUE"*)input  app_wdf_rdy_i,
    output app_en_o,
    output [3-1:0] app_cmd_o,
    output reg [64-1:0] app_wdf_mask_o,
    output reg [ADDR_WIDTH-1:0] app_addr_o,
    //-- write
    input  [DATA_NUM_BITS-1:0] wr_burst_num_i,
    input  [ADDR_WIDTH-1:0] wr_start_addr_i,
    input  [DATA_WIDTH-1:0] wr_data_i,
    (*mark_debug="TRUE"*)output reg app_wdf_wren_o,
    output reg [DATA_WIDTH-1:0] app_wdf_data_o,
    output reg app_wdf_end_o,
    (*mark_debug="TRUE"*)output reg fetch_data_en_o,
    output reg wr_ddr_done_o,
    //-- read
    input  [DATA_NUM_BITS-1:0] rd_burst_num_i,
    input  [ADDR_WIDTH-1:0] rd_start_addr_i,
    input  app_rd_data_valid_i,
    input  [DATA_WIDTH-1:0] app_rd_data_i,
    input  app_rd_data_end_i,
    output reg rd_ddr_done_o,
    output rd_data_valid_o,
    output [DATA_WIDTH-1:0] rd_data_o
);

    localparam IDLE      = 3'd0;
    localparam WR_READY  = 3'd1;
    localparam WR_PROC   = 3'd2;
    localparam RD_PROC   = 3'd3;
    localparam CMD_WAIT  = 3'd4;
    (*mark_debug="TRUE"*)reg [3-1:0] _cs_;

    reg app_en;
    reg [3-1:0] app_cmd;
    reg [ADDR_WIDTH-1:0] wr_addr;
    reg [ADDR_WIDTH-1:0] rd_addr;

    (*mark_debug="TRUE"*)reg  [DATA_NUM_BITS-1:0] wr_data_burst_cnt;
    (*mark_debug="TRUE"*)reg  [DATA_NUM_BITS-1:0] wr_addr_burst_cnt;
    (*mark_debug="TRUE"*)wire [DATA_NUM_BITS-1:0] addr_data_cnt_diff;
    reg  [DATA_NUM_BITS-1:0] rd_addr_burst_cnt;

    //--assign app_cmd_o = (~app_wdf_wren_o && app_cmd==3'd0) ? 3'd2: app_cmd;
    //--assign app_en_o  = (~app_wdf_wren_o && app_cmd==3'd0) ? 1'b0: app_en;
    assign app_en_o = app_en;
    assign app_cmd_o = app_cmd;
    assign addr_data_cnt_diff = wr_addr_burst_cnt - wr_data_burst_cnt;
    always @(posedge rst_i or posedge clk_i) begin
        if(rst_i || ~init_calib_complete_i) begin
            _cs_ <= IDLE;

            app_en         <= 1'b0;
            app_cmd        <= 3'd2;
            app_addr_o     <= {ADDR_WIDTH{1'b0}};
            app_wdf_mask_o <= 64'd0;
            
            wr_ddr_done_o    <= 1'b0;
            wr_addr          <= {ADDR_WIDTH{1'b0}};
            rd_ddr_done_o    <= 1'b0;
            rd_addr          <= {ADDR_WIDTH{1'b0}};

            wr_addr_burst_cnt  <= {DATA_NUM_BITS{1'b0}};
            rd_addr_burst_cnt  <= {DATA_NUM_BITS{1'b0}};
        end
        else begin
            case(_cs_)
            IDLE: begin
                app_en     <= 1'b0;
                app_cmd    <= 3'd2;
                app_addr_o <= {ADDR_WIDTH{1'b0}};

                wr_ddr_done_o    <= 1'b0;
                wr_addr          <= {ADDR_WIDTH{1'b0}};
                rd_ddr_done_o    <= 1'b0;
                rd_addr          <= {ADDR_WIDTH{1'b0}};

                wr_addr_burst_cnt  <= {DATA_NUM_BITS{1'b0}};
                rd_addr_burst_cnt  <= {DATA_NUM_BITS{1'b0}};

                if(app_rdy_i) begin
                    if(wr_en_i && ~wr_ddr_done_o) begin
                        _cs_ <= WR_READY;
                    end
                    else if(rd_en_i) begin
                        _cs_ <= RD_PROC;

                        app_en     <= 1'b1;
                        app_cmd    <= 3'd1;
                        app_addr_o <= rd_start_addr_i;
                    end
                end
                else begin
                    _cs_ <= IDLE;
                end
            end
            WR_READY: begin
                if(app_rdy_i) begin
                    _cs_ <= WR_PROC;

                    app_en            <= 1'b1;
                    app_cmd           <= 3'd0;
                    wr_addr_burst_cnt <= wr_addr_burst_cnt + 1'b1;
                    app_addr_o        <= wr_start_addr_i;
                    wr_addr           <= wr_start_addr_i;
                end
                else begin
                   _cs_ <= WR_READY;

                   app_en             <= 1'b0;
                   wr_addr            <= wr_start_addr_i;
                end
            end
            WR_PROC: begin
                if(wr_en_i && app_rdy_i &&
                   wr_data_burst_cnt == wr_burst_num_i &&
                   wr_addr_burst_cnt == wr_burst_num_i) begin
                   _cs_ <= IDLE;

                   wr_ddr_done_o  <= 1'b1;
                   app_en         <= 1'b0;
                   app_cmd        <= 3'd2;
                end
                else begin
                    if(~app_rdy_i) begin
                        if(app_en) begin
                            _cs_ <= CMD_WAIT;
                            wr_addr           <= app_addr_o;
                            wr_addr_burst_cnt <= wr_addr_burst_cnt - 1'b1;
                        end
                        else begin
                            if(wr_en_i && 
                               wr_data_burst_cnt == wr_burst_num_i &&
                               wr_addr_burst_cnt == wr_burst_num_i) begin
                               _cs_ <= IDLE;

                               wr_ddr_done_o <= 1'b1;
                               app_en        <= 1'b0;
                               app_cmd       <= 3'd2;
                            end
                            else begin
                               _cs_ <= WR_PROC;
                            end
                        end
                    end
                    else begin
                        _cs_ <= WR_PROC;
                        
                        // data advance the address, or lag the address within
                        // two clock period 
                        if((addr_data_cnt_diff[DATA_NUM_BITS-1] == 1'b1 ||
                           addr_data_cnt_diff == {{(DATA_NUM_BITS-2){1'b0}}, 2'b00} ||
                           addr_data_cnt_diff == {{(DATA_NUM_BITS-2){1'b0}}, 2'b01} ||
                           addr_data_cnt_diff == {{(DATA_NUM_BITS-2){1'b0}}, 2'b10}) && (wr_addr_burst_cnt != wr_burst_num_i)) begin
                            app_en            <= 1'b1;
                            app_addr_o        <= wr_addr + 4'h8;
                            wr_addr           <= wr_addr + 4'd8;
                            wr_addr_burst_cnt <= wr_addr_burst_cnt + 1'b1;
                        end
                        else begin
                            app_en        <= 1'b0;
                        end
                    end
                end
            end
            RD_PROC: begin
                if(rd_addr_burst_cnt != rd_burst_num_i) begin
                    if(rd_en_i && ~app_rdy_i) begin
                        _cs_ <= CMD_WAIT;

                        rd_addr       <= app_addr_o;
                    end
                    else begin
                        _cs_ <= RD_PROC;

                        app_addr_o        <= app_addr_o + 4'h8;
                        rd_addr_burst_cnt <= rd_addr_burst_cnt + 1'b1;
                    end
                end
                else if(rd_addr_burst_cnt==rd_burst_num_i) begin
                    // if ~app_rdy_i, the last read address won't be input to 
                    // mig unit. So _cs_ will go to CMD_WAIT, waiting for
                    // next app_rdy_i signal
                    if(rd_en_i && ~app_rdy_i) begin
                        _cs_ <= CMD_WAIT;

                        rd_addr            <= app_addr_o;
                    end
                    else begin
                        _cs_ <= IDLE;

                        rd_ddr_done_o <= 1'b1;
                        app_en        <= 1'b0;
                    end
                end
            end
            CMD_WAIT: begin
                if(app_rdy_i && wr_en_i) begin
                    _cs_ <= WR_PROC;

                    if((addr_data_cnt_diff[DATA_NUM_BITS-1] == 1 ||
                       addr_data_cnt_diff == {{(DATA_NUM_BITS-2){1'b0}}, 2'b00} ||
                       addr_data_cnt_diff == {{(DATA_NUM_BITS-2){1'b0}}, 2'b01} ||
                       addr_data_cnt_diff == {{(DATA_NUM_BITS-2){1'b0}}, 2'b10}) ) begin
                       if(wr_addr_burst_cnt == (wr_burst_num_i-1'b1)) begin
                           wr_addr_burst_cnt <= wr_addr_burst_cnt + 1'b1;
                           app_en            <= 1'b0;
                       end
                       else begin
                           app_en            <= 1'b1;
                           app_addr_o        <= wr_addr + 4'h8;
                           wr_addr           <= wr_addr + 4'd8;
                           wr_addr_burst_cnt <= wr_addr_burst_cnt + 2'd2;
                       end
                    end
                    else begin
                        app_en        <= 1'b0;
                    end
                end
                else if (app_rdy_i && rd_en_i) begin
                    if(rd_addr_burst_cnt != rd_burst_num_i) begin
                        _cs_ <= RD_PROC;

                        app_addr_o        <= rd_addr + 4'd8;
                        rd_addr_burst_cnt <= rd_addr_burst_cnt + 1'b1;
                    end
                    else begin
                        _cs_ <= IDLE;
 
                        rd_ddr_done_o <= 1'b1;
                        app_en        <= 1'b0;
                    end
                end
                else if (wr_en_i || rd_en_i )begin
                    _cs_ <= CMD_WAIT;

                end
                else begin
                    _cs_ <= IDLE;

                    app_en         <= 1'b0;
                end
            end
            endcase
        end
    end

    // fetch data control
    // app_wdf* signal in controlled only by state, no clock
`ifdef SIM
    reg sim_wr_ddr_block_done;
    reg sim_rd_ddr_block_done;
    always @(posedge rst_i or posedge clk_i) begin
        if(rst_i) begin
            sim_wr_ddr_block_done <= 1'b0;
            sim_rd_ddr_block_done <= 1'b0;
        end
        else begin
            if(wr_data_burst_cnt[9] && sim_wr_ddr_block_done) begin
                $display("%t] %d write bursts finished.", $realtime, wr_data_burst_cnt);
                sim_wr_ddr_block_done <= 1'b0;
            end
            else if(~wr_data_burst_cnt[9]) begin
                sim_wr_ddr_block_done <= 1'b1;
            end
            if(rd_addr_burst_cnt[9] && sim_rd_ddr_block_done) begin
                $display("%t] %d read bursts finished.", $realtime, rd_addr_burst_cnt);
                sim_rd_ddr_block_done <= 1'b0;
            end
            else if(~rd_addr_burst_cnt[9]) begin sim_rd_ddr_block_done <= 1'b1;
            end
        end
    end
`endif
    always @(_cs_ or app_rdy_i or wr_en_i or app_wdf_rdy_i or wr_data_i or wr_data_burst_cnt or wr_burst_num_i) begin
        case(_cs_)
        WR_READY: begin
            if(app_rdy_i) begin
                 fetch_data_en_o  = 1'b1;
            end
            else begin
                 fetch_data_en_o  = 1'b0;
            end

            app_wdf_data_o = wr_data_i;
            app_wdf_wren_o = 1'b0;
            app_wdf_end_o  = 1'b0;
        end
        WR_PROC,CMD_WAIT: begin
            if(wr_en_i && app_wdf_rdy_i &&
               wr_data_burst_cnt != wr_burst_num_i) begin
                app_wdf_data_o = wr_data_i;
                app_wdf_wren_o = 1'b1;
                app_wdf_end_o  = 1'b1;

                fetch_data_en_o = 1'b1;
            end
            else begin
                app_wdf_data_o = wr_data_i;
                app_wdf_wren_o = 1'b0;
                app_wdf_end_o  = 1'b0;

                fetch_data_en_o = 1'b0;
            end
        end
        default: begin
            app_wdf_data_o = wr_data_i;
            app_wdf_wren_o = 1'b0;
            app_wdf_end_o  = 1'b0;

            fetch_data_en_o = 1'b0;
        end
        endcase
    end
    always @(posedge rst_i or posedge clk_i) begin
        if(rst_i) begin
            wr_data_burst_cnt <= {DATA_NUM_BITS{1'b0}};
        end
        else if(wr_ddr_done_o) begin
            wr_data_burst_cnt <= {DATA_NUM_BITS{1'b0}};            
        end
        else if(fetch_data_en_o) begin
            if(wr_data_burst_cnt != wr_burst_num_i)
                wr_data_burst_cnt <= wr_data_burst_cnt + 1'b1;
        end
    end

    assign rd_data_valid_o = app_rd_data_valid_i;
    assign rd_data_o       = app_rd_data_i;
endmodule
