# Create a Hadoop compute context
context <- RxHadoopMR(sshUsername = "sshuser", 
                      sshHostname = "LON-HADOOP")

rxSetComputeContext(context)

# List the contents of the /user/sshuser folder in HDFS
rxHadoopCommand("fs -ls /user/sshuser")

# Connect directly to HFDS on the Hadoop VM
hdfsConnection <- RxHdfsFileSystem()
rxSetFileSystem(hdfsConnection)

# Create a data source for the CensusWorkers.xdf file
workerInfo <- RxXdfData("/user/sshuser/CensusWorkers.xdf")

# Perform functions that read from the CensusWorkers.xdf file
head(workerInfo)
rxSummary(~., workerInfo)
