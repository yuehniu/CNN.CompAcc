// ---------------------------------------------------
// File       : rd_bram_row.v
//
// Description: read data(top row of processing registers) from bram
//              check compatibility with fsm -- 1.1
//
// Version    : 1.1
// ---------------------------------------------------

module rd_bram_row(
    input wire          clk,
    input wire          rst_n,
    //
    input wire          rd_data_bram_row,   // rd bottom data enable
    input wire [09: 0]  rd_data_bram_row_addr,  // top row bram addr offset of ith bottom feature map,
                                                // stable till last valid output
                                                // rd_data_x*num_of_patch_in_one_bar + rd_data_y
    // bram control
    output reg          rd_data_bram_row_enb,   // enable port b
    output reg          rd_data_bram_row_valid, // data on port b is valid
  //output wire         rd_data_bram_row_last,  // last valid data
    output reg [09: 0]  rd_data_bram_row_addrb  // read address
  );

  //simulation
//reg       rd_data_bram_row_enb;
//reg       rd_data_bram_row_valid;
//reg       rd_data_bram_row_last;
//reg       rd_data_bram_row_addrb;

  reg  [09: 0]  _rd_data_bram_row_addr_rec; // record last transaction addr
  wire          _rd_data_bram_row_new; // new transaction
//assign rd_data_bram_row_last = rd_data_bram_row_valid;

  // record last reading address
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      _rd_data_bram_row_addr_rec <= {10{1'b1}};
    end else begin
      if(rd_data_bram_row) begin
        _rd_data_bram_row_addr_rec <= rd_data_bram_row_addr;
      end
    end
  end
  // determine
  assign _rd_data_bram_row_new = (rd_data_bram_row && (_rd_data_bram_row_addr_rec!=rd_data_bram_row_addr));
  // signal to fsm module
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      rd_data_bram_row_enb   <= 1'b0;
      rd_data_bram_row_valid <= 1'b0;
      rd_data_bram_row_addrb <= 10'b0;
    end else begin
      if(_rd_data_bram_row_new) begin
        rd_data_bram_row_enb    <= 1'b1;
        rd_data_bram_row_addrb  <= rd_data_bram_row_addr;
      end else begin
        rd_data_bram_row_enb    <= 1'b0;
        rd_data_bram_row_addrb  <= 10'b0;
      end

      if(rd_data_bram_row_enb) begin
        rd_data_bram_row_valid  <= 1'b1;
      end else begin
        rd_data_bram_row_valid  <= 1'b0;
      end
    end
  end

  // simulation
//bram_top_row your_instance_name (
//  .clka(clk),    // input wire clka
//  .ena(1'b0),      // input wire ena
//  .wea(1'b0),      // input wire [0 : 0] wea
//  .addra(10'b0),  // input wire [9 : 0] addra
//  .dina(512'b0),    // input wire [511 : 0] dina
//  .douta(512'b0),  // output wire [511 : 0] douta
//  .clkb(clk),    // input wire clkb
//  .enb(rd_data_bram_row_enb),      // input wire enb
//  .web(1'b0),      // input wire [0 : 0] web
//  .addrb(rd_data_bram_row_addrb),  // input wire [9 : 0] addrb
//  .dinb(512'b0),    // input wire [511 : 0] dinb
//  .doutb()  // output wire [511 : 0] doutb
//);

endmodule
