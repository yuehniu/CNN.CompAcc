set_clock_groups -name async_axi_ddr_clks -asynchronous -group [get_clocks -include_generated_clocks clk_pll_i] -group [get_clocks -include_generated_clocks clk_125mhz]


connect_debug_port dbg_hub/clk [get_nets u_ila_1_CLK]


connect_debug_port u_ila_0/probe30 [get_nets [list accel/vgg_net/vgg_end0]]


connect_debug_port u_ila_0/probe2 [get_nets [list {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[0]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[1]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[2]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[3]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[4]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[5]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[6]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[7]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[8]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[9]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[10]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[11]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[12]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[13]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[14]} {accel/vgg_net/conv_layers/conv_layer/cnn_conv/_data_from_pe_array0[15]}]]



