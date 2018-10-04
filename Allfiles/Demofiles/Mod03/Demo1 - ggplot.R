# Install packages
install.packages("tidyverse")
library(tidyverse)

# Create a data frame containing 2% of the flight delay data
setwd("E:\\Demofiles\\Mod03")
airlineDataFile <- "FlightDelayReasonData.xdf"
airlineData <- rxImport(airlineDataFile,
                        rowSelection = (Delay > 0) & as.logical(rbinom(n = .rxNumRows, size = 1, prob = 0.05)))
                        
rxGetInfo(airlineData, getVarInfo = TRUE)

# Generate a plot of Departure Delay time versus Arrival Delay time
ggplot(data = airlineData) +
  geom_point(mapping = aes(x = ArrDelay, y = DepDelay), alpha = 1/50) +
  xlab("Arrival Delay (minutes") +
  ylab("Departure Delay (minutes)")

# Fit a regression line to this data
ggplot(data = airlineData, mapping = aes(x = ArrDelay, y = DepDelay)) +
  geom_point(alpha = 1/50) +
  geom_smooth(color = "red") + 
  xlab("Arrival Delay (minutes") +
  ylab("Departure Delay (minutes)")

# Facet by month
ggplot(data = airlineData, mapping = aes(x = ArrDelay, y = DepDelay)) +
  geom_point(alpha = 1/50) +
  geom_smooth(color = "red") + 
  facet_wrap( ~ MonthName, nrow = 3) +
  xlab("Arrival Delay (minutes") +
  ylab("Departure Delay (minutes)")
