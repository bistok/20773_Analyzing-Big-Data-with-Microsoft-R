# EX 1

# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Examine the relationship between the Delay and DepTime variables in the flight delay data
# Create a test sample containing 10% of the flight delay data
rxOptions(reportProgress = 1)
flightDelayData = RxXdfData("\\\\LON-RSVR\\Data\\flightDelayData.xdf")
sampleDataFile = "\\\\LON-RSVR\\Data\\flightDelayDatasample.xdf"

flightDelayDataSample <- rxDataStep(inData = flightDelayData, 
                                    outFile = sampleDataFile, overwrite = TRUE,
                                    rowSelection = rbinom(.rxNumRows, size = 1, prob = 0.10)
                         )

# Plot delays as a function of departure time
rxLinePlot(formula = Delay~as.numeric(DepTime), data = flightDelayDataSample, 
           type = c("p", "r"), symbolStyle = c("."), alpha = 1/50,
           lineColor = "red", 
           xlab = "Departure Time",
           ylab = "Delay (mins)",
           xlim = c(0, 2400), ylim = c(-120, 1000)
           )

# Expression to factorize the departure time
depTimeFactor <- expression(list(DepTime = cut(as.numeric(DepTime),  
                                               breaks = c(0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100,
                                                          1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000, 2100, 2200, 2300, 2400),
                                               labels = c("Midnight-1:00AM", "1:01-2:00AM", "2:01-3:00AM", "3:01-4:00AM", "4:01-5:00AM",
                                                          "5:01-6:00 AM", "6:01-7:00AM", "7:01-8:00AM", "8:01-9:00AM", "9:01-10:00AM", "10:01-11:00AM",
                                                          "11:01-Midday", "12:01-1:00PM", "1:01-2:00PM", "2:01-3:00PM", "3:01-4:00PM", "4:01-5:00PM",
                                                          "5:01-6:00PM", "6:01-7:00PM", "7:01-8:00PM", "8:01-9:00PM", "9:01-10:00PM", 
                                                          "10:01-11:00PM", "11:01PM-Midnight"))))

# Create a histogram showing the number of departures by time
# using the departure time factors as bins
rxHistogram(formula = ~DepTime, data = flightDelayDataSample,
            histType = "Counts",
            xlab = "Departure Time",
            ylab = "Number of Departures",
            transforms = depTimeFactor)

# Cluster the data by time of day and delay
# Set k to 12
# Use a sample of the data initially
delayCluster <- rxKmeans(formula = ~DepTime + Delay,
                         data = flightDelayDataSample,
                         transforms = list(DepTime = as.numeric(DepTime)),
                         numClusters = 12
                         )

# Examine the cluster sums of squares ratio
delayCluster$betweenss / delayCluster$totss

# Examine the influence of each variable
delayCluster$centers

# Run a series of models over a range of values of k from 2 to 24
library(doRSR)
registerDoRSR()

# Maximize parallelism
rxSetComputeContext(RxLocalParallel())

numberOfClusters <- 12 
testClusters <- vector("list", numberOfClusters)

# Create the cluster models
foreach (k = 1:numberOfClusters) %dopar% {
  testClusters[[k]] <<- rxKmeans(formula = ~DepTime + Delay,
                                 data = flightDelayDataSample,
                                 transforms = list(DepTime = as.numeric(DepTime)),
                                 numClusters = k * 2
                                )
}

# Calculate the sums of squares ratios
ratio <- vector()
for (cluster in testClusters)
  ratio <- c(ratio, cluster$betweenss / cluster$totss)

# Plot the sums of squares ratios for each cluster
plotData <- data.frame(num = c(1:numberOfClusters) * 2, ratio)
rxLinePlot(ratio ~ num, plotData, type="p")




# EX 2

# Pick a cluster
k <- 9

# Fit a linear regression model to the cluster data
clusterModel <- rxLinMod(Delay ~ DepTime, data = as.data.frame(testClusters[[k]]$centers),
                         covCoef = TRUE)

# Retrieve a random set of departure times and actual delays from the flight delay data
delayTestData <- rxDataStep(inData = flightDelayData, 
                            varsToKeep = c("DepTime", "Delay"),
                            transforms = list(DepTime = as.numeric(DepTime)),
                            rowSelection = rbinom(.rxNumRows, size = 1, prob = 0.01)
)

# Make predictions using the linear regression model
# Include confidence intervals
delayPredictions <- rxPredict(clusterModel, data = delayTestData, 
                              computeStdErr = TRUE, interval = "confidence",
                              writeModelVars = TRUE
                              )
head(delayPredictions)

# Plot the predicted delays, for comparison
rxLinePlot(formula = Delay~as.numeric(DepTime), data = delayPredictions, 
           type = c("p", "r"), symbolStyle = c("."),
           lineColor = "red",
           xlab = "Departure Time",
           ylab = "Delay (mins)",
           xlim = c(0, 2400), ylim = c(-120, 1000)
)

# Plot the differences between actual and predicted delays
rxLinePlot(formula = Delay - Delay_Pred~as.numeric(DepTime), data = delayPredictions, 
           type = c("p"), symbolStyle = c("."),
           xlab = "Departure Time",
           ylab = "Difference between Actual and Predicted Delay",
           xlim = c(0, 2400), ylim = c(-500, 1000)
)



# EX 3  

# Fit a linear regression model to the entire dataset
regressionModel <- rxLinMod(Delay ~ as.numeric(DepTime), data = flightDelayData,
                         covCoef = TRUE)

# Make predictions using the same test data as before
delayPredictionsFull <- rxPredict(regressionModel, data = delayTestData, 
                                  computeStdErr = TRUE, interval = "confidence",
                                  writeModelVars = TRUE
)

head(delayPredictionsFull)

# Plot the predicted delays, for comparison
rxLinePlot(formula = Delay~as.numeric(DepTime), data = delayPredictionsFull, 
           type = c("p", "r"), symbolStyle = c("."),
           lineColor = "red",
           xlab = "Departure Time",
           ylab = "Delay (mins)",
           xlim = c(0, 2400), ylim = c(-120, 1000)
)

# Plot the differences between actual and predicted delays
rxLinePlot(formula = Delay - Delay_Pred~as.numeric(DepTime), data = delayPredictionsFull, 
           type = c("p"), symbolStyle = c("."),
           xlab = "Departure Time",
           ylab = "Difference between Actual and Predicted Delay",
           xlim = c(0, 2400), ylim = c(-500, 1000)
)

