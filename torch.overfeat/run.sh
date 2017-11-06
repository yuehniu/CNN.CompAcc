# Finetune for big original Overfeat
th mainTrain.lua 

# Big original model for Overfeat
# th mainTest.lua -data /data/niuy/ml.DataSet/ILSVRC2012/ -netType overfeat -cropSize 221 -nEpochs 1 -retrain model.t7

# Big finetune model for Overfeat
# th mainTest.lua -data /data/niuy/ml.DataSet/ILSVRC2012/ -netType overfeat -cropSize 221 -nEpochs 1 -retrain imagenet/checkpoint/overfeat/finetuneOverfeatThread-b-conv1-wellSolver/model_5.t7

# Small model for Overfeat
# th mainTest.lua -data /data/niuy/ml.DataSet/ILSVRC2012/ -netType overfeat -cropSize 231 -nEpochs 1 -retrain model.small.t7 

# Big model for Overfeat in FCNN
# th mainTest.lua -data /data/niuy/ml.DataSet/ILSVRC2012/ -netType overfeat -cropSize 256 -nEpochs 1 
