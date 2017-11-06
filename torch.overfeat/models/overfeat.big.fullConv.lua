function createModel(nGPU)
   local ParamBank = require 'ParamBank'
   local features = nn.Sequential()

   features:add(nn.SpatialConvolution(3, 96, 7, 7, 2, 2))
   features:add(nn.ReLU(true))
   features:add(nn.SpatialMaxPooling(3, 3, 3, 3))

   features:add(nn.SpatialConvolution(96, 256, 7, 7, 1, 1))
   features:add(nn.ReLU(true))
   features:add(nn.SpatialMaxPooling(2, 2, 2, 2))

   features:add(nn.SpatialConvolution(256, 512, 3, 3, 1, 1, 1, 1))
   features:add(nn.ReLU(true))

   features:add(nn.SpatialConvolution(512, 512, 3, 3, 1, 1, 1, 1))
   features:add(nn.ReLU(true))

   features:add(nn.SpatialConvolution(512, 1024, 3, 3, 1, 1, 1, 1))
   features:add(nn.ReLU(true))

   features:add(nn.SpatialConvolution(1024, 1024, 3, 3, 1, 1, 1, 1))
   features:add(nn.ReLU(true))
   features:add(nn.SpatialMaxPooling(3, 3, 3, 3))

   -- Overwrite network parameter
   ParamBank:init("net_weight_1")
   ParamBank:read(        0, {96,3,7,7},      features:get(1).weight)
   ParamBank:read(    14112, {96},            features:get(1).bias)
   ParamBank:read(    14208, {256,96,7,7},    features:get(4).weight)
   ParamBank:read(  1218432, {256},           features:get(4).bias)
   ParamBank:read(  1218688, {512,256,3,3},   features:get(7).weight)
   ParamBank:read(  2398336, {512},           features:get(7).bias)
   ParamBank:read(  2398848, {512,512,3,3},   features:get(9).weight)
   ParamBank:read(  4758144, {512},           features:get(9).bias)
   ParamBank:read(  4758656, {1024,512,3,3},  features:get(11).weight)
   ParamBank:read(  9477248, {1024},          features:get(11).bias)
   ParamBank:read(  9478272, {1024,1024,3,3}, features:get(13).weight)
   ParamBank:read( 18915456, {1024},          features:get(13).bias)
   print('Feature: Parameter initialization finished.')
   

   features:cuda()
   features = makeDataParallel(features, nGPU) -- defined in util.lua

   -- 1.3. Create Classifier (fully connected layers)
   local classifier = nn.Sequential()
   -- classifier:add(nn.View(1024*5*5))
   classifier:add(nn.SpatialConvolution(1024, 4096, 5, 5, 1, 1))
   classifier:add(nn.ReLU(true))
   classifier:add(nn.SpatialConvolution(4096, 4096, 1, 1, 1, 1))
   classifier:add(nn.ReLU(true))
   classifier:add(nn.SpatialConvolution(4096, 1000, 1, 1, 1, 1))
   classifier:add(nn.SpatialSoftMax())
   -- classifier:add(nn.Dropout(0.5))
   -- classifier:add(nn.Linear(1024*5*5, 4096))
   -- classifier:add(nn.Threshold(0, 1e-6))

   -- classifier:add(nn.Dropout(0.5))
   -- classifier:add(nn.Linear(4096, 4096))
   -- classifier:add(nn.Threshold(0, 1e-6))

   -- classifier:add(nn.Linear(4096, nClasses))
   -- classifier:add(nn.LogSoftMax())

   -- Overwrite network parameter
   ParamBank:read( 18916480, {4096,1024,5,5}, classifier:get(1).weight)
   ParamBank:read(123774080, {4096},          classifier:get(1).bias)
   ParamBank:read(123778176, {4096,4096,1,1}, classifier:get(3).weight)
   ParamBank:read(140555392, {4096},          classifier:get(3).bias)
   ParamBank:read(140559488, {1000,4096,1,1}, classifier:get(5).weight)
   ParamBank:read(144655488, {1000},          classifier:get(5).bias)
   print('Classifier: Parameter initialization finished.')

   classifier:cuda()

   ParamBank:close()
   -- 1.4. Combine 1.2 and 1.3 to produce final model
   local model = nn.Sequential():add(features):add(classifier)
   model.imageSize = 256
   model.imageCrop = 256
   return model
end
