# Create a SQL Server compute context
sqlConnString <- "Driver=SQL Server;Server=LON-SQLR;Database=AirlineData;Trusted_Connection=Yes" 
sqlWait <- TRUE
sqlConsoleOutput <- TRUE

sqlCompute <- RxInSqlServer(  
  connectionString = sqlConnString,            
  wait = sqlWait,  
  consoleOutput = sqlConsoleOutput)

rxSetComputeContext(sqlCompute)

# Create a data source that retrieves airport information
rxOptions(reportProgress = 1)
airlineData <- RxSqlServerData(connectionString = sqlConnString,
                               table = "dbo.Airports", rowsPerRead = 10000,
                               stringsAsFactors = TRUE)

# Create and display a histogram showing a count of of airports by state
chart <- rxHistogram(~state, data = airlineData,
                     xTitle = "State",
                     yTitle = "Number of Airports",
                     scales = (list(
                       x = list(rot = 90, cex = 0.5)
                     )))

# Save the histogram to SQL Server

# In SQL Server, create a table for storing charts:
#
# CREATE TABLE [dbo].[charts]
# (
#    id    VARCHAR(200) NOT NULL PRIMARY KEY,
#    value VARBINARY(MAX) NOT NULL
# )

# Create an ODBC data source that connects to the charts table
rxSetComputeContext(RxLocalSeq())
chartsTable <- RxOdbcData(table = "charts", connectionString = sqlConnString)

# Save the chart to the charts table, and give it a unique name to identify it later
rxWriteObject(dest = chartsTable, key = "chart1", value = chart)


# Later on ...

# Retrieve the persisted chart
chartObject = rxReadObject(src = chartsTable, key = "chart1" )

# Display the chart
print(chartObject)

