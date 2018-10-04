# EX 1 - Run locally

setwd("E:\\Labfiles\\Lab02")

# Examine the structure of the data file
flightDataSampleCsv <- "2000.csv"
flightDataSample <- rxImport(flightDataSampleCsv, numRows = 10)

rxGetVarInfo(flightDataSample)

# The structure of the data
flightDataColumns <- c("Year" = "factor",
                       "DayofMonth" = "factor",
                       "DayOfWeek" = "factor",
                       "UniqueCarrier" = "factor",
                       "Origin" = "factor",
                       "Dest" = "factor",
                       "CancellationCode" = "factor"
                       )

# Read the CSV file and write it out as an XDF file
flightDataXdf <- "2000.xdf"
rxOptions(reportProgress = 1)
flightDataSampleXDF <- rxImport(inData = flightDataSampleCsv, outFile = flightDataXdf, overwrite = TRUE, append = "none", colClasses = flightDataColumns)

# Check the structure of the new file
rxGetVarInfo(flightDataXdf)

# Compare sizes of XDF and CSV files at this point (using File Explorer, not R)

# Compare performance of CSV and XDF

system.time(csvDelaySummary <- rxSummary(~., flightDataSampleCsv))
# print(csvDelaySummary)

system.time(xdfDelaySummary <- rxSummary(~., flightDataSampleXDF))
# print(xdfDelaySummary)

# Generate crosstabs and cubes for cancelled flights - still comparing performance
system.time(csvCrossTabInfo <- rxCrossTabs(~as.factor(Month):as.factor(Cancelled == 1), flightDataSampleCsv))
# print(csvCrossTabInfo)

system.time(xdfCrossTabInfo <- rxCrossTabs(~as.factor(Month):as.factor(Cancelled == 1), flightDataSampleXDF))
# print(xdfCrossTabInfo)

system.time(csvCubeInfo <- rxCube(~as.factor(Month):as.factor(Cancelled), flightDataSampleCsv))
# print(csvCubeInfo)

system.time(xdfCubeInfo <- rxCube(~as.factor(Month):as.factor(Cancelled), flightDataSampleXDF))
# print(xdfCubeInfo)

# Tidy up memory
rm(flightDataSample, flightDataSampleXDF, csvDelaySummary, xdfDelaySummary, 
   csvCrossTabInfo, xdfCrossTabInfo, csvCubeInfo, xdfCubeInfo)


# EX 2 - Run remotely on R Server

# Preparation: Log into the LON-RSVR VM and create the Data share over the C:\Temp folder
# Copy the CSV files from E:\Setup\Data to \\LON-RSVR\\Data

remoteLogin("http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE)

pause()

putLocalObject(c("flightDataColumns"))

resume()

ls()

# Transform the data - create a combined Delay column, filter all cancelled flights, and discard FlightNum, TailNum, and CancellationCode
# Test import and transform over a small sample first
flightDataSampleXDF <- rxImport(inData = "\\\\LON-RSVR\\Data\\2000.csv", outFile = "\\\\LON-RSVR\\Data\\Sample.xdf", overwrite = TRUE, append = "none", colClasses = flightDataColumns,
                                transforms = list(
                                  Delay = ArrDelay + DepDelay + ifelse(is.na(CarrierDelay), 0, CarrierDelay) + ifelse(is.na(WeatherDelay), 0, WeatherDelay) + ifelse(is.na(NASDelay), 0, NASDelay) + ifelse(is.na(SecurityDelay), 0, SecurityDelay) + ifelse(is.na(LateAircraftDelay), 0, LateAircraftDelay),
                                  MonthName = factor(month.name[as.numeric(Month)], levels=month.name)),
                                rowSelection = (Cancelled == 0),
                                varsToDrop = c("FlightNum", "TailNum", "CancellationCode"),
                                numRows = 1000
)

head(flightDataSampleXDF, 100)

# Combine separate CSV files containing data for each year into one big XDF file, performing the same transformations (which have now been tested)
rxOptions(reportProgress = 1)

delayXdf <- "\\\\LON-RSVR\\Data\\FlightDelayData.xdf"
flightDataCsvFolder <- "\\\\LON-RSVR\\Data"
flightDataXDF <- rxImport(inData = flightDataCsvFolder, outFile = delayXdf, overwrite = TRUE, append = ifelse(file.exists(delayXdf), "rows", "none"), colClasses = flightDataColumns,
                          transforms = list(
                            Delay = ArrDelay + DepDelay + ifelse(is.na(CarrierDelay), 0, CarrierDelay) + ifelse(is.na(WeatherDelay), 0, WeatherDelay) + ifelse(is.na(NASDelay), 0, NASDelay) + ifelse(is.na(SecurityDelay), 0, SecurityDelay) + ifelse(is.na(LateAircraftDelay), 0, LateAircraftDelay),
                            MonthName = factor(month.name[as.numeric(Month)], levels=month.name)),
                          rowSelection = (Cancelled == 0),
                          varsToDrop = c("FlightNum", "TailNum", "CancellationCode"),
                          rowsPerRead = 500000
)

exit

# EX3 - Start locally

# Import airport data from the Airports table in the AirlineData database, and save it as an XDF file
conString <- "Server=LON-SQLR;Database=AirlineData;Trusted_Connection=TRUE"
airportData <- RxSqlServerData(connectionString = conString, table = "Airports")

# Examine the first few rows of data
head(airportData)

# Import the data to a data frame
airportInfo <- rxImport(inData = airportData, stringsAsFactors = TRUE)
head(airportInfo)

# Connect remotely
remoteLogin("http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE)

pause()

# Copy the data frame
putLocalObject(c("airportInfo"))

resume()

# Add the OriginState and DestState columns. These columns hold the US state for the Origin and Dest airports, retrieved from the airportData data frame
enhancedDelayDataXdf <- "\\\\LON-RSVR\\Data\\EnhancedFlightDelayData.xdf"
flightDelayDataXdf <- "\\\\LON-RSVR\\Data\\FlightDelayData.xdf"

enhancedXdf <- rxImport(inData = flightDelayDataXdf, outFile = enhancedDelayDataXdf,
                        overwrite = TRUE, append = "none", rowsPerRead = 500000,
                        transforms = list(OriginState = stateInfo$state[match(Origin, stateInfo$iata)],
                                          DestState = stateInfo$state[match(Dest, stateInfo$iata)]),
                        transformObjects = list(stateInfo = airportInfo)
                        )

head(enhancedXdf)


# EX4 - Remain connected remotely

# delayFactor breaks the continous variable Delay into a series of factored values
delayFactor <- expression(list(Delay = cut(Delay, breaks = c(0, 1, 30, 60, 120, 180, 181), labels = c("No delay", "Up to 30 mins", "30 mins - 1 hour", "1 hour to 2 hours", "2 hours to 3 hours", "More than 3 hours"))))

# Generate a crosstab that summarizes the delays for flights starting at the Origin airport
originAirportDelays <- rxCrossTabs(formula = ~ Origin:Delay, data = enhancedXdf,
                                   transforms = delayFactor
                       )
print(originAirportDelays)

# Generate a crosstab that summarizes the delays for flights finishing at the Dest airport
destAirportDelays <- rxCrossTabs(formula = ~ Dest:Delay, data = enhancedXdf,
                                 transforms = delayFactor
                     )
print(destAirportDelays)

# Generate a crosstab that summarizes the delays for flights starting in the OriginState state
originStateDelays <- rxCrossTabs(formula = ~ OriginState:Delay, data = enhancedXdf,
                                 transforms = delayFactor
                     )
print(originStateDelays)

# Generate a crosstab that summarizes the delays for flights finishing in the DestState state
destStateDelays <- rxCrossTabs(formula = ~ DestState:Delay, data = enhancedXdf,
                               transforms = delayFactor
                   )
print(destStateDelays)

# return to the local session
exit

# Install dplyrXdf
install.packages("dplyr")
install.packages("devtools")
devtools::install_github("RevolutionAnalytics/dplyrXdf")
library(dplyr)
library(dplyrXdf)

# Read in a subset of the data from the XDF file containing the data to be summarized (discard all the other columns)
enhancedDelayDataXdf <- "\\\\LON-RSVR\\Data\\EnhancedFlightDelayData.xdf"
essentialData <-RxXdfData(enhancedDelayDataXdf, varsToKeep = c("Delay", "Origin", "Dest", "OriginState", "DestState"))

# Summarize the data using dplyrXdf
originAirportStats <- filter(essentialData, !is.na(Delay)) %>%
  select(Origin, Delay) %>%
  group_by(Origin) %>%
  summarise(mean_delay = mean(Delay), .method = 1) %>% # Use methods 1 or 2 only
  arrange(desc(mean_delay)) %>%
  persist("\\\\LON-RSVR\\Data\\temp.xdf")  # Return a reference to a persistent file. By default, temp files will be deleted
head(originAirportStats, 100)

destAirportStats <- filter(essentialData, !is.na(Delay)) %>%
  select(Dest, Delay) %>%
  group_by(Dest) %>%
  summarise(mean_delay = mean(Delay), .method = 1) %>%
  arrange(desc(mean_delay)) %>%
  persist("\\\\LON-RSVR\\Data\\temp.xdf")
head(destAirportStats, 100)

originStateStats <- filter(essentialData, !is.na(Delay)) %>%
  select(OriginState, Delay) %>%
  group_by(OriginState) %>%
  summarise(mean_delay = mean(Delay), .method = 1) %>%
  arrange(desc(mean_delay)) %>%
  persist("\\\\LON-RSVR\\Data\\temp.xdf")
head(originStateStats, 100)

destStateStats <- filter(essentialData, !is.na(Delay)) %>%
  select(DestState, Delay) %>%
  group_by(DestState) %>%
  summarise(mean_delay = mean(Delay), .method = 1) %>%
  arrange(desc(mean_delay)) %>%
  persist("\\\\LON-RSVR\\Data\\temp.xdf")
head(destStateStats, 100)

