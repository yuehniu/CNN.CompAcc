%% tranform conv layer parameter using svd
clear all

%% load net first

use_gpu = 0;

if exist('../+caffe', 'dir')
  addpath('..');
else
  error('Please run this demo from caffe/matlab/demo');
end

if exist('use_gpu', 'var') && use_gpu
  caffe.set_mode_gpu();
  gpu_id = 0;
  caffe.set_device(gpu_id)
else
  caffe.set_mode_cpu()
end

% model_dir = '../../models/bvlc_vggnet/';
% net_model = [model_dir 'deploy.prototxt'];
% net_weights = [model_dir 'VGG_ILSVRC_16_layers.caffemodel'];
model_dir = '../../models/bvlc_alexnet/';
net_model = [model_dir 'deploy.prototxt'];
net_weights = [model_dir 'bvlc_alexnet.caffemodel'];
phase = 'test';

if ~exist(net_weights, 'file')
  error('Please Download vggnet model from internet');
end
net = caffe.Net(net_model, net_weights, phase);

%% extract kernel data and save to file first
layer_list = {'conv2'};
color_list = ['b', 'r', 'k'];
cur_layer = layer_list{1};
kernel_orig = net.params(cur_layer, 1).get_data();

%% do svd and load to new caffeNet

% load matdata
i = 1;
% layer_list = {'conv1_2'};
num_layers = size(layer_list, 2);
cut_point = 256;
% model_prefix = 'VGG_ILSVRC_16_layers_';
model_prefix = 'bvlc_alexnet_';
% kernel_orig = double(kernel_orig);
while cut_point >= 0
    kernel_size = size(kernel_orig);
    kernel = reshape(...
    kernel_orig,...
    kernel_size(1)*kernel_size(2)*kernel_size(3),...
    kernel_size(4)...
    );
    [UU, SS, VV] = svd(kernel);
    disp 'svd done'
    disp 'visualize sigular value'
    plot(diag(SS))
    UU = UU(:, 1:cut_point) * sqrt(SS(1:cut_point, 1:cut_point));
    VV = sqrt(SS(1:cut_point, 1:cut_point)) * VV(:, 1:cut_point)';
    kernel_svd = UU * VV;
    kernel_svd = reshape(...
    kernel_svd,...
    kernel_size(1), kernel_size(2), kernel_size(3),...
    kernel_size(4)...
    );
    net.params([layer_list{i}], 1).set_data(kernel_svd);

    disp_str = ['load new kernel for' layer_list{i} ' done'];
    disp(disp_str);
    cur_model_name = [model_prefix, layer_list{i}, ...
                      '_svd_', ...
                      num2str(cut_point), ...
                      '.caffemodel'];
    disp('save net model...');
    net.save(cur_model_name);
    
    cut_point = cut_point - 4;
end
%% save net
%net.save('VGG_ILSVRC_16_layers_conv2_2_svd_68.caffemodel');

%% kernel importance
plot(diag(SS) / sum(diag(SS)))
%% connection importance
w_fc6 = net.params('fc6',1).get_data();
[U,SS,V] = svd(w_fc6); 
plot(diag(SS) / sum(diag(SS)))