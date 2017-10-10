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

-- Get weight matrix and do SVD
wConv2 = torch.Tensor(model:get(4).weight:size()):copy(model:get(4).weight)
wConv2Size = wConv2:size()
wConv2_2d = wConv2:reshape(wConv2Size[1], wConv2Size[2]*wConv2Size[3]*wConv2Size[4])
U,S,V = torch.svd(wConv2_2d)
keepN = 128
wConv2_2dKeep = U:sub(1,-1,1,keepN) * torch.diag(S:sub(1,keepN)) * V:sub(1,-1,1,keepN):t()
wConv2Keep = wConv2_2dKeep:reshape(wConv2Size)
model:get(4).weight:copy(wConv2Keep)

cutorch.setDevice(opt.GPU) -- by default, use GPU 1
torch.manualSeed(opt.manualSeed)

print('Saving everything to: ' .. opt.save)
os.execute('mkdir -p ' .. opt.save)

paths.dofile('data.lua')
paths.dofile('testOverfeat.lua')

epoch = opt.epochNumber

test()
