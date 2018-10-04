# Cluster the data in the diamonds dataset into 5 partitions by carat, depth, and price
install.packages("ggplot2")
library(ggplot2)

clust <- rxKmeans(~ carat + depth + price, 
                  data = ggplot2::diamonds, 
                  numClusters = 5, seed = 1979)

# Examine the cluster
clust
clust$numIterations

# Assess the variation between clusters
clust$betweenss / clust$totss

# Examine the standard deviations between the cluster variables
apply(ggplot2::diamonds[,c("carat", "depth", "price")], 2, sd)

# Create a cluster with standardized data
clust_z <- rxKmeans(~ carat_z + depth_z + price_z, 
                    data = ggplot2::diamonds, 
                    numClusters = 5, seed = 1979,
                    transforms = list(
                      carat_z = (carat - mean(carat)) / sd(carat),
                      depth_z = (depth - mean(depth)) / sd(depth),
                      price_z = (price - mean(price)) / sd(price))
)

# Examine the cluster sums of squares
clust_z$betweenss / clust_z$totss

# Examine the influence of each variable
clust_z$centers

# Run a series of models over a range of values of k
numClusters <- 20
ratio = double(numClusters)
for (k in c(1:numClusters)) {
  clust_z <- rxKmeans(~ carat_z + depth_z + price_z, 
                      data = ggplot2::diamonds, 
                      numClusters = k, seed = 1979,
                      transforms = list(
                        carat_z = (carat - mean(carat)) / sd(carat),
                        depth_z = (depth - mean(depth)) / sd(depth),
                        price_z = (price - mean(price)) / sd(price))
  )
  
  ratio[k] <- clust_z$betweenss / clust_z$totss
}

# Plot the results
plotData <- data.frame(num = c(1:numClusters), ratio)
rxLinePlot(ratio ~ num, plotData, type="p")
