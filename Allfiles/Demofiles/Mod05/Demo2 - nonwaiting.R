# Create a Hadoop compute context
context <- RxHadoopMR(sshUsername = "sshuser", 
                      sshHostname = "LON-HADOOP")
rxSetComputeContext(context, wait = TRUE)

# Upload the Flight Delay Data
rxHadoopRemove(path = "/user/sshuser/FlightDelayData.xdf" )
rxHadoopCopyFromClient(source = "E:\\Demofiles\\Mod05\\FlightDelayData.xdf",
                       hdfsDest = "/user/sshuser/")

# Perform an analysis on the flight data
# What are the most popular routes?
rxOptions(reportProgress = 1)
hdfsConnection <- RxHdfsFileSystem()
rxSetFileSystem(hdfsConnection)
flightDelayDataFile <- "/user/sshuser/FlightDelayData.xdf"
flightDelayData <- RxXdfData(flightDelayDataFile)
routes <- rxSummary(~Origin:Dest, flightDelayData)

# Try and sort the data in the Hadoop context.
# Note the error message
sortedData <- rxSort(as.data.frame(routes$categorical[[1]]), 
                     sortByVars = c("Counts"), decreasing = TRUE)

# Use rxExec to run rxSort in a distributed context
sortedData <- rxExec(FUN = rxSort, 
                     inData = as.data.frame(routes$categorical[[1]]),
                     sortByVars = c("Counts"), 
                     decreasing = TRUE
                    )

head(sortedData)

# Create a non-waiting Hadoop compute context
context <- RxHadoopMR(sshUsername = "sshuser", 
                      sshHostname = "LON-HADOOP",
                      wait = FALSE)
rxSetComputeContext(context)

# Perform the analysis again
job <- rxSummary(~Origin:Dest, flightDelayData)

# Check the status of the job
rxGetJobStatus(job)

# When the job has finished, get the results
# This will fail if the job is still running
routes <- rxGetJobResults(job)
print(routes$categorical[[1]])

# Run the job again
job <- rxSummary(~Origin:Dest, flightDelayData)

# Check the status of the job
rxGetJobStatus(job)

# Cancel the job
rxCancelJob(job)

# Check the status of the job
rxGetJobStatus(job)

# Return to the local compute context
rxSetComputeContext(RxLocalSeq())
