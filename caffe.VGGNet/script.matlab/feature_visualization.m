clear all;

im = imread('../../examples/images/cat.jpg');
% im = imread('bird1.jpg');
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
model_dir = '../../models/bvlc_vggnet/';
net_model = [model_dir 'deploy.prototxt'];
net_weights = [model_dir 'VGG_ILSVRC_16_layers.caffemodel'];
phase = 'test'; % run with phase test (so that dropout isn't applied)
if ~exist(net_weights, 'file')
  error('Please download CaffeNet from Model Zoo before you run this demo');
end

%% original caffe validate
% Initialize a network
net = caffe.Net(net_model, net_weights, phase);

% prepare oversampled input
% input_data is Height x Width x Channel x Num
tic;
input_data = {prepare_image(im)};
toc;

% do forward pass to get scores
% scores are now Channels x Num, where Channels == 1000
disp('orignal caffe validate');
tic;
% The net forward function. It takes in a cell array of N-D arrays
% (where N == 4 here) containing data of input blob(s) and outputs a cell
% array containing data from output blob(s)
scores = net.forward(input_data);
toc;

%% visualize feature map in binarizatin-form
conv_name = {'conv1_1', 'conv1_2', ...
             'conv2_1', 'conv2_2', ...
             'conv3_1', 'conv3_2', 'conv3_3', ...
             'conv4_1', 'conv4_2', 'conv4_3', ...
             'conv5_1', 'conv5_2', 'conv5_3'};
nonzeros = 0;
samples = 0;
one_kernel = ones(1, 3);
% calcute zero 3x3 block rate
for j = 1:12
    feature_map = net.blobs(cell2mat(conv_name(j))).get_data;
    feature_map_binary = feature_map > 0;
    shape = size(feature_map_binary);

    for i = 1:shape(3)
        cur_feature = single(feature_map_binary(:, :, i, 1));
        cur_feature_1conv = conv2(cur_feature', one_kernel, 'same');
        cur_feature_1conv = cur_feature_1conv > 0;
        nonzeros = nonzeros + sum(sum(cur_feature_1conv));
        samples = samples + shape(1) * shape(2);
%         figure(i)
%         imshow(cur_feature_1conv);
    end
end
nonzero_rate = nonzeros / samples

%% visualization binarization feature map
feature_map = net.blobs('conv1_1').get_data;
% feature_map_binary = feature_map > 0;
feature_map_binary = feature_map;
shape = size(feature_map_binary);
one_kernel = ones(1, 1);

for i = 1:shape(3)
    cur_feature = single(feature_map_binary(:, :, i, 1));
%     cur_feature_1conv = conv2(cur_feature', one_kernel, 'same');
%     cur_feature_1conv = cur_feature_1conv > 0;
%     nonzeros = nonzeros + sum(sum(cur_feature_1conv));
%     samples = samples + shape(1) * shape(2);
    figure(i)
%     subplot(121)
%     imshow(cur_feature_1conv);
%     subplot(122)
    imshow(cur_feature', [0, 255], 'border', 'tight');
end

%% output feature map redundancy
subplot('position', [0 0 0.5 0.45])
cur_feature = imadjust(uint8(feature_map_binary(:, :, 1, 1)));
imshow(cur_feature', [0, 255], 'border', 'tight');
subplot('position', [0 0.5 0.5 0.45])
cur_feature = imadjust(uint8(feature_map_binary(:, :, 4, 1)));
imshow(cur_feature', [0, 255], 'border', 'tight');
subplot('position', [0.5 0 0.5 0.45])
cur_feature = imadjust(uint8(feature_map_binary(:, :, 5, 1)));
imshow(cur_feature', [0, 255], 'border', 'tight');
subplot('position', [0.5 0.5 0.5 0.45])
cur_feature = imadjust(uint8(feature_map_binary(:, :, 11, 1)));
imshow(cur_feature', [0, 255], 'border', 'tight');

%% correlation between output feature map
corr_matrix = zeros(shape(3));
for i = 1:shape(3)
    for j = 1:shape(3)
        cur_feature1 = double(feature_map(:, :, i, 1));
        cur_feature2 = double(feature_map(:, :, j, 1));
        cur_corr = corrcoef(cur_feature1, cur_feature2);
        corr_matrix(i, j) = cur_corr(1,2);
    end
end
imshow(abs(corr_matrix)>0.2,'border', 'tight')

%%
for i = 1:64
    corr_matrix(i,i) = 0;
end
i = 1;

for level = 0:0.1:1
    num_level(i) = sum(sum((abs(corr_matrix)>level))~=0);
    i = i + 1;
end
figure
plot([0:0.1:1], num_level, 'LineWidth',2)
xlabel('correlation level','FontSize', 15, 'FontWeight', 'bold');
ylabel('num of pairs', 'FontSize', 15, 'FontWeight', 'bold');