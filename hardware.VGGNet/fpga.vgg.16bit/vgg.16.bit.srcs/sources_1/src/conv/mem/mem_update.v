// ---------------------------------------------------
// File       : mem_update.v
//
// Description: read/write from/to bram
//              enable updating bram_row when the left most micro-patch is
//              full -- 1.1
//
// Version    : 1.1
// ---------------------------------------------------

module mem_update#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10
  ) (
    input  wire                                     clk,
    input  wire                                     rst_n,
    input  wire                                     mem_update_en, // write top row and right patch data into bram at last valid data burst
    input  wire                                     mem_update_bram_patch_last,
    input  wire                                     mem_update_first_fm,
    input  wire                                     mem_update_x_eq_zero,
    input  wire[16*(EXPONENT+MANTISSA+1)-1:0]       mem_update_top_row,
    input  wire[15*8*(EXPONENT+MANTISSA+1)-1:0]     mem_update_right_patch,
    output reg                                      mem_update_bram_patch_ena,
    output wire[11:0]                               mem_update_bram_patch_addr,
    output reg [15*(EXPONENT+MANTISSA+1)-1:0]       mem_update_bram_patch_data,
    output reg                                      mem_update_bram_row_ena,
    output reg [9:0]                                mem_update_bram_row_addr,
    output wire[16*(EXPONENT+MANTISSA+1)-1:0]       mem_update_bram_row_data,
    output wire                                     mem_update_bram_last
  );

  localparam BURST_LEN  = 8;
  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;
  localparam MAX_NUM_OF_CHANNELS  = 512;
  localparam DDR_BURST_DATA_WIDTH = 512;
  localparam NUM_OF_DATA_IN_1_BURST =  DDR_BURST_DATA_WIDTH / DATA_WIDTH;

  reg  [11:0] _mem_update_bram_patch_base;
  reg  [2:0]  _mem_update_bram_patch_offset;
  reg         _mem_update_bram_patch_en;
  reg         _mem_update_ddr_last;
  reg         _mem_update_bram_patch_last;
  assign mem_update_bram_last = (_mem_update_bram_patch_offset == 3'h7);
  assign mem_update_bram_row_data = mem_update_bram_row_ena ? mem_update_top_row : {(16*DATA_WIDTH){1'b0}};

  always@(posedge clk) begin
    if(mem_update_en) begin
      _mem_update_ddr_last <= 1'b1;
    end else if(mem_update_bram_last) begin
      _mem_update_ddr_last <= 1'b0;
    end
    if(mem_update_bram_patch_last) begin
      _mem_update_bram_patch_last <= 1'b1;
    end else if(mem_update_bram_last) begin
      _mem_update_bram_patch_last <= 1'b0;
    end
  end
  // bram_row address
  //  side effect: bram_row will continue updating at y==end
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      mem_update_bram_row_addr <= 10'h0;
    end else begin
      if(mem_update_en) begin
        if(mem_update_first_fm && mem_update_x_eq_zero) begin // first feature map, at position (0,y)
          mem_update_bram_row_addr <= 10'h0;
        end else begin
          mem_update_bram_row_addr <= mem_update_bram_row_addr + 1'b1;
        end
      end
    end
  end
  // bram_row control and data
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      mem_update_bram_row_ena   <= 1'b0;
    //mem_update_bram_row_data  <= {(16*(EXPONENT+MANTISSA+1)){1'b0}};
    end else begin
    //if(mem_update_en) begin   // <-x
      if((mem_update_x_eq_zero && mem_update_en) // at fsm_x == 0, there is no bram_patch
          || (mem_update_bram_patch_last && (_mem_update_ddr_last || mem_update_en)) // bram_patch_last lags ddr_data_valid_last
          || (mem_update_en && (_mem_update_bram_patch_last || mem_update_bram_patch_last))) begin  // bram_patch_last leads ddr_data_valid_last
        mem_update_bram_row_ena   <= 1'b1;
      //mem_update_bram_row_data  <= mem_update_top_row;
      end else begin
        mem_update_bram_row_ena   <= 1'b0;
      //mem_update_bram_row_data  <= {(16*(EXPONENT+MANTISSA+1)){1'b0}};
      end
    end
  end

  // bram_patch address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_update_bram_patch_base <= 12'h0;
    end else begin
      if(mem_update_en) begin
        if(mem_update_first_fm) begin
          _mem_update_bram_patch_base <= 12'h0;
        end else begin
          _mem_update_bram_patch_base <= _mem_update_bram_patch_base + 12'h8; // right patch size is 15x8
        end
      end
    end
  end
  // bram_patch_en
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_update_bram_patch_en <= 1'b0;
      mem_update_bram_patch_ena <= 1'b0;
    end else begin
      // enable
      if(mem_update_en) begin
        _mem_update_bram_patch_en <= 1'b1;
        mem_update_bram_patch_ena <= 1'b1;
      end
      // disable after last patch is writen
      if(_mem_update_bram_patch_offset == 3'h7) begin
        _mem_update_bram_patch_en <= 1'b0;
        mem_update_bram_patch_ena <= 1'b0;
      end
    end
  end
  // bram_patch control
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _mem_update_bram_patch_offset <= 3'h0;
    end else begin
      if(_mem_update_bram_patch_en) begin
        _mem_update_bram_patch_offset <= _mem_update_bram_patch_offset + 1'b1;
      end else begin
        _mem_update_bram_patch_offset <= 3'h0;
      end
    end
  end
  assign mem_update_bram_patch_addr = _mem_update_bram_patch_base + {{(9){1'b0}},_mem_update_bram_patch_offset};
  // bram_patch data
  always@(mem_update_bram_patch_addr or mem_update_bram_patch_ena or mem_update_right_patch) begin
    if(mem_update_bram_patch_ena) begin
      case(mem_update_bram_patch_addr[2:0])
        3'h0: mem_update_bram_patch_data = mem_update_right_patch[15*8*(EXPONENT+MANTISSA+1)-1 : 15*7*(EXPONENT+MANTISSA+1)];
        3'h1: mem_update_bram_patch_data = mem_update_right_patch[15*7*(EXPONENT+MANTISSA+1)-1 : 15*6*(EXPONENT+MANTISSA+1)];
        3'h2: mem_update_bram_patch_data = mem_update_right_patch[15*6*(EXPONENT+MANTISSA+1)-1 : 15*5*(EXPONENT+MANTISSA+1)];
        3'h3: mem_update_bram_patch_data = mem_update_right_patch[15*5*(EXPONENT+MANTISSA+1)-1 : 15*4*(EXPONENT+MANTISSA+1)];
        3'h4: mem_update_bram_patch_data = mem_update_right_patch[15*4*(EXPONENT+MANTISSA+1)-1 : 15*3*(EXPONENT+MANTISSA+1)];
        3'h5: mem_update_bram_patch_data = mem_update_right_patch[15*3*(EXPONENT+MANTISSA+1)-1 : 15*2*(EXPONENT+MANTISSA+1)];
        3'h6: mem_update_bram_patch_data = mem_update_right_patch[15*2*(EXPONENT+MANTISSA+1)-1 : 15*1*(EXPONENT+MANTISSA+1)];
        3'h7: mem_update_bram_patch_data = mem_update_right_patch[15*1*(EXPONENT+MANTISSA+1)-1 : 15*0*(EXPONENT+MANTISSA+1)];
        default: mem_update_bram_patch_data = {(15*(EXPONENT+MANTISSA+1)){1'b0}};
      endcase
    end else begin
      mem_update_bram_patch_data = {(15*(EXPONENT+MANTISSA+1)){1'b0}};
    end
  end

endmodule
