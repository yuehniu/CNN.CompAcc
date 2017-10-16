--
-- Calculate the sensitivity for each convolutional layer in Overfeat.
--

require "gnuplot"

-- Read test log file
Testlogger = io.open(arg[1], 'r')

top1Conv1 = torch.Tensor(24)
top1Conv2 = torch.Tensor(64)
top1Conv3 = torch.Tensor(128)
top1Conv4 = torch.Tensor(128)
top1Conv5 = torch.Tensor(256)
top1Conv6 = torch.Tensor(256)
rankConv1 = torch.Tensor(24)
rankConv2 = torch.Tensor(64)
rankConv3 = torch.Tensor(128)
rankConv4 = torch.Tensor(128)
rankConv5 = torch.Tensor(256)
rankConv6 = torch.Tensor(256)
areaConv1 = torch.Tensor(1):zero()
areaConv2 = torch.Tensor(1):zero()
areaConv3 = torch.Tensor(1):zero()
areaConv4 = torch.Tensor(1):zero()
areaConv5 = torch.Tensor(1):zero()
areaConv6 = torch.Tensor(1):zero()

-- Iterate over line
conv1R_ = 1
conv2R_ = 1
conv3R_ = 1
conv4R_ = 1
conv5R_ = 1
conv6R_ = 1
for line in Testlogger:lines() do
  -- Get Convolution layer index
  --print(line)
  beg_, end_ = line:find("ConvLayer: %[[%d]+%]")
  -- print(beg_ .. ' ' .. end_) 
  beg_, end_ = line:sub(beg_,end_):find("[%d]+")
  -- print(beg_ .. ' ' .. end_) 
  convIndex = tonumber(line:sub(beg_, end_))
  -- print(convIndex)

  -- Get Rank
  beg_, end_ = line:find("Rank: %[[%d]+%]")
  begR_, endR_ = line:sub(beg_,end_):find("[%d]+")
  rank = tonumber(line:sub(beg_, end_):sub(begR_, endR_))

  -- Get top1 accuracy
  -- beg_, end_ = line:find("Top-1(%%):\t [%d]+%.[%d]+")
  beg_, end_ = line:find("Top%-1%(.%):\t %d+%.%d+")
  begA_, endA_ = line:sub(beg_, end_):find("%d+%.%d+")
  top1A = tonumber(line:sub(beg_, eng_):sub(begA_, endA_))

  if 1 == convIndex then
    print("Proc on Conv1----" .. conv1R_)
    top1Conv1[conv1R_] = top1A / 100
    rankConv1[conv1R_] = rank/96
    areaConv1 = areaConv1 + top1A/100/24
    conv1R_ = conv1R_ + 1
  end
  if 4 == convIndex then
    top1Conv2[conv2R_] = top1A / 100
    rankConv2[conv2R_] = rank/256
    areaConv2 = areaConv2 + top1A/100/64
    conv2R_ = conv2R_ + 1
  end
  if 7 == convIndex then
    top1Conv3[conv3R_] = top1A / 100
    rankConv3[conv3R_] = rank/512
    areaConv3 = areaConv3 + top1A/100/128
    conv3R_ = conv3R_ + 1
  end
  if 9 == convIndex then
    top1Conv4[conv4R_] = top1A / 100
    rankConv4[conv4R_] = rank/512
    areaConv4 = areaConv4 + top1A/100/128
    conv4R_ = conv4R_ + 1
  end
  if 11 == convIndex then
    top1Conv5[conv5R_] = top1A / 100
    rankConv5[conv5R_] = rank/1024
    areaConv5 = areaConv5 + top1A/100/256
    conv5R_ = conv5R_ + 1
  end
  if 13 == convIndex then
    top1Conv6[conv6R_] = top1A / 100
    rankConv6[conv6R_] = rank/1024
    areaConv6 = areaConv6 + top1A/100/256
    conv6R_ = conv6R_ + 1
  end
end

-- Calculate sensitivity
sensConv1 = 1 / areaConv1[1]
sensConv2 = 1 / areaConv2[1]
sensConv3 = 1 / areaConv3[1]
sensConv4 = 1 / areaConv4[1]
sensConv5 = 1 / areaConv5[1]
sensConv6 = 1 / areaConv6[1]
sensAv = (sensConv1+sensConv2+sensConv3+sensConv4+sensConv5+sensConv6)/6
print('sensitivity of Conv1: ' .. sensConv1)
print('sensitivity of Conv2: ' .. sensConv2)
print('sensitivity of Conv3: ' .. sensConv3)
print('sensitivity of Conv4: ' .. sensConv4)
print('sensitivity of Conv5: ' .. sensConv5)
print('sensitivity of Conv6: ' .. sensConv6)
print('Average sensitivity: ' .. sensAv)

gnuplot.plot({rankConv1, top1Conv1},{rankConv2, top1Conv2},{rankConv3, top1Conv3},{rankConv4, top1Conv4},{rankConv5, top1Conv5},{rankConv6, top1Conv6})
gnuplot.xlabel('Rank Fraction')
gnuplot.ylabel('Top-1 Accuracy')
