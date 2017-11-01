// ---------------------------------------------------
// File       : rd_bram_patch.v
//
// Description: read data(right most patch of size 15x8) from bram
//              check compatibility with fsm -- 1.2
//              compatible with mem_patch module -- 1.3
//
// Version    : 1.3
// ---------------------------------------------------

module rd_bram_patch(
    input wire          clk,
    input wire          rst_n,
    //
    input wire          rd_data_bram_patch,   // rd bottom data enable
    input wire [11: 0]  rd_data_bram_patch_addr, // bram addr offset of ith bottom feature map,
                                                 // stable till last valid output
                                                 // ith*RD_BRAM_PATCH_NUM
    // bram control
    output reg          rd_data_bram_patch_enb,   // enable port b
    output reg          rd_data_bram_patch_valid, // data on port b is valid
    output wire         rd_data_bram_patch_first, // first valid data
    output wire         rd_data_bram_patch_last,  // last valid data
    output reg [11: 0]  rd_data_bram_patch_addrb  // read address
  );

  localparam RD_BRAM_PATCH_RST  = 1'b0;
  localparam RD_BRAM_PATCH_RD   = 1'b1;
  localparam RD_BRAM_PATCH_NUM  = 4'h8;
  // simulation
//reg           rd_data_bram_patch_enb;
//reg  [11: 0]  rd_data_bram_patch_addrb;
//reg           rd_data_bram_patch_valid;

  wire          _rd_data_bram_patch_full;
  reg           _rd_data_bram_patch_state;
  reg           _rd_data_bram_patch_next_state;
  reg  [3:0]    _rd_data_bram_patch_cnt;      // num of datum read
  wire          _rd_data_bram_patch_new_tran; // new transaction
  reg           _rd_data_bram_patch;
  reg           _rd_data_bram_patch_full_reg;
  assign        rd_data_bram_patch_last = (!_rd_data_bram_patch_full_reg && _rd_data_bram_patch_full);
  // first valid data
  assign rd_data_bram_patch_first = (_rd_data_bram_patch_cnt == 4'h1);
  // last valid data
  assign _rd_data_bram_patch_full = (_rd_data_bram_patch_cnt == RD_BRAM_PATCH_NUM);

  // record last address
  always@(posedge clk) begin
    _rd_data_bram_patch         <= rd_data_bram_patch;
    _rd_data_bram_patch_full_reg<= _rd_data_bram_patch_full;
  end
  // check if it is a new transaction
  assign _rd_data_bram_patch_new_tran = (_rd_data_bram_patch==1'b0) && (rd_data_bram_patch==1'b1);

  // flip-flop
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_bram_patch_state <= RD_BRAM_PATCH_RST;
    end else begin
      _rd_data_bram_patch_state <= _rd_data_bram_patch_next_state;
    end
  end
  // transition
  always@(_rd_data_bram_patch_state or _rd_data_bram_patch_new_tran or _rd_data_bram_patch_full) begin
    _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RST;
    case(_rd_data_bram_patch_state)
      RD_BRAM_PATCH_RST: begin
        if(_rd_data_bram_patch_new_tran) begin // <-x
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RD;
        end else begin
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RST;
        end
      end

      RD_BRAM_PATCH_RD: begin
        if(_rd_data_bram_patch_full) begin
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RST;
        end else begin
          _rd_data_bram_patch_next_state = RD_BRAM_PATCH_RD;
        end
      end
    endcase
  end
  // logic
  always@(_rd_data_bram_patch_state or rd_data_bram_patch_addr or
          _rd_data_bram_patch_cnt or _rd_data_bram_patch_full
          ) begin
    rd_data_bram_patch_enb = 1'b0;
    rd_data_bram_patch_addrb = 12'b0;
    case(_rd_data_bram_patch_state)
      RD_BRAM_PATCH_RST: begin
        rd_data_bram_patch_addrb = 12'b0;
      end

      RD_BRAM_PATCH_RD: begin
        if(_rd_data_bram_patch_full) begin
          rd_data_bram_patch_enb = 1'b0;
        end else begin
          rd_data_bram_patch_enb = 1'b1;
        end
        rd_data_bram_patch_addrb  = rd_data_bram_patch_addr + {8'b0,_rd_data_bram_patch_cnt};
      end
    endcase
  end

  // valid
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_bram_patch_cnt   <= 4'h0;
      rd_data_bram_patch_valid  <= 1'b0;
    end else begin
      if(_rd_data_bram_patch_new_tran) begin
        _rd_data_bram_patch_cnt   <= 4'h0;
        rd_data_bram_patch_valid  <= 1'b0;
      end else begin
        if(rd_data_bram_patch_enb) begin
          _rd_data_bram_patch_cnt   <= _rd_data_bram_patch_cnt + 1'b1;
          rd_data_bram_patch_valid  <= 1'b1;
        end else begin
          rd_data_bram_patch_valid  <= 1'b0;
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
