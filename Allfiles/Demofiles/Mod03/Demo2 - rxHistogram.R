# Use the flight delay data
setwd("E:\\Demofiles\\Mod03")
airlineDataFile <- "FlightDelayData.xdf"
airlineData <- RxXdfData(airlineDataFile)
rxGetInfo(airlineData, getVarInfo = TRUE)

# Create a histogram showing the number of flights departing from each state
rxHistogram(~OriginState, airlineData,
            xTitle = "Departure State",
            yTitle = "Number of Flights",
            scales = (list(
              x = list(rot = 90, cex = 0.5)
            )))

# Filter the data to only count late flights
rxHistogram(~OriginState, airlineData, rowSelection = ArrDelay > 0,
            xTitle = "Departure State",
            yTitle = "Number of Late Flights",
            scales = (list(
              x = list(rot = 90, cex = 0.5)
            )))

# Flights by Carrier
flightsByCarrier <- rxHistogram(~UniqueCarrier, airlineData,
                                xTitle = "Carrier",
                                yTitle = "Number of Flights",
                                yAxisMinMax = c(0, 2E6),
                                scales = (list(
                                  x = list(rot = 90, cex = 0.6)
                              )))

# Late flights by carrier
lateFlightsByCarrier <- rxHistogram(~UniqueCarrier, airlineData, rowSelection = ArrDelay > 0,
                                    xTitle = "Carrier",
                                    yTitle = "Number of Late Flights",
                                    yAxisMinMax = c(0, 2E6),
                                    plotAreaColor = "transparent",
                                    fillColor = "magenta",
                                    scales = (list(
                                      x = list(rot = 90, cex = 0.6)
                                  )))

# Display both histograms in adjacent panels
install.packages("latticeExtra")
library(latticeExtra)

print(c(flightsByCarrier, lateFlightsByCarrier))

# Overlay the histograms
print(flightsByCarrier + lateFlightsByCarrier)
