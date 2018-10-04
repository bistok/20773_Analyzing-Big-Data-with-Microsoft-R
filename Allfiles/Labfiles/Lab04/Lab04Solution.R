#EX 1
# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Examine the factor levels in each dataset
airportData = RxXdfData("\\\\LON-RSVR\\Data\\airportData.xdf")
flightDelayData = RxXdfData("\\\\LON-RSVR\\Data\\flightDelayData.xdf")

iataFactor <- rxGetVarInfo(airportData, varsToKeep = c("iata"))
print(iataFactor)

originFactor <- rxGetVarInfo(flightDelayData, varsToKeep = c("Origin"))
print(originFactor)

destFactor <- rxGetVarInfo(flightDelayData, varsToKeep = c("Dest"))
print(destFactor)

# Create a set of levels for refactoring the datasets
refactorLevels <- unique(c(iataFactor$iata[["levels"]],
                           originFactor$Origin[["levels"]],
                           destFactor$Dest[["levels"]]))

# Refactor the datasets
rxOptions(reportProgress = 2)
refactoredAirportDataFile <- "\\\\LON-RSVR\\Data\\RefactoredAirportData.xdf"
refactoredAirportData <- rxFactors(inData = airportData, outFile = refactoredAirportDataFile, overwrite = TRUE,
                                   factorInfo = list(iata = list(newLevels = refactorLevels))
                                  )

refactoredFlightDelayDataFile <- "\\\\LON-RSVR\\Data\\RefactoredFlightDelayData.xdf"
refactoredFlightDelayData <- rxFactors(inData = flightDelayData, outFile = refactoredFlightDelayDataFile, overwrite = TRUE,
                                       factorInfo = list(Origin = list(newLevels = refactorLevels),
                                                         Dest = list(newLevels = refactorLevels))
                                      )

# Verify the new factor levels in each dataset. They should all be the same
iataFactor <- rxGetVarInfo(refactoredAirportData, varsToKeep = c("iata"))
print(iataFactor)

originFactor <- rxGetVarInfo(refactoredFlightDelayData, varsToKeep = c("Origin"))
print(originFactor)

destFactor <- rxGetVarInfo(refactoredFlightDelayData, varsToKeep = c("Dest"))
print(destFactor)

# Rename the iata variable as Origin - names must match when joining
names(refactoredAirportData)[[1]] <- "Origin" 

# reblock the airport data file
reblockedAirportDataFile <- "\\\\LON-RSVR\\Data\\reblockedAirportData.xdf"
reblockedAirportData <- rxDataStep(refactoredAirportData, 
                                   reblockedAirportDataFile, overwrite = TRUE
                                  )

# Perform the merge to add the timezone of the Origin airport
mergedFlightDelayDataFile <- "\\\\LON-RSVR\\Data\\MergedFlightDelayData.xdf"
mergedFlightDelayData <- rxMerge(inData1 = refactoredFlightDelayData, inData2 = reblockedAirportData,
                                 outFile = mergedFlightDelayDataFile, overwrite = TRUE,
                                 type = "inner", matchVars = c("Origin"), autoSort = TRUE,
                                 varsToKeep2 = c("timezone", "Origin"),
                                 newVarNames2 = c(timezone = "OriginTimeZone"),
                                 rowsPerOutputBlock = 500000
                                )

# Check that the data now contains OriginTimeZone variable
rxGetVarInfo(mergedFlightDelayData)
head(mergedFlightDelayData)
tail(mergedFlightDelayData)



# EX2

# Generate a sample of the data to transform
rxOptions(reportProgress = 1)

flightDelayDataSubsetFile <- "\\\\LON-RSVR\\Data\\flightDelayDataSubset.xdf"
flightDelayDataSubset <- rxDataStep(inData = mergedFlightDelayData,
                                    outFile = flightDelayDataSubsetFile, overwrite = TRUE,
                                    rowSelection = rbinom(.rxNumRows, size = 1, prob = 0.005)
)

rxGetInfo(flightDelayDataSubset, getBlockSizes = TRUE)

# Date manipulation uses the lubridate package
install.packages("lubridate")

# Add departure and arrival times recorded as UTC to the dataset 
standardizeTimes <- function (dataList) {
  
  # Check to see whether this is a test chunk
  if (.rxIsTestChunk) {
    return(dataList)
  }
  
  # Create a new vector for holding the standardized departure time 
  # and add it to the list of variable values
  departureTimeVarIndex <- length(dataList) + 1
  dataList[[departureTimeVarIndex]] <- rep(as.numeric(NA), times = .rxNumRows)
  names(dataList)[departureTimeVarIndex] <- "StandardizedDepartureTime"
  
  # Do the same for standardized arrival time
  arrivalTimeVarIndex <- length(dataList) + 1
  dataList[[arrivalTimeVarIndex]] <- rep(as.numeric(NA), times = .rxNumRows)
  names(dataList)[arrivalTimeVarIndex] <- "StandardizedArrivalTime"
  
  departureYearVarIndex <- 1
  departureMonthVarIndex <- 2
  departureDayVarIndex <- 3
  departureTimeStringVarIndex <- 4
  elapsedTimeVarIndex <- 5
  departureTimezoneVarIndex <- 6
  
  # Iterate through the rows and add the standardized arrival and departure times
  for (i in 1:.rxNumRows) {
    
    # Get the local departure time details
    departureYear <- dataList[[departureYearVarIndex]][i]
    departureMonth <- dataList[[departureMonthVarIndex]][i]
    departureDay <- dataList[[departureDayVarIndex]][i]
    departureHour <- trunc(as.numeric(dataList[[departureTimeStringVarIndex]][i]) / 100)
    departureMinute <- as.numeric(dataList[[departureTimeStringVarIndex]][i]) %% 100
    departureTimeZone <- dataList[[departureTimezoneVarIndex]][i]
    
    # Construct the departure date and time, including timezone
    departureDateTimeString <- paste(departureYear, "-", departureMonth, "-", departureDay, " ", departureHour, ":", departureMinute, sep="")
    departureDateTime <- as.POSIXct(departureDateTimeString, tz = departureTimeZone)
    
    # Convert to UTC and store it
    standardizedDepartureDateTime <- format(departureDateTime, tz="UTC")
    dataList[[departureTimeVarIndex]][i] <- standardizedDepartureDateTime 

    # Calculate the arrival date and time
    # Do this by adding the elapsed time to the departure time
    # The elapsed time is stored as the number of minutes (an integer)
    elapsedTime = dataList[[5]][i]
    standardizedArrivalDateTime <- format(as.POSIXct(standardizedDepartureDateTime) + minutes(elapsedTime))
    
    # Store it
    dataList[[arrivalTimeVarIndex]][i] <- standardizedArrivalDateTime 
  }
  
  # Return the data including the new variables
  return(dataList)
}

# Transform the sample data
flightDelayDataTimeZonesFile <- "\\\\LON-RSVR\\Data\\flightDelayDataTimezones.xdf"
flightDelayDataTimeZones <- rxDataStep(inData = flightDelayDataSubset,
                                       outFile = flightDelayDataTimeZonesFile, overwrite = TRUE,
                                       transformFunc = standardizeTimes,
                                       transformVars = c("Year", "Month", "DayofMonth", "DepTime", "ActualElapsedTime", "OriginTimeZone"),
                                       transformPackages = c("lubridate")
                            )

# Verify the results
rxGetVarInfo(flightDelayDataTimeZones)
head(flightDelayDataTimeZones)
tail(flightDelayDataTimeZones)



# EX3

# Sort the flight delay data by the departure time
rxOptions(reportProgress = 1)
sortedFlightDelayDataFile <- "sortedFlightDelayData.xdf"
sortedFlightDelayData <- rxSort(inData = flightDelayDataTimeZones, 
                                outFile = sortedFlightDelayDataFile, overwrite = TRUE,
                                sortByVars = c("StandardizedDepartureTime")
                               )

# Verify that the data has been sorted
head(sortedFlightDelayData)
tail(sortedFlightDelayData)

# Add cumulative average flight delays for each route
calculateCumulativeAverageDelays <- function (dataList) {
  
  # Check to see whether this is a test chunk
  if (.rxIsTestChunk) {
    return(dataList)
  }
  
  # Add a new vector for holding the cumulative average delay 
  # and add it to the list of variable values
  cumulativeAverageDelayVarIndex <- length(dataList) + 1
  dataList[[cumulativeAverageDelayVarIndex]] <- rep(as.numeric(NA), times = .rxNumRows)
  names(dataList)[cumulativeAverageDelayVarIndex] <- "CumulativeAverageDelayForRoute"

  originVarIndex <- 1
  destVarIndex <- 2
  delayVarIndex <- 3
  
  # Retrieve the vector containing the cumulative delays recorded so far for each route
  cumulativeDelays <- .rxGet("cumulativeDelays")

  # Retrieve the vecor containing the number of times each route has occurred so far
  cumulativeRouteOccurrences <- .rxGet("cumulativeRouteOccurrences")

  # Iterate through the rows and add the standardized arrival and departure times
  for (i in 1:.rxNumRows) {
  
    # Get the route and delay details
    origin <- dataList[[originVarIndex]][i]
    dest <- dataList[[destVarIndex]][i]
    routeDelay <- dataList[[delayVarIndex]][i]

    # Create a string that identifies the route
    route <- paste(origin, dest, sep = "")

    # Retrieve the current cumulative delay and number of occurrences for each route
    delay <- cumulativeDelays[[route]]
    occurrences <- cumulativeRouteOccurrences[[route]]
    
    # Update the cumulative statistics
    delay <- ifelse(is.null(delay), 0, delay) + routeDelay
    occurrences <- ifelse(is.null(occurrences), 0, occurrences) + 1

    # Work out the new running average delay for the route
    cumulativeAverageDelay <- delay / occurrences
    
    # Store the data and updated stats
    dataList[[cumulativeAverageDelayVarIndex]][i] <- cumulativeAverageDelay 
    cumulativeDelays[[route]] <- delay
    cumulativeRouteOccurrences[[route]] <- occurrences
  }
 
  # Save the lists containing the cumulative data so far
  .rxSet("cumulativeDelays", cumulativeDelays)
  .rxSet("cumulativeRouteOccurrences", cumulativeRouteOccurrences)
  
  # Return the data including the new variable
  return(dataList)
}

# Perform the transformation
flightDelayDataWithAveragesFile <- "\\\\LON-RSVR\\Data\\flightDelayDataWithAverages.xdf"
flightDelayDataWithAverages <- rxDataStep(inData = sortedFlightDelayData,
                                          outFile = flightDelayDataWithAveragesFile, overwrite = TRUE,
                                          transformFunc = calculateCumulativeAverageDelays,
                                          transformVars = c("Origin", "Dest", "Delay"),
                                          transformObjects = list(cumulativeDelays = list(), cumulativeRouteOccurrences = list())
                                         )

# Verify the results
rxGetVarInfo(flightDelayDataWithAverages)
head(flightDelayDataWithAverages)
tail(flightDelayDataWithAverages)

# Plot the delays for the Atlanta/Phoenix route
rxLinePlot(CumulativeAverageDelayForRoute ~ as.POSIXct(StandardizedDepartureTime), type = c("p", "r"),
           flightDelayDataWithAverages,
           rowSelection = (Origin == "ATL") & (Dest == "PHX"),
           yTitle = "Cumulative Average Delay for Route",
           xTitle = "Date"
          )
