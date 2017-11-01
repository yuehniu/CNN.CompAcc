// inner product layer controller
// ip_control just output enable signal,
// no other data/addr signal
`include "common.v"
module ip_control
#(
    parameter LAYER_NUM = 3,
    parameter WL = 288
)
(
    input  clk_i,
    input  rstn_i,
    input  ip_en_i,
    input  wr_ddr_done_i,
    input  init_calib_complete_i,
    input          wr_buf_done_i,
    input  [2-1:0] param_buf_full_i,
    output reg     rd_bram_start_o,
    input          rd_bram_en_i,
    input          rd_buf_done_i,
    input  [9-1:0] ip_buf_addr_i,
    input          output_en_i,
    output reg     rd_buf_en_o,
    output reg     rd_ddr_en_o,
    output [3-1:0] cur_layer_index_o,
    output reg     relu_en_o,
    output reg     block_en_o,
    output         ip_oneuron_start_o,
    output         ip_oneuron_done_o,
    output [13-1:0]onn_o,
    output reg     ip_layer_done_o,
    output reg     ip_done_o
);

// layer transition
reg [3-1:0] cur_layer_index; // contains sub layer
assign cur_layer_index_o = cur_layer_index;
always @(negedge rstn_i or posedge clk_i) begin
    if(rstn_i==1'b0) begin
        cur_layer_index <= 3'd0;
        ip_done_o <= 1'b0;
    end
    else begin
        if (ip_layer_done_o==1'b1) begin
            if(cur_layer_index[2:1]==LAYER_NUM) begin
                cur_layer_index <= 2'd0;

                ip_done_o <= 1'b1;               
            end
            else begin
                cur_layer_index <= cur_layer_index + 1'b1;

                ip_done_o <= 1'b0;
            end
        end
    end
    
end
reg [15-1:0] inn; // input neuron number
reg [13-1:0] onn; // output neuron number
assign onn_o = onn;
always @(cur_layer_index)
begin
    case(cur_layer_index)
        3'd0: begin inn = 15'd25088; onn = 13'd256;  relu_en_o = 1'b0; block_en_o <= 1'b1; end
        3'd1: begin inn = 15'd256;   onn = 13'd4096; relu_en_o = 1'b1; block_en_o <= 1'b0; end
        3'd2: begin inn = 15'd4096;  onn = 13'd256;  relu_en_o = 1'b0; block_en_o <= 1'b0; end
        3'd3: begin inn = 15'd256;   onn = 13'd4096; relu_en_o = 1'b1; block_en_o <= 1'b0; end
        3'd4: begin inn = 15'd4096;  onn = 13'd1000; relu_en_o = 1'b0; block_en_o <= 1'b0; end
        default: begin inn = 15'd0;  onn = 13'd0;    relu_en_o = 1'b0; block_en_o <= 1'b0; end
    endcase
end
// read input neurons control
reg [15-1:0] num_ineuron_proc;
reg [13-1:0] num_oneuron_proc;
reg last_oneuron_proc;
reg ip_oneuron_done_delay;
wire param_buf_ready;
wire last_ineuron_proc;
wire ip_first_neuron_start;

assign param_buf_ready = param_buf_full_i[1] || param_buf_full_i[0];
always @(posedge clk_i or negedge rstn_i) begin
    if (~rstn_i or ~init_calib_complete_i) begin
        // reset
        rd_bram_start_o   <= 1'b0;
        num_ineuron_proc  <= 15'd0;
        num_oneuron_proc  <= 12'd0;
        // ip_oneuron_done_o <= 1'b0;
    end
    else if (ip_en_i && param_buf_ready && ~rd_buf_done_i && ~last_ineuron_proc && ~ip_oneuron_done_o && ~ip_layer_done_o) begin
        rd_bram_start_o <= 1'b1;
        rd_buf_en_o  <= 1'b1;
    end
    else begin
        rd_bram_start_o <= 1'b0;
        rd_buf_en_o  <= 1'b0;
    end
    if (rd_bram_en_i==1'b1) begin
        if (num_ineuron_proc != inn) begin
            num_ineuron_proc  <= num_ineuron_proc + 1'b1;
            // ip_oneuron_done_o <= 1'b0;
        end
        else begin
            num_ineuron_proc  <= 15'd0;

            // ip_oneuron_done_o <= 1'b1;
        end
    end
    else begin
        if(num_ineuron_proc == inn) begin
            num_ineuron_proc <= 15'd0;
        end
    end

    if(ip_oneuron_done_o) begin
        if(num_oneuron_proc == onn-1'b1) begin
            num_oneuron_proc  <= 12'd0;
            last_oneuron_proc <= 1'b1;
        end
        else begin
            num_oneuron_proc  <= num_oneuron_proc + 1'b1;
            last_oneuron_proc <= 1'b0;
        end
    end
    else if(num_oneuron_proc != onn - 1'b1 ) begin
        last_oneuron_proc <= 1'b0;
    end
end

// read parameter control
reg rd_ddr_start;
always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i==1'b0) begin
        // reset
        rd_ddr_en_o  <= 1'b0;
        rd_ddr_start <= 1'b0;
    end
    else if (ip_en_i==1'b1) begin
        if (param_buf_full_i!=2'b11 && wr_ddr_done_i) begin
            if(rd_ddr_start == 1'b0) begin
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
        if(wr_buf_done_i==1'b1) begin
            rd_ddr_start <= 1'b0;
        end
    end
    else begin
        rd_ddr_en_o <= 1'b0;
        rd_ddr_start <= 1'b0;
    end
end

// start after 1 clock-> ip_oneuron_done
always @(negedge rstn_i or posedge clk_i) begin
    if(~rstn_i) begin
        ip_oneuron_done_delay <= 1'b0;

        ip_layer_done_o       <= 1'b0;
    end
    else begin
        ip_oneuron_done_delay <= ip_oneuron_done_o;

        ip_layer_done_o       <= last_oneuron_proc;
    end
end
assign ip_oneuron_done_o = num_ineuron_proc == inn;
assign last_ineuron_proc = num_ineuron_proc == (inn-1'b1) && rd_bram_en_i;
// assign ip_oneuron_start_o = (num_ineuron_proc == 15'd0 && rd_buf_en_o && (ip_buf_addr_i == 9'd288)) || ip_oneuron_done_delay;
assign ip_first_neuron_start = (num_ineuron_proc==15'd0) && 
                               (num_oneuron_proc == 13'd0) && 
                               (ip_buf_addr_i==WL) && 
                               (cur_layer_index==3'd0) && 
                               rd_buf_en_o;
assign ip_oneuron_start_o = ip_first_neuron_start || output_en_i;

endmodule
