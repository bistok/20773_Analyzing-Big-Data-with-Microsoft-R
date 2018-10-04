# Create a logit regression model
mortXdf <- file.path(rxGetOption("sampleDataDir"), "mortDefaultSmall")
logitOut1 <- rxLogit(default ~ creditScore + yearsEmploy + ccDebt,
                     data = mortXdf, blocksPerRead = 5)

# Generate predictions that include credit card debt as a predictor variable
predFile <- "mortPred.xdf"
predOutXdf <- rxPredict(modelObject = logitOut1, data = mortXdf,
                        writeModelVars = TRUE, predVarNames = "Model1", outData = predFile, overwrite = TRUE)

# Display the results
head(RxXdfData(predOutXdf), 50)

# Generate predictions a model and predictions that exclude credit card debt
logitOut2 <- rxLogit(default ~ creditScore + yearsEmploy,
                     data = predOutXdf, blocksPerRead = 5)
predOutXdf <- rxPredict(modelObject = logitOut2, data = predOutXdf,
                        predVarNames = "Model2")

# Display the results
head(RxXdfData(predOutXdf), 50)

# Generate the ROC curves for both models
rocOut <- rxRoc(actualVarName = "default",
                predVarNames = c("Model1", "Model2"),
                data = predOutXdf)

# Visualize the ROC curve
plot(rocOut)
