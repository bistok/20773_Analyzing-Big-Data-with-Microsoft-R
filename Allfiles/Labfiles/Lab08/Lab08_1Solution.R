# Lab Initialization:
# Create FlightDelays database
# Copy FlightDelayDataSample.xdf to shared folder
# Enable external scripts in SQL Server
#    sp_configure 'external scripts enabled', 1
#    reconfigure
#    restart SQL Server

# Ex 1:

# Run the first part locally - SQL Server compute context cannot access XDF files
rxSetComputeContext(RxLocalSeq())

# Create a SQL Server data source for uploading the flight delay data
connStr <- "Driver=SQL Server;Server=LON-SQLR;Database=FlightDelays;Trusted_Connection=Yes"
flightDelayDataTable <- RxSqlServerData(connectionString = connStr,
                                        table = "flightdelaydata")

# Upload flight delay data to FlightDelays database
# Add a boolean factor variable, DelayedByWeather, as the data is uploaded
# Also add a column to indicate whether a row should be used for training the predictive model or testing it
rxOptions(reportProgress = 2)
flightDelayDataFile <- "\\\\LON-RSVR\\Data\\FlightDelayDataSample.xdf"
flightDelayData <- rxDataStep(inData = flightDelayDataFile,
                              outFile = flightDelayDataTable, overwrite = TRUE,
                              transforms = list(DelayedByWeather = factor(ifelse(is.na(WeatherDelay), 0, WeatherDelay) > 0, levels = c(FALSE, TRUE)),
                                                Dataset = factor(ifelse(runif(.rxNumRows) >= 0.05, "train", "test")))
)

# Create a SQL Server compute context and connect
sqlWait <- TRUE
sqlConsoleOutput <- TRUE
sqlContext <- RxInSqlServer(connectionString = connStr,   
                            wait = sqlWait, consoleOutput = sqlConsoleOutput
)
rxSetComputeContext(sqlContext)

# Create a data source for the weather delay data and factorize the delay
weatherDelayQuery = "SELECT Month, MonthName, OriginState, DestState, Dataset,
                            DelayedByWeather, WeatherDelayCategory = CASE
                              WHEN CEILING(WeatherDelay) <= 0 THEN 'No delay'
                              WHEN CEILING(WeatherDelay) BETWEEN 1 AND 30 THEN '1-30 minutes'
                              WHEN CEILING(WeatherDelay) BETWEEN 31 AND 60 THEN '31-60 minutes'
                              WHEN CEILING(WeatherDelay) BETWEEN 61 AND 120 THEN '61-120 minutes'
                              WHEN CEILING(WeatherDelay) BETWEEN 121 AND 180 THEN '121-180 minutes'
                              WHEN CEILING(WeatherDelay) >= 181 THEN 'More than 180 minutes'
                            END
                     FROM flightdelaydata"

delayDataSource <- RxSqlServerData(sqlQuery = weatherDelayQuery,
                                   colClasses = c(
                                     Month = "factor",
                                     OriginState = "factor",
                                     DestState = "factor",
                                     Dataset = "character",
                                     DelayedByWeather = "factor",
                                     WeatherDelayCategory = "factor"
                                   ),
                                   colInfo = list(
                                     MonthName = list(
                                       type = "factor",
                                       levels = month.name
                                     )
                                   ),
                                   connectionString = connStr
)

# Summarize the weather delay data
rxGetVarInfo(delayDataSource)
rxSummary(~., delayDataSource)

# Visualize weather delays by month
rxHistogram(~WeatherDelayCategory | MonthName, 
            data = delayDataSource,
            xTitle = "Weather Delay",
            scales = (list(
              x = list(rot = 90)
            ))
)

# Visualize weather delays by origin state
rxHistogram(~WeatherDelayCategory | OriginState, 
            data = delayDataSource,
            xTitle = "Weather Delay",
            scales = (list(
              x = list(rot = 90, cex = 0.5)
            ))
)



# EX 2:

# Fit a DForest model 
# - will a flight departing from a specific state to another state in a given month be delayed due to weather?
weatherDelayModel <- rxDForest(DelayedByWeather ~ Month + OriginState + DestState,
                               data = delayDataSource,
                               cp = 0.0001, 
                               rowSelection = (Dataset == "train")
)

# Get the overall error rate for the model
weatherDelayModel

# Inspect the details of the model
head(weatherDelayModel)

# Plot the influence that each predictor variable has on the forecast results
rxVarUsed(weatherDelayModel)

# Predict weather delays and score the results
# Use the test dataset for scoring
delayDataSource@sqlQuery <- paste(delayDataSource@sqlQuery, "WHERE Dataset = 'test'", sep = " ")

# Save the scores in SQL Server
weatherDelayScoredResults <- RxSqlServerData(connectionString = connStr,
                                             table = "scoredresults")

# Temporarily switch back to the local compute context 
# (rxPredict doesn't currently work properly in the SQL Server compute context)
rxSetComputeContext(RxLocalSeq())

# Make predictions against the test data and save them
rxPredict(modelObj = weatherDelayModel,
          data = delayDataSource,
          outData = weatherDelayScoredResults, overwrite = TRUE,
          writeModelVars = TRUE,
          predVarNames = c("PredictedDelay", "PredictedNoDelay", "PredictedDelayedByWeather"),
          type = "prob"
)

# Return to the SQL Server compute context
rxSetComputeContext(sqlContext)

# Use the ROCR library to plot the accuracy of the predictions made against the real data
install.packages('ROCR')
library(ROCR)

# Transform the prediction data into a standardized form
results <- rxImport(weatherDelayScoredResults)
weatherDelayPredictions <- prediction(results$PredictedDelay, results$DelayedByWeather)

# Plot the ROC curve of the predictions
rocCurve <- performance(weatherDelayPredictions, measure = "tpr", x.measure = "fpr")
plot(rocCurve)



# EX 3:

# Serialize the model as a string of binary data for storing in SQL Server
serializedModel <- serialize(weatherDelayModel, NULL)
serializedModelString <- paste(serializedModel, collapse = "")

# In SQL Server, create a table for storing models:
#
# CREATE TABLE [dbo].[delaymodels]
# (
#    modelId   INT IDENTITY(1,1) NOT NULL Primary KEY,
#    model     VARBINARY(MAX) NOT NULL
# )
#
# Create a stored proc to save models:
#
# CREATE PROCEDURE [dbo].[PersistModel]  @m NVARCHAR(MAX)  
# AS  
# BEGIN  
#   SET NOCOUNT ON;  
#   INSERT INTO delaymodels(model) VALUES (CONVERT(VARBINARY(MAX),@m,2))  
# END

# Save the model to SQL Server
install.packages('RODBC')
library(RODBC)

connection <- odbcDriverConnect(connStr)
cmd <- paste("EXEC PersistModel @m='", serializedModelString, "'", sep = "")
sqlQuery(connection, cmd)

# Create a stored procedure for predicting whether a specified flight will be delayed.
#  - Pass a the month, origin state, and destination state as parameters
#  - Use the model to generate the prediction
#  - Return a result set that includes the probability of the flight being delayed
#
# CREATE PROCEDURE [dbo].[PredictWeatherDelay]   
# @Month integer = 1,
# @OriginState char(2),
# @DestState char(2)  
# AS  
# BEGIN  
#
#   DECLARE @weatherDelayModel varbinary(max) = (SELECT TOP 1 model  FROM dbo.delaymodels)
#
#   EXEC sp_execute_external_script @language = N'R',  
#     @script = N' 
# 	    delayParams <- data.frame(Month = month, OriginState = originState, DestState = destState)  
#         delayModel <- unserialize(as.raw(model))  
#         OutputDataSet<-rxPredict(modelObject = delayModel, 
#             data = delayParams, 
#             outData = NULL, 
#             predVarNames = c("PredictedDelay", "PredictedNoDelay", "PredictedDelayedByWeather"),
#             type = "prob", 
#             writeModelVars = TRUE)',    
#     @params = N'@model varbinary(max),
#                 @month integer,
# 		            @originState char(2),
# 			          @destState char(2)',  
#     @model = @weatherDelayModel,
#     @month = @Month,
#     @originState = @OriginState,
#     @destState = @DestState   
#   WITH RESULT SETS (([PredictedDelay] float, [PredictedNoDelay] float, [PredictedDelayedByWeather] bit, [Month] integer, [OriginState] char(2), [DestState] char(2)));  
# END

# Call the stored procedure with some test data
cmd <- "EXEC [dbo].[PredictWeatherDelay] @Month = 11, @OriginState = 'GA', @DestState = 'NY'"
sqlQuery(connection, cmd)

