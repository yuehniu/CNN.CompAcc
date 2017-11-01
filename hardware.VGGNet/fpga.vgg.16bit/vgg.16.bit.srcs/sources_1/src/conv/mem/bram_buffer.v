// ---------------------------------------------------
// File       : bram_buffer.v
//
// Description: storage
//              bram depth = 512x14x14/32
//
// Version    : 1.0
// ---------------------------------------------------

module bram_buffer #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter PORT_ADDR_WIDTH  = 12
  ) (
    input   wire                                clk,
    // port a
    input   wire[32*PORT_ADDR_WIDTH - 1:0]      port_a_addr, // 32*port_addr_width-1 : 0
    input   wire                                port_a_en,
    input   wire                                port_a_wr_en,
    input   wire[32*(EXPONENT+MANTISSA+1)-1:0]  port_a_data_i,
    // port b
    input   wire[32*PORT_ADDR_WIDTH - 1:0]      port_b_addr, // port b address, 32*port_addr_width-1 : 0
    input   wire                                port_b_en, // read enable
    // output
    output  wire[32*(EXPONENT+MANTISSA+1)-1:0]  port_a_data_o,
    output  wire[32*(EXPONENT+MANTISSA+1)-1:0]  port_b_data_o
  );

  localparam DATA_WIDTH       = EXPONENT+MANTISSA+1;

  genvar i;
  generate
    for(i=0; i<32; i=i+1) begin : generate_top_buffer
      of_blkmem  bram_top(
        .clka  (clk),    // input wire clka
        .ena   (port_a_en),      // input wire ena
        .wea   (port_a_wr_en),      // input wire [0 : 0] wea
        .addra (port_a_addr[(32-i)*PORT_ADDR_WIDTH-1 : (32-1-i)*PORT_ADDR_WIDTH]),  // input wire [11 : 0] addra
        .dina  (port_a_data_i[(32-i)*DATA_WIDTH-1 : (32-1-i)*DATA_WIDTH]),    // input wire [31 : 0] dina
        .douta (port_a_data_o[(32-i)*DATA_WIDTH-1 : (32-1-i)*DATA_WIDTH]),  // output wire [31 : 0] douta
        .clkb  (clk),    // input wire clkb
        .enb   (port_b_en),      // input wire enb
        .web   (1'b0),      // input wire [0 : 0] web
        .addrb (port_b_addr[(32-i)*PORT_ADDR_WIDTH-1 : (32-1-i)*PORT_ADDR_WIDTH]),  // input wire [11 : 0] addrb
        .dinb  ({(DATA_WIDTH){1'b0}}),    // input wire [31 : 0] dinb
        .doutb (port_b_data_o[(32-i)*DATA_WIDTH-1 : (32-1-i)*DATA_WIDTH])  // output wire [31 : 0] doutb
      );
    end
  endgenerate

endmodule
