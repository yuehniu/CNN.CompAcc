%% tranform conv layer parameter using svd
clear all
clc
%% pre-parameter setting
netType = ['AlexNet'];
model = ['bvlc_alexnet_'];
caffemodelPrefix = ['bvlc_alexnet_'];
speedRatio = '2x';
rankFlag = '_rank';

prevLayer = 'ft_conv3';
prevLayers = 'conv3_conv4_conv5_';
curLayer = 'conv2';
layerList = {'conv2'};
cutPoint = [128/2];
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
netWeights = [modelDir 'ft_alexnet_' prevLayers, speedRatio, rankFlag, '.caffemodel'];
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
netWeights = [modelDir '../', prevLayer, '/ft_alexnet_', prevLayers, speedRatio, rankFlag ,'.caffemodel'];
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
  [UU1, SS1, VV1] = svd(kernel(:,1:kernel_size(4)/2));
  disp '\nsvd done'
  disp 'visualize sigular value'
  plot(diag(SS1))
  UU1 = UU1(:, 1:cutPoint(i)) * sqrt(SS1(1:cutPoint(i), 1:cutPoint(i)));
  VV1 = sqrt(SS1(1:cutPoint(i), 1:cutPoint(i))) * VV1(:, 1:cutPoint(i))';
  
  [UU2, SS2, VV2] = svd(kernel(:,kernel_size(4)/2+1:kernel_size(4)));
  disp '\nsvd done'
  disp 'visualize sigular value'
  plot(diag(SS1))
  UU2 = UU2(:, 1:cutPoint(i)) * sqrt(SS2(1:cutPoint(i), 1:cutPoint(i)));
  VV2 = sqrt(SS2(1:cutPoint(i), 1:cutPoint(i))) * VV2(:, 1:cutPoint(i))';
  bias = load([matDir model layerList{i}, '_finetune' '_bias.mat']);
  bias = bias.bias;
  UU = [UU1, UU2];
  UU = reshape(...
    UU,...
    kernel_size(1), kernel_size(2), kernel_size(3),...
    2*cutPoint(i)...
  );
  VV = [VV1, VV2];
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
net.save([caffemodelPrefix, '', curLayer, '_', prevLayers, speedRatio, rankFlag, '.caffemodel']);
