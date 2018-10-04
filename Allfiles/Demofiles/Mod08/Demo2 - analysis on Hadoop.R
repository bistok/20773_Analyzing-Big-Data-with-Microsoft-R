# Create a Hadoop compute context
context <- RxHadoopMR(sshUsername = "sshuser",
                      sshHostname = "LON-HADOOP",
                      consoleOutput = TRUE)

rxSetComputeContext(context, wait = TRUE)

# Copy FlightDelayData.xdf to HDFS (/user/RevoShare/sshuser)
# Remove the file if it already exists first
rxHadoopRemove("/user/RevoShare/sshuser/FlightDelayData.xdf")
rxHadoopCopyFromClient(source = "E:\\Demofiles\\Mod08\\FlightDelayData.xdf",
                       hdfsDest = "/user/RevoShare/sshuser/FlightDelayData.xdf")

# Verify that the file has been uploaded
rxHadoopCommand("fs -ls -R /user/RevoShare/sshuser")

# Connect to the R server running Hadoop
# Replace nn.nn.nn.nn with the IP address of the edge node of the cluster
remoteLogin(deployr_endpoint = "http://nn.nn.nn.nn:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")
library(RevoScaleR)

# Create a Hadoop compute context on this server
# Note that you don't have to specify the host name this time because Hadoop is running on the same machine
context <- RxHadoopMR(sshUsername = "sshuser",
                      consoleOutput = TRUE)

rxSetComputeContext(context, wait = TRUE)

# Examine the structure of the data
# Switch to HDFS (the default file system is native)
rxSetFileSystem(RxHdfsFileSystem())
flightDelayData <- RxXdfData("/user/RevoShare/sshuser/FlightDelayData.xdf")
rxGetVarInfo(flightDelayData)

# Read a subset of the data into a data frame
flightDelaySample <- rxImport(flightDelayData, rowSelection = rbinom(n = .rxNumRows, size = 1, prob = 0.1))

# Summarize the flight delay data sample
# Note that this does not run as a distributed Map/Reduce job because the data is in memory
rxSummary(~., flightDelaySample)

# Break the data file down into composite pieces 
# to enable the ScaleR functions to run Map/Reduce tasks more efficiently on this data
rxHadoopMakeDir("/user/RevoShare/sshuser/DelayData")
flightDelayDataDir = RxXdfData("/user/RevoShare/sshuser/DelayData")
compositeFlightDelayData <- rxImport(inData = flightDelayData, 
                                     outFile = flightDelayDataDir, overwrite = TRUE, 
                                     createCompositeSet = TRUE)

# Examine the composite XDF file
rxHadoopListFiles("/user/RevoShare/sshuser/DelayData")
rxHadoopListFiles("/user/RevoShare/sshuser/DelayData/data")

# Perform a more complex analysis - compute a crosstab
airportAirlineCrosstab <- rxCrossTabs(data = compositeFlightDelayData,
                                      formula = ~UniqueCarrier:Origin)
head(airportAirlineCrosstab)

# Switch to the Job Tracker and display the job tracking info


