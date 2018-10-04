# Fit a linear model showing how price of a diamond varies with weight
install.packages("ggplot2")
library(ggplot2)

mod1 <- rxLinMod(price ~ carat, data = ggplot2::diamonds,
                 covCoef = TRUE)

# Examine the results
mod1
summary(mod1)

# Use a categorical predictor variable
mod2 <- rxLinMod(price ~ F(carat),
                 data = ggplot2::diamonds,
                 dropFirst = TRUE,
                 covCoef = TRUE)
mod2

# Generate a subset of the data for testing predictions made by using the model
testData = rxDataStep(ggplot2::diamonds,
                      rowSelection = color == "H",
                      varsToKeep = c("carat", "price"))

# Make price predictions against this dataset
predictions <- rxPredict(mod1, testData, writeModelVars = TRUE)

# View the predictions to compare the predicted prices against the real prices
head(predictions, 50)

# Calculate confidence intervals around each prediction
predictions_se <- rxPredict(mod1, data=testData, computeStdErrors=TRUE,
                            interval="confidence", writeModelVars = TRUE)

head(predictions_se, 50)

# Visualize the predicted prices as a line plot
rxLinePlot(price + price_Pred + price_Upper + price_Lower ~ carat,
           data = predictions_se, type = "b",
           lineStyle = c("blank", "solid", "dotted", "dotted"),
           lineColor = c(NA, "red", "black", "black"),
           symbolStyle = c("solid circle", "blank", "blank", "blank"),
           title = "Data, Predictions, and Confidence Bounds",
           xTitle = "Diamond weight (carats)",
           yTitle = "Price", legend = FALSE)
