%% transform original caffemodel to self-network caffemodel
clear all;
clc
%% read original caffemodel first
% im = imread('../../examples/images/cat.jpg');
im = imread('bird1.jpg');
use_gpu = 0;

% Add caffe/matlab to you Matlab search PATH to use matcaffe
if exist('../+caffe', 'dir')
  addpath('..');
else
  error('Please run this demo from caffe/matlab/demo');
end

% Set caffe mode
if exist('use_gpu', 'var') && use_gpu
  caffe.set_mode_gpu();
  gpu_id = 0;  % we will use the first gpu in this demo
  caffe.set_device(gpu_id);
else
  caffe.set_mode_cpu();
end

% Initialize the network using BVLC CaffeNet for image classification
% Weights (parameter) file needs to be downloaded from Model Zoo.
num_prefix_prev = '';
% model_dir = '../../models/finetune_vggnet/ft_fc7/';
model_dir = '../../models/bvlc_vggnet/';
% net_model = [model_dir 'deploy_fc7_' num_prefix_prev '.prototxt'];
net_model = [model_dir 'deploy.prototxt'];
% net_weights = [model_dir 'train_vgg_fc7_' num_prefix_prev '.caffemodel'];
net_weights = [model_dir 'VGG_ILSVRC_16_layers.caffemodel'];
phase = 'test'; % run with phase test (so that dropout isn't applied)
if ~exist(net_weights, 'file')
  error('Please download CaffeNet from Model Zoo before you run this demo');
end
net = caffe.Net(net_model, net_weights, phase);

% w_fc6_1 = net.layers(['fc7_' num_prefix_prev '_1']).params(1).get_data();
% w_fc6_2 = net.layers(['fc7_' num_prefix_prev '_2']).params(1).get_data();
% w_fc6 = w_fc6_1 * w_fc6_2;
% b_fc6 = net.layers(['fc7_' num_prefix_prev '_2']).params(2).get_data();
w_fc6 = net.layers('fc6').params(1).get_data();
b_fc6 = net.layers('fc6').params(2).get_data();
w_fc7 = net.layers('fc7').params(1).get_data();
b_fc7 = net.layers('fc7').params(2).get_data();

disp('get sinular value for fc6_layer');
% save original parameter for innerproduct
% save('matdata/vgg_19_w_fc6_finetune.mat', 'w_fc6');
% save('matdata/vgg_19_b_fc6_finetune.mat', 'b_fc6');

%% load original innerproduct parameter and 
%  transform to self-network parameter
% clear all
% load('matdata/vgg_19_w_fc6_finetune.mat'); 
% load('matdata/vgg_19_b_fc6_finetune.mat');

disp('SVD for fc6 layer...')
tic;
start_cut_point = 256;
num_prefix_cur = num2str(start_cut_point); 
[U,S,V] = svd(w_fc6); 
[row,col] = size(S);
S(start_cut_point+1:row,:) = zeros(row-start_cut_point,col);
U_cut = U(:,1:start_cut_point);
S_cut = S(1:start_cut_point,1:start_cut_point);
V_cut = V(:,1:start_cut_point);
S_cut_sqrt = sqrt(S_cut);
U6_cut_comb = U_cut * S_cut;
V6_cut_comb = V_cut';
toc;

disp('SVD for fc7 layer...')
tic;
start_cut_point = 256;
num_prefix_cur = num2str(start_cut_point); 
[U,S,V] = svd(w_fc7); 
[row,col] = size(S);
S(start_cut_point+1:row,:) = zeros(row-start_cut_point,col);
U_cut = U(:,1:start_cut_point);
S_cut = S(1:start_cut_point,1:start_cut_point);
V_cut = V(:,1:start_cut_point);
S_cut_sqrt = sqrt(S_cut);
U7_cut_comb = U_cut * S_cut;
V7_cut_comb = V_cut';
toc;

% im = imread('../../examples/images/cat.jpg');
im = imread('bird1.jpg');
use_gpu = 0;


% Add caffe/matlab to you Matlab search PATH to use matcaffe
if exist('../+caffe', 'dir')
  addpath('..');
else
  error('Please run this demo from caffe/matlab/demo');
end

% Set caffe mode
if exist('use_gpu', 'var') && use_gpu
  caffe.set_mode_gpu();
  gpu_id = 0;  % we will use the first gpu in this demo
  caffe.set_device(gpu_id);
else
  caffe.set_mode_cpu();
end

% Initialize the network using BVLC CaffeNet for image classification
% Weights (parameter) file needs to be downloaded from Model Zoo.
model_dir = '../../models/finetune_vggnet/ft_fc7/';
net_model = [model_dir 'deploy_fc7_' num_prefix_cur '.prototxt'];
net_weights = [model_dir 'train_vgg_fc7_' num_prefix_prev '.caffemodel'];
model_dir = '../../models/bvlc_vggnet/';
net_model = [model_dir 'deploy_fc6_256_fc7_256', '.prototxt'];
net_weights = [model_dir 'VGG_ILSVRC_16_layers.caffemodel'];
phase = 'test'; % run with phase test (so that dropout isn't applied)
if ~exist(net_weights, 'file')
  error('Please download CaffeNet from Model Zoo before you run this demo');
end
net = caffe.Net(net_model, net_weights, phase);

% resture fc layer param
net.params(['fc6_1'], 1).set_data(U6_cut_comb);
net.params(['fc6_2'], 1).set_data(V6_cut_comb);
net.params(['fc6_2'], 2).set_data(b_fc6);
net.params(['fc7_1'], 1).set_data(U7_cut_comb);
net.params(['fc7_2'], 1).set_data(V7_cut_comb);
net.params(['fc7_2'], 2).set_data(b_fc7);

%% run test
tic;
input_data = {prepare_image(im)};
toc;
scores = net.forward(input_data);
scores = scores{1};
scores = mean(scores, 2);  % take average scores over 10 crops

% top-1 and top-5 label
[~, maxlabel] = max(scores);

[I_sort, maxlabel_sort] = sort(scores,'descend');
I_5 = I_sort(1:5);
maxlabel_5 = maxlabel_sort(1:5);

%% save net
net.save(['VGG_ILSVRC_16_layers_fc6_256_fc7_256', '.caffemodel']);