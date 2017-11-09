%% tranform conv layer parameter using svd
clear all
clc
%% pre-parameter setting
vgg_type = '16';
netType = ['VGGNet',vgg_type, '_nonorder'];
model = ['vgg_', vgg_type ,'_'];
caffemodelPrefix = ['VGG_ILSVRC_', vgg_type];
speedRatio = '_3x';
rankFlag = '_rank';

prevLayer = 'ft_conv2';
prevLayers = 'conv2_conv3_conv4_conv5_fc6_256';
curLayer = 'conv1';
layerList = {'conv1_2'};
cutPoint = [21];
flagVisual = false;
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

modelDir = ['/home/Data/caffe/caffemodel/rank_selection/', netType, '/', prevLayer, '/'];
% model_dir = '/home/niuyue/caffe-master/models/finetune_vggnet/ft_conv2/';
netModel = [modelDir 'deploy_', prevLayers, speedRatio, rankFlag, '.prototxt'];
netWeights = [modelDir 'train_vgg_' prevLayers, speedRatio, rankFlag, '.caffemodel'];
phase = 'test';

if ~exist(netWeights, 'file')
  error('Please Download vggnet model from internet');
end
net = caffe.Net(netModel, netWeights, phase);

%% extract kernel data and save to file first
matDir = ['/home/Data/caffe/matdata/rank_selection/', netType, '/'];

colorList = ['b', 'r', 'k'];
numLayers = size(layerList, 2);
for i = 1 : numLayers
  curLayerName = layerList{i};
  kernel = net.params(curLayerName, 1).get_data();
  save([matDir model curLayerName '_finetune' '.mat'], 'kernel')
  bias = net.params(curLayerName, 2).get_data();
  save([matDir model curLayerName '_finetune' '_bias.mat'], 'bias');
end

%% visualize convolution kernel
figure(1)
hold on
for i = 1:numLayers
  curLayer = layerList{i};
  cur_finetune_kernel = load([matDir model curLayer '_finetune' '.mat']);
  cur_finetune_kernel = cur_finetune_kernel.kernel;
  sz = size(cur_finetune_kernel);
  cur_finetune_kernel = reshape(...
    cur_finetune_kernel, ...
    sz(1)*sz(2)*sz(3),...
    sz(4));
  cur_kernel_1 = net.params([curLayer, '_1'], 1).get_data();
  cur_kernel_2 = net.params([curLayer, '_2'], 1).get_data();
%   cur_kernel = cur_kernel.kernel;
  sz = size(cur_kernel_1);
  cur_kernel_1 = reshape(...
    cur_kernel_1, ...
    sz(1)*sz(2)*sz(3),...
    sz(4));
  sz = size(cur_kernel_2);
  cur_kernel_2 = reshape(...
    cur_kernel_2, ...
    sz(1)*sz(2)*sz(3),...
    sz(4));
  cur_kernel = cur_kernel_1 * cur_kernel_2;
  [UU_finetune, SS_finetune, VV_finetune] = svd(cur_finetune_kernel);
  [UU, SS, VV] = svd(cur_kernel);
  
  plot(diag(SS_finetune), 'b');
  plot(diag(SS), 'r--');
  
  max_s = max(diag(SS))
  plot(diag(SS).^2, 'k--');
end

%% do svd and load to new caffeNet
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

modelDir = ['/home/Data/caffe/caffemodel/rank_selection/', ...
             netType, '/ft_', curLayer, '/'];
% model_dir = '/home/niuyue/caffe-master/models/finetune_vggnet/ft_conv1/';
netModel = [modelDir 'deploy_', curLayer, '_', prevLayers, speedRatio, rankFlag,'.prototxt'];
netWeights = [modelDir '../', prevLayer, '/train_vgg_', prevLayers, speedRatio, rankFlag ,'.caffemodel'];
phase = 'test';

if ~exist(netWeights, 'file')
  error('Please Download vggnet model from internet');
end
net = caffe.Net(netModel, netWeights, phase);

% load matdata
matDir = ['/home/Data/caffe/matdata/rank_selection/', netType ,'/'];
numLayers = size(layerList, 2);

figure(1)
hold on
for i = 1 : numLayers
  kernel = load([matDir model layerList{i} '_finetune' '.mat']);
  kernel = kernel.kernel;
  kernel_size = size(kernel);
  disp_str = ['load ' layerList{i}, ' kernel done.'];
  disp(disp_str)
  kernel = reshape(...
    kernel,...
    kernel_size(1)*kernel_size(2)*kernel_size(3),...
    kernel_size(4)...
  );
  [UU, SS, VV] = svd(kernel);
  disp '\nsvd done'
  disp 'visualize sigular value'
  plot(diag(SS))
  UU = UU(:, 1:cutPoint(i)) * sqrt(SS(1:cutPoint(i), 1:cutPoint(i)));
  VV = sqrt(SS(1:cutPoint(i), 1:cutPoint(i))) * VV(:, 1:cutPoint(i))';
  bias = load([matDir model layerList{i}, '_finetune' '_bias.mat']);
  bias = bias.bias;
  UU = reshape(...
    UU,...
    kernel_size(1), kernel_size(2), kernel_size(3),...
    cutPoint(i)...
  );
  VV = reshape(...
    VV, ...
    1, 1, cutPoint(i), ...
    kernel_size(4)...
  );
  net.params([layerList{i}, '_1'], 1).set_data(UU);
  net.params([layerList{i}, '_2'], 1).set_data(VV);
  net.params([layerList{i}, '_2'], 2).set_data(bias);
  
  disp_str = ['load new kernel for ' layerList{i} ' done'];
  disp(disp_str)
end

%% save net
net.save([caffemodelPrefix, '_', curLayer, '_', prevLayers, speedRatio, rankFlag, '.caffemodel']);
