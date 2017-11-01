`define FP16

`ifdef FP16
extern "C" void to_float16(input bit[32-1:0] Fp32, output bit[16-1:0] Fp16);
extern "C" void to_float32(input bit[16-1:0] Fp16, output bit[32-1:0] Fp32);
`endif

`include "common.v"
module ip_mul_add
#(
    parameter EW = 8,
    parameter MW = 23,
    parameter FW = 32
)
(
    input  clk_i,
    input  rstn_i,
`ifdef SIM
    output [FW-1:0]     accum_data_sim_o,
`endif
    input [2-1:0]       bend_i,
    input [13-1:0]      onn_i,
    input               relu_en_i,
    input  [FW-1:0]     ip_data_i,
    input               ip_data_valid_i,
    input  [FW-1:0]     ip_weight_i,
    input               ip_weight_valid_i,
    input  [FW-1:0]     ip_bias_i,
    input               ip_bias_valid_i,
    input               ip_oneuron_done_i,
    output reg [FW-1:0] accum_data_o,
    output reg [12-1:0] accum_addr_o,
    output reg          output_valid_o,
    output reg          output_en_o
);
    localparam HFW = 16; // half float width

    reg [FW-1:0] ip_data_bend;
    reg [FW-1:0] ip_weight_bend;
    reg [FW-1:0] ip_bias_bend;

    reg [FW-1:0] _accum_data_;
    wire ip_accum_data_valid;
    wire [FW-1:0] accum_data;
    wire          accum_data_valid;

`ifdef FP16
    reg [HFW-1:0] ip_data_bend16;
    reg [HFW-1:0] ip_weight_bend16;
    reg [HFW-1:0] ip_bias_bend16;
    reg [HFW-1:0] _accum_data16_;
    wire [HFW-1:0] accum_data16;
`endif

    assign ip_accum_data_valid = ip_data_valid_i;

    // data is in big-endian or little-endian form?
    always @(ip_data_i or ip_weight_i or ip_bias_i or bend_i) begin
        if(~bend_i[0]) begin
            ip_data_bend[31:24] = ip_data_i[7:0];
            ip_data_bend[23:16] = ip_data_i[15:8];
            ip_data_bend[15:8]  = ip_data_i[23:16];
            ip_data_bend[7:0]   = ip_data_i[31:24];
        end
        else begin
            ip_data_bend   = ip_data_i;
        end

        if(~bend_i[1]) begin
            ip_weight_bend[31:24] = ip_weight_i[7:0];
            ip_weight_bend[23:16] = ip_weight_i[15:8];
            ip_weight_bend[15:8]  = ip_weight_i[23:16];
            ip_weight_bend[7:0]   = ip_weight_i[31:24];

            ip_bias_bend[31:24] = ip_bias_i[7:0];
            ip_bias_bend[23:16] = ip_bias_i[15:8];
            ip_bias_bend[15:8]  = ip_bias_i[23:16];
            ip_bias_bend[7:0]   = ip_bias_i[31:24];
        end
        else begin
            ip_weight_bend = ip_weight_i;
            ip_bias_bend   = ip_bias_i;
        end
    end

`ifdef FP16
    always @(ip_data_bend or ip_weight_bend or ip_bias_bend) begin
       to_float16(ip_data_bend, ip_data_bend16); 
       to_float16(ip_weight_bend, ip_weight_bend16); 
       to_float16(ip_bias_bend, ip_bias_bend16); 
    end
    always @(_accum_data16_) begin
      to_float32(_accum_data16_, _accum_data_);
    end
`endif

    // _accum_data_ 
    // Due to float_multiply_adder with one clock letency,
    // _accum_data_ should be updated in negedge clk 
    always @(negedge rstn_i or negedge clk_i) begin
`ifdef FP16
        if(rstn_i==1'b0) begin
            _accum_data16_ <= {HFW{1'b0}};
        end
        if(ip_bias_valid_i==1'b1) begin
            _accum_data16_ <= ip_bias_bend16;
        end
        else if(accum_data_valid==1'b1) begin
            _accum_data16_ <= accum_data16;
        end
`else
        if(rstn_i==1'b0) begin
            _accum_data_ <= {FW{1'b0}};
        end
        if(ip_bias_valid_i==1'b1) begin
            _accum_data_   <= ip_bias_bend;
        end
        else if(accum_data_valid==1'b1) begin
            _accum_data_   <= accum_data;
        end
`endif 
    end

    reg ip_oneuron_done_delay;
    always @(negedge rstn_i or posedge clk_i) begin
        if(rstn_i==1'b0) begin
            output_valid_o       <= 1'b0;
            accum_data_o         <= {FW{1'b0}};
            accum_addr_o         <= 12'd0;
            output_en_o          <= 1'b0;
            ip_oneuron_done_delay <= 1'b0;
        end
        else begin 
            ip_oneuron_done_delay <= ip_oneuron_done_i;

            if (ip_oneuron_done_delay) begin // ip_neuron_done_i should be delay for one clock
                output_valid_o <= 1'b1;
                accum_data_o   <= (~relu_en_i || ~_accum_data_[FW-1]) ? _accum_data_ : {FW{1'b0}};
                // accum_addr_o   <=  accum_addr_o + 1'b1;
                output_en_o    <= 1'b1;
            end
            else begin
                output_valid_o <= 1'b0;
                accum_data_o   <= {FW{1'b0}};
                output_en_o    <= 1'b0;
            end

            if(output_valid_o) begin
                if(accum_addr_o != onn_i - 1'b1)
                    accum_addr_o   <= accum_addr_o + 1'b1;
                else
                    accum_addr_o   <= 12'd0;
            end
        end 
    end

    // doing fused add with one clock letency
    // Xilinx float ip
`ifdef FP16
    float_multiply_adder
    float_multiply_adder_U
    (
        .aclk(clk_i), 
        .s_axis_a_tvalid      (ip_data_valid_i    ),
        .s_axis_a_tdata       (ip_data_bend16     ),
        .s_axis_b_tvalid      (ip_weight_valid_i  ),
        .s_axis_b_tdata       (ip_weight_bend16   ),
        .s_axis_c_tvalid      (ip_accum_data_valid),
        .s_axis_c_tdata       (_accum_data16_     ),
        .m_axis_result_tvalid (accum_data_valid   ),
        .m_axis_result_tdata  (accum_data16       )
    );
`else
    float_multiply_adder
    float_multiply_adder_U
    (
        .aclk(clk_i), 
        .s_axis_a_tvalid      (ip_data_valid_i    ),
        .s_axis_a_tdata       (ip_data_bend       ),
        .s_axis_b_tvalid      (ip_weight_valid_i  ),
        .s_axis_b_tdata       (ip_weight_bend     ),
        .s_axis_c_tvalid      (ip_accum_data_valid),
        .s_axis_c_tdata       (_accum_data_       ),
        .m_axis_result_tvalid (accum_data_valid   ),
        .m_axis_result_tdata  (accum_data         )
    );
`endif
 
 `ifdef SIM
     assign accum_data_sim_o = _accum_data_;
 `endif   

endmodule
