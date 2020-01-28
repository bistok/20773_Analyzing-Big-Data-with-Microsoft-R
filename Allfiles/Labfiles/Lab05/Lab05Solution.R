# EX 1

# Run locally on R client

install.packages("dplyr")
library(dplyr)
library(RevoPemaR)

# Create the PemaFlightDelays class

# PEMA class that finds the number of times flights that match 
# a specified origin, destination, and airline are delayed, 
# and how long each delay was

PemaFlightDelays <- setPemaClass(
  Class = "PemaFlightDelays",
  contains = "PemaBaseClass",
  fields = list(
    totalFlights = "numeric",
    totalDelays = "numeric",
    origin = "character",
    dest = "character",
    airline = "character",
    delayTimes = "vector",
    results = "list"
  ),
  methods = list(
    initialize = function(originCode = "", destinationCode = "", 
                          airlineCode = "", ...)  {
      'initialize fields'
      callSuper(...)
      usingMethods(.pemaMethods)
      totalFlights <<- 0
      totalDelays <<- 0
      delayTimes <<- vector(mode="numeric", length=0)
      origin <<- originCode
      dest <<- destinationCode
      airline <<- airlineCode
    },
    
    processData = function(dataList) {
      'Generates a vector of delay times for specified variables in the current chunk of data.'
      data <- as.data.frame(dataList)

      # If no origin was specified, default to the first value in the dataset
      if (origin == "") {
        origin <<- as.character(as.character(data$Origin[1]))
      }

      # If no destination was specified, default to the first value in the dataset
      if (dest == "") {
        dest <<- as.character(as.character(data$Dest[1]))
      }
      
      # If no airline was specified, default to the first value in the dataset
      if (airline == "") {
        airline <<- as.character(as.character(data$UniqueCarrier[1]))
      }
      
      # Use dplyr to filter by origin, dest, and airline
      # update the number of flights
      # select the Delay variable
      # only include delayed flights in the results
      data %>%
        filter(Origin == origin, Dest == dest, UniqueCarrier == airline) %T>%
        {totalFlights <<- totalFlights + length(.$Origin)} %>%
        select(ifelse(is.na(Delay), 0, Delay)) %>%
        filter(Delay > 0) ->
        temp

      # Store the result in the delayTimes vector
      delayTimes <<- c(delayTimes, as.vector(temp[,1]))
      totalDelays <<- length(delayTimes)
      
      invisible(NULL)
    },
    
    updateResults = function(pemaFlightDelaysObj) {
      'Updates total observations and delayTimes vector from another PemaFlightDelays object object.'

      # Update the totalFlights and totalDelays fields
      totalFlights <<- totalFlights + pemaFlightDelaysObj$totalFlights
      totalDelays <<- totalDelays + pemaFlightDelaysObj$totalDelays
      
      # Append the delay data to the delayTimes vector
      delayTimes <<- c(delayTimes, pemaFlightDelaysObj$delayTimes)

      invisible(NULL)
    },
    
    processResults = function() {
      'Generates a list containing the results:'
      '  The first element is the number of flights made by the airline'
      '  The second element is the number of delayed flights'
      '  The third element is the list of delay times'
      
      results <<- list("NumberOfFlights" = totalFlights,
                       "NumberOfDelays" = totalDelays, 
                       "DelayTimes" = delayTimes)
      
      return(results)
    }
  )
)

# Instantiate a PemaFlightDelays object
pemaFlightDelaysObj <- PemaFlightDelays()

# Connect to R Server and set up the environment
remoteLogin(deployr_endpoint = "http://localhost:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Copy the PEMA object from the R client
pause()
putLocalObject("pemaFlightDelaysObj")

# Perform testing on R server
resume()
install.packages("dplyr")
library(dplyr)
library(RevoPemaR)

# Create some test data
flightDelayDataFile <- ("E:\\Data\\FlightDelayData.xdf")
flightDelayData <- RxXdfData(flightDelayDataFile)
testData <- rxDataStep(flightDelayData, numRows = 50000)

# Run an analysis
result <- pemaCompute(pemaObj = pemaFlightDelaysObj, data = testData, originCode = "ABE", destinationCode = "PIT", airlineCode = "US")
print(result)

# Examine the internal fields of the PemaFlightDelays object
print(pemaFlightDelaysObj$delayTimes)
print(pemaFlightDelaysObj$totalDelays)
print(pemaFlightDelaysObj$totalFlights)
print(pemaFlightDelaysObj$origin)
print(pemaFlightDelaysObj$dest)
print(pemaFlightDelaysObj$airline)

# Create a subset of the XDF data
flightDelayDataSubsetFile <- ("E:\\Data\\FlightDelayDataSubset.xdf")
testData2 <- rxDataStep(flightDelayData, flightDelayDataSubsetFile, 
                       overwrite = TRUE, numRows = 50000, rowsPerRead = 5000)

# Run the same analysis
result <- pemaCompute(pemaObj = pemaFlightDelaysObj, data = testData2, originCode = "ABE", destinationCode = "PIT", airlineCode = "US")

# Verify that the results are the same as before
print(result)

# Perform an analysis using the entire XDF file
result <- pemaCompute(pemaObj = pemaFlightDelaysObj, data = flightDelayData, originCode = "LAX", destinationCode = "JFK", airlineCode = "DL")
print(result)

