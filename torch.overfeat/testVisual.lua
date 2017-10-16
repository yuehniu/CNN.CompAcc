--
-- Calculate the sensitivity for each convolutional layer in Overfeat.
--

require "gnuplot"

-- Read test log file
Testlogger = io.open(arg[1], 'r')

top1Accuracy = torch.Tensor(856)

-- Iterate over line
ri_ = 1
for line in Testlogger:lines() do
  -- Get top1 accuracy
  -- beg_, end_ = line:find("Top-1(%%):\t [%d]+%.[%d]+")
  beg_, end_ = line:find("Top%-1%(.%):\t %d+%.%d+")
  begA_, endA_ = line:sub(beg_, end_):find("%d+%.%d+")
  top1A = tonumber(line:sub(beg_, eng_):sub(begA_, endA_))

  top1Accuracy[ri_] = top1A / 100
  ri_ = ri_ + 1
end

gnuplot.figure()
gnuplot.plot(top1Accuracy)
gnuplot.xlabel('Record')
gnuplot.ylabel('Top-1 Accuracy')
