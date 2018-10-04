# Connect to R Server
remoteLogin(deployr_endpoint = "http://LON-RSVR.ADATUM.COM:12800", session = TRUE, diff = TRUE, commandline = TRUE, username = "admin", password = "Pa55w.rd")

# Create dice game simulation function:
# If you roll a 7 or 11 on your initial roll, you win. 
# If you roll 2, 3, or 12, you lose. 
# Roll a 4, 5, 6, 8, 9, or 10, and that number becomes your point and you continue rolling until you either roll your point again in which case you win, or roll a 7, in which case you lose. 
playDice <- function()
{
  result <- NULL
  point <- NULL
  count <- 1
  while (is.null(result))
  {
    roll <- sum(sample(6, 2, replace=TRUE))
    
    if (is.null(point))
    {
      point <- roll
    }
    if (count == 1 && (roll == 7 || roll == 11))
    {
      result <- "Win"
    }
    else if (count == 1 && (roll == 2 || roll == 3 || roll == 12))
    {
      result <- "Loss"
    }
    else if (count > 1 && roll == 7 )
    {
      result <- "Loss"
    }
    else if (count > 1 && point == roll)
    {
      result <- "Win"
    }
    else
    {
      count <- count + 1
    }
  }
  result
}

# Test the function
playDice()

# Play the game 100000 times sequentially
system.time(diceResults <- replicate(100000, playDice()))
table(unlist(diceResults))

# Play the game 100000 times using rxExec
rxGetComputeContext()
system.time(diceResults <- rxExec(playDice, timesToRun=100000, taskChunkSize = 20000))
table(unlist(diceResults))

# Switch to RxLocalParallel. rxExec will run tasks in parallel
# Elapsed time may be longer on a single-node cluster or for small jobs
rxSetComputeContext(RxLocalParallel())
system.time(diceResults <- rxExec(playDice, timesToRun=100000, taskChunkSize = 20000))
table(unlist(diceResults))
