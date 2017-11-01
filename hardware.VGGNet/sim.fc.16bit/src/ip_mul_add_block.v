`include "common.v"
//`ifdef FP16
//extern "C" void to_float16(input bit[32-1:0] Fp32, output bit[16-1:0] Fp16);
//extern "C" void to_float32(input bit[16-1:0] Fp16, output bit[32-1:0] Fp32);
//`endif
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
    input               block_en_i,
    input               switch_block_i,
    input [13-1:0]      onn_i,
    input               relu_en_i,
    input  [FW-1:0]     ip_data_i,
    input               ip_data_valid_i,
    input  [FW-1:0]     ip_weight_i,
    input               ip_weight_valid_i,
    input  [FW-1:0]     ip_bias_i,
    input               ip_bias_valid_i,
    input               ip_oneuron_done_i,
    output reg          fma_data_ready_o,
    output reg [FW-1:0] accum_data_o,
    output reg [12-1:0] accum_addr_o,
    output reg          output_valid_o,
    output reg          output_en_o
);
    localparam HFW = 16; // half float width


    wire ip_accum_data_valid;
    wire accum_data_valid;
    reg  _accum_data_valid_;
    reg  switch_block_reg_1clk;
    reg  switch_block_reg_2clk;
    reg  switch_block_reg_3clk;
    reg  switch_block_reg_4clk;
    reg  switch_block_reg_5clk;
    reg  switch_block_reg_6clk;
    reg  switch_block_reg_7clk;
    reg  switch_block_reg_8clk;

    reg  [FW-1:0] ip_data_bend;
    reg  [FW-1:0] ip_weight_bend;
    reg  [FW-1:0] ip_bias_bend;
    reg  [FW-1:0] _accum_data_;
    reg  [2-1:0]  _accum_en_;
    reg [FW-1:0] _accum_data_a_;
    reg [FW-1:0] _accum_data_b_;
    reg          _accum_data_b_valid_;
    reg [FW-1:0] _accum_data_c_;
    reg [FW-1:0] _accum_data_d_;
    wire [FW-1:0] accum_data;
    reg  [FW-1:0] _accum_data_block_;
    wire          accum_data_block_valid;
    wire [FW-1:0] accum_data_block;

    assign ip_accum_data_valid = ip_data_valid_i;

    // data is in big-endian or little-endian form?
    `ifdef FP16
    always @(ip_data_i or ip_weight_i or ip_bias_i or bend_i) begin
        if(~bend_i[0]) begin
            ip_data_bend[15:8]  = ip_data_i[7:0];
            ip_data_bend[7:0]   = ip_data_i[15:8];
        end
        else begin
            ip_data_bend   = ip_data_i;
        end

        if(~bend_i[1]) begin
            ip_weight_bend[15:8]  = ip_weight_i[7:0];
            ip_weight_bend[7:0]   = ip_weight_i[15:8];

            ip_bias_bend[15:8]  = ip_bias_i[7:0];
            ip_bias_bend[7:0]   = ip_bias_i[15:8];
        end
        else begin
            ip_weight_bend = ip_weight_i;
            ip_bias_bend   = ip_bias_i;
        end
    end
    `else
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
    `endif

    // _accum_data_ 
    // Due to float_multiply_adder with one clock letency,
    // _accum_data_ should be updated in negedge clk 
    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i || ~block_en_i) begin
            switch_block_reg_1clk <= 1'b0;
            switch_block_reg_2clk <= 1'b0;
            switch_block_reg_3clk <= 1'b0;
            switch_block_reg_4clk <= 1'b0;
        end
        else begin
            switch_block_reg_1clk <= switch_block_i;
            switch_block_reg_2clk <= switch_block_reg_1clk;
            switch_block_reg_3clk <= switch_block_reg_2clk;
            switch_block_reg_4clk <= switch_block_reg_3clk;
            switch_block_reg_5clk <= switch_block_reg_4clk;
            switch_block_reg_6clk <= switch_block_reg_5clk;
            switch_block_reg_7clk <= switch_block_reg_6clk;
            switch_block_reg_8clk <= switch_block_reg_7clk;
        end
    end

    // register for mul_add and accum is in 
    // negative edge clk_i
    wire use_fifo;
    reg  [3-1:0] wr_fifo_cnt;
    reg  [3-1:0] rd_fifo_cnt;
    reg  [2-1:0] accum_en_arr[0:3];
    assign use_fifo = (wr_fifo_cnt != rd_fifo_cnt);
    always @(negedge rstn_i or posedge clk_i) begin
        if(rstn_i==1'b0) begin
            _accum_data_block_   <= {FW{1'b0}};

            _accum_data_a_       <= {FW{1'b0}};
            _accum_data_b_       <= {FW{1'b0}};
            _accum_data_b_valid_ <= 1'b0;
            _accum_data_c_       <= {FW{1'b0}};
            _accum_data_d_       <= {FW{1'b0}};
            _accum_en_           <= 2'b00;

            wr_fifo_cnt          <= 3'd0;
        end
        else begin
            if(accum_data_valid) begin
                _accum_en_ <= _accum_en_ + 1'b1;
                if(((~ip_data_valid_i || ~ip_weight_valid_i) && accum_data_valid) || use_fifo) begin
                    wr_fifo_cnt               <= wr_fifo_cnt + 1'b1;
                    accum_en_arr[wr_fifo_cnt] <= _accum_en_;
                end
                else begin
                    wr_fifo_cnt <= 3'd0;
                end
                case(_accum_en_)
                2'b00: begin
                    _accum_data_a_       <= accum_data;
                    _accum_data_b_valid_ <= 1'b0;
                end
                2'b01: begin
                    _accum_data_b_       <= accum_data;
                    _accum_data_b_valid_ <= 1'b1;
                end
                2'b10: begin
                    _accum_data_c_       <= accum_data;
                    _accum_data_b_valid_ <= 1'b0;
                end
                2'b11: begin
                    _accum_data_d_       <= accum_data;
                    _accum_data_b_valid_ <= 1'b0;
                end
                default: begin
                    _accum_data_a_       <= accum_data;
                    _accum_data_b_valid_ <= 1'b0;
                end
                endcase
            end

            // update block float
            if(ip_bias_valid_i) begin
                _accum_data_block_ <= {FW{1'b0}};
            end
            else if(accum_data_block_valid) begin
                _accum_data_block_ <= accum_data_block;
            end
        end
    end

    reg ip_oneuron_done_delay;
    always @(negedge rstn_i or posedge clk_i) begin
        if(rstn_i==1'b0) begin
            output_valid_o        <= 1'b0;
            accum_data_o          <= {FW{1'b0}};
            accum_addr_o          <= 12'd0;
            output_en_o           <= 1'b0;
            ip_oneuron_done_delay <= 1'b0;
        end
        else begin 
            ip_oneuron_done_delay <= ip_oneuron_done_i;

            if (ip_oneuron_done_delay) begin // ip_neuron_done_i should be delay for one clock
                output_valid_o <= 1'b1;
                // accum_addr_o   <=  accum_addr_o + 1'b1;
                output_en_o    <= 1'b1;
                // only in first ip layer, block operation is enabled
                if(block_en_i)
                    accum_data_o   <= (~relu_en_i || ~_accum_data_block_[FW-1]) ? _accum_data_block_ : {FW{1'b0}};
                else
                    accum_data_o   <= (~relu_en_i || ~_accum_data_[FW-1]) ? _accum_data_ : {FW{1'b0}};
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

    //====================================
    //  multiply_addr Xilinx IP
    //====================================
    reg  [FW-1:0] _accum_data_arr_[0:3];
    reg  fma_s_axis_c_tvalid;
    reg  [FW-1:0] fma_s_axis_c_tdata;
    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i) begin
            rd_fifo_cnt <= 3'd0;
        end
        else begin
            if(use_fifo && ip_data_valid_i && ip_weight_valid_i) begin
                rd_fifo_cnt <= rd_fifo_cnt + 1'b1;
            end
            else begin
                rd_fifo_cnt <= 3'd0;
            end
        end
    end
    always @(accum_data_valid or accum_data or ip_bias_valid_i or ip_bias_bend or use_fifo or
             _accum_data_a_ or _accum_data_b_ or _accum_data_c_ or _accum_data_d_ or
             ip_data_valid_i or ip_weight_valid_i or accum_en_arr or rd_fifo_cnt) begin
        if(ip_bias_valid_i) begin
            fma_s_axis_c_tvalid <= 1'b1;
            fma_s_axis_c_tdata  <= ip_bias_valid_i;
        end
        else if(use_fifo && ip_data_valid_i && ip_weight_valid_i) begin
            fma_s_axis_c_tvalid <= 1'b1;
            case(accum_en_arr[rd_fifo_cnt])
            2'd0: begin
                fma_s_axis_c_tdata <= _accum_data_a_;
            end
            2'd1: begin
                fma_s_axis_c_tdata <= _accum_data_b_;
            end
            2'd2: begin
                fma_s_axis_c_tdata <= _accum_data_c_;
            end
            2'd3: begin
                fma_s_axis_c_tdata <= _accum_data_d_;
            end
            default: begin
                fma_s_axis_c_tdata <= {FW{1'b0}};
            end
            endcase
        end
        else if(accum_data_valid) begin
            fma_s_axis_c_tvalid <= 1'b1;
            if(switch_block_reg_1clk || switch_block_reg_2clk ||
               switch_block_reg_3clk || switch_block_reg_4clk
            ) begin
                fma_s_axis_c_tdata  <= {FW{1'b0}};
            end
            else begin
                fma_s_axis_c_tdata  <= accum_data;
            end
        end
        else if(ip_data_valid_i) begin
            fma_s_axis_c_tvalid <= 1'b1;
            fma_s_axis_c_tdata  <= {FW{1'b0}};
        end
        else begin
            fma_s_axis_c_tvalid <= 1'b0;
            fma_s_axis_c_tdata  <= {FW{1'b0}};
        end
    end
    float_multiply_adder
    float_multiply_adder_U
    (
        .aclk(clk_i), 
        .s_axis_a_tvalid      (ip_data_valid_i     ),
        .s_axis_a_tdata       (ip_data_bend        ),
        .s_axis_b_tvalid      (ip_weight_valid_i   ),
        .s_axis_b_tdata       (ip_weight_bend      ),
        .s_axis_c_tvalid      (fma_s_axis_c_tvalid ),
        .s_axis_c_tdata       (fma_s_axis_c_tdata  ),
        .m_axis_result_tvalid (accum_data_valid    ),
        .m_axis_result_tdata  (accum_data          )
    );

    //====================================
    //  accumulator Xilinx IP
    //====================================
    reg  [FW-1:0] _accum_data_a_1clk_;
    reg  _accum_data_a_valid_1clk_;

    reg  [2-1:0]  _accum_data_c_cnt_;
    reg  [FW-1:0] _accum_data_c_1clk_;
    reg  _accum_data_c_valid_1clk_;
    reg  [FW-1:0] _accum_data_c_3clk_;
    reg  _accum_data_c_valid_3clk_;

    reg  [3-1:0]  _accum_data_d_cnt_;
    reg  [FW-1:0] _accum_data_d_1clk_;
    reg  _accum_data_d_valid_1clk_;
    reg  [FW-1:0] _accum_data_d_6clk_;
    reg  _accum_data_d_valid_6clk_;

    wire fa_s_axis_a_tvalid;
    wire [FW-1:0] fa_s_axis_a_tdata;
    wire fa_s_axis_b_tvalid;
    wire [FW-1:0] fa_s_axis_b_tdata;
    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i) begin
            _accum_data_a_1clk_       <= {FW{1'b0}};
            _accum_data_a_valid_1clk_ <= 1'b0;

            _accum_data_c_cnt_        <= 2'd0;
            _accum_data_c_1clk_       <= {FW{1'b0}};
            _accum_data_c_valid_1clk_ <= 1'b0;
            _accum_data_c_3clk_       <= {FW{1'b0}};
            _accum_data_c_valid_3clk_ <= 1'b0;

            _accum_data_d_cnt_        <= 3'd0;
            _accum_data_d_1clk_       <= {FW{1'b0}};
            _accum_data_d_valid_1clk_ <= 1'b0;
            _accum_data_d_6clk_       <= {FW{1'b0}};
            _accum_data_d_valid_6clk_ <= 1'b0;
        end
        else begin
            if(switch_block_reg_5clk) begin
                _accum_data_a_1clk_       <= _accum_data_a_;
                _accum_data_a_valid_1clk_ <= 1'b1;
            end
            else begin
                _accum_data_a_1clk_       <= {FW{2'b0}};
                _accum_data_a_valid_1clk_ <= 1'b0;
            end
            if(switch_block_reg_7clk) begin
                _accum_data_c_1clk_       <= _accum_data_c_;
                _accum_data_c_valid_1clk_ <= 1'b1;
                _accum_data_c_cnt_  <= _accum_data_c_cnt_ + 1'b1;
            end
            else begin
                _accum_data_c_1clk_       <= {FW{2'b0}};
                _accum_data_c_valid_1clk_ <= 1'b0;
            end
            if(_accum_data_c_cnt_ != 2'd0) begin
                if(_accum_data_c_cnt_ != 2'd2) begin
                    _accum_data_c_cnt_ <= _accum_data_c_cnt_ + 1'b1;
                    _accum_data_c_3clk_       <= {FW{1'b0}};
                    _accum_data_c_valid_3clk_ <= 1'b0;
                end
                else begin
                    _accum_data_c_cnt_ <= 2'd0;
                    _accum_data_c_3clk_       <= _accum_data_a_1clk_;
                    _accum_data_c_valid_3clk_ <= _accum_data_a_valid_1clk_;
                end
            end
            if(switch_block_reg_8clk) begin
                _accum_data_d_1clk_       <= _accum_data_d_;
                _accum_data_d_valid_1clk_ <= 1'b1;
                _accum_data_d_cnt_  <= _accum_data_d_cnt_ + 1'b1;
            end
            else begin
                _accum_data_d_1clk_       <= {FW{2'b0}};
                _accum_data_d_valid_1clk_ <= 1'b0;
            end
            if(_accum_data_d_cnt_ != 3'd0) begin
                if(_accum_data_d_cnt_ != 3'd4) begin
                    _accum_data_d_cnt_ <= _accum_data_d_cnt_ + 1'b1;
                    _accum_data_d_6clk_       <= {FW{1'b0}};
                    _accum_data_d_valid_6clk_ <= 1'b0;
                end
                else begin
                    _accum_data_d_cnt_ <= 2'd0;
                    _accum_data_d_6clk_       <= _accum_data_d_1clk_;
                    _accum_data_d_valid_6clk_ <= _accum_data_d_valid_1clk_;
                end
            end
        end
    end
    assign fa_s_axis_a_tvalid = _accum_data_a_valid_1clk_ || _accum_data_c_valid_3clk_ || _accum_data_d_valid_6clk_;
    assign fa_s_axis_a_tdata  = (_accum_data_a_valid_1clk_ 
                                 ? _accum_data_a_1clk_ 
                                 : (_accum_data_c_valid_3clk_
                                    ? _accum_data_c_3clk_
                                    : (_accum_data_d_valid_6clk_
                                       ? _accum_data_d_6clk_ 
                                       : {FW{1'b0}}
                                      )
                                   )
                                );
    assign fa_s_axis_b_tvalid = _accum_data_b_valid_ || accum_data_block_valid; 
    assign fa_s_axis_b_tdata  = _accum_data_b_valid_ 
                                ? _accum_data_b_ 
                                : (accum_data_block_valid
                                   ? accum_data_block
                                   : {FW{1'b0}}
                                  ); 
    float_adder
    float_adder_U
    (
        .aclk(clk_i),
        .s_axis_a_tvalid     (fa_s_axis_a_tvalid     ),
        .s_axis_a_tdata      (fa_s_axis_a_tdata      ),
        .s_axis_b_tvalid     (fa_s_axis_b_tvalid     ),
        .s_axis_b_tdata      (_accum_data_block_     ),
        .m_axis_result_tvalid(accum_data_block_valid ),
        .m_axis_result_tdata (accum_data_block       )
    );
 `ifdef SIM
     assign accum_data_sim_o = _accum_data_;
 `endif   

endmodule
