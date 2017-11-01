// ---------------------------------------------------
// File       : rd_ddr_patch.v
//
// Description: read data(right most patch of size 15x8) from bram
//
// Version    : 1.0
// ---------------------------------------------------

module rd_bram_patch(
    input wire          clk,
    input wire          rst_n,
    //
    input wire          rd_data_bottom,   // rd bottom data enable
    input wire [12: 0]  rd_data_bram_patch_ith_offset, // bram addr offset of ith bottom feature map,
                                                       // stable till last valid output
                                                       // ith*RD_BRAM_PATCH_NUM
    // bram control
    output reg          rd_data_bram_patch_enb,   // enable port b
    output reg          rd_data_bram_patch_valid, // data on port b is valid
    output wire         rd_data_bram_patch_last,  // last valid data
    output reg [12: 0]  rd_data_bram_patch_addrb  // read address
  );

  localparam RD_BRAM_PATCH_RST  = 1'b0;
  localparam RD_BRAM_PATCH_RD   = 1'b1;
  localparam RD_BRAM_PATCH_NUM  = 4'h8;
  // simulation
//reg           rd_data_bram_patch_enb;
//reg  [12: 0]  rd_data_bram_patch_addrb;
//reg           rd_data_bram_patch_valid;

  reg           _rd_data_bram_patch_state;
  reg           _rd_data_bram_patch_next_state;
  reg  [3:0]    _rd_data_bram_patch_cnt;      // num of datum read
  wire          _rd_data_bram_patch_new_tran; // new transaction
  reg  [12: 0]  _rd_data_bram_patch_ith_offset_rec; // record last transaction addr offset
  // last valid data
  assign rd_data_bram_patch_last = (_rd_data_bram_patch_cnt == RD_BRAM_PATCH_NUM);
  // check if it is a new transaction
  //assign _rd_data_bram_patch_new_tran = (_rd_data_bram_patch_ith_offset_rec != rd_data_bram_patch_ith_offset);
  assign _rd_data_bram_patch_new_tran = _rd_data_bram_patch_cnt > (RD_BRAM_PATCH_NUM - 4'h1);

  // flip-flop
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_bram_patch_state <= RD_BRAM_PATCH_RST;
    end else begin
      _rd_data_bram_patch_state <= _rd_data_bram_patch_next_state;
    end
  end
  // transition
  always@(rd_data_bottom or _rd_data_bram_patch_state or rd_data_bram_patch_last) begin
    _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RST;
    case(_rd_data_bram_patch_state)
      RD_BRAM_PATCH_RST: begin
        if(rd_data_bottom) begin // <-x
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RD;
        end else begin
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RST;
        end
      end

      RD_BRAM_PATCH_RD: begin
        if(rd_data_bram_patch_last) begin
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RST;
        end else begin
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RD;
        end
      end
    endcase
  end
  // logic
  always@(_rd_data_bram_patch_state or rd_data_bram_patch_ith_offset or _rd_data_bram_patch_cnt) begin
    rd_data_bram_patch_enb = 1'b0;
    rd_data_bram_patch_addrb = 13'b0;
    case(_rd_data_bram_patch_state)
      RD_BRAM_PATCH_RST: begin
        rd_data_bram_patch_addrb = 13'b0;
      end

      RD_BRAM_PATCH_RD: begin
        rd_data_bram_patch_enb    = 1'b1;
        rd_data_bram_patch_addrb  = rd_data_bram_patch_ith_offset + {9'b0,_rd_data_bram_patch_cnt};
      end
    endcase
  end

  // valid
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_bram_patch_cnt   <= 4'h0;
      _rd_data_bram_patch_ith_offset_rec <= 13'b0;
      rd_data_bram_patch_valid  <= 1'b0;
    end else begin
      if(rd_data_bottom) begin
        _rd_data_bram_patch_ith_offset_rec <= rd_data_bram_patch_ith_offset;
      end

      if(_rd_data_bram_patch_new_tran) begin
        _rd_data_bram_patch_cnt   <= 4'h0;
        rd_data_bram_patch_valid  <= 1'b0;
      end else begin
        if(rd_data_bram_patch_enb) begin
		  if( _rd_data_bram_patch_cnt == 4'h8 ) begin
            rd_data_bram_patch_valid  <= 1'b0;
		  end
		  else begin
            _rd_data_bram_patch_cnt   <= _rd_data_bram_patch_cnt + 1'b1;
            rd_data_bram_patch_valid  <= 1'b1;
		  end
        end
      end
    end
  end

  // simulation
//bram_right_patch right_patch(
//  .clka(clk),    // input wire clka
//  .ena(1'b0),      // input wire ena
//  .wea(1'b0),      // input wire [0 : 0] wea
//  .addra(12'b0),  // input wire [11 : 0] addra
//  .dina(480'b0),    // input wire [479 : 0] dina
//  .douta(480'b0),  // output wire [479 : 0] douta
//  .clkb(clk),    // input wire clkb
//  .enb(rd_data_bram_row_enb),      // input wire enb
//  .web(1'b0),      // input wire [0 : 0] web
//  .addrb(rd_data_bram_patch_addrb),  // input wire [11 : 0] addrb
//  .dinb(480'b0),    // input wire [479 : 0] dinb
//  .doutb()  // output wire [479 : 0] doutb
//);

endmodule
