`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/28/2017 11:32:02 AM
// Design Name: 
// Module Name: mem_patch
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mem_patch#(
    parameter EXPONENT = 5,
    parameter MANTISSA = 10
  ) (
    input  wire                                   clk,
  //input  wire                                   rst_n,
    input  wire                                   mem_patch_x_eq_zero,    // patch position x==0
    input  wire                                   mem_patch_x_eq_end,     // patch position x==end
    input  wire                                   mem_patch_y_eq_zero,    // patch position y==0
    input  wire                                   mem_patch_y_eq_end,     // patch position y==end
    input  wire                                   mem_patch_ddr_valid,    // bottom data valid
    input  wire[5:0]                              mem_patch_ddr_num_valid,// number of valid datum
    input  wire                                   mem_patch_ddr_valid_first,// first valid bottom data burst
    input  wire                                   mem_patch_ddr_valid_last, // last valid bottom data burst
    input  wire                                   mem_patch_ddr_patch_last, // last valid patch data burst
    input  wire                                   mem_patch_ddr_upper_last, // last valid upper half patch data <-x Nov.30
  //input  wire                                   mem_patch_ddr_padding_last, // last valid padding data burst
    input  wire[511:0]                            mem_patch_ddr_i,        // bottom data burst from ddr
    input  wire                                   mem_patch_bram_row_valid,
    input  wire[16*(EXPONENT+MANTISSA+1)-1:0]     mem_patch_bram_row_i,   // bottom data from bram_row, (1+14+1)x1
    input  wire                                   mem_patch_bram_patch_valid, // data from bram_patch valid
    input  wire                                   mem_patch_bram_patch_first, // first valid bram_patch data
    input  wire                                   mem_patch_bram_patch_last,  // last valid bram_patch data
    input  wire[15*(EXPONENT+MANTISSA+1)-1:0]     mem_patch_bram_patch_i, // bottom data from bram_right_patch((1+14)x8), (1+14)x1
    output wire[16*(EXPONENT+MANTISSA+1)-1:0]     mem_patch_bottom_row,      // top row output, second bottom row of current patch
    output wire[15*8*(EXPONENT+MANTISSA+1)-1:0]   mem_patch_right_patch,  // right-most micro-patch
    output wire[16*16*(EXPONENT+MANTISSA+1)-1:0]  mem_patch_proc_ram      // procesing ram (16x16)
  );

  localparam BURST_LEN  = 8;
  localparam DATA_WIDTH = EXPONENT + MANTISSA + 1;
  localparam MAX_NUM_OF_CHANNELS  = 512;
  localparam DDR_BURST_DATA_WIDTH = 512;
  localparam NUM_OF_DATA_IN_1_BURST =  DDR_BURST_DATA_WIDTH / DATA_WIDTH;

  reg  [DATA_WIDTH-1:0] _mem_patch[0:22*16-1-6]; // (1+7+7+1)x(1+7+7+7) => 7x7x6+7x3+15x1+1x16 => 15x21+15x1+1x16
  reg  [8:0]            _mem_patch_ddr_offset, _mem_patch_ddr_offset_pre;
  reg  [3:0]            _mem_patch_grp, _mem_patch_grp_pre, _mem_patch_grp_reg;
  reg                   _mem_patch_slice, _mem_patch_slice_pre, _mem_patch_slice_reg;
  reg  [8:0]            _mem_patch_grp_start;
  reg  [2:0]            _mem_patch_bram_offset;

  // bottom data address
  // aa , bb , cc , dd , ee , ff , g , h , i , jjj , kkk
  // |            7x7            |    1x7    |1x15 | 1x16

  always @(mem_patch_ddr_valid or  mem_patch_x_eq_zero or mem_patch_x_eq_end or
           _mem_patch_ddr_offset or mem_patch_ddr_valid_last or mem_patch_ddr_valid_first or 
           mem_patch_ddr_upper_last or mem_patch_ddr_patch_last or mem_patch_ddr_num_valid)
  begin

      if(mem_patch_ddr_valid_first) begin // first valid data burst
        if(mem_patch_x_eq_zero) begin
          _mem_patch_ddr_offset_pre = 9'h0 + NUM_OF_DATA_IN_1_BURST;
        end else begin
          _mem_patch_ddr_offset_pre = 9'd49 + NUM_OF_DATA_IN_1_BURST; // 7x7
        end
      end else if(mem_patch_ddr_valid_last) begin // reset to zero, set high priority for y==end
        _mem_patch_ddr_offset_pre = 9'h0;
      end else if(mem_patch_ddr_upper_last) begin // fill lower half patch data
        if(mem_patch_x_eq_zero) begin // <-x modify to write 14x14, Dec.27
          if(mem_patch_x_eq_end) begin
            _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid} + 9'd49;
          end else begin
            _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid};
          end
        end else if(mem_patch_x_eq_end) begin
          _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid} + 9'd98; // + 7x7 + 7x7
        end else begin
          _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid} + 9'd49; // + 7x7
        end
      end else if(mem_patch_ddr_patch_last) begin // last valid patch data burst, fill padding data
        if(mem_patch_x_eq_zero) begin // <-x need not to modify to write 14x14, Dec.27
          _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid};
        end else if(mem_patch_x_eq_end) begin
          _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid} + 9'd56; // + 7x7 + 1x7
        end else begin
          _mem_patch_ddr_offset_pre = _mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid} + 9'd7; // + 1x7
        end
      end else begin // increment
        _mem_patch_ddr_offset_pre =_mem_patch_ddr_offset + {{3{1'b0}},mem_patch_ddr_num_valid};
      end

  end

  always @(posedge clk)
  begin
    if(mem_patch_ddr_valid) begin
      _mem_patch_ddr_offset <= _mem_patch_ddr_offset_pre;
    end
  end

  //partition j and k will not be written by ddr, so we ignore
  //their logic  
  reg  [8:0]            _mem_patch_grp_inter_offset_pre;
  reg  [5:0]            _mem_patch_grp_inter_offset;

  always @(_mem_patch_ddr_offset_pre)
  begin

    _mem_patch_grp_start = 9'd0;

    if(_mem_patch_ddr_offset_pre < 9'd245)
    begin
      if(_mem_patch_ddr_offset_pre < 9'd147)
      begin
        if(_mem_patch_ddr_offset_pre < 9'd98)
        begin
          if(_mem_patch_ddr_offset_pre < 9'd49)
          begin
            _mem_patch_grp_pre = 4'd0; //grp a
            _mem_patch_grp_start = 9'd0;            
          end
          else
          begin
            _mem_patch_grp_pre = 4'd1; //grp b
            _mem_patch_grp_start = 9'd49;   
          end          
        end
        else
        begin
          _mem_patch_grp_pre = 4'd2; //grp c
          _mem_patch_grp_start = 9'd98; 
        end
      end
      else
      begin
        if(_mem_patch_ddr_offset_pre < 9'd196)
        begin
          _mem_patch_grp_pre = 4'd3; //grp d
          _mem_patch_grp_start = 9'd147; 
        end
        else
        begin
          _mem_patch_grp_pre = 4'd4; //grp e
          _mem_patch_grp_start = 9'd196; 
        end
      end
    end
    else
    begin
      if(_mem_patch_ddr_offset_pre < 9'd301)
      begin
        if(_mem_patch_ddr_offset_pre < 9'd294)
        begin
          _mem_patch_grp_pre = 4'd5; //grp f
          _mem_patch_grp_start = 9'd245;
        end
        else
        begin
          _mem_patch_grp_pre = 4'd6; //grp g
        end
      end
      else
      begin
        if(_mem_patch_ddr_offset_pre < 9'd308)
        begin
          _mem_patch_grp_pre = 4'd7; //grp h
        end
        else
        begin
          _mem_patch_grp_pre = 4'd8; //grp i
        end
      end
    end

    _mem_patch_grp_inter_offset_pre = _mem_patch_ddr_offset_pre - _mem_patch_grp_start;
    _mem_patch_grp_inter_offset = _mem_patch_grp_inter_offset_pre[5:0];

    if(_mem_patch_grp_inter_offset < 6'd32)
    begin
      _mem_patch_slice_pre = 1'd0;
    end
    else
    begin
      _mem_patch_slice_pre = 1'd1;
    end
  end

  always @(posedge clk)
  begin
    if(mem_patch_ddr_valid == 1'b1)
    begin
      _mem_patch_grp_reg <= _mem_patch_grp_pre;
      _mem_patch_slice_reg <= _mem_patch_slice_pre;
    end
  end

  always @(mem_patch_ddr_valid_first or 
           mem_patch_x_eq_zero or 
           _mem_patch_grp_reg or _mem_patch_slice_reg)
  begin
    if(mem_patch_ddr_valid_first == 1'b1)
    begin
      _mem_patch_slice = 1'd0;

      if(mem_patch_x_eq_zero)
      begin
        _mem_patch_grp = 4'd0;
      end
      else
      begin
        _mem_patch_grp = 4'd1;
      end
    end
    else
    begin
      _mem_patch_slice = _mem_patch_slice_reg;
      _mem_patch_grp = _mem_patch_grp_reg;
    end

  end
  
  // bram_patch data address
  always@(posedge clk) begin
    if(mem_patch_bram_patch_valid) begin
      if(mem_patch_bram_patch_first) begin
        _mem_patch_bram_offset <= 3'h0;
      end else if(mem_patch_bram_patch_last) begin
        _mem_patch_bram_offset <= 3'h0;
      end else begin
        _mem_patch_bram_offset <= _mem_patch_bram_offset + 1'b1;
      end
    end
  end

  always@(posedge clk) 
  begin
    //block k fill logic
    if(mem_patch_bram_row_valid == 1'b1)
    begin
      {_mem_patch[330], _mem_patch[331], _mem_patch[332], _mem_patch[333],
       _mem_patch[334], _mem_patch[335], _mem_patch[336], _mem_patch[337],
       _mem_patch[338], _mem_patch[339], _mem_patch[340], _mem_patch[341],
       _mem_patch[342], _mem_patch[343], _mem_patch[344], _mem_patch[345]} <= mem_patch_bram_row_i;
    end
    else if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_y_eq_zero && mem_patch_ddr_valid_last)
      begin
          {_mem_patch[330], _mem_patch[331], _mem_patch[332], _mem_patch[333],
           _mem_patch[334], _mem_patch[335], _mem_patch[336], _mem_patch[337],
           _mem_patch[338], _mem_patch[339], _mem_patch[340], _mem_patch[341],
           _mem_patch[342], _mem_patch[343], _mem_patch[344], _mem_patch[345]} <= {(16*DATA_WIDTH){1'b0}};
      end
    end

    //block j fill logic
    if(mem_patch_bram_patch_valid) 
    begin
      if(mem_patch_bram_patch_first) begin
      // filling padding data region j
        {_mem_patch[315], _mem_patch[316], _mem_patch[317],
         _mem_patch[318], _mem_patch[319], _mem_patch[320],
         _mem_patch[321], _mem_patch[322], _mem_patch[323],
         _mem_patch[324], _mem_patch[325], _mem_patch[326],
         _mem_patch[327], _mem_patch[328], _mem_patch[329]} <= mem_patch_bram_patch_i;
      end
    end
    else if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_x_eq_zero && mem_patch_ddr_valid_last)
      begin
          {_mem_patch[315], _mem_patch[316], _mem_patch[317],
           _mem_patch[318], _mem_patch[319], _mem_patch[320],
           _mem_patch[321], _mem_patch[322], _mem_patch[323],
           _mem_patch[324], _mem_patch[325], _mem_patch[326],
           _mem_patch[327], _mem_patch[328], _mem_patch[329]} <= {(15*DATA_WIDTH){1'b0}};
      end
    end
    
    //block a fill logic
    if(mem_patch_bram_patch_valid) 
    begin
      case (_mem_patch_bram_offset)
        3'd0:
        begin
          { _mem_patch[0 + 0], _mem_patch[0 + 7], _mem_patch[0 +14],
            _mem_patch[0 +21], _mem_patch[0 +28], _mem_patch[0 +35],
            _mem_patch[0 +42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
        3'd1:
        begin
          { _mem_patch[1 + 0], _mem_patch[1 + 7], _mem_patch[1 +14],
            _mem_patch[1 +21], _mem_patch[1 +28], _mem_patch[1 +35],
            _mem_patch[1 +42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
        3'd2:
        begin
          { _mem_patch[2 + 0], _mem_patch[2 + 7], _mem_patch[2 + 14],
            _mem_patch[2 + 21], _mem_patch[2 + 28], _mem_patch[2 + 35],
            _mem_patch[2 + 42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
        3'd3:
        begin
          { _mem_patch[3 + 0], _mem_patch[3 + 7], _mem_patch[3 + 14],
            _mem_patch[3 + 21], _mem_patch[3 + 28], _mem_patch[3 + 35],
            _mem_patch[3 + 42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
        3'd4:
        begin
          { _mem_patch[4 + 0], _mem_patch[4 + 7], _mem_patch[4 + 14],
            _mem_patch[4 + 21], _mem_patch[4 + 28], _mem_patch[4 + 35],
            _mem_patch[4 + 42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
        3'd5:
        begin
          { _mem_patch[5 + 0], _mem_patch[5 + 7], _mem_patch[5 + 14],
            _mem_patch[5 + 21], _mem_patch[5 + 28], _mem_patch[5 + 35],
            _mem_patch[5 + 42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
        3'd6:
        begin
          { _mem_patch[6 + 0], _mem_patch[6 + 7], _mem_patch[6 + 14],
            _mem_patch[6 + 21], _mem_patch[6 + 28], _mem_patch[6 + 35],
            _mem_patch[6 + 42]} <= mem_patch_bram_patch_i[15*(EXPONENT+MANTISSA+1)-1:8*(EXPONENT+MANTISSA+1)];
        end
      endcase
    end
    else if(mem_patch_ddr_valid == 1'b1)
    begin
      if(_mem_patch_grp == 4'd0)
      begin
        case(_mem_patch_slice)
          1'b0:
          begin
            { _mem_patch[ 0], _mem_patch[ 1], _mem_patch[ 2], _mem_patch[ 3], 
              _mem_patch[ 4], _mem_patch[ 5], _mem_patch[ 6], _mem_patch[ 7],
              _mem_patch[ 8], _mem_patch[ 9], _mem_patch[10], _mem_patch[11],
              _mem_patch[12], _mem_patch[13], _mem_patch[14], _mem_patch[15],
              _mem_patch[16], _mem_patch[17], _mem_patch[18], _mem_patch[19], 
              _mem_patch[20], _mem_patch[21], _mem_patch[22], _mem_patch[23],
              _mem_patch[24], _mem_patch[25], _mem_patch[26], _mem_patch[27],
              _mem_patch[28], _mem_patch[29], _mem_patch[30], _mem_patch[31]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:0*DATA_WIDTH];
          end
          default:
          begin
            { _mem_patch[32], _mem_patch[33], _mem_patch[34], _mem_patch[35], 
              _mem_patch[36], _mem_patch[37], _mem_patch[38], _mem_patch[39],
              _mem_patch[40], _mem_patch[41], _mem_patch[42], _mem_patch[43],
              _mem_patch[44], _mem_patch[45], _mem_patch[46], _mem_patch[47],
              _mem_patch[48]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:15*DATA_WIDTH];
          end
        endcase
      end
    end
    
    //block d fill logic
    if(mem_patch_bram_patch_valid) 
    begin
      case (_mem_patch_bram_offset)
        3'd0:
        begin
          { _mem_patch[0 + 147], _mem_patch[0 + 154], _mem_patch[0 + 161],
            _mem_patch[0 + 168], _mem_patch[0 + 175], _mem_patch[0 + 182],
            _mem_patch[0 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
        3'd1:
        begin
          { _mem_patch[1 + 147], _mem_patch[1 + 154], _mem_patch[1 + 161],
            _mem_patch[1 + 168], _mem_patch[1 + 175], _mem_patch[1 + 182],
            _mem_patch[1 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
        3'd2:
        begin
          { _mem_patch[2 + 147], _mem_patch[2 + 154], _mem_patch[2 + 161],
            _mem_patch[2 + 168], _mem_patch[2 + 175], _mem_patch[2 + 182],
            _mem_patch[2 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
        3'd3:
        begin
          { _mem_patch[3 + 147], _mem_patch[3 + 154], _mem_patch[3 + 161],
            _mem_patch[3 + 168], _mem_patch[3 + 175], _mem_patch[3 + 182],
            _mem_patch[3 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
        3'd4:
        begin
          { _mem_patch[4 + 147], _mem_patch[4 + 154], _mem_patch[4 + 161],
            _mem_patch[4 + 168], _mem_patch[4 + 175], _mem_patch[4 + 182],
            _mem_patch[4 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
        3'd5:
        begin
          { _mem_patch[5 + 147], _mem_patch[5 + 154], _mem_patch[5 + 161],
            _mem_patch[5 + 168], _mem_patch[5 + 175], _mem_patch[5 + 182],
            _mem_patch[5 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
        3'd6:
        begin
          { _mem_patch[6 + 147], _mem_patch[6 + 154], _mem_patch[6 + 161],
            _mem_patch[6 + 168], _mem_patch[6 + 175], _mem_patch[6 + 182],
            _mem_patch[6 + 189]} <= mem_patch_bram_patch_i[8*(EXPONENT+MANTISSA+1)-1:1*(EXPONENT+MANTISSA+1)];
        end
      endcase
    end
    else if(mem_patch_ddr_valid == 1'b1)
    begin
      if(_mem_patch_grp == 4'd3)
      begin
        case(_mem_patch_slice)
          1'b0:
          begin
            { _mem_patch[147], _mem_patch[148], _mem_patch[149], _mem_patch[150], 
              _mem_patch[151], _mem_patch[152], _mem_patch[153], _mem_patch[154],
              _mem_patch[155], _mem_patch[156], _mem_patch[157], _mem_patch[158],
              _mem_patch[159], _mem_patch[160], _mem_patch[161], _mem_patch[162],
              _mem_patch[163], _mem_patch[164], _mem_patch[165], _mem_patch[166], 
              _mem_patch[167], _mem_patch[168], _mem_patch[169], _mem_patch[170],
              _mem_patch[171], _mem_patch[172], _mem_patch[173], _mem_patch[174],
              _mem_patch[175], _mem_patch[176], _mem_patch[177], _mem_patch[178] 
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:0*DATA_WIDTH];
          end
          default:
          begin
            { _mem_patch[179], _mem_patch[180], _mem_patch[181], _mem_patch[182], 
              _mem_patch[183], _mem_patch[184], _mem_patch[185], _mem_patch[186],
              _mem_patch[187], _mem_patch[188], _mem_patch[189], _mem_patch[190],
              _mem_patch[191], _mem_patch[192], _mem_patch[193], _mem_patch[194],
              _mem_patch[195]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:15*DATA_WIDTH];
          end
        endcase
      end
    end

    //block g fill logic
    if(mem_patch_bram_patch_valid) 
    begin
      case (_mem_patch_bram_offset)
        3'd0:
        begin
          _mem_patch[294] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
        3'd1:
        begin
          _mem_patch[295] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
        3'd2:
        begin
          _mem_patch[296] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
        3'd3:
        begin
          _mem_patch[297] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
        3'd4:
        begin
          _mem_patch[298] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
        3'd5:
        begin
          _mem_patch[299] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
        3'd6:
        begin
          _mem_patch[300] <= mem_patch_bram_patch_i[1*(EXPONENT+MANTISSA+1)-1:0*(EXPONENT+MANTISSA+1)];
        end
      endcase
    end
    else if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_y_eq_end && mem_patch_ddr_valid_last)
      begin
        { _mem_patch[294], _mem_patch[295], _mem_patch[296], _mem_patch[297], 
          _mem_patch[298], _mem_patch[299], _mem_patch[300] 
        } <= {(7*DATA_WIDTH){1'b0}};
      end
      else if(_mem_patch_grp == 4'd6)
      begin
        { _mem_patch[294], _mem_patch[295], _mem_patch[296], _mem_patch[297], 
          _mem_patch[298], _mem_patch[299], _mem_patch[300] 
        } <= mem_patch_ddr_i[32*DATA_WIDTH-1:25*DATA_WIDTH];
      end
    end

    //block b fill logic
    if(mem_patch_ddr_valid == 1'b1)
    begin
      if(_mem_patch_grp == 4'd1)
      begin
        case(_mem_patch_slice)
          1'b0:
          begin
            { _mem_patch[49], _mem_patch[50], _mem_patch[51], _mem_patch[52], 
              _mem_patch[53], _mem_patch[54], _mem_patch[55], _mem_patch[56],
              _mem_patch[57], _mem_patch[58], _mem_patch[59], _mem_patch[60],
              _mem_patch[61], _mem_patch[62], _mem_patch[63], _mem_patch[64],
              _mem_patch[65], _mem_patch[66], _mem_patch[67], _mem_patch[68], 
              _mem_patch[69], _mem_patch[70], _mem_patch[71], _mem_patch[72],
              _mem_patch[73], _mem_patch[74], _mem_patch[75], _mem_patch[76],
              _mem_patch[77], _mem_patch[78], _mem_patch[79], _mem_patch[80]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:0*DATA_WIDTH];
          end
         default:
          begin
            { _mem_patch[81], _mem_patch[82], _mem_patch[83], _mem_patch[84], 
              _mem_patch[85], _mem_patch[86], _mem_patch[87], _mem_patch[88],
              _mem_patch[89], _mem_patch[90], _mem_patch[91], _mem_patch[92],
              _mem_patch[93], _mem_patch[94], _mem_patch[95], _mem_patch[96],
              _mem_patch[97] 
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:15*DATA_WIDTH];
          end
        endcase
      end
    end

    //block c fill logic
    if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_x_eq_end && mem_patch_ddr_valid_last)
      begin
        {_mem_patch[98],  _mem_patch[105], _mem_patch[112], _mem_patch[119],
           _mem_patch[126], _mem_patch[133], _mem_patch[140]} <= {(7*DATA_WIDTH){1'b0}};
      end
      else if(_mem_patch_grp == 4'd2)
      begin
        case(_mem_patch_slice)
          1'b0:
          begin
            { _mem_patch[98],  _mem_patch[99],  _mem_patch[100], _mem_patch[101], 
              _mem_patch[102], _mem_patch[103], _mem_patch[104], _mem_patch[105],
              _mem_patch[106], _mem_patch[107], _mem_patch[108], _mem_patch[109],
              _mem_patch[110], _mem_patch[111], _mem_patch[112], _mem_patch[113],
              _mem_patch[114], _mem_patch[115], _mem_patch[116], _mem_patch[117], 
              _mem_patch[118], _mem_patch[119], _mem_patch[120], _mem_patch[121],
              _mem_patch[122], _mem_patch[123], _mem_patch[124], _mem_patch[125],
              _mem_patch[126], _mem_patch[127], _mem_patch[128], _mem_patch[129]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:0*DATA_WIDTH];
          end
          default:
          begin
            { _mem_patch[130], _mem_patch[131], _mem_patch[132], _mem_patch[133], 
              _mem_patch[134], _mem_patch[135], _mem_patch[136], _mem_patch[137],
              _mem_patch[138], _mem_patch[139], _mem_patch[140], _mem_patch[141],
              _mem_patch[142], _mem_patch[143], _mem_patch[144], _mem_patch[145],
              _mem_patch[146]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:15*DATA_WIDTH];
          end
        endcase
      end
    end

    //block e fill logic
    if(mem_patch_ddr_valid == 1'b1)
    begin
      if(_mem_patch_grp == 4'd4)
      begin
        case(_mem_patch_slice)
          1'b0:
          begin
            { _mem_patch[196], _mem_patch[197], _mem_patch[198], _mem_patch[199], 
              _mem_patch[200], _mem_patch[201], _mem_patch[202], _mem_patch[203],
              _mem_patch[204], _mem_patch[205], _mem_patch[206], _mem_patch[207],
              _mem_patch[208], _mem_patch[209], _mem_patch[210], _mem_patch[211],
              _mem_patch[212], _mem_patch[213], _mem_patch[214], _mem_patch[215], 
              _mem_patch[216], _mem_patch[217], _mem_patch[218], _mem_patch[219],
              _mem_patch[220], _mem_patch[221], _mem_patch[222], _mem_patch[223],
              _mem_patch[224], _mem_patch[225], _mem_patch[226], _mem_patch[227]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:0*DATA_WIDTH];
          end
          default:
          begin
            { _mem_patch[228], _mem_patch[229], _mem_patch[230], _mem_patch[231], 
              _mem_patch[232], _mem_patch[233], _mem_patch[234], _mem_patch[235],
              _mem_patch[236], _mem_patch[237], _mem_patch[238], _mem_patch[239],
              _mem_patch[240], _mem_patch[241], _mem_patch[242], _mem_patch[243],
              _mem_patch[244]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:15*DATA_WIDTH];
          end
        endcase
      end
    end

    //block f fill logic
    if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_x_eq_end && mem_patch_ddr_valid_last)
      begin
        {_mem_patch[245],  _mem_patch[252], _mem_patch[259], _mem_patch[266], 
         _mem_patch[273],  _mem_patch[280], _mem_patch[287]} <= {(7*DATA_WIDTH){1'b0}};
      end
      else if(_mem_patch_grp == 4'd5)
      begin
        case(_mem_patch_slice)
          1'b0:
          begin
            { _mem_patch[245], _mem_patch[246], _mem_patch[247], _mem_patch[248], 
              _mem_patch[249], _mem_patch[250], _mem_patch[251], _mem_patch[252],
              _mem_patch[253], _mem_patch[254], _mem_patch[255], _mem_patch[256],
              _mem_patch[257], _mem_patch[258], _mem_patch[259], _mem_patch[260],
              _mem_patch[261], _mem_patch[262], _mem_patch[263], _mem_patch[264], 
              _mem_patch[265], _mem_patch[266], _mem_patch[267], _mem_patch[268],
              _mem_patch[269], _mem_patch[270], _mem_patch[271], _mem_patch[272],
              _mem_patch[273], _mem_patch[274], _mem_patch[275], _mem_patch[276]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:0*DATA_WIDTH];
          end
          default:
          begin
            { _mem_patch[277], _mem_patch[278], _mem_patch[279], _mem_patch[280], 
              _mem_patch[281], _mem_patch[282], _mem_patch[283], _mem_patch[284],
              _mem_patch[285], _mem_patch[286], _mem_patch[287], _mem_patch[288],
              _mem_patch[289], _mem_patch[290], _mem_patch[291], _mem_patch[292],
              _mem_patch[293]
            } <= mem_patch_ddr_i[32*DATA_WIDTH-1:15*DATA_WIDTH];
          end
        endcase
      end
    end

    //block h fill logic
    if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_y_eq_end && mem_patch_ddr_valid_last)
      begin
        { _mem_patch[301], _mem_patch[302], _mem_patch[303], _mem_patch[304], 
          _mem_patch[305], _mem_patch[306], _mem_patch[307] 
        } <= {(7*DATA_WIDTH){1'b0}};
      end
      else if(_mem_patch_grp == 4'd7)
      begin
        { _mem_patch[301], _mem_patch[302], _mem_patch[303], _mem_patch[304], 
          _mem_patch[305], _mem_patch[306], _mem_patch[307] 
        } <= mem_patch_ddr_i[32*DATA_WIDTH-1:25*DATA_WIDTH];
      end
    end

    //block i fill logic
    if(mem_patch_ddr_valid == 1'b1)
    begin
      if(mem_patch_y_eq_end && mem_patch_ddr_valid_last)
      begin
        { _mem_patch[308], _mem_patch[309], _mem_patch[310], _mem_patch[311], 
          _mem_patch[312], _mem_patch[313], _mem_patch[314] 
        } <= {(7*DATA_WIDTH){1'b0}};
      end
      else if(mem_patch_x_eq_end && mem_patch_ddr_valid_last)
      begin
        {_mem_patch[308]} <= {(1*DATA_WIDTH){1'b0}};
      end      
      else if(_mem_patch_grp == 4'd8)
      begin
        { _mem_patch[308], _mem_patch[309], _mem_patch[310], _mem_patch[311], 
          _mem_patch[312], _mem_patch[313], _mem_patch[314] 
        } <= mem_patch_ddr_i[32*DATA_WIDTH-1:25*DATA_WIDTH];
      end
    end

  end

  // output
  // top row, bottom in current patch              // |j|---d---|---e---|f|
  assign mem_patch_bottom_row[16*DATA_WIDTH-1 : 0] = {_mem_patch[328],
                                                      _mem_patch[189], _mem_patch[190], _mem_patch[191], _mem_patch[192], _mem_patch[193], _mem_patch[194], _mem_patch[195],
                                                      _mem_patch[238], _mem_patch[239], _mem_patch[240], _mem_patch[241], _mem_patch[242], _mem_patch[243], _mem_patch[244],
                                                      _mem_patch[287]};
  // right micro-patch                                              |-------b/e------|h|
  assign mem_patch_right_patch[15*8*DATA_WIDTH-1:15*7*DATA_WIDTH]= {_mem_patch[55], _mem_patch[62], _mem_patch[69], _mem_patch[76], _mem_patch[83], _mem_patch[90], _mem_patch[97],
                                                                    _mem_patch[202], _mem_patch[209], _mem_patch[216], _mem_patch[223], _mem_patch[230], _mem_patch[237], _mem_patch[244],
                                                                    _mem_patch[307]};
  genvar i;
  generate
    for(i=0; i<7; i=i+1) begin : bram_right_patch
      assign mem_patch_right_patch[15*(i+1)*DATA_WIDTH-1:15*i*DATA_WIDTH] = // |-------c/f------|i|
                                                {_mem_patch[98+6-i],_mem_patch[105+6-i],_mem_patch[112+6-i],_mem_patch[119+6-i], _mem_patch[126+6-i],_mem_patch[133+6-i],_mem_patch[140+6-i],
                                                 _mem_patch[245+6-i], _mem_patch[252+6-i],_mem_patch[259+6-i],_mem_patch[266+6-i],_mem_patch[273+6-i], _mem_patch[280+6-i],_mem_patch[287+6-i],
                                                 _mem_patch[308+6-i]};
    end
  endgenerate

  // proc ram                                                      // |-----k------|
  assign mem_patch_proc_ram[16*16*DATA_WIDTH-1:16*15*DATA_WIDTH] = {_mem_patch[330],_mem_patch[331],_mem_patch[332],_mem_patch[333],
                                                                    _mem_patch[334],_mem_patch[335],_mem_patch[336],_mem_patch[337],
                                                                    _mem_patch[338],_mem_patch[339],_mem_patch[340],_mem_patch[341],
                                                                  _mem_patch[342],_mem_patch[343],_mem_patch[344],_mem_patch[345]};
  generate
    // lower half
    for(i=0; i<7; i=i+1) begin : proc_ram_upper
      assign mem_patch_proc_ram[16*(i+2)*DATA_WIDTH-1:16*(i+1)*DATA_WIDTH] = // |j|---d---|---e---|f|
                                               {_mem_patch[328-i],
                                                _mem_patch[189-7*i],_mem_patch[190-7*i],_mem_patch[191-7*i],_mem_patch[192-7*i], _mem_patch[193-7*i],_mem_patch[194-7*i],_mem_patch[195-7*i],
                                                _mem_patch[238-7*i],_mem_patch[239-7*i],_mem_patch[240-7*i],_mem_patch[241-7*i], _mem_patch[242-7*i],_mem_patch[243-7*i],_mem_patch[244-7*i],
                                                _mem_patch[287-7*i]};
    end
    // upper half
    for(i=0; i<7; i=i+1) begin : proc_ram_lower
      assign mem_patch_proc_ram[16*(i+9)*DATA_WIDTH-1:16*(i+8)*DATA_WIDTH] = // |j|---a---|---b---|c|
                                               {_mem_patch[328-7-i],
                                                _mem_patch[42-7*i], _mem_patch[43-7*i], _mem_patch[44-7*i], _mem_patch[45-7*i], _mem_patch[46-7*i], _mem_patch[47-7*i], _mem_patch[48-7*i],
                                                _mem_patch[91-7*i], _mem_patch[92-7*i], _mem_patch[93-7*i], _mem_patch[94-7*i], _mem_patch[95-7*i], _mem_patch[96-7*i], _mem_patch[97-7*i],
                                                _mem_patch[140-7*i]};
    end
  endgenerate
  assign mem_patch_proc_ram[16*DATA_WIDTH-1: 0] = // |j|---g---|---h---|i|
                                               {_mem_patch[329],_mem_patch[294],_mem_patch[295],_mem_patch[296],
                                                _mem_patch[297],_mem_patch[298],_mem_patch[299],_mem_patch[300],
                                                _mem_patch[301],_mem_patch[302],_mem_patch[303],_mem_patch[304],
                                                _mem_patch[305],_mem_patch[306],_mem_patch[307],_mem_patch[308]};

  //synopsys translate_off
  // -------------------- simulation --------------------{
  wire [31:0] _mem_patch_top_row01,_mem_patch_top_row02,_mem_patch_top_row03,_mem_patch_top_row04,_mem_patch_top_row05,_mem_patch_top_row06,_mem_patch_top_row07,_mem_patch_top_row08,
              _mem_patch_top_row09,_mem_patch_top_row10,_mem_patch_top_row11,_mem_patch_top_row12,_mem_patch_top_row13,_mem_patch_top_row14,_mem_patch_top_row15,_mem_patch_top_row16;
  assign _mem_patch_top_row01 = _mem_patch[328];
  assign _mem_patch_top_row02 = _mem_patch[91];
  assign _mem_patch_top_row03 = _mem_patch[92];
  assign _mem_patch_top_row04 = _mem_patch[93];
  assign _mem_patch_top_row05 = _mem_patch[94];
  assign _mem_patch_top_row06 = _mem_patch[95];
  assign _mem_patch_top_row07 = _mem_patch[96];
  assign _mem_patch_top_row08 = _mem_patch[97];
  assign _mem_patch_top_row09 = _mem_patch[189];
  assign _mem_patch_top_row10 = _mem_patch[190];
  assign _mem_patch_top_row11 = _mem_patch[191];
  assign _mem_patch_top_row12 = _mem_patch[192];
  assign _mem_patch_top_row13 = _mem_patch[193];
  assign _mem_patch_top_row14 = _mem_patch[194];
  assign _mem_patch_top_row15 = _mem_patch[329]; // 195
  assign _mem_patch_top_row16 = _mem_patch[345]; // 287
  // -------------------- simulation --------------------}
  //synopsys translate_on

endmodule
