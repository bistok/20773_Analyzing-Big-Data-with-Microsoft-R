# Run Locally

# Create the PemaMean class
library(RevoPemaR)

PemaMean <- setPemaClass(
  Class = "PemaMean",
  contains = "PemaBaseClass",
  fields = list(
    sum = "numeric",
    totalObs = "numeric",
    totalValidObs = "numeric",
    mean = "numeric",
    varName = "character"
  ),
  methods = list(
    initialize = function(varName = "", ...)  {
      'sum, totalValidObs, and mean are all initialized to 0'
      callSuper(...)
      usingMethods(.pemaMethods)
      varName <<- varName
      sum <<- 0
      totalObs <<- 0
      totalValidObs <<- 0
      mean <<- 0
      traceLevel <<- as.integer(1)
    },
    
    processData = function(dataList) {
      'Updates the sum and total observations from the current chunk of data.'
      sum <<- sum + sum(as.numeric(dataList[[varName]]),
                        na.rm = TRUE)
      totalObs <<- totalObs + length(dataList[[varName]])
      totalValidObs <<- totalValidObs +
        sum(!is.na(dataList[[varName]]))
      invisible(NULL)
    },
    
    updateResults = function(pemaMeanObj) {
      'Updates sum and total observations from another PemaMean object.'
      sum <<- sum + pemaMeanObj$sum
      totalObs <<- totalObs + pemaMeanObj$totalObs
      totalValidObs <<- totalValidObs + pemaMeanObj$totalValidObs
      
      invisible(NULL)
    },
    
    processResults = function() {
      'Returns the sum divided by the totalValidObs.'
      if (totalValidObs > 0)
      {
        mean <<- sum/totalValidObs
      }
      else
      {
        mean <<- as.numeric(NA)
      }
      
      outputTrace("outputting mean:\n", outTraceLevel = 1)
      
      return( mean )
    }
  )
)

# Instantiate a PemaMean object
meanPemaObj <- PemaMean()

# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")
library(RevoPemaR)

# Copy the PemaMean object to the R server environment for testing
pause()
putLocalObject("meanPemaObj")
resume()

# Create some test data
set.seed(12345)
testData <- data.frame(x = rnorm(1000))

# Run the analysis
result <- pemaCompute(pemaObj = meanPemaObj, data = testData, varName = "x")
print(result)

# Examine the internal fields of the PemaMean object
print(meanPemaObj$sum)
print(meanPemaObj$mean)
print(meanPemaObj$totalValidObs)

# Create some more test data
set.seed(54321)
testData <- data.frame(x = rnorm(1000))

# Run the analysis again, but include the previous results
result <- pemaCompute(pemaObj = meanPemaObj, data = testData, varName = "x", initPema = FALSE)
print(result)

# Examine the internal fields of the PemaMean object again
print(meanPemaObj$sum)
print(meanPemaObj$mean)
print(meanPemaObj$totalValidObs)

# Perform an analysis against the flight delay data
# - Calculate the mean delay time
rxSetFileSystem(RxNativeFileSystem()) # Just in case the session is still connected to HDFS
pause()
setwd("E:\\Demofiles\\Mod05")
putLocalFile("FlightDelayDataSubset.xdf")
resume()
flightDelayData = RxXdfData("FlightDelayDataSubset.xdf")
result <- pemaCompute(pemaObj = meanPemaObj, data = flightDelayData, varName = "Delay")
print(result)
