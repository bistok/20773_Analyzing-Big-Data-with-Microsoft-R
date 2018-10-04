# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Examine the dataset
FlightDelayData <- "\\\\LON-RSVR\\Data\\FlightDelayData.xdf"
rxGetInfo(FlightDelayData, getVarInfo = TRUE, getBlockSize = TRUE)
head(RxXdfData(FlightDelayData))

# Create the transformation function
addRunningTotal <- function (dataList) {
  
  # Check to see whether this is a test chunk
  if (.rxIsTestChunk) {
    return(dataList)
  }
  
  # Retrieve the current running total for the distance from the environment
  runningTotal <- as.double(.rxGet("runningTotal"))
  
  # Add a new vector for holding the running totals 
  # and add it to the list of variable values
  runningTotalVarIndex <- length(dataList) + 1
  dataList[[runningTotalVarIndex]] <- rep(as.numeric(NA), times = .rxNumRows)
  names(dataList)[runningTotalVarIndex] <- "RunningTotal"
  
  # Iterate through the values for the Distance variable and accumulate them
  idx <- 1
  for (distance in dataList[[1]]) {
    runningTotal <- runningTotal + distance
    dataList[[runningTotalVarIndex]][idx] <- runningTotal
    idx <- idx + 1
  }
  
  # Save the running total back to the environment, ready for the next chunk
  .rxSet("runningTotal", as.double(runningTotal))
  return(dataList)
}

# Run the transformation
EnhancedFlightDelayData <- "\\\\LON-RSVR\\Data\\EnhancedFlightDelayData.xdf"

rxOptions("reportProgress" = 2)
rxDataStep(inData = FlightDelayData, outFile = EnhancedFlightDelayData, 
           overwrite = TRUE, append = "none",
           transforms = list(ObservationNum = .rxStartRow : (.rxStartRow + .rxNumRows - 1)),
           transformFunc = addRunningTotal,
           transformVars = c("Distance"),
           transformObjects = list(runningTotal = 0),
           numRows = 2000000,
           rowsPerRead = 200000
)

# View the results
rxGetInfo(EnhancedFlightDelayData, getVarInfo = TRUE, getBlockSize = TRUE)
head(RxXdfData(EnhancedFlightDelayData))
tail(RxXdfData(EnhancedFlightDelayData))

# Plot a line to visualize the results using a random sample of the data
rxLinePlot(RunningTotal ~ ObservationNum, EnhancedFlightDelayData, 
           rowSelection = rbinom(.rxNumRows, size = 1, prob = 0.01)
)

