//*****************************************************************************
// (c) Copyright 2009 - 2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 4.0
//  \   \         Application        : MIG
//  /   /         Filename           : example_top.v
// /___/   /\     Date Last Modified : $Date: 2011/06/02 08:35:03 $
// \   \  /  \    Date Created       : Tue Sept 21 2010
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : DDR3 SDRAM
// Purpose          :
//   Top-level  module. This module serves as an example,
//   and allows the user to synthesize a self-contained design,
//   which they can be used to test their hardware.
//   In addition to the memory controller, the module instantiates:
//     1. Synthesizable testbench - used to model user's backend logic
//        and generate different traffic patterns
// Reference        :
// Revision History :
//*****************************************************************************

//`define SKIP_CALIB
`timescale 1ps/1ps

module rd_wr_interface #
  (
    parameter APP_DATA_WIDTH = 512,
    parameter DATA_NUM_BITS  = 16,
    `include "mig.inc"
  )
  (
   output clk_o,
   output rst_o,

   // Inouts
   inout [63:0]     ddr3_dq,
   inout [7:0]      ddr3_dqs_n,
   inout [7:0]      ddr3_dqs_p,

   // Outputs
   output [15:0]    ddr3_addr,
   output [2:0]     ddr3_ba,
   output           ddr3_ras_n,
   output           ddr3_cas_n,
   output           ddr3_we_n,
   output           ddr3_reset_n,
   output [0:0]     ddr3_ck_p,
   output [0:0]     ddr3_ck_n,
   output [0:0]     ddr3_cke,
   
   output [0:0]     ddr3_cs_n,
   
   
   output [0:0]     ddr3_odt,
   

   // user design port
   input                       wr_en_i,
   input                       rd_en_i,
   input  [DATA_NUM_BITS-1:0]  wr_burst_num_i,
   output                      fetch_data_en_o,
   input  [ADDR_WIDTH-1:0]     wr_start_addr_i,
   input  [APP_DATA_WIDTH-1:0] wr_data_i,
   output                      wr_ddr_done_o,
   input  [ADDR_WIDTH-1:0]     rd_start_addr_i,
   input  [DATA_NUM_BITS-1:0]  rd_burst_num_i,
   output                      rd_ddr_done_o,
   output                      rd_data_valid_o,
   output [APP_DATA_WIDTH-1:0] rd_data_o,

   
   // Differential system clocks
   input            sys_clk_p,
   input            sys_clk_n,
   

   //output           tg_compare_error,
   output           init_calib_complete,

   // System reset - Default polarity of sys_rst pin is Active Low.
   // System reset polarity will change based on the option 
   // selected in GUI.
   input            sys_rst
   );

  function integer clogb2 (input integer size);
    begin
      size = size - 1;
      for (clogb2=1; size>1; clogb2=clogb2+1)
        size = size >> 1;
    end
  endfunction // clogb2

  function integer STR_TO_INT;
    input [7:0] in;
    begin
      if(in == "8")
        STR_TO_INT = 8;
      else if(in == "4")
        STR_TO_INT = 4;
      else
        STR_TO_INT = 0;
    end
  endfunction

  localparam DATA_WIDTH            = 64;
  localparam RANK_WIDTH = clogb2(RANKS);
  localparam PAYLOAD_WIDTH         = (ECC_TEST == "OFF") ? DATA_WIDTH : DQ_WIDTH;
  localparam BURST_LENGTH          = STR_TO_INT(BURST_MODE);
  // localparam APP_DATA_WIDTH        = 2 * nCK_PER_CLK * PAYLOAD_WIDTH;
  localparam APP_MASK_WIDTH        = APP_DATA_WIDTH / 8;

  //***************************************************************************
  // Traffic Gen related parameters (derived)
  //***************************************************************************
  localparam  TG_ADDR_WIDTH = ((CS_WIDTH == 1) ? 0 : RANK_WIDTH)
                                 + BANK_WIDTH + ROW_WIDTH + COL_WIDTH;
  localparam MASK_SIZE             = DATA_WIDTH/8;
      

  // Wire declarations
  wire [ADDR_WIDTH-1:0]                 app_addr;
  wire [2:0]                            app_cmd;
  wire                                  app_en;
  wire                                  app_rdy;
  wire [APP_DATA_WIDTH-1:0]             app_rd_data;
  wire                                  app_rd_data_end;
  wire                                  app_rd_data_valid;
  wire [APP_DATA_WIDTH-1:0]             app_wdf_data;
  wire                                  app_wdf_end;
  wire [APP_MASK_WIDTH-1:0]             app_wdf_mask;
  wire                                  app_wdf_rdy;
  wire                                  app_sr_active;
  wire                                  app_ref_ack;
  wire                                  app_zq_ack;
  wire                                  app_wdf_wren;
  wire                                  clk;
  wire                                  rst;

      
// Start of User Design top instance
//***************************************************************************
// The User design is instantiated below. The memory interface ports are
// connected to the top-level and the application interface ports are
// connected to the traffic generator module. This provides a reference
// for connecting the memory controller to system.
//***************************************************************************

  mig_7series_0 u_mig_7series_0
      (
       
       
// Memory interface ports
       .ddr3_addr                      (ddr3_addr),
       .ddr3_ba                        (ddr3_ba),
       .ddr3_cas_n                     (ddr3_cas_n),
       .ddr3_ck_n                      (ddr3_ck_n),
       .ddr3_ck_p                      (ddr3_ck_p),
       .ddr3_cke                       (ddr3_cke),
       .ddr3_ras_n                     (ddr3_ras_n),
       .ddr3_we_n                      (ddr3_we_n),
       .ddr3_dq                        (ddr3_dq),
       .ddr3_dqs_n                     (ddr3_dqs_n),
       .ddr3_dqs_p                     (ddr3_dqs_p),
       .ddr3_reset_n                   (ddr3_reset_n),
       .init_calib_complete            (init_calib_complete),
      
       .ddr3_cs_n                      (ddr3_cs_n),
       .ddr3_odt                       (ddr3_odt),
// Application interface ports
       .app_addr                       (app_addr),
       .app_cmd                        (app_cmd),
       .app_en                         (app_en),
       .app_wdf_data                   (app_wdf_data),
       .app_wdf_end                    (app_wdf_end),
       .app_wdf_wren                   (app_wdf_wren),
       .app_rd_data                    (app_rd_data),
       .app_rd_data_end                (app_rd_data_end),
       .app_rd_data_valid              (app_rd_data_valid),
       .app_rdy                        (app_rdy),
       .app_wdf_rdy                    (app_wdf_rdy),
       .app_sr_req                     (1'b0),
       .app_ref_req                    (1'b0),
       .app_zq_req                     (1'b0),
       .app_sr_active                  (app_sr_active),
       .app_ref_ack                    (app_ref_ack),
       .app_zq_ack                     (app_zq_ack),
       .ui_clk                         (clk),
       .ui_clk_sync_rst                (rst),
      
// System Clock Ports
       .sys_clk_p                      (sys_clk_p),
       .sys_clk_n                      (sys_clk_n),
       .device_temp                    (device_temp),
      
       .sys_rst                        (sys_rst)
       );
// End of User Design top instance

    /*
    ddr_model
    #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(APP_DATA_WIDTH)
    )
    ddr_model_U
    (
      .init_calib_complete_o(init_calib_complete),
      .app_rdy_o            (app_rdy            ),
      .app_en_i             (app_en             ),
      .app_cmd_i            (app_cmd            ),
      .app_addr_i           (app_addr           ),
      .app_wdf_rdy_o        (app_wdf_rdy        ),
      .app_wdf_wren_i       (app_wdf_wren       ),
      .app_wdf_end_i        (app_wdf_end        ),
      .app_wdf_data_i       (app_wdf_data       ),
      .app_rd_data_valid_o  (app_rd_data_valid  ),
      .app_rd_data_o        (app_rd_data        ),
      .app_rd_data_end_o    (app_rd_data_end    ),

      .ui_clk(clk),
      .ui_rst(rst)
    );
    */

    /*
    ddr_model
    ddr_model_U
    (
      .init_calib_complete(init_calib_complete),
      .ddr_rdy            (app_rdy            ),
      .ddr_en             (app_en             ),
      .ddr_cmd            (app_cmd            ),
      .ddr_addr           (app_addr           ),
      .ddr_wdf_rdy        (app_wdf_rdy        ),
      .ddr_wdf_wren       (app_wdf_wren       ),
      .ddr_wdf_end        (app_wdf_end        ),
      .ddr_wdf_mask       (64'd0              ),
      .ddr_wdf_data       (app_wdf_data       ),
      .ddr_rd_data_valid  (app_rd_data_valid  ),
      .ddr_rd_data        (app_rd_data        ),
      .ddr_rd_data_end    (app_rd_data_end    ),

      .ui_clk(clk),
      .ui_rst(rst)
    );
    */

    rd_wr_path
    #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .DATA_WIDTH   (APP_DATA_WIDTH),
        .DATA_NUM_BITS(DATA_NUM_BITS)
    )
    rd_wr_path_U
    (
        .clk_i(clk),
        .rst_i(rst),
        .wr_en_i              (wr_en_i            ),
        .rd_en_i              (rd_en_i            ),
        .init_calib_complete_i(init_calib_complete),
        .app_rdy_i            (app_rdy            ),
        .app_wdf_rdy_i        (app_wdf_rdy        ),
        .app_en_o             (app_en             ),
        .app_cmd_o            (app_cmd            ),
        .app_addr_o           (app_addr           ),
        .wr_burst_num_i       (wr_burst_num_i     ),
        .wr_start_addr_i      (wr_start_addr_i    ),
        .wr_data_i            (wr_data_i          ),
        .app_wdf_wren_o       (app_wdf_wren       ),
        .app_wdf_data_o       (app_wdf_data       ),
        .app_wdf_end_o        (app_wdf_end        ),
        .fetch_data_en_o      (fetch_data_en_o    ),
        .wr_ddr_done_o        (wr_ddr_done_o      ),
        .rd_burst_num_i       (rd_burst_num_i     ),
        .rd_start_addr_i      (rd_start_addr_i    ),
        .app_rd_data_valid_i  (app_rd_data_valid  ),
        .app_rd_data_i        (app_rd_data        ),
        .app_rd_data_end_i    (app_rd_data_end    ),
        .rd_ddr_done_o        (rd_ddr_done_o      ),
        .rd_data_valid_o      (rd_data_valid_o    ),
        .rd_data_o            (rd_data_o          )
    );

    assign clk_o = clk;
    assign rst_o = rst;
endmodule
