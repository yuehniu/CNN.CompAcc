/*
  --inner product op controller
*/
`include "common.v"
module ip_control
#(
    parameter LAYER_NUM = 2'b10,
    parameter BATCH_NUM = 8'd64,
    parameter WL = 32
)
(
    input  clk_i,
    input  rstn_i,
    (*mark_debug="TRUE"*)input  ip_en_i,
    (*mark_debug="TRUE"*)input  exp_done_i,
    input  wr_ddr_done_i,
    (*mark_debug="TRUE"*)input  wr_buf_done_i,
    (*mark_debug="TRUE"*)input  [2-1:0] param_buf_full_i,
    output reg rd_bram_start_o,
    input  rd_bram_en_i,
    input  rd_buf_done_i,
    input  [9-1:0] ip_buf_addr_i,
    input  output_en_i,
    output reg rd_buf_en_o,
    output reg rd_ddr_en_o,
    (*mark_debug="TRUE"*)output arbitor_rd_en_o,
    (*mark_debug="TRUE"*)output [3-1:0] cur_layer_index_o,
    output reg relu_en_o,
    output reg block_en_o,
    output reg ip_oneuron_start_o,
    output reg ip_oneuron_done_o,
    output [13-1:0]onn_o,
    output reg ip_layer_done_o,
    output reg conv_buf_free_o,
    output     ip_proc_o,
    output reg ip_done_o,
    output reg img_done_o,
    output reg batch_done_o
);

    localparam IP_IDLE    = 3'd0;
    localparam LAYER_PROC = 3'd1;
    localparam ONEUR_PROC = 3'd2;
    localparam ONEUR_DONE = 3'd3;
    localparam ONEUR_WRIT = 3'd4;
    localparam LAYER_DONE = 3'd5;
    localparam IP_DONE    = 3'd6;

    (*mark_debug="TRUE"*)reg [3-1:0] _cs_;

    reg [3-1:0] cur_layer_index;
    wire        param_buf_ready;
    reg         last_ineuron_proc;
    reg         last_oneuron_proc;
    (*mark_debug="TRUE"*)reg [15-1:0] num_ineuron_proc;
    (*mark_debug="TRUE"*)reg [13-1:0] num_oneuron_proc;
    reg [15-1:0] inn; // input neuron number
    reg [13-1:0] onn; // output neuron number
    (*mark_debug="TRUE"*)reg [8-1:0]  batch_num;
    reg ip_proc;

    assign param_buf_ready = param_buf_full_i[1] || param_buf_full_i[0];
    assign ip_proc_o = ip_proc;
    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i) begin
            _cs_ <= IP_IDLE;

            rd_bram_start_o <= 1'b0;
            rd_buf_en_o     <= 1'b0;
            cur_layer_index <= 3'd0;
            ip_oneuron_start_o <= 1'b0;
            ip_oneuron_done_o  <= 1'b0;
            ip_layer_done_o    <= 1'b0;
            conv_buf_free_o    <= 1'b1;
            ip_proc            <= 1'b0;
            ip_done_o          <= 1'b0;
            batch_done_o       <= 1'b0;
            img_done_o         <= 1'b0;
            batch_num          <= 8'd0;

            num_ineuron_proc   <= 15'd0;
            num_oneuron_proc   <= 13'd0;
            last_ineuron_proc  <= 1'b0;
            last_oneuron_proc  <= 1'b0;
        end
        else begin
            case(_cs_)
            IP_IDLE: begin
                if(ip_en_i) begin
                    _cs_ <= LAYER_PROC;
                   
                   ip_proc         <= 1'b1;
                   conv_buf_free_o <= 1'b0;
                end
                else begin
                    _cs_ <= IP_IDLE;
                end
            end
            LAYER_PROC: begin
                if(param_buf_ready) begin
                    _cs_ <= ONEUR_PROC;

                    // param_buf enable signal should be ahead of 
                    // bram signal to read bias for beginning of 
                    // process output neuron
                    rd_bram_start_o    <= 1'b0;
                    rd_buf_en_o        <= 1'b1;
                    ip_oneuron_start_o <= 1'b1;
                    ip_oneuron_done_o  <= 1'b0;
                    ip_layer_done_o    <= 1'b0;
                    ip_done_o          <= 1'b0;
                    batch_done_o       <= 1'b0;
                    img_done_o         <= 1'b0;
                end
                /*
                else if(~ip_en_i) begin
                    _cs_ <= IP_IDLE;
                end
                */
                else begin
                    _cs_ <= LAYER_PROC;

                    rd_bram_start_o <= 1'b0;
                    rd_buf_en_o     <= 1'b0;
                end
            end
            ONEUR_PROC: begin 
                // last input process for output neuron,
                // make sure it will be processed with rd_buf_done_i=1
                if(last_ineuron_proc && ~rd_buf_done_i) begin
                    _cs_ <= ONEUR_DONE;

                    rd_bram_start_o   <= 1'b0;
                    rd_buf_en_o       <= 1'b0;
                    ip_oneuron_done_o <= 1'b1;
                    last_ineuron_proc <= 1'b0;
                    if(num_oneuron_proc == onn-1'b1) begin
                        num_oneuron_proc  <= 12'd0;
                        last_oneuron_proc <= 1'b1;
                    end
                    else begin
                        num_oneuron_proc  <= num_oneuron_proc + 1'b1;
                        last_oneuron_proc <= 1'b0;
                    end
                end
                else begin
                    _cs_ <= ONEUR_PROC;

                    // wait one clock to switch param buffer
                    if(rd_buf_done_i || (rd_bram_en_i && num_ineuron_proc == inn-1'b1) || 
                      ~param_buf_ready) begin
                        rd_bram_start_o <= 1'b0;
                        rd_buf_en_o     <= 1'b0;
                    end
                    else begin
                        rd_bram_start_o <= 1'b1;
                        rd_buf_en_o     <= 1'b1;
                    end
                    if (rd_bram_en_i==1'b1) begin
                        if (num_ineuron_proc == inn-1'b1) begin
                            num_ineuron_proc  <= 15'd0;
                            last_ineuron_proc <= 1'b1;
                            // ip_oneuron_done_o <= 1'b0;
                        end
                        else begin
                            num_ineuron_proc  <= num_ineuron_proc + 1'b1;
                            last_ineuron_proc <= 1'b0;
                            // ip_oneuron_done_o <= 1'b1;
                        end
                    end
                    ip_oneuron_start_o <= 1'b0;
                    ip_oneuron_done_o  <= 1'b0;
                    ip_layer_done_o    <= 1'b0;
                    ip_done_o          <= 1'b0;
                end
            end
            ONEUR_DONE: begin
                // after output data has been wrotten out, 
                // state can change
                if(output_en_i) begin
                    _cs_ <= ONEUR_WRIT;
                end
                else begin
                    _cs_ <= ONEUR_DONE;
                end
                
                num_ineuron_proc  <= 15'd0;
                last_ineuron_proc <= 1'b0;
                ip_oneuron_done_o <= 1'b0;
                ip_done_o         <= 1'b0;
            end
            ONEUR_WRIT: begin
                if(last_oneuron_proc) begin
                    _cs_ <= LAYER_DONE;

                    ip_layer_done_o <= 1'b1;
                end
                else begin 
                    if(param_buf_ready && ~rd_buf_done_i) begin
                        _cs_ <= ONEUR_PROC;

                        rd_bram_start_o    <= 1'b0;
                        rd_buf_en_o        <= 1'b1;
                        ip_oneuron_start_o <= 1'b1;
                    end
                    else begin
                        _cs_ <= ONEUR_WRIT;

                        rd_bram_start_o    <= 1'b0;
                        rd_buf_en_o        <= 1'b0;
                        ip_oneuron_start_o <= 1'b0;
                    end
                end 
            end
            LAYER_DONE: begin
                if(cur_layer_index[2:1] == LAYER_NUM) begin
                    _cs_ <= IP_DONE;

                    ip_layer_done_o <= 1'b0;
                    ip_done_o       <= 1'b1;
                end
                else begin
                    _cs_ <= LAYER_PROC;

                    ip_layer_done_o <= 1'b0;
                end

                if(cur_layer_index[2:1] == LAYER_NUM) begin
                    cur_layer_index  <= 3'd0;
                end
                else begin
                    cur_layer_index  <= cur_layer_index + 1'b1;
                end
                conv_buf_free_o <= 1'b1;
            end
            IP_DONE: begin            
                ip_proc   <= 1'b0;
                ip_done_o <= 1'b0;
                cur_layer_index <= 3'd0;
                ip_oneuron_start_o <= 1'b0;
                ip_oneuron_done_o  <= 1'b0;
                ip_layer_done_o    <= 1'b0;
                conv_buf_free_o    <= 1'b1;
                num_ineuron_proc   <= 15'd0;
                num_oneuron_proc   <= 13'd0;
                last_ineuron_proc  <= 1'b0;
                last_oneuron_proc  <= 1'b0;
                
                if(exp_done_i) begin
                    _cs_ <= IP_IDLE;
                    
                    img_done_o <= 1'b1;
                    if(batch_num != BATCH_NUM-1'b1) begin
                        batch_num    <= batch_num + 1'b1;
                        batch_done_o <= 1'b0;
                    end
                    else begin
                        batch_num    <= 8'd0;
                        batch_done_o <= 1'b1;
                    end
                end
                else begin
                    _cs_ <= IP_DONE;

                    img_done_o <= 1'b0;
                end
            end
            endcase
        end
    end
    
    assign onn_o = onn;
    assign cur_layer_index_o = cur_layer_index;
    always @(cur_layer_index)
    begin
        case(cur_layer_index)
            3'd0: begin inn = 15'd25088; onn = 13'd256;  relu_en_o = 1'b0; block_en_o = 1'b1; end
            3'd1: begin inn = 15'd256;   onn = 13'd4096; relu_en_o = 1'b1; block_en_o = 1'b0; end
            3'd2: begin inn = 15'd4096;  onn = 13'd256;  relu_en_o = 1'b0; block_en_o = 1'b0; end
            3'd3: begin inn = 15'd256;   onn = 13'd4096; relu_en_o = 1'b1; block_en_o = 1'b0; end
            3'd4: begin inn = 15'd4096;  onn = 13'd1000; relu_en_o = 1'b0; block_en_o = 1'b0; end
            default: begin inn = 15'd0;  onn = 13'd0;    relu_en_o = 1'b0; block_en_o = 1'b0; end
        endcase
    end

    // read parameter control
    (*mark_debug="TRUE"*)reg ddr_data_ready;
    reg rd_ddr_start;
    //--write done signal should be kept during all 
    //--inner product process
    always @(posedge clk_i or negedge rstn_i) begin
        if(~rstn_i) begin ddr_data_ready <= 1'b0; end
        else begin
            if(wr_ddr_done_i) begin ddr_data_ready <= 1'b1; end
        end
    end
    //--read ddr enable is not related to state _cs_
    //--so, read ddr enable signal is only controlled
    //--by param buf state

    //--arbitor_rd_en_o must be hold hight until
    //--read ddr cycle is done
    assign arbitor_rd_en_o = rd_ddr_start;
    always @(posedge clk_i or negedge rstn_i) begin
        if (~rstn_i) begin 
            rd_ddr_en_o  <= 1'b0; 
            rd_ddr_start <= 1'b0; 
        end
        else begin
            if (ip_proc) begin
                if (param_buf_full_i!=2'b11 && ddr_data_ready) 
                begin
                    if(~rd_ddr_start) begin 
                        rd_ddr_en_o  <= 1'b1; 
                        rd_ddr_start <= 1'b1; 
                    end
                    else begin 
                        rd_ddr_en_o <= 1'b0; 
                    end
                end
                else begin 
                    rd_ddr_en_o <= 1'b0; 
                end
                if(wr_buf_done_i) begin 
                    rd_ddr_start <= 1'b0; 
                end
            end
            else begin 
                rd_ddr_en_o <= 1'b0; 
                rd_ddr_start <= 1'b0; 
            end
        end
    end

endmodule
