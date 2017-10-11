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
opt.retrain = 'model.t7'

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
paths.dofile('testOverfeat.lua')

-- Get weight matrix and do SVD
convLayer = {1, 4, 7, 9, 11, 13}
-- convLayer = {1}

epoch = opt.epochNumber
rank_ = 4
layer_ = 4
for _, l_ in pairs(convLayer) do
  print("Proc on ... ")
  print(model:get(l_))
  layer_ = l_
  wConv = torch.Tensor(model:get(l_).weight:size()):copy(model:get(l_).weight)
  size_ = wConv:size()
  print('Transform tensor to 2-D matrix ...')
  wConv2d = wConv:reshape(size_[1], size_[2]*size_[3]*size_[4])
  print('Do SVD ...')
  U,S,V = torch.svd(wConv2d)
  
  for kpN_ = 4, size_[1], 4 do
    print('Keep ' .. kpN_ .. ' singular values ...')
    wConv2dKp = U:sub(1,-1,1,kpN_) * torch.diag(S:sub(1,kpN_)) * V:sub(1,-1,1,kpN_):t()
    wConv2Kp = wConv2dKp:reshape(size_)
    model:get(l_).weight:copy(wConv2Kp)
    test()
    
    epoch =  epoch + 1
    rank_ = rank_ + 4;
  end
  print('Conv' .. l_ .. 'Done.')
  rank_ = 4
end

