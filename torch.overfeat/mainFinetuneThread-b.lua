--
--  Copyright (c) 2014, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.
--
require 'torch'
require 'cutorch'
require 'paths'
require 'xlua'
require 'optim'
require 'nn'

torch.setdefaulttensortype('torch.FloatTensor')

local opts = paths.dofile('opts.lua')

opt = opts.parse(arg)
opt.netType = 'overfeat'
opt.data = '/data/niuy/ml.DataSet/ILSVRC2012/'
opt.cropSize = 221
opt.retrain = "model.t7"
-- opt.optimState = "imagenet/checkpoint/overfeat/TueOct1713:23:142017/optimState_5.t7"
opt.nEpochs = 5
opt.epochSize = 5000

nClasses = opt.nClasses

paths.dofile('util.lua')
paths.dofile('model.lua')
opt.imageSize = model.imageSize or opt.imageSize
opt.imageCrop = model.imageCrop or opt.imageCrop

print(opt)

cutorch.setDevice(opt.GPU) -- by default, use GPU 1
torch.manualSeed(opt.manualSeed)

print('Saving everything to: ' .. opt.save)
os.execute('mkdir -p ' .. opt.save)

paths.dofile('data.lua')
paths.dofile('finetuneOverfeat.lua')
paths.dofile('testOverfeat.lua')

-- Convolution layer waiting for finetune
-- convLayer = {13, 11, 9, 7, 4, 1}
-- reservRank = {478, 443, 225, 232, 148, 61}
convLayer = {13, 11, 9, 7, 4, 1}
reservRank = {478, 443, 225, 232, 148, 61}


for i_ = 1,5 do
  print('Proc on ...')
  print(model:get(convLayer[i_]))

  -- Decomposite current conv layer
  wConv = torch.Tensor(model:get(convLayer[i_]).weight:size()):copy(model:get(convLayer[i_]).weight)
  bConv = torch.Tensor(model:get(convLayer[i_]).bias:size()):copy(model:get(convLayer[i_]).bias)
  sizeO_ = wConv:size()
  print('Transform tensor to 2-D matrix ...')
  print(sizeO_)
  wConv2d = wConv:reshape(sizeO_[1], sizeO_[2]*sizeO_[3]*sizeO_[4])
  print('Do SVD ...')
  U,S,V = torch.svd(wConv2d)
  UCrop = U:sub(1,-1, 1, reservRank[i_]) * torch.diag(S:sub(1,reservRank[i_])):sqrt()
  VCrop = torch.diag(S:sub(1, reservRank[i_])):sqrt() * V:sub(1,-1,1,reservRank[i_]):t()
  print(UCrop:size())
  print(VCrop:size())
  wConv2dRecon = UCrop * VCrop;

  print('Decomposite Conv' .. convLayer[i_] .. '...')
  model:remove(convLayer[i_])
  model:insert(nn.SpatialConvolution(sizeO_[2], reservRank[i_], 3, 3, 1, 1, 1, 1):noBias(), convLayer[i_])
  size_ = model:get(convLayer[i_]).weight:size()
  model:get(convLayer[i_]).weight:copy(VCrop:reshape(size_))
  model:insert(nn.SpatialConvolution(reservRank[i_], sizeO_[1], 1, 1, 1, 1, 0, 0), convLayer[i_]+1)
  size_ = model:get(convLayer[i_]+1).weight:size()
  model:get(convLayer[i_]+1).weight:copy(UCrop:reshape(size_))
  model:get(convLayer[i_]+1).bias:copy(bConv)
  print('Decomposite Conv' .. convLayer[i_] .. ' done')
  model:cuda()
  print(model)

  epoch = opt.epochNumber
  
  rank_ = reservRank[i_]
  layer_ = convLayer[i_]
  print('Finetune on ...')
  print(model:get(convLayer[i_]))
  for i=1,opt.nEpochs do
     train()
     test()
     epoch = epoch + 1
  end
end
