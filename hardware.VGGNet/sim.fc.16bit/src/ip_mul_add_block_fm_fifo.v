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
    localparam FOP_IDLE = 4'd0;
    localparam FOP_BIAS_VALID = 4'd1;
    localparam FOP_OUT_NONE   = 4'd2;
    localparam FOP_ALL_VALID  = 4'd3;
    localparam FOP_OUT_VALID  = 4'd4;
    localparam FOP_ALL_NONE   = 4'd5;
    localparam FOP_FIFO_VALID = 4'd6;
    localparam FOP_SEC_DONE   = 4'd7;
    localparam FOP_SEC_WAIT   = 4'd8;

    reg [4-1:0] _cs_;

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
    reg          _last_sec_;
    reg          _output_valid_;
    reg [FW-1:0] _accum_data_block_reg_;
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

            if (_output_valid_) begin // ip_neuron_done_i should be delay for one clock
                output_valid_o <= 1'b1;
                // accum_addr_o   <=  accum_addr_o + 1'b1;
                output_en_o    <= 1'b1;
                // only in first ip layer, block operation is enabled
                if(block_en_i)
                    accum_data_o   <= (~relu_en_i || ~_accum_data_block_reg_[FW-1]) ? _accum_data_block_reg_ : {FW{1'b0}};
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
    //  float operation control
    //====================================
    reg fma_s_axis_a_tvalid;
    reg [FW-1:0] fma_s_axis_a_tdata;
    reg fma_s_axis_b_tvalid;
    reg [FW-1:0] fma_s_axis_b_tdata;
    reg fma_s_axis_c_tvalid;
    reg [FW-1:0] fma_s_axis_c_tdata;
    reg [FW-1:0] ip_bias_reg;

    reg fa_s_axis_a_tvalid;
    reg [FW-1:0] fa_s_axis_a_tdata;
    reg fa_s_axis_b_tvalid;
    reg [FW-1:0] fa_s_axis_b_tdata;
    reg _accum_data_block_empty_;

    reg [3-1:0]  _wr_fifo_loc_;
    reg [3-1:0]  _rd_fifo_loc_;
    reg          fifo_empty;
    reg [FW-1:0] _accum_data_a_;
    reg [FW-1:0] _accum_data_b_;
    reg [FW-1:0] _accum_data_c_;
    reg [FW-1:0] _accum_data_d_;
    reg [FW-1:0] _accum_data_e_;

    reg [3-1:0]  _wr_sec_loc_;
    reg [3-1:0]  _rd_sec_loc_;
    reg [FW-1:0] _sec_data_a_;
    reg [FW-1:0] _sec_data_b_;
    reg [FW-1:0] _sec_data_c_;
    reg [FW-1:0] _sec_data_d_;
    reg [FW-1:0] _sec_data_e_;

    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i) begin
            _cs_ <= FOP_IDLE;

            fma_s_axis_a_tvalid <= 1'b0;
            fma_s_axis_a_tdata  <= {FW{1'b0}};
            fma_s_axis_b_tvalid <= 1'b0;
            fma_s_axis_b_tdata  <= {FW{1'b0}};
            fma_s_axis_c_tvalid <= 1'b0;
            fma_s_axis_c_tdata  <= {FW{1'b0}};
            ip_bias_reg         <= {FW{1'b0}};

            _accum_data_block_empty_ <= 1'b1;

            _wr_fifo_loc_    <= 3'd0;
            _rd_fifo_loc_    <= 3'd0;
            _accum_data_a_      <= {FW{1'b0}};
            _accum_data_b_      <= {FW{1'b0}};
            _accum_data_c_      <= {FW{1'b0}};
            _accum_data_d_      <= {FW{1'b0}};
            _accum_data_e_      <= {FW{1'b0}};

            _wr_sec_loc_        <= 3'd0;
            _rd_sec_loc_        <= 3'd0;
            _sec_data_a_        <= {FW{1'b0}};
            _sec_data_b_        <= {FW{1'b0}};
            _sec_data_c_        <= {FW{1'b0}};
            _sec_data_d_        <= {FW{1'b0}};
            _sec_data_e_        <= {FW{1'b0}};

            _last_sec_          <= 1'b0;
            _output_valid_      <= 1'b0;
        end
        else begin
            case(_cs_)
            FOP_IDLE: begin
                if(ip_bias_valid_i) begin
                    _cs_ <= FOP_BIAS_VALID;

                    ip_bias_reg <= ip_bias_bend;
                end
                else begin
                    _cs_ <= FOP_IDLE;
                end
            end
            FOP_BIAS_VALID: begin
                _cs_ <= FOP_OUT_NONE;

                fma_s_axis_a_tvalid <= ip_data_valid_i;
                fma_s_axis_a_tdata  <= ip_data_bend;
                fma_s_axis_b_tvalid <= ip_weight_valid_i;
                fma_s_axis_b_tdata  <= ip_weight_bend;
                fma_s_axis_c_tvalid <= 1'b1;
                fma_s_axis_c_tdata  <= ip_bias_reg;
            end
            FOP_OUT_NONE: begin
                if(accum_data_valid && ip_weight_valid_i && ip_data_valid_i) begin
                    _cs_ <= FOP_ALL_VALID;

                    fma_s_axis_a_tvalid <= ip_data_valid_i;
                    fma_s_axis_a_tdata  <= ip_data_bend;
                    fma_s_axis_b_tvalid <= ip_weight_valid_i;
                    fma_s_axis_b_tdata  <= ip_weight_bend;
                    fma_s_axis_c_tvalid <= accum_data_valid;
                    fma_s_axis_c_tdata  <= accum_data;
                end
                else begin
                    _cs_ <= FOP_OUT_NONE;

                    fma_s_axis_a_tvalid <= ip_data_valid_i;
                    fma_s_axis_a_tdata  <= ip_data_bend;
                    fma_s_axis_b_tvalid <= ip_weight_valid_i;
                    fma_s_axis_b_tdata  <= ip_weight_bend;
                    fma_s_axis_c_tvalid <= 1'b1;
                    fma_s_axis_c_tdata  <= {FW{1'b0}};
                end
            end
            FOP_ALL_VALID: begin
                if(accum_data_valid && (~ip_weight_valid_i || ~ip_data_valid_i)) begin
                    _cs_ <= FOP_OUT_VALID;

                    fma_s_axis_a_tvalid <= 1'b0;
                    fma_s_axis_b_tvalid <= 1'b0;
                    fma_s_axis_c_tvalid <= 1'b0;

                    _accum_data_a_      <= accum_data;
                    _wr_fifo_loc_       <= _wr_fifo_loc_ + 1'b1;
                end
                else begin
                    _cs_ <= FOP_ALL_VALID;

                    fma_s_axis_a_tvalid <= ip_data_valid_i;
                    fma_s_axis_a_tdata  <= ip_data_bend;
                    fma_s_axis_b_tvalid <= ip_weight_valid_i;
                    fma_s_axis_b_tdata  <= ip_weight_bend;
                    fma_s_axis_c_tvalid <= accum_data_valid;
                    fma_s_axis_c_tdata  <= accum_data;
                end
            end
            FOP_OUT_VALID: begin
                if(ip_data_valid_i && ip_weight_valid_i) begin
                    if(~switch_block_reg_2clk) begin
                        _cs_ <= FOP_FIFO_VALID;

                        fma_s_axis_a_tvalid <= ip_data_valid_i;
                        fma_s_axis_a_tdata  <= ip_data_bend;
                        fma_s_axis_b_tvalid <= ip_weight_valid_i;
                        fma_s_axis_b_tdata  <= ip_weight_bend;
                        fma_s_axis_c_tvalid <= 1'b1;
                        fma_s_axis_c_tdata  <= _accum_data_a_;
                        _rd_fifo_loc_       <= _rd_fifo_loc_ + 1'b1;

                        _wr_fifo_loc_       <= _wr_fifo_loc_ + 1'b1;
                        case(_wr_fifo_loc_)
                        3'd0: begin _accum_data_a_      <= accum_data; end
                        3'd1: begin _accum_data_b_      <= accum_data; end
                        3'd2: begin _accum_data_c_      <= accum_data; end
                        3'd3: begin _accum_data_d_      <= accum_data; end
                        3'd4: begin _accum_data_e_      <= accum_data; end
                        default: begin _accum_data_a_      <= accum_data; end
                        endcase
                    end
                else if(accum_data_valid) begin
                    _cs_ <= FOP_OUT_VALID;
                    
                    fma_s_axis_a_tvalid <= 1'b0;
                    fma_s_axis_b_tvalid <= 1'b0;
                    fma_s_axis_c_tvalid <= 1'b0;

                    _wr_fifo_loc_       <= _wr_fifo_loc_ + 1'b1;
                    case(_wr_fifo_loc_)
                    3'd0: begin  _accum_data_a_     <= accum_data; end
                    3'd1: begin _accum_data_b_      <= accum_data; end
                    3'd2: begin _accum_data_c_      <= accum_data; end
                    3'd3: begin _accum_data_d_      <= accum_data; end
                    3'd4: begin _accum_data_e_      <= accum_data; end
                    default: begin _accum_data_a_      <= accum_data; end
                    endcase
                end
                else begin
                    _cs_ <= FOP_ALL_NONE;

                    fma_s_axis_a_tvalid <= 1'b0;
                    fma_s_axis_a_tdata  <= {FW{1'b0}};
                    fma_s_axis_b_tvalid <= 1'b0;
                    fma_s_axis_b_tdata  <= {FW{1'b0}};
                    fma_s_axis_c_tvalid <= 1'b0;
                    fma_s_axis_c_tdata  <= {FW{1'b0}};
                end
            end
            FOP_ALL_NONE: begin
                if(ip_data_valid_i && ip_weight_valid_i) begin
                    _cs_ <= FOP_FIFO_VALID;

                    fma_s_axis_a_tvalid <= ip_data_valid_i;
                    fma_s_axis_a_tdata  <= ip_data_bend;
                    fma_s_axis_b_tvalid <= ip_weight_valid_i;
                    fma_s_axis_b_tdata  <= ip_weight_bend;
                    fma_s_axis_c_tvalid <= 1'b1;
                    fma_s_axis_c_tdata  <= _accum_data_a_;
                    _rd_fifo_loc_       <= _rd_fifo_loc_ + 1'b1;
                end
                else begin
                    _cs_ <= FOP_ALL_NONE;

                    fma_s_axis_a_tvalid <= 1'b0;
                    fma_s_axis_a_tdata  <= {FW{1'b0}};
                    fma_s_axis_b_tvalid <= 1'b0;
                    fma_s_axis_b_tdata  <= {FW{1'b0}};
                    fma_s_axis_c_tvalid <= 1'b0;
                    fma_s_axis_c_tdata  <= {FW{1'b0}};
                end
            end
            FOP_FIFO_VALID: begin
                if(switch_block_reg_2clk) begin
                    _cs_ <= FOP_SEC_DONE;

                    if(accum_data_valid) begin
                        _wr_sec_loc_ <= _wr_sec_loc_ + 1'b1;
                        _sec_data_a_ <= accum_data;
                    end
                end
                else if(~switch_block_reg_2clk && (_rd_fifo_loc_!=3'd5) && ip_data_valid_i && ip_weight_valid_i) begin
                    _cs_ <= FOP_FIFO_VALID;

                    fma_s_axis_a_tvalid <= ip_data_valid_i;
                    fma_s_axis_a_tdata  <= ip_data_bend;
                    fma_s_axis_b_tvalid <= ip_weight_valid_i;
                    fma_s_axis_b_tdata  <= ip_weight_bend;

                    fma_s_axis_c_tvalid <= 1'b1;
                    _rd_fifo_loc_ <= _rd_fifo_loc_ + 1'b1;
                    case(_rd_fifo_loc_)
                    3'd0: begin fma_s_axis_c_tdata  <= _accum_data_a_; end
                    3'd1: begin fma_s_axis_c_tdata  <= _accum_data_b_; end
                    3'd2: begin fma_s_axis_c_tdata  <= _accum_data_c_; end
                    3'd3: begin fma_s_axis_c_tdata  <= _accum_data_d_; end
                    3'd4: begin fma_s_axis_c_tdata  <= _accum_data_e_; end
                    default: begin fma_s_axis_c_tdata  <= _accum_data_a_; end
                    endcase

                    if(accum_data_valid) begin
                        _wr_fifo_loc_       <= _wr_fifo_loc_ + 1'b1;
                        case(_wr_fifo_loc_)
                        3'd0: begin _accum_data_a_      <= accum_data; end
                        3'd1: begin _accum_data_b_      <= accum_data; end
                        3'd2: begin _accum_data_c_      <= accum_data; end
                        3'd3: begin _accum_data_d_      <= accum_data; end
                        3'd4: begin _accum_data_e_      <= accum_data; end
                        default: begin _accum_data_a_      <= accum_data; end
                        endcase
                    end
                end
                if((_rd_fifo_loc_==3'd5) && ip_data_valid_i && ip_weight_valid_i) begin
                    _cs_ <= FOP_ALL_VALID;

                    _rd_fifo_loc_ <= 3'd0;
                    _wr_fifo_loc_ <= 3'd0;
                    
                    fma_s_axis_a_tvalid <= ip_data_valid_i;
                    fma_s_axis_a_tdata  <= ip_data_bend;
                    fma_s_axis_b_tvalid <= ip_weight_valid_i;
                    fma_s_axis_b_tdata  <= ip_weight_bend;
                    fma_s_axis_c_tvalid <= accum_data_valid;
                    fma_s_axis_c_tdata  <= accum_data;
                end
                else begin
                    _cs_ <= FOP_FIFO_VALID;

                end
            end
            FOP_SEC_DONE: begin
                if(ip_oneuron_done_delay) begin
                    _last_sec_ <= 1'b1;
                end
                if(_last_sec_ && accum_data_block_valid && (_rd_fifo_loc_==3'd5)) begin
                    _cs_ <= FOP_SEC_WAIT;
                    _output_valid_ <= 1'b1; 
                    _last_sec_ <= 1'b0;
                end
                else begin
                    _output_valid_ <= 1'b0;
                    if((_rd_fifo_loc_==3'd5) && ip_data_valid_i && ip_weight_valid_i) begin
                        _cs_ <= FOP_ALL_VALID;

                        fma_s_axis_a_tvalid <= ip_data_valid_i;
                        fma_s_axis_a_tdata  <= ip_data_bend;
                        fma_s_axis_b_tvalid <= ip_weight_valid_i;
                        fma_s_axis_b_tdata  <= ip_weight_bend;
                        fma_s_axis_c_tvalid <= accum_data_valid;
                        fma_s_axis_c_tdata  <= accum_data;

                        fa_s_axis_a_tvalid  <= 1'b0;
                        fa_s_axis_b_tvalid  <= 1'b0;

                        _rd_fifo_loc_ <= 3'd0;
                        _wr_fifo_loc_ <= 3'd0;
                        _accum_data_block_empty_ <= 1'b0;
                    end
                    else begin
                        _cs_ <= FOP_SEC_DONE;

                        if(_wr_fifo_loc_ != 3'd5 || ~accum_data_valid) begin
                                fma_s_axis_a_tvalid <= ip_data_valid_i;
                                fma_s_axis_a_tdata  <= ip_data_bend;
                                fma_s_axis_b_tvalid <= ip_weight_valid_i;
                                fma_s_axis_b_tdata  <= ip_weight_bend;
                                fma_s_axis_c_tvalid <= 1'b1;
                                fma_s_axis_c_tdata  <= {FW{1'b0}};
                        end
                        else begin
                                fma_s_axis_a_tvalid <= ip_data_valid_i;
                                fma_s_axis_a_tdata  <= ip_data_bend;
                                fma_s_axis_b_tvalid <= ip_weight_valid_i;
                                fma_s_axis_b_tdata  <= ip_weight_bend;
                                fma_s_axis_c_tvalid <= accum_data_valid;
                                fma_s_axis_c_tdata  <= accum_data;
                        end
                        if(_rd_fifo_loc_==3'd0) begin
                            fa_s_axis_a_tvalid <= 1'b1;
                            fa_s_axis_a_tdata  <= _accum_data_block_empty_ ? _accum_data_a_ : _accum_data_block_reg_;
                            fa_s_axis_b_tvalid <= 1'b1;
                            fa_s_axis_b_tdata  <= _accum_data_block_empty_ ? _accum_data_b_ : _accum_data_a_;

                            if(_accum_data_block_empty_)
                                _rd_fifo_loc_ <= 3'd2;
                            else 
                                _rd_fifo_loc_ <= 3'd1;
                        end
                        else if(accum_data_block_valid) begin
                            if(_rd_fifo_loc_!=3'd5) begin
                                _rd_fifo_loc_ <= _rd_fifo_loc_ + 1'b1;
                                fa_s_axis_a_tvalid <= 1'b1;
                                case(_rd_fifo_loc_)
                                3'd1: begin 
                                    if(~_accum_data_block_empty_) begin fa_s_axis_a_tdata <= _accum_data_b_; end
                                end
                                3'd2: begin fa_s_axis_a_tdata  <= _accum_data_c_; end
                                3'd3: begin fa_s_axis_a_tdata  <= _accum_data_d_; end
                                3'd4: begin fa_s_axis_a_tdata  <= _accum_data_e_; end
                                default: begin fa_s_axis_a_tdata <= {FW{1'b0}}; end
                                endcase
                                fa_s_axis_b_tvalid <= accum_data_block_valid;
                                fa_s_axis_b_tdata  <= accum_data_block;
                            end
                            else begin
                                fa_s_axis_a_tvalid <= 1'b0;
                                fa_s_axis_b_tvalid <= 1'b0;
                            end
                        end
                        else begin
                            fa_s_axis_a_tvalid <= 1'b0;
                            fa_s_axis_b_tvalid <= 1'b0;
                        end

                        if(accum_data_valid) begin
                            if(_wr_fifo_loc_ != 3'd5) begin
                                _wr_fifo_loc_       <= _wr_fifo_loc_ + 1'b1;
                                case(_wr_fifo_loc_)
                                3'd0: begin _accum_data_a_      <= accum_data; end
                                3'd1: begin _accum_data_b_      <= accum_data; end
                                3'd2: begin _accum_data_c_      <= accum_data; end
                                3'd3: begin _accum_data_d_      <= accum_data; end
                                3'd4: begin _accum_data_e_      <= accum_data; end
                                default: begin _accum_data_a_      <= accum_data; end
                                endcase
                            end
                        end
                    end
                end
            end
            FOP_SEC_WAIT: begin
                if(ip_bias_valid_i) begin
                    _cs_ <= FOP_BIAS_VALID;

                    ip_bias_reg <= ip_bias_bend;
                end
                else begin
                    _cs_ <= FOP_IDLE;

                    fma_s_axis_a_tvalid <= 1'b0;
                    fma_s_axis_a_tdata  <= {FW{1'b0}};
                    fma_s_axis_b_tvalid <= 1'b0;
                    fma_s_axis_b_tdata  <= {FW{1'b0}};
                    fma_s_axis_c_tvalid <= 1'b0;
                    fma_s_axis_c_tdata  <= {FW{1'b0}};
                    ip_bias_reg         <= {FW{1'b0}};

                    fa_s_axis_a_tvalid  <= 1'b0;
                    fa_s_axis_a_tdata   <= {FW{1'b0}};
                    fa_s_axis_b_tvalid  <= 1'b0;
                    fa_s_axis_b_tdata   <= {FW{1'b0}};
                    _accum_data_block_empty_ <= 1'b1;

                    _wr_fifo_loc_       <= 3'd0;
                    _rd_fifo_loc_       <= 3'd0;
                    _accum_data_a_      <= {FW{1'b0}};
                    _accum_data_b_      <= {FW{1'b0}};
                    _accum_data_c_      <= {FW{1'b0}};
                    _accum_data_d_      <= {FW{1'b0}};
                    _accum_data_e_      <= {FW{1'b0}};

                    _last_sec_          <= 1'b0;
                    _output_valid_      <= 1'b0;
                end
            end
            endcase
        end
    end

    always @(negedge rstn_i or posedge clk_i) begin
        if(~rstn_i) begin
            _accum_data_block_reg_ <= {FW{1'b0}};
        end
        else begin
            if(accum_data_block_valid) begin
                _accum_data_block_reg_ <= accum_data_block;
            end
        end
    end

    //====================================
    //  multiply_addr Xilinx IP
    //====================================
    float_multiply_adder
    float_multiply_adder_U
    (
        .aclk(clk_i), 
        .s_axis_a_tvalid      (fma_s_axis_a_tvalid ),
        .s_axis_a_tdata       (fma_s_axis_a_tdata  ),
        .s_axis_b_tvalid      (fma_s_axis_b_tvalid ),
        .s_axis_b_tdata       (fma_s_axis_b_tdata  ),
        .s_axis_c_tvalid      (fma_s_axis_c_tvalid ),
        .s_axis_c_tdata       (fma_s_axis_c_tdata  ),
        .m_axis_result_tvalid (accum_data_valid    ),
        .m_axis_result_tdata  (accum_data          )
    );

    //====================================
    //  accumulator Xilinx IP
    //====================================
    float_adder
    float_adder_U
    (
        .aclk(clk_i),
        .s_axis_a_tvalid     (fa_s_axis_a_tvalid     ),
        .s_axis_a_tdata      (fa_s_axis_a_tdata      ),
        .s_axis_b_tvalid     (fa_s_axis_b_tvalid     ),
        .s_axis_b_tdata      (fa_s_axis_b_tdata      ),
        .m_axis_result_tvalid(accum_data_block_valid ),
        .m_axis_result_tdata (accum_data_block       )
    );
 `ifdef SIM
     assign accum_data_sim_o = _accum_data_;
 `endif   

endmodule
