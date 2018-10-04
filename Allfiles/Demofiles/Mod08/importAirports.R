setwd("E:\\Demofiles\\Mod08")
conString <- "Server=LON-SQLR;Database=AirlineData;Trusted_Connection=TRUE"
airportData <- RxSqlServerData(connectionString = conString, table = "Airports")
colClasses <- c(
	"iata" = "character",
	"airport" = "character",
	"city" = "character",
	"state" = "factor",
	"country" = "factor",
	"lat" = "numeric",
	"long" = "numeric")
csvData <- RxTextData(file = "airports.csv", colClasses = colClasses)
rxDataStep(inData = csvData, outFile = airportData, overwrite = TRUE)
