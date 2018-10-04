# Connect to SQL Server

sqlConnString <- "Driver=SQL Server;Server=LON-SQLR;Database=AirlineData;Trusted_Connection=True"

connection <- RxSqlServerData(connectionString = sqlConnString,
                              table = "dbo.Airports", rowsPerRead = 1000)

# Use R functions to examine the data in the Airports table

head(connection)

rxGetVarInfo(connection)

rxSummary(~., connection)