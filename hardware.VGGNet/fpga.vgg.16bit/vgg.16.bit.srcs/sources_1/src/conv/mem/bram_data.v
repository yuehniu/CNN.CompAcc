// ---------------------------------------------------
// File       : bram_data.v
//
// Description: partial convolution result storage module,
//              bram port a is write port and port b is read port in convolution mode
//              bram port b is read port. port a works in read-write interval mode in convolution with pooling mode
//              bram port a and port b are both read port. 7x7 block is read in one cycle in ddr read mode
//
// Version    : 1.0
// ---------------------------------------------------

//`define sim_
module bram_data #(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10,
    parameter PORT_ADDR_WIDTH = 12
  ) (
    input  wire                                 rst_n,
    input  wire                                 clk,
    input  wire[1:0]                            bram_data_quarter_num,
    input  wire[3:0]                            bram_data_ker_set,        //max_out_channel(512) / pe_num(32)=16   
    input  wire[4:0]                            bram_data_channel_idx,    //indicate ddr read pe in each set [0:31]
    input  wire[3:0]                            bram_data_wr_x,           //write data into port a, range in [0:14]
    input  wire[3:0]                            bram_data_wr_y,           //write data into port a, range in [0:14]
    input  wire[3:0]                            bram_data_rd_x,           //read data from port b, range in [0:14]
    input  wire[3:0]                            bram_data_rd_y,           //read data from port b, range in [0:14]
    input  wire[2:0]                            bram_data_pooling_rd_x,   //read x from port a, range in [0:6]
    input  wire[2:0]                            bram_data_pooling_rd_y,   //read y from port a, range in [0:6]
    input  wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_data_data_i,
    input  wire                                 bram_data_wr_en,          //port a write enable
    input  wire                                 bram_data_conv_rd_en,     //port b read enable
    input  wire                                 bram_data_pooling_rd_en,  //port a read enable
    input  wire                                 bram_data_wr_ddr_rd_en,   //port a & b read enable
    input  wire                                 bram_data_rd_top_buffer,
    input  wire                                 bram_data_wr_ddr_rd_next_quar,
    output wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_data_pre_data,
    output wire[49*(EXPONENT+MANTISSA+1)-1:0]   bram_data_ddr_do,
    output wire[32*(EXPONENT+MANTISSA+1)-1:0]   bram_data_pooling_data,
    output wire                                 bram_data_ddr_rd_valid,
    output wire                                 bram_data_conv_rd_valid,
    output wire                                 bram_data_pooling_rd_valid
  );

  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;

  // write to port a
  wire                            _bram_data_wr_a_en; // write into port a
  wire[32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_wr_addr;
  wire[32*DATA_WIDTH-1 : 0]       _bram_data_wr_data;
  // read partial sum data from port b
  wire                            _bram_data_rd_en;
  wire                            _bram_data_rd_bram_valid;
  wire[32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_rd_addr;
  reg [32*DATA_WIDTH-1 : 0]       _bram_data_partial_sum;
  // read pooling data from port a
  wire                            _bram_data_pooling_rd_en;
  wire                            _bram_data_pooling_bram_valid;
  wire[32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_pooling_rd_addr;
  reg [32*DATA_WIDTH-1 : 0]       _bram_data_pooling_pre_data;
  // read 7x7 result from port a & b
  wire                            _bram_data_ddr_rd_a_en;
  wire                            _bram_data_ddr_rd_b_en;
  assign _bram_data_ddr_rd_b_en = _bram_data_ddr_rd_a_en;
  wire                            _bram_data_ddr_bram_valid;
  wire[32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_ddr_rd_a_addr;
  wire[32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_ddr_rd_b_addr;
  reg [32*DATA_WIDTH-1 : 0]       _bram_data_ddr_rd_a_data;
  reg [32*DATA_WIDTH-1 : 0]       _bram_data_ddr_rd_b_data;
  // port a
  reg [32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_port_a_addr;
  reg                             _bram_data_port_a_en;
  reg                             _bram_data_port_a_wr_en;
  wire[32*DATA_WIDTH-1 : 0]       _bram_data_port_a_data_o;
  // port b
  reg [32*PORT_ADDR_WIDTH-1 : 0]  _bram_data_port_b_addr;
  reg                             _bram_data_port_b_en;
  wire[32*DATA_WIDTH-1 : 0]       _bram_data_port_b_data_o;

  // write data into bram
  bram_conv_wr #(
      .MANTISSA(MANTISSA),
      .EXPONENT(EXPONENT),
      .PORT_ADDR_WIDTH(PORT_ADDR_WIDTH)
    ) wr_bram_portA (
      .clk(clk),
      .rst_n(rst_n),
      .bram_wr_ker_set(bram_data_ker_set),
      .bram_wr_x(bram_data_wr_x),
      .bram_wr_y(bram_data_wr_y),
      .bram_wr_addr(_bram_data_wr_addr), // o
      .bram_wr_conv_valid(bram_data_wr_en),
      .bram_wr_en(_bram_data_wr_a_en), // o
      .bram_wr_conv_i(bram_data_data_i),
      .bram_wr_data(_bram_data_wr_data) // o
  );

  // read data from bram port b
  bram_conv_rd #(
      .MANTISSA(MANTISSA),
      .EXPONENT(EXPONENT),
      .PORT_ADDR_WIDTH(PORT_ADDR_WIDTH)
    ) rd_bram_portB (
      .clk(clk),
      .rst_n(rst_n),
      .bram_rd_ker_set(bram_data_ker_set),
      .bram_rd_x(bram_data_rd_x),
      .bram_rd_y(bram_data_rd_y),
      .bram_rd_addr(_bram_data_rd_addr), // o
      .bram_rd_conv_en(bram_data_conv_rd_en),
      .bram_rd_bram_valid(_bram_data_rd_bram_valid),
      .bram_rd_en(_bram_data_rd_en), // o
      .bram_rd_data_valid(bram_data_conv_rd_valid),
      .bram_rd_partial_sum(_bram_data_partial_sum), // i
      .bram_rd_data(bram_data_pre_data)
  );

  // read data from bram port a for pooling
  bram_pooling_rd #(
      .MANTISSA(MANTISSA),
      .EXPONENT(EXPONENT),
      .PORT_ADDR_WIDTH(PORT_ADDR_WIDTH)
    ) rd_bram_portA_pooling (
      .clk(clk),
      .rst_n(rst_n),
      .bram_rd_pooling_ker_set(bram_data_ker_set),
      .bram_rd_pooling_x(bram_data_pooling_rd_x),
      .bram_rd_pooling_y(bram_data_pooling_rd_y),
      .bram_rd_pooling_addr(_bram_data_pooling_rd_addr), // o
      .bram_rd_pooling_pre_en(bram_data_pooling_rd_en),
      .bram_rd_pooling_en(_bram_data_pooling_rd_en), // o
      .bram_rd_pooling_bram_valid(_bram_data_pooling_bram_valid), // o
      .bram_rd_pooling_pre(_bram_data_pooling_pre_data), // i
      .bram_rd_pooling_data_valid(bram_data_pooling_rd_valid),
      .bram_rd_pooling_data(bram_data_pooling_data)
  );

  // read 7x7 output data
  bram_ddr_rd #(
      .MANTISSA(MANTISSA),
      .EXPONENT(EXPONENT),
      .PORT_ADDR_WIDTH(PORT_ADDR_WIDTH)
  ) rd_bram_ddr_portAB (
      .clk(clk),
      .rst_n(rst_n),
      .bram_rd_ddr_ker_set(bram_data_ker_set),
      .bram_rd_ddr_channel_idx(bram_data_channel_idx),
      .bram_rd_ddr_quarter_num(bram_data_quarter_num),
      .bram_rd_ddr_addr_a(_bram_data_ddr_rd_a_addr), // o
      .bram_rd_ddr_addr_b(_bram_data_ddr_rd_b_addr), // o
      .bram_rd_ddr_en(bram_data_wr_ddr_rd_en),
      .bram_rd_ddr_rd_en(bram_data_rd_top_buffer), // i
      .bram_rd_ddr_next_quar(bram_data_wr_ddr_rd_next_quar),
      .bram_rd_ddr_bram_valid(_bram_data_ddr_bram_valid),
      .bram_rd_ddr_en_bram(_bram_data_ddr_rd_a_en), // o
      .bram_rd_ddr_a_data(_bram_data_ddr_rd_a_data), // i
      .bram_rd_ddr_b_data(_bram_data_ddr_rd_b_data), // i
      .bram_rd_ddr_data_valid(bram_data_ddr_rd_valid),
      .bram_rd_ddr_data(bram_data_ddr_do)
  );

  // collision
  `ifdef sim_ // collision {{{
  always@(_bram_data_wr_a_en or _bram_data_pooling_rd_en) begin
    if(_bram_data_wr_a_en && _bram_data_pooling_rd_en) begin
      $display("[%t] COLLISION ACCURED", $realtime);
      #100 $finish;
    end
  end
  `endif // }}}

  // switches
  // port a
  always@(_bram_data_wr_a_en or _bram_data_pooling_rd_en or _bram_data_ddr_rd_a_en or
          _bram_data_wr_addr or _bram_data_pooling_rd_addr or _bram_data_ddr_rd_a_addr
          ) begin
    // address
    if(_bram_data_pooling_rd_en) begin
      _bram_data_port_a_addr = _bram_data_pooling_rd_addr;
    end else if(_bram_data_ddr_rd_a_en) begin
      _bram_data_port_a_addr = _bram_data_ddr_rd_a_addr;
    end else begin
      _bram_data_port_a_addr = _bram_data_wr_addr;
    end
    // enable
    if(_bram_data_pooling_rd_en || _bram_data_ddr_rd_a_en || _bram_data_wr_a_en) begin
      _bram_data_port_a_en = 1'b1; // <-xxxxxxxxx
    end else begin
      _bram_data_port_a_en = 1'b0;
    end
    if(_bram_data_wr_a_en) begin
      _bram_data_port_a_wr_en = 1'b1;
    end else begin
      _bram_data_port_a_wr_en = 1'b0;
    end
  end
  // port b
  always@(_bram_data_rd_en or _bram_data_ddr_rd_b_en or
          _bram_data_rd_addr or _bram_data_ddr_rd_b_addr
          )begin
    // enable
    if(_bram_data_ddr_rd_b_en || _bram_data_rd_en) begin
      _bram_data_port_b_en = 1'b1;
    end else begin
      _bram_data_port_b_en = 1'b0;
    end
    // address
    if(_bram_data_ddr_rd_b_en) begin
      _bram_data_port_b_addr = _bram_data_ddr_rd_b_addr;
    end else begin
      _bram_data_port_b_addr = _bram_data_rd_addr;
    end
  end
  always@(_bram_data_pooling_bram_valid or _bram_data_ddr_bram_valid or
          _bram_data_rd_bram_valid or _bram_data_port_a_data_o or
          _bram_data_port_b_data_o
          ) begin
    // port a
    if(_bram_data_pooling_bram_valid) begin
      _bram_data_pooling_pre_data = _bram_data_port_a_data_o;
    end else begin
      _bram_data_pooling_pre_data = {(32*DATA_WIDTH){1'b0}};
    end
    if(_bram_data_ddr_bram_valid) begin
      _bram_data_ddr_rd_a_data = _bram_data_port_a_data_o;
    end else begin
      _bram_data_ddr_rd_a_data = {(32*DATA_WIDTH){1'b0}};
    end
    // port b
    if(_bram_data_rd_bram_valid) begin
      _bram_data_partial_sum = _bram_data_port_b_data_o;
    end else begin
      _bram_data_partial_sum = {(32*DATA_WIDTH){1'b0}};
    end
    if(_bram_data_ddr_bram_valid) begin
      _bram_data_ddr_rd_b_data = _bram_data_port_b_data_o;
    end else begin
      _bram_data_ddr_rd_b_data = {(32*DATA_WIDTH){1'b0}};
    end
  end

  // output bram buffer
  bram_buffer #(
      .MANTISSA(MANTISSA),
      .EXPONENT(EXPONENT)
    ) top_bram32 (
      .clk          (clk),
      // port a
      .port_a_addr  (_bram_data_port_a_addr),
      .port_a_en    (_bram_data_port_a_en),
      .port_a_wr_en (_bram_data_port_a_wr_en),
      .port_a_data_i(_bram_data_wr_data),
      .port_a_data_o(_bram_data_port_a_data_o),
      // port b
      .port_b_addr  (_bram_data_port_b_addr),
      .port_b_en    (_bram_data_port_b_en),
      .port_b_data_o(_bram_data_port_b_data_o)
  );

endmodule
