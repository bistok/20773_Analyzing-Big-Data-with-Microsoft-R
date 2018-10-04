# Examine the diamond data
install.packages("ggplot2")
library(ggplot2)

head(ggplot2::diamonds, 20)

# Generate a dataset containing just the columns required
setwd("E:\\Demofiles\\Mod07\\")
diamondData <- rxDataStep(inData = ggplot2::diamonds, outFile = "Diamonds.xdf", overwrite = TRUE,
                          transforms = list(
                            set = factor(ifelse(runif(.rxNumRows) >= 0.05, "train", "test")),
                            value = factor(ifelse(price >= 4000,  "high", "low"))),
                          varsToKeep = c("cut", "clarity", "carat", "color"))

# Divide the dataset into training and test data 
diamondDataList <- rxSplit(diamondData, splitByFactor = "set", overwrite = TRUE)
lapply(diamondDataList, nrow)

# Fit a DTree model
trainingSet <- "Diamonds.set.train.xdf"
diamondDTree <- rxDTree(value ~ cut + carat + color + clarity,
                        data = trainingSet,
                        maxDepth = 4)

# Show the results
diamondDTree

# For comparison, fit a DTreeForest model
diamondDForest <- rxDForest(value ~ cut + carat + color + clarity,
                            data = trainingSet,
                            maxDepth = 4,
                            nTree = 50, mTry = 2, importance = TRUE)

diamondDForest

# ... and a BTree model
diamondDBoost <- rxBTrees(value ~ cut + carat + color + clarity,
                          data = trainingSet, 
                          lossFunction = "bernoulli",
                          maxDepth = 3,
                          learningRate = 0.4,
                          mTry = 2,
                          nTree = 50)

diamondDBoost

# Assess the complexity of the DTree model
dt1 <- rxDTree(value ~ cut + carat + color + clarity,
               data = trainingSet)
plotcp(rxAddInheritance(dt1))

# Prune the tree to remove unnecessary complexity from the model
dt2 <- prune.rxDTree(dt1, cp=0.0025)
plotcp(rxAddInheritance(dt2))
