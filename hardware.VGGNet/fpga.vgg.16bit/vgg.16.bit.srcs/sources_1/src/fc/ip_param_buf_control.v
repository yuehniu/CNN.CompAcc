/* 
  //--buffer controller for ip param
*/
`include "common.v"
module ip_param_buf_control
#(
    parameter FW = 32,
    parameter WL = 9'd288
)
(
    input  clk_i,
    input  rstn_i,
    input  rd_buf_en_i,
    input  wr_buf_done_i,
    input  ip_done_i,
    input  ip_oneuron_start_i,
    input  ip_oneuron_done_i,
    input  [FW-1:0] ip_param_i,
    output rd_buf_done_o,
    output wr_buf_sel_o,
    output reg ip_bias_valid_o,
    output reg ip_weight_valid_o,
    output [2-1:0] param_buf_full_o,
    output [2-1:0] param_buf_busy_o,
    (*mark_debug="TRUE"*)output [9-1:0] ip_buf_addr_o,
    output reg[FW-1:0] ip_bias_o,
    output reg[FW-1:0] ip_weight_o
);

    reg [2-1:0] _buffer_full_;
    reg [2-1:0] _buffer_busy_;
    reg [9-1:0] ip_buf_addr;

    //--addr counter
    //--Since in param_buf, first data is at the highest address,
    //--read address is accordingly from high to low
    reg rd_buf_done;
    assign rd_buf_done_o = rd_buf_done;
    assign ip_buf_addr_o = WL-1 - ip_buf_addr;
    always @(posedge clk_i or negedge rstn_i) begin
        if (rstn_i == 1'b0) begin
            // reset
            ip_buf_addr <= WL;
            rd_buf_done <= 1'b0;
        end
        else begin
            if(ip_done_i) begin
                // reset
                ip_buf_addr <= WL;
                rd_buf_done <= 1'b0;
            end
            else if (rd_buf_en_i==1'b1) begin
                if (ip_buf_addr == 9'd0) begin
                    ip_buf_addr <= WL;
                    rd_buf_done <= 1'b0;
                end
                else if(ip_buf_addr == 9'd1) begin
                    rd_buf_done <= 1'b1;
                    ip_buf_addr <= ip_buf_addr - 1'b1;
                end
                else begin
                    ip_buf_addr <= ip_buf_addr - 1'b1;
                    rd_buf_done <= 1'b0;
                end
            end
            else begin
                if(ip_buf_addr == 9'd0) begin
                    ip_buf_addr <= WL;
                end
                rd_buf_done <= 1'b0;
            end
        end
    end

    //--weight or bias data?
    //--first fetch bias data and then weight
    reg ip_oneuron_start_delay_1clk;
    reg ip_oneuron_start_delay_2clk;
    reg rd_buf_en_delay_1clk;
    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i) begin
            ip_weight_valid_o <= 1'b0;
            ip_weight_o       <= {FW{1'b0}};

            ip_bias_valid_o   <= 1'b0;
            ip_bias_o         <= {FW{1'b0}};

            ip_oneuron_start_delay_1clk <= 1'b0;
            ip_oneuron_start_delay_2clk <= 1'b0;
            rd_buf_en_delay_1clk        <= 1'b0;
        end
        else begin
            ip_oneuron_start_delay_1clk <= ip_oneuron_start_i;
            rd_buf_en_delay_1clk        <= rd_buf_en_i;
            ip_oneuron_start_delay_2clk <= ip_oneuron_start_delay_1clk;

            if(ip_oneuron_start_delay_1clk) begin
                ip_bias_valid_o   <= 1'b1;
                ip_weight_valid_o <= 1'b0;

                ip_bias_o <= ip_param_i;
                ip_weight_o <= {FW{1'b0}};
            end
            else if(rd_buf_en_delay_1clk) begin
                ip_bias_valid_o   <= 1'b0;
                ip_weight_valid_o <= 1'b1;
                ip_bias_o <= {FW{1'b0}};
                ip_weight_o <= ip_param_i;
            end
            else begin
                ip_bias_valid_o   <= 1'b0;
                ip_weight_valid_o <= 1'b0;
                ip_bias_o         <= {FW{1'b0}};
                ip_weight_o       <= {FW{1'b0}};
            end
        end
    end

    //--buffer status
    //--_buffer_full_: which buffer is available
    //--_buffer_busy_: which buffer is used currently
    assign param_buf_full_o = _buffer_full_;
    assign param_buf_busy_o = _buffer_busy_;
    reg rd_buf_sel;
    reg wr_buf_sel;

    assign wr_buf_sel_o  = wr_buf_sel;
    always @(negedge rstn_i or posedge clk_i) begin
        if(rstn_i==1'b0) begin
            _buffer_busy_ <= 2'b00;
            _buffer_full_ <= 2'b00;
            rd_buf_sel <= 1'b0;
            wr_buf_sel <= 1'b0;
        end
        else begin
            if(ip_done_i) begin
                _buffer_busy_ <= 2'b00;
                _buffer_full_ <= 2'b00;
                rd_buf_sel <= 1'b0;
                wr_buf_sel <= 1'b0;
            end
            else begin
                if(wr_buf_done_i == 1'b1) begin
                    if(_buffer_full_[0] == 1'b0 && wr_buf_sel==1'b0) begin
                        _buffer_full_[0] <= 1'b1;
                        wr_buf_sel       <= 1'b1;
                    end
                    else if(_buffer_full_[1] == 1'b0 && wr_buf_sel==1'b1) begin
                        _buffer_full_[1] <= 1'b1;
                        wr_buf_sel       <= 1'b0;
                    end
                end
                if(rd_buf_en_i == 1'b1) begin
                    if(_buffer_full_[0]==1'b1 && rd_buf_sel==1'b0) begin
                        _buffer_busy_[0] <= 1'b1;
                    end
                    else if(_buffer_full_[1] == 1'b1 && rd_buf_sel==1'b1) begin
                        _buffer_busy_[1] <= 1'b1;
                    end
                end
                if(rd_buf_done==1'b1) begin
                    if(_buffer_busy_[0] == 1'b1) begin
                        _buffer_busy_[0] <= 1'b0;
                        _buffer_full_[0] <= 1'b0;
                    end
                    else if(_buffer_busy_[1] == 1'b1) begin
                        _buffer_busy_[1] <= 1'b0;
                        _buffer_full_[1] <= 1'b0;
                    end
                    rd_buf_sel <= rd_buf_sel + 1'b1;
                end
            end
        end
    end
endmodule
