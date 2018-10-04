# Flight delay data for the year 2000
setwd("E:\\Demofiles\\Mod02")

csvDataFile = "2000.csv" 

# Examine the raw data
rawData <- rxImport(csvDataFile, numRows = 1000)
rxGetVarInfo(rawData)

# Create an XDF file that combines the ArrDelay and DepDelay variables, 
# and that selects a random 10% sample from the data

outFileName <- "2000.xdf"
filteredData <- rxImport(csvDataFile, outFile = outFileName, 
                         overwrite = TRUE, append = "none",
                         transforms = list(Delay = ArrDelay + DepDelay),
                         rowSelection = ifelse(rbinom(.rxNumRows, size=1, prob=0.1), TRUE, FALSE))

# Examine the stucture of the XDF data - it should contain a Delay variable
# Note that Origin is a character
rxGetVarInfo(filteredData)

# Generate a quick summary of the numeric data in the XDF file
rxSummary(~., filteredData)

# Summarize the delay fields
rxSummary(~Delay+ArrDelay+DepDelay, filteredData)

# Examine Delay broken down by origin airport
# Need to change Origin and Dest to factors

refactoredData = "2000Refactored.xdf"
refactoredXdf = RxXdfData(refactoredData)

rxFactors(inData = filteredData, outFile = refactoredXdf, 
          overwrite = TRUE, factorInfo = c("Origin", "Dest"))

rxSummary(Delay~Origin, refactoredXdf)

# Generate a crosstab showing the average delay 
# for flights departing from each origin to each destination
rxCrossTabs(Delay ~ Origin:Dest, refactoredXdf, means = TRUE)

# Generate a cube of the same data
rxCube(Delay ~ Origin:Dest, refactoredXdf)

# Omit the routes that don't exist
rxCube(Delay ~ Origin:Dest, refactoredXdf, removeZeroCounts = TRUE)


