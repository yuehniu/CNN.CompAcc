# VGG_verilog
This project is a VGG hardware accelerator design.
Extension design for other CNN net will be added in the future

# fully-connection layer
Fully-connected layer read input data from SRAM, 
![fully-connected layer hardware structure](/home/niuyue/cnn_vgg_proj/git-proj/VGG_verilog/design_flow/fully_connected_structure.jpg)
Here, we use only one multiplier to do all fully-connected computation, in order to synchronize with convolution operation in the whole pipeline structure. 

## Run process
In order to reduce the times for reading data from SRAM, we demand that do computation for another input data until all the computation for current input is finished over all output neurals. As a example, for fc6 in VGGNet-16, which consists 25088 inputs and 4096 outputs, we first do all the 4096 multiplication computations associated to the first input, and then do the next 4096 multiplications associated to the next input. On the output side, there are 4096 output register to register the accumulated result for current time, and wait for the next result associated to this output neuron.

## ip bram memory arrangement
![ip_bram_arrangement](/home/niuyue/cnn_vgg_proj/git-proj/VGG_verilog/design_flow/ip_bram_arrange.jpg)
Since data output from **conv_op** is $32 * FW$ during one clock cycle, correspondingly, data width in bram is $32 * FW$. Furthermore, **conv_op** can process $32$ output channels at one time. After first $32$ output channels is done, another $32$ output channel will start to be processed. So in this design, we call data in $32$ output channels **sector**. for ***fc6*** layer in VGGNet-16, there are $16$ *sectors*.

So in real realization, we use $pixel\\_pos$, $channel\\_pos$ and $sec\\_pos$ to locate the pixel data we need. $pixel\\_pos$ indicate the pixel position for one $7 * 7$ output channel block, $channel\\_pos$ indicate which channel we are looking for, $sec\\_pos$ indicate which **sector** we are.