// ---------------------------------------------------
// File       : cnn_conv_op.v
//
// Description: convolution operation
//              1.2: seperate convolve and output into two FSM
//
// Version    : 1.3
// ---------------------------------------------------
module cnn_conv_op#(
          parameter EXPONENT = 8,
          parameter MANTISSA = 23,
          parameter K_C      = 32, // kernel channels
          parameter K_H      = 3,  // kernel height
          parameter K_W      = 3,  // kernel width
          parameter DATA_H   = 16, // feature map data height
          parameter DATA_W   = 16  // feature map data width
      )(
        input  wire                                               cnn_conv_rst_n,
        input  wire                                               cnn_conv_clk,
        input  wire                                               cnn_conv_start,  // at current clock, last data is writen, convolution starts at next clock
        input  wire                                               cnn_conv_next_ker_valid_at_next_clk, // next set of kernel valid at next clock
        input  wire [(EXPONENT+MANTISSA+1)*K_C*K_H*K_W-1:0]       cnn_conv_ker,    // shape: k_c k_h k_w
        input  wire [(EXPONENT+MANTISSA+1)*DATA_H*DATA_W-1:0]     cnn_conv_bottom, // shape: data_h data_w
        output wire [(EXPONENT+MANTISSA+1)*K_C-1:0]               cnn_conv_top,    // shape: k_c, no output buffer reg
        output reg                                                cnn_conv_output_valid,
        output reg                                                cnn_conv_output_last,
        output reg  [3:0]                                         cnn_conv_x,      // ceil(log(14))
        output reg  [3:0]                                         cnn_conv_y,      // ceil(log(14))
        output reg                                                cnn_conv_busy
      //output reg                                                cnn_conv_done
      );

  localparam CONV_RST   = 2'b00;
  localparam CONV_CONV  = 2'b01;
  localparam CONV_TAIL  = 2'b10;
  localparam FALSE_OUTPUT = 5'd6;
  localparam CNT_WIDTH  = 5; // bit width of FALSE_OUTPUT

  // wire to reg array
  wire [EXPONENT+MANTISSA:0]            _bottom00[0:DATA_H-1]; // column-wise
  wire [EXPONENT+MANTISSA:0]            _bottom01[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom02[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom03[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom04[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom05[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom06[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom07[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom08[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom09[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom10[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom11[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom12[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom13[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom14[0:DATA_H-1];
  wire [EXPONENT+MANTISSA:0]            _bottom15[0:DATA_H-1];

  wire [EXPONENT+MANTISSA:0]            _ker[0:K_C*K_H*K_W-1];
  wire [EXPONENT+MANTISSA:0]            _top[0:K_C*DATA_H*DATA_W-1];
  reg  [1:0]                            _conv_state;
  reg  [1:0]                            _next_state;
  reg  [(EXPONENT+MANTISSA+1)*K_W-1:0]  _data0;
  reg  [(EXPONENT+MANTISSA+1)*K_W-1:0]  _data1;
//reg                                   _pa0_sel0; // pe array 0, select _data0
  reg                                   _pa1_sel0;
  reg                                   _pa2_sel0;
  reg                                   _pa_data_valid;
  wire [(EXPONENT+MANTISSA+1)*K_W-1:0]  _pa0_data;
  wire [(EXPONENT+MANTISSA+1)*K_W-1:0]  _pa1_data;
  wire [(EXPONENT+MANTISSA+1)*K_W-1:0]  _pa2_data;
  reg                                   _next_pos; // move to next position
  wire                                  _end_pos; // end of a 16x16 patch convolution position
  wire                                  _tail_last; // end of 16x16 patch data feeding
  reg [3:0]                             _col; // log(DATA_W)
  reg [3:0]                             _row; // log(DATA_H)

  // convolution FSM
  // FF
  always@(posedge cnn_conv_clk) begin
    if(!cnn_conv_rst_n)
      _conv_state <= CONV_RST;
    else
      _conv_state <= _next_state;
  end

  // state transition
  always@(_conv_state or _end_pos or cnn_conv_start or
          _tail_last or cnn_conv_next_ker_valid_at_next_clk
          )begin
    // default next state
    _next_state = CONV_RST;
    case(_conv_state)
      CONV_RST: begin
        if(cnn_conv_start) begin
          _next_state = CONV_CONV;
        end else begin
          _next_state = CONV_RST;
        end
      end

      CONV_CONV: begin
        // convolve to the last position
        if(_end_pos) begin
          if(cnn_conv_next_ker_valid_at_next_clk) begin
            _next_state = CONV_CONV;
          end else begin
            _next_state = CONV_TAIL;
          end
        end else begin
          _next_state = CONV_CONV;
        end
      end

      CONV_TAIL: begin
        if(_tail_last) begin
          _next_state = CONV_RST;
        end else begin
          _next_state = CONV_TAIL;
        end
      end
    endcase
  end

  // logic
  always@(_conv_state or _row) begin
  //_pa0_sel0  = 1'b1;
    _pa1_sel0  = 1'b1;
    _pa2_sel0  = 1'b1;
    _next_pos  = 1'b0;
    _pa_data_valid = 1'b0;
    cnn_conv_busy = 1'b0;

    case(_conv_state)
      CONV_RST: begin
        cnn_conv_busy = 1'b0;
      end

      CONV_CONV: begin
        cnn_conv_busy  = 1'b1;
        _next_pos      = 1'b1;
        _pa_data_valid = 1'b1;
        // pa1,pa2 data mux
        if(_row == 4'b0) begin
          _pa1_sel0 = 1'b0; // select _data1
          _pa2_sel0 = 1'b0; // select _data1
        end
        if(_row == 4'b1) begin
          _pa2_sel0 = 1'b0; // select _data1
        end
      end
      CONV_TAIL: begin
        cnn_conv_busy  = 1'b1;
        _next_pos      = 1'b1;
        _pa_data_valid = 1'b1;
        // pa1,pa2 data mux
        if(_row == 4'b0) begin
          _pa1_sel0 = 1'b0; // select _data1
          _pa2_sel0 = 1'b0; // select _data1
        end
        if(_row == 4'b1) begin
          _pa2_sel0 = 1'b0; // select _data1
        end
      end
    endcase
  end

  // pa1,pa2 data mux
  assign _pa0_data = _data0;
//assign _pa0_data = (_pa0_sel0 == 1'b1) ? _data0[(EXPONENT+MANTISSA+1)*(K_W-0)-1:(EXPONENT+MANTISSA+1)*(K_W-1)] :
//                                          _data1[(EXPONENT+MANTISSA+1)*(K_W-0)-1:(EXPONENT+MANTISSA+1)*(K_W-1)];

  assign _pa1_data = (_pa1_sel0 == 1'b1) ? _data0 : _data1;

  assign _pa2_data = (_pa2_sel0 == 1'b1) ? _data0 : _data1;

  // convolute position
  assign _end_pos = (_row == 4'd13) && (_col == 4'd13);
  assign _tail_last = (_row == 4'd1) && (_col==4'd0);
  always@(posedge cnn_conv_clk) begin
    if(!cnn_conv_rst_n) begin
      _col <= 4'b0;
      _row <= 4'b0;
    end else begin
      if(_next_pos) begin
        // row
        if(_row!=4'd13) begin // DATA_H-1 - K_H + 1
          _row <= _row+1'b1;
        end else begin
          _row <= 4'b0;
        end
        // column
        if(_col!=4'd13) begin // DATA_W-1 - K_W + 1
          if(_row == 4'd13)
            _col <= _col + 1'b1;
        end else begin
          if(_row == 4'd13)
            _col <= 4'b0;
        end
      end else if(cnn_conv_start) begin
        _row <= 4'd0;
        _col <= 4'd0;
      end
    end
  end

  // counter
  reg  [CNT_WIDTH-1:0] _counter;
  wire                 _output_valid; // at current clock, output valid
  wire                 _output_valid_at_next_clk; // output valid at next clock
  assign _output_valid = (_counter == {(CNT_WIDTH){1'b0}});
  assign _output_valid_at_next_clk = (_counter == {{(CNT_WIDTH-1){1'b0}}, 1'b1});
  always@(posedge cnn_conv_clk) begin
    if(!cnn_conv_rst_n) begin
      _counter <= FALSE_OUTPUT; // number of false output
    end else begin
      if(cnn_conv_start && (!cnn_conv_busy)) begin // on CONV_RST
    //if(cnn_conv_start && _end_pos) begin // go to CONV_RST at next clock
        _counter <= FALSE_OUTPUT;
      end else if(_end_pos && cnn_conv_next_ker_valid_at_next_clk) begin
        _counter <= FALSE_OUTPUT;
      end else if(cnn_conv_busy) begin
        if(!_output_valid) begin // false output
          _counter <= _counter - 1'b1;
        end
      end else begin
        _counter <= FALSE_OUTPUT;
      end
    end
  end

  // --------------------------- output ----------------------------------------
  // output FSM -- lag num_of_false_output clock behind convolution FSM
  localparam  CONV_OUTPUT_RST = 1'b0;
  localparam  CONV_OUTPUT     = 1'b1;
  reg      _conv_out_state;
  reg      _next_out_state;
  reg      _next_output;
  wire     _last_output_pos;

  assign  _last_output_pos = (cnn_conv_x == 4'd13) && (cnn_conv_y == 4'd13);
  // FF
  always@(posedge cnn_conv_clk) begin
    if(!cnn_conv_rst_n) begin
      _conv_out_state <= CONV_OUTPUT_RST;
    end else begin
      _conv_out_state <= _next_out_state;
    end
  end

  // state transition
  always@(_conv_out_state or _output_valid_at_next_clk or _last_output_pos) begin
    _next_out_state = CONV_OUTPUT_RST;
    case(_conv_out_state)
      CONV_OUTPUT_RST: begin
        if(_output_valid_at_next_clk) // output valid
          _next_out_state = CONV_OUTPUT;
        else
          _next_out_state = CONV_OUTPUT_RST;
      end
      CONV_OUTPUT: begin
        // last output position && next set of kernel convolution output is not valid
        if( _last_output_pos  && (!_output_valid_at_next_clk))
          _next_out_state = CONV_OUTPUT_RST;
        else
          _next_out_state = CONV_OUTPUT;
      end
    endcase
  end

  // logic
  always@(_conv_out_state or _last_output_pos or _output_valid_at_next_clk) begin
    _next_output = 1'b0;
    cnn_conv_output_valid = 1'b0;
    cnn_conv_output_last  = 1'b0;
    case(_conv_out_state)
      CONV_OUTPUT_RST: begin
        _next_output = 1'b0;
      end
      CONV_OUTPUT: begin
        _next_output = 1'b1;
        cnn_conv_output_valid = 1'b1;
        if(_last_output_pos && (!_output_valid_at_next_clk)) begin
          cnn_conv_output_last = 1'b1;
        end
      end
    endcase
  end

  // output position
  always@(posedge cnn_conv_clk) begin
    if(!cnn_conv_rst_n) begin
      cnn_conv_x <= 4'b0;
      cnn_conv_y <= 4'b0;
    end else begin
      // output valid or convolution tail
      if(_next_output) begin
        // row
        if(cnn_conv_y!=4'd13) begin
          cnn_conv_y <= cnn_conv_y+1'b1;
        end else begin
          cnn_conv_y <= 4'h0;
        end
        // col
        if(cnn_conv_x!=4'd13) begin
          if(cnn_conv_y == 4'd13)
            cnn_conv_x <= cnn_conv_x + 1'b1;
        end else begin
          if(cnn_conv_y == 4'd13)
            cnn_conv_x <= 4'd0;
        end
      end else begin
        cnn_conv_x <= 4'd0;
        cnn_conv_y <= 4'd0;
      end
    end
  end

  // data multiplexer
  always@(_row or _col or _bottom00 or _bottom01 or _bottom02 or _bottom03 or
          _bottom04 or _bottom05 or _bottom06 or _bottom07 or _bottom08 or _bottom09 or
          _bottom10 or _bottom11 or _bottom12 or _bottom13 or _bottom14 or _bottom15) begin
    _data0 = {((EXPONENT+MANTISSA+1)*K_W){1'b0}};
    _data1 = {((EXPONENT+MANTISSA+1)*K_W){1'b0}};
    case(_col)
      4'd0:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom13[4'd14],_bottom14[4'd14],_bottom15[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom13[4'd15],_bottom14[4'd15],_bottom15[4'd15]};
        end
        _data0 = {_bottom00[_row],_bottom01[_row],_bottom02[_row]};
      end
      4'd1:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom00[4'd14],_bottom01[4'd14],_bottom02[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom00[4'd15],_bottom01[4'd15],_bottom02[4'd15]};
        end
        _data0 = {_bottom01[_row],_bottom02[_row],_bottom03[_row]};
      end
      4'd2:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom01[4'd14],_bottom02[4'd14],_bottom03[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom01[4'd15],_bottom02[4'd15],_bottom03[4'd15]};
        end
        _data0 = {_bottom02[_row],_bottom03[_row],_bottom04[_row]};
      end
      4'd3:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom02[4'd14],_bottom03[4'd14],_bottom04[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom02[4'd15],_bottom03[4'd15],_bottom04[4'd15]};
        end
        _data0 = {_bottom03[_row],_bottom04[_row],_bottom05[_row]};
      end
      4'd4:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom03[4'd14],_bottom04[4'd14],_bottom05[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom03[4'd15],_bottom04[4'd15],_bottom05[4'd15]};
        end
        _data0 = {_bottom04[_row],_bottom05[_row],_bottom06[_row]};
      end
      4'd5:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom04[4'd14],_bottom05[4'd14],_bottom06[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom04[4'd15],_bottom05[4'd15],_bottom06[4'd15]};
        end
        _data0 = {_bottom05[_row],_bottom06[_row],_bottom07[_row]};
      end
      4'd6:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom05[4'd14],_bottom06[4'd14],_bottom07[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom05[4'd15],_bottom06[4'd15],_bottom07[4'd15]};
        end
        _data0 = {_bottom06[_row],_bottom07[_row],_bottom08[_row]};
      end
      4'd7:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom06[4'd14],_bottom07[4'd14],_bottom08[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom06[4'd15],_bottom07[4'd15],_bottom08[4'd15]};
        end
        _data0 = {_bottom07[_row],_bottom08[_row],_bottom09[_row]};
      end
      4'd8:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom07[4'd14],_bottom08[4'd14],_bottom09[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom07[4'd15],_bottom08[4'd15],_bottom09[4'd15]};
        end
        _data0 = {_bottom08[_row],_bottom09[_row],_bottom10[_row]};
      end
      4'd9:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom08[4'd14],_bottom09[4'd14],_bottom10[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom08[4'd15],_bottom09[4'd15],_bottom10[4'd15]};
        end
        _data0 = {_bottom09[_row],_bottom10[_row],_bottom11[_row]};
      end
      4'd10:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom09[4'd14],_bottom10[4'd14],_bottom11[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom09[4'd15],_bottom10[4'd15],_bottom11[4'd15]};
        end
        _data0 = {_bottom10[_row],_bottom11[_row],_bottom12[_row]};
      end
      4'd11:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom10[4'd14],_bottom11[4'd14],_bottom12[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom10[4'd15],_bottom11[4'd15],_bottom12[4'd15]};
        end
        _data0 = {_bottom11[_row],_bottom12[_row],_bottom13[_row]};
      end
      4'd12:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom11[4'd14],_bottom12[4'd14],_bottom13[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom11[4'd15],_bottom12[4'd15],_bottom13[4'd15]};
        end
        _data0 = {_bottom12[_row],_bottom13[_row],_bottom14[_row]};
      end
      4'd13:begin
        if(_row == 4'd0) begin
          _data1 = {_bottom12[4'd14],_bottom13[4'd14],_bottom14[4'd14]};
        end else if(_row == 4'd1) begin
          _data1 = {_bottom12[4'd15],_bottom13[4'd15],_bottom14[4'd15]};
        end
        _data0 = {_bottom13[_row],_bottom14[_row],_bottom15[_row]};
      end
    endcase
  end

  // convert from/to 1-dim array
  genvar c, w, h;
  generate
    for(c=0; c<K_C; c=c+1) begin
      for(h=0; h<K_H; h=h+1) begin
        for(w=0; w<K_W; w=w+1)begin
          assign _ker[K_C*K_H*K_W-1-(w+h*K_W+c*K_H*K_W)] = cnn_conv_ker[(EXPONENT+MANTISSA+1)*(1+w+h*K_W+c*K_H*K_W)-1 : (EXPONENT+MANTISSA+1)*(w+h*K_W+c*K_H*K_W)];
        end
      end
    end
    for(h=0; h<DATA_H; h=h+1)begin // column-wise
      assign _bottom00[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+15+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*(15+h*DATA_W)];
      assign _bottom01[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+14+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*(14+h*DATA_W)];
      assign _bottom02[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+13+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*(13+h*DATA_W)];
      assign _bottom03[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+12+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*(12+h*DATA_W)];
      assign _bottom04[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+11+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*(11+h*DATA_W)];
      assign _bottom05[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+10+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*(10+h*DATA_W)];
      assign _bottom06[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 9+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 9+h*DATA_W)];
      assign _bottom07[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 8+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 8+h*DATA_W)];
      assign _bottom08[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 7+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 7+h*DATA_W)];
      assign _bottom09[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 6+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 6+h*DATA_W)];
      assign _bottom10[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 5+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 5+h*DATA_W)];
      assign _bottom11[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 4+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 4+h*DATA_W)];
      assign _bottom12[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 3+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 3+h*DATA_W)];
      assign _bottom13[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 2+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 2+h*DATA_W)];
      assign _bottom14[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 1+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 1+h*DATA_W)];
      assign _bottom15[DATA_H-1-h] = cnn_conv_bottom[(EXPONENT+MANTISSA+1)*(1+ 0+h*DATA_W)-1 : (EXPONENT+MANTISSA+1)*( 0+h*DATA_W)];
    end
  endgenerate

  // generate PE3x3
  generate
    for(c=0; c<K_C; c=c+1) begin
      pe_array3x3#(
        .EXPONENT(EXPONENT),
        .MANTISSA(MANTISSA)
        ) pe_array(
          .clk(cnn_conv_clk),
          .pe3_array0_ker3({_ker[c*K_H*K_W  ],_ker[c*K_H*K_W+1],_ker[c*K_H*K_W+2]}),
          .pe3_array1_ker3({_ker[c*K_H*K_W+3],_ker[c*K_H*K_W+4],_ker[c*K_H*K_W+5]}),
          .pe3_array2_ker3({_ker[c*K_H*K_W+6],_ker[c*K_H*K_W+7],_ker[c*K_H*K_W+8]}),
          .pe3_array0_data3(_pa0_data),
          .pe3_array1_data3(_pa1_data),
          .pe3_array2_data3(_pa2_data),
          .pe3_array0_valid(_pa_data_valid),
          .pe3_array1_valid(_pa_data_valid),
          .pe3_array2_valid(_pa_data_valid),
          .pe3_o(cnn_conv_top[(EXPONENT+MANTISSA+1)*(K_C-1-c+1)-1:(EXPONENT+MANTISSA+1)*(K_C-1-c)])
        );
    end
  endgenerate

endmodule
