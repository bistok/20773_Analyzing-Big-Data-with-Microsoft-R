# EX 1

# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Split the data into training and test datasets
rxOptions(reportProgress = 1)
flightDelayDataFile <- "\\\\LON-RSVR\\Data\\FlightDelayData.xdf"
flightDelayData <- RxXdfData(flightDelayDataFile)

partitionedFlightDelayDataFile <- "\\\\LON-RSVR\\Data\\PartitionedFlightDelayData.xdf"

flightData <- rxDataStep(inData = flightDelayData, 
                         outFile = partitionedFlightDelayDataFile, overwrite = TRUE,
                         transforms = list(
                            DepTime = as.numeric(DepTime),
                            ArrTime = as.numeric(ArrTime),
                            Dataset = factor(ifelse(runif(.rxNumRows) >= 0.05, "train", "test"))),
                         varsToKeep = c("Delay", "Origin", "Month", "DayOfWeek", "DepTime", "ArrTime",
                                        "Dest", "Distance", "UniqueCarrier", "OriginState", "DestState"))

partitionFilesBaseName <- "\\\\LON-RSVR\\Data\\Partition"
flightDataSets <- rxSplit(flightData, splitByFactor = "Dataset", 
                          outFilesBase = partitionFilesBaseName, overwrite = TRUE)

# Verify the number of observations in each set
lapply(flightDataSets, nrow)

# Create a DTree model for predicting delays based on departure time, arrival time, month, and day of week
delayDTree <- rxDTree(formula = Delay ~ DepTime + ArrTime + Month + DayOfWeek,
                      data = names(flightDataSets[2]))

# Examine the model
delayDTree

# Visualise the DTree - use R Client
pause()
getRemoteObject("delayDTree")

# Use RevoTreeView to display an interactive view of the DTree
library(RevoTreeView)
plot(createTreeView(delayDTree))

resume()

# On R Server, look at the scree plot for the tree and decide whether this model is an "overfit"
plotcp(rxAddInheritance(delayDTree))

delayDTree$cptable

# Prune the tree back to 7 levels
prunedDelayDTree <- prune.rxDTree(delayDTree, cp=1.36e-03) # Replace cp with the value for 7 levels
prunedDelayDTree$cptable

# Make predictions using the pruned tree
# Extract a copy of the predictor variables from the test data
testData <- rxDataStep(names(flightDataSets[1]),
                       varsToKeep = c("DepTime", "ArrTime", "Month", "DayOfWeek"))

predictData <- rxPredict(prunedDelayDTree, data = testData)

# Summarize the real data and predictions, for comparison
rxSummary(~Delay, data = names(flightDataSets[1]))
rxSummary(~Delay_Pred, data = predictData)

# Merge the predicted delays 
mergedDelayData <- rxMerge(inData1 = predictData, 
                           inData2 = names(flightDataSets[1]),
                           type = "oneToOne")

# Function to process and display the results of predictions 
processResults <- function(inputData, minuteRange) {

    # Calculate the accuracy between the actual and predicted delays. How many are within 'minuteRange' minutes of each other
    results <- rxDataStep(inputData, 
                          transforms = list(Accuracy = factor(abs(Delay_Pred - Delay) <= minuteRange)),
                          transformObjects = list(minuteRange = minuteRange))
    print(head(results, 100))

    # How accurate are the predictions? How many are within 'minuteRange' minutes?
    matches <- table(results$Accuracy)[2]
    percentage <- (matches / nrow(results)) * 100
    print(sprintf("%d predictions were within %d minutes of the actual delay time. This is %f percent of the total", matches, minuteRange, percentage))

    # How many are within 5% of the minuteRange' minute range
    matches <- table(abs(results$Delay_Pred - results$Delay) / results$Delay <= 0.05)[2]
    percentage <- (matches / nrow(results)) * 100
    print(sprintf("%d predictions were within 5 percent of the actual delay time. This is %f percent of the total", matches, percentage))

    # How many are within 10%
    matches <- table(abs(results$Delay_Pred - results$Delay) / results$Delay <= 0.1)[2]
    percentage <- (matches / nrow(results)) * 100
    print(sprintf("%d predictions were within 10 percent of the actual delay time. This is %f percent of the total", matches, percentage))

    # How many are within 50%
    matches <- table(abs(results$Delay_Pred - results$Delay) / results$Delay <= 0.5)[2]
    percentage <- (matches / nrow(results)) * 100
    print(sprintf("%d predictions were within 50 percent of the actual delay time. This is %f percent of the total", matches, percentage))
    
    invisible(NULL)
}

processResults(mergedDelayData, 10)




# EX 2
# Repeat, using a DForest trimmed to 7 levels
delayDForest <- rxDForest(formula = Delay ~ DepTime + ArrTime + Month + DayOfWeek,
                          data = names(flightDataSets[2]),
                          maxDepth = 7)

predictData <- rxPredict(delayDForest, data = testData)

mergedDelayData <- rxMerge(inData1 = predictData, 
                           inData2 = names(flightDataSets[1]),
                           type = "oneToOne")

processResults(mergedDelayData, 10)

# Try with a maxDepth of 5 - differences could be caused by overfitting
delayDForest <- rxDForest(formula = Delay ~ DepTime + ArrTime + Month + DayOfWeek,
                          data = names(flightDataSets[2]),
                          maxDepth = 5)

predictData <- rxPredict(delayDForest, data = testData)

mergedDelayData <- rxMerge(inData1 = predictData, 
                           inData2 = names(flightDataSets[1]),
                           type = "oneToOne")

processResults(mergedDelayData, 10)



# EX 3
# Try a different set of variables concerned with location, carrier, and distance rather than timings
delayDTree2 <- rxDTree(formula = Delay ~ Origin + Dest + 
                         Distance + UniqueCarrier + OriginState + DestState,
                       data = names(flightDataSets[2]),
                       maxDepth = 7)

# Create a new set of test data with the specified variables
testData <- rxDataStep(names(flightDataSets[1]),
                       varsToKeep = c("Origin", "Dest", "Distance", "UniqueCarrier", "OriginState", "DestState"))

predictData <- rxPredict(delayDTree2, data = testData)

mergedDelayData <- rxMerge(inData1 = predictData, 
                           inData2 = names(flightDataSets[1]),
                           type = "oneToOne")

processResults(mergedDelayData, 10)




# EX 4
# Combine variables. Stick to the same depth as before
delayDTree3 <- rxDTree(formula = Delay ~ DepTime + Month + DayOfWeek + ArrTime + Origin + Dest + 
                         Distance + UniqueCarrier + OriginState + DestState,
                       data = names(flightDataSets[2]), 
                       maxDepth = 7)

# Rebuild the test data with the additional variables - keep them all except for Delay
testData <- rxDataStep(names(flightDataSets[1]),
                       varsToDrop = c("Delay"))

# Run predictions
predictData <- rxPredict(delayDTree3, data = testData)

# Merge the results
mergedDelayData <- rxMerge(inData1 = predictData, 
                           inData2 = names(flightDataSets[1]),
                           type = "oneToOne")

# Evaluate the predictions
processResults(mergedDelayData, 10)
