# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Examine the data
flightDelayDataSubset = RxXdfData("\\\\LON-RSVR\\Data\\FlightDelayData.xdf")
head(flightDelayDataSubset)                            

# Sort it by Origin (this will take approx 90 seconds)
sortedFlightDelayData = "SortedFlightDelayData.xdf"
sortedData <- rxSort(inData = flightDelayDataSubset, outFile = sortedFlightDelayData, overwrite = TRUE,
                     sortByVars = c("Origin"), decreasing = c(TRUE))

# Note the factor levels for Origin
rxGetVarInfo(sortedData, varsToKeep = c("Origin"))

# View the data. It should be sorted in descending order of Origin
head(sortedData,200)

#Sort the data again. This should be much quicker as it only uses a subset of the variables
sortedData <- rxSort(inData = flightDelayDataSubset, outFile = sortedFlightDelayData, overwrite = TRUE,
                     sortByVars = c("Origin"), decreasing = c(TRUE),
                     varsToKeep = c("Origin", "Dest", "Distance", "CRSDepTime"))

# View the data
head(sortedData,200)

# De-dup routes
sortedData <- rxSort(inData = flightDelayDataSubset, outFile = sortedFlightDelayData, overwrite = TRUE,
       sortByVars = c("Origin"), decreasing = c(TRUE),
       varsToKeep = c("Origin", "Dest", "Distance"),
       removeDupKeys = TRUE, dupFreqVar = "RoutesFrequency"
)

# View the data
head(sortedData,200)

