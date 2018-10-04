# EX1
# Generate plots of delay data to visualize any relationship between delay and distance. 
# Use ggplot2, with overlays and facets

# The location of the XDF file used in this exercise
setwd("E:\\Labfiles\\Lab03")

# Create a data source for the extended data
flightDelayDataXdf <- "FlightDelayData.xdf"
flightDelayData <- RxXdfData(flightDelayDataXdf)

# Create a data frame using the columns required for the plots. 
# Create a random sample of 2% of the data (to avoid running out of memory in ggplot)
rxOptions(reportProgress = 1)
delayPlotData <- rxImport(flightDelayData, rowsPerRead = 1000000, 
                     varsToKeep = c("Distance", "Delay", "Origin", "OriginState"),
                     rowSelection = (Distance > 0) & as.logical(rbinom(n = .rxNumRows, size = 1, prob = 0.02))
                )

# Install packages
install.packages("tidyverse")
library(tidyverse)

# Basic plot: Flight Distance vs Total Delay
ggplot(data = delayPlotData) +
  geom_point(mapping = aes(x = Distance, y = Delay)) +
  xlab("Distance (miles)") +
  ylab("Delay (minutes)")

# Add a line plot to establish whether there is a pattern
# Remove all non-existant, negative delays, and questionable outliers first
delayPlotData %>%
  filter(!is.na(Delay) & (Delay >= 0) & (Delay <= 1000)) %>%
  ggplot(mapping = aes(x = Distance, y = Delay)) +
  xlab("Distance (miles)") +
  ylab("Delay (minutes)") +
  geom_point(alpha = 1/50) +
  geom_smooth(color = "red")

# Faceted by originState
delayPlotData %>%
  filter(!is.na(Delay) & (Delay >= 0) & (Delay <= 1000)) %>%
  ggplot(mapping = aes(x = Distance, y = Delay)) +
  xlab("Distance (miles)") +
  ylab("Delay (minutes)") +
  geom_point(alpha = 1/50) +
  geom_smooth(color = "red") +
  theme(axis.text = element_text(size = 6)) +
  facet_wrap( ~ OriginState, nrow = 8)

# EX2

# Add delay as a percentage of flight time to the data

delayDataWithProportionsXdf <- "FlightDelayDataWithProportions.xdf"
delayPlotDataXdf <- rxImport(flightDelayData, outFile = delayDataWithProportionsXdf, 
                             overwrite = TRUE, append ="none", rowsPerRead = 1000000, 
                             varsToKeep = c("Distance", "ActualElapsedTime", "Delay", "Origin", "Dest", "OriginState", "DestState", "ArrDelay", "DepDelay", "CarrierDelay", "WeatherDelay", "NASDelay", "SecurityDelay", "LateAircraftDelay"),
                             rowSelection = (Distance > 0) & (Delay >= 0) & (Delay <= 1000) & !is.na(ActualElapsedTime) & (ActualElapsedTime > 0),
                             transforms = list(DelayPercent = (Delay / ActualElapsedTime) * 100) 
                    )

# Create a cube to summarize the data of interest - gets the data down to a manageable volume for plotting
delayPlotCube <- rxCube(DelayPercent ~ F(Distance):OriginState, data = delayPlotDataXdf,
                        rowSelection = (DelayPercent <= 100)
                 )

names(delayPlotCube)[1] <- "Distance"

# Convert the cube into a data frame (required by rxLinePlot)
delayPlotDF <- rxResultsDF(delayPlotCube)

# Generate line plots of delay as a percentage of flight time versus distance
# First, as a set of points
rxLinePlot(DelayPercent~Distance, data = delayPlotDF, type="p",
           title = "Flight delay as a percentage of flight time against distance",
           xTitle = "Distance (miles)",
           yNumTicks = 10,
           yTitle = "Delay %",
           symbolStyle = ".",
           symbolSize = 2,
           symbolColor = "red",
           scales = (list(x = list(draw = FALSE)))
)

# Next, with a smoothed curve overlay
rxLinePlot(DelayPercent~Distance, data = delayPlotDF, type=c("p", "smooth"),
           title = "Flight delay as a percentage of flight time against distance",
           xTitle = "Distance (miles)",
           yNumTicks = 10,
           yTitle = "Delay %",
           symbolStyle = ".",
           symbolSize = 2,
           symbolColor = "red",
           scales = (list(x = list(draw = FALSE)))
)

# Break the plot down by origin state
rxLinePlot(DelayPercent~Distance | OriginState, data = delayPlotDF, type="smooth",
           title = "Flight delay as a percentage of flight time against distance, by state",
           xTitle = "Distance (miles)",
           yTitle = "Delay %",
           symbolStyle = ".",
           symbolColor = "red",
           scales = (list(x = list(draw = FALSE)))
)


# Examine whether delay might be a function of departure time and day
# Break the departure time down into 30 minute intervals so it can be plotted more easily
delayDataWithDayXdf <- "FlightDelayWithDay.xdf"
delayPlotDataWithDayXdf <- rxImport(flightDelayData, outFile = delayDataWithDayXdf, 
                                    overwrite = TRUE, append ="none", rowsPerRead = 1000000, 
                                    varsToKeep = c("Delay", "CRSDepTime", "DayOfWeek"),
                                    transforms = list(CRSDepTime = cut(as.numeric(CRSDepTime), breaks = 48)),
                                    rowSelection = (Delay >= 0) & (Delay <= 180)
                           )

# Recode the DayOfWeek factor from a number to a meaningful set of abbreviations
delayPlotDataWithDayXdf <- rxFactors(delayPlotDataWithDayXdf, outFile = delayDataWithDayXdf, 
                                     overwrite = TRUE, blocksPerRead = 1,
                                     factorInfo = list(DayOfWeek = list(newLevels = c(Mon = "1", Tue = "2", Wed = "3", Thu = "4", Fri = "5", Sat = "6", Sun = "7"),
                                                                   varName = "DayOfWeek"))
                           )

# Summarize the data
delayDataWithDayCube <- rxCube(Delay ~ CRSDepTime:DayOfWeek, data = delayPlotDataWithDayXdf)

# Convert the cube into a data frame 
delayPlotDataWithDayDF <- rxResultsDF(delayDataWithDayCube)

# Generate a line plot of delay as a function of departure time
rxLinePlot(Delay~CRSDepTime|DayOfWeek, data = delayPlotDataWithDayDF, type=c("p", "smooth"),
           lineColor = "blue",
           symbolStyle = ".",
           symbolSize = 2,
           symbolColor = "red",
           title = "Flight delay, by departure day and time",
           xTitle = "Departure time",
           yTitle = "Delay (mins)",
           xNumTicks = 24,
           scales = (list(y = list(labels = c("0", "20", "40", "60", "80", "100", "120", "140", "160", "180")),
                          x = list(rot = 90),
                                   labels = c("Midnight", "", "", "", "02:00", "", "", "", "04:00", "", "", "", "06:00", "", "", "", "08:00", "", "", "", "10:00", "", "", "", "Midday", "", "", "", "14:00", "", "", "", "16:00", "", "", "", "18:00", "", "", "", "20:00", "", "", "", "22:00", "", "", "")))
           )

#EX 3

# Generate histograms of delay data to visualize the rates of different causes of delay by origin state and time of year. 
delayReasonDataXdf <- "FlightDelayReasonData.xdf"

delayReasonData <- rxImport(flightDelayData, outFile = delayReasonDataXdf, 
                            overwrite = TRUE, append ="none", rowsPerRead = 1000000, 
                            varsToKeep = c("OriginState", "Delay", "ArrDelay", "WeatherDelay", "MonthName"),
                            rowSelection = (Delay >= 0) & (Delay <= 1000) &
                                           (ArrDelay >= 0) & (DepDelay >= 0)
                            )

rxHistogram(formula = ~ ArrDelay, data = delayReasonData, 
            histType = "Counts", title = "Total Arrival Delays",
            xTitle = "Arrival Delay (minutes)",
            xNumTicks = 10)

rxHistogram(formula = ~ ArrDelay, data = delayReasonData, 
            histType = "Percent", title = "Frequency of Arrival Delays",
            xTitle = "Arrival Delay (minutes)",
            xNumTicks = 10)

rxHistogram(formula = ~ ArrDelay | OriginState, data = delayReasonData, 
            histType = "Percent", title = "Frequency of Arrival Delays by State",
            xTitle = "Arrival Delay (minutes)",
            xNumTicks = 10)

rxHistogram(formula = ~ WeatherDelay, data = delayReasonData, 
            histType = "Counts", title = "Frequency of Weather Delays",
            xTitle = "Weather Delay (minutes)",
            xNumTicks = 20, xAxisMinMax = c(0, 180), yAxisMinMax = c(0, 20000))

rxHistogram(formula = ~ WeatherDelay | MonthName, data = delayReasonData, 
            histType = "Counts", title = "Frequency of Weather Delays by Month",
            xTitle = "Weather Delay (minutes)",
            xNumTicks = 10, xAxisMinMax = c(0, 180), yAxisMinMax = c(0, 3000))
