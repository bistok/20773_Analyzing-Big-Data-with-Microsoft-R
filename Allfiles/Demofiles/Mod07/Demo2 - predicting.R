# Create a copy of the test set without the value and set variables
setwd("E:\\Demofiles\\Mod07\\")
testSet <- "Diamonds.set.test.xdf" 
predictData <- rxDataStep(testSet, varsToKeep = c("cut", "carat", "color", "clarity"))

# Predict the value of each diamond in the test set using the DTree model
pDTree <- rxPredict(diamondDTree, predictData, type = "class")

# Assess the results against the values recorded in the test set
rxSummary(~ value, data = testSet)
rxSummary(~ value_Pred, data = pDTree)

# Repeat using the DForest model
pDForest <- rxPredict(diamondDForest, predictData, type = "class")
rxSummary(~ value, data = testSet)
rxSummary(~ value_Pred, data = pDForest)

# Add the predicted value of each diamond to the in-memory data frame
predictData1 <- rxMerge(predictData, pDTree, type = "oneToOne")

# Compare the predicted results against the actual values by variable
rxSummary(~ value : (color + clarity + F(carat)), data = testSet)
rxSummary(~ value_Pred : (color + clarity + F(carat)), data = predictData1)
          
# Visualize the DTree model using RevoTreeView
library(RevoTreeView)
plot(createTreeView(diamondDTree))

# Generate a line plot of the DTree model
library(rpart)
plot(rxAddInheritance(diamondDTree))
text(rxAddInheritance(diamondDTree))

# Show an importance plot from the DForest model
rxVarImpPlot(diamondDForest)
