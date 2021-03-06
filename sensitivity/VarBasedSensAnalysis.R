# Variance-Based Sensitivity Analysis


###=======================================================================
### Parameters
###=======================================================================
#install.packages('sensitivity')
#install.packages('markovchain')

library(sensitivity)
library(boot)
library(lhs)

# highHarvestFecundity <- 1 # Multiplier for fecundity rate for Adult trees under HIGH harvest
# highHarvestSurvival <- 0.9 # Multiplier for survival rate of Adult trees under HIGH harvest
# agoutiGrowth <- 1.1 # Growth rate of Agoutis in logistic model
# 
# lowHunting <- 0.1 # Percentage of agoutis hunted during LOW hunting
# highHunting <- 0.25 # Percentage of agoutis hunted during HIGH hunting

seedlingCapacity <- 5000 # Carrying Capacities. Tree capacities don't matter as much.
saplingCapacity <- 500
adultCapacity <- 100
agoutiCapacity <- 5200
perc <- 0.9
ylimit <- 1 # For plotting

seedlingInit <- perc * seedlingCapacity#5000 # Initial Populations
saplingInit <- perc * saplingCapacity#500
adultInit <- perc * adultCapacity#100
agoutiInit <- perc * agoutiCapacity#5000

# m <- 0.05    # m is the desired proportion at which sigmoid(m) = m . Ideally it is small (~0.01-0.05).
# agouti_to_PlantSteepness <- -(log(1-m)-log(m))/((m-0.5)*agoutiCapacity) # Steepness needed for sigmoid(m) = m
# plant_to_AgoutiSteepness <- -(log(1-m)-log(m))/((m-0.5)*adultCapacity)  # Steepness needed for sigmoid(m) = m
#This formula above is derived from logistic function with "x = m*CAP" , "x0 = .5*CAP" , "y = m" , and solving for k. (CAP = carrying capacity)

time_end <- 500 # Length of simulation in years
maxt <- 500 # Length of simulation for stoch_growth function.

#brazilNut <- list(low=plant_mat_low, high=plant_mat_high)

# high_harv <- matrix(1, nrow = 17, ncol = 17)

##=======The Original 17-Stage Matrix from Zuidema and high-harvest multiplier
# plant_S_mat <- matrix( 0, nrow = 17, ncol = 17)
# diag(plant_S_mat) <- c(0.455, 0.587, 0.78, 0.821, 0.941, 0.938, 0.961, 0.946, 0.94, 0.937, 0.936, 0.966, 0.968, 0.971, 0.965, 0.967, 0.985)
# plant_S_mat[cbind(2:17,1:16)] <- matrix(c(0.091, 0.147, 0.134, 0.167, 0.044, 0.047, 0.034, 0.049, 0.055, 0.058, 0.059, 0.029, 0.027, 0.024, 0.020, 0.018))
# plant_S_mat[1,12:17] <- matrix( c(12.3, 14.6, 16.9, 19.3, 22.3, 26.6) )
# high_harv[1,12:17] <- highHarvestFecundity 
# high_harv[cbind(12:17,12:17)] <- highHarvestSurvival # Multiplier for survival rate of Adult trees
# plant_mat_low <- plant_S_mat
# plant_mat_high <- plant_S_mat * high_harv


#===========================================================================
#============FUNCTIONS======================================================
#===========================================================================

sigmoid <- function(k, x0, x) 
{
  1/(1+exp(-k*(x-x0))) #k: steepness #x0 = midpoint
} 


linear <- function(m, x, b)
{
  y <- m*x + b
  return(y)
}


LogisticGrowthHunt<- function(R, N, K, H, p) 
{ # p is how the plant affects carrying capacity of agoutis (from 0 to 1)
  Nnext <- R*N*(1-N/(K*(p))) - H*N + N
  return(Nnext)
}


LogisticGrowthHuntRK<- function(R, N, K, H, p,s) 
{ # p is how the plant affects carrying capacity of agoutis (from 0 to 1)
  Nnext <- R*(s)*N*(1-N/((K*(p)))) - H*N + N
  return(Nnext)
} 


# Specifying the markov chain
library('markovchain')
markovChain<- function(tEnd){
  
  statesNames = c("low","high")
  mcHarvest <- new("markovchain", states = statesNames, 
                   transitionMatrix = matrix(data = c(0.2, 0.8, 0.8, 0.2), byrow = TRUE, 
                                             nrow = 2, dimnames=list(statesNames,statesNames)), name="Harvest")
  # Simulating a discrete time process for harvest
#  set.seed(100)
  harvest_seq <- markovchain::rmarkovchain(n=tEnd, object = mcHarvest, t0="low")
  return(harvest_seq)
}

#harvest_seq <- markovChain(time_end)




###=====================================================================

# Parameter list is as follows:
# 1.  m (determines steepness of sigmoid) ... [0.03, 0.1]
# 2.  delta ... [0, 1]
# 3.  high harvest fecundity ... [0, .9] ... get better interval?
# 4.  high harvest adult survival ... [0, .9] ... get better interval?
# 5.  low hunting rate (herbivores) ... [0, 0.25]
# 6.  high hunting rate (herbivores) ... [0.25, 1]
# 7.  rMax (herbivore) ... [0.2, 1.1]
# 8.  Adult Plant Carrying Capacity ... [50, 150]
# 9.  delta_plant ... [0, 1]

# To be added:
# 10. initial populations ... []
# 11. 
# 12. 

plant_sobol <- function(X) # X is matrix of parameters. Columns are each parameter. Rows are different parameter sets.
{
  # Function taking in matrix of parameters
  # Returns (nx1) matrix of stochastic growth rates
  
  numSamples <- nrow(X)
  stochGrowthRates <- numeric(numSamples)
  popAfterTime <- numeric(numSamples)

  for (i in 1:numSamples)
  {
    # Unpacking parameters from matrix
    m <- X[i, 1] * (0.1 - 0.03) + 0.03 # Mapping [0,1] to [0.03,0.1]
    delta <- X[i, 2] # No need for mapping since delta is in [0,1] already
    highHarvestFecundity <- X[i, 3] * (0.9 - 0) + 0 # No mapping?
    highHarvestSurvival <- X[i, 4] * (0.9 - 0) + 0 # Mapping to [0,0.9]
#    lowHunting <- X[i, 5] * (0.25 - 0) + 0 # Mapping to [0,0.25]
#    highHunting <- X[i, 6] * (1 - 0.25) + 0.25 # Mapping to [0.25,1]
    constHunt <- X[i, 5]
    agoutiGrowth <- X[i, 6] * (1.1 - 0.2) + 0.2 # Mapping to [0.2,1.1]
    adultCapacity <- X[i, 7] * (150 - 50) + 50 # Mapping to [50,150]
    deltaPlant <- X[i, 8] # No need for mapping
    
    ### Using parameters ###
    # Setting low harvest matrix
    plant_S_mat <- matrix( 0, nrow = 17, ncol = 17)
    diag(plant_S_mat) <- c(0.455, 0.587, 0.78, 0.821, 0.941, 0.938, 0.961, 0.946, 0.94, 0.937, 0.936, 0.966, 0.968, 0.971, 0.965, 0.967, 0.985)
    plant_S_mat[cbind(2:17,1:16)] <- matrix(c(0.091, 0.147, 0.134, 0.167, 0.044, 0.047, 0.034, 0.049, 0.055, 0.058, 0.059, 0.029, 0.027, 0.024, 0.020, 0.018))
    plant_S_mat[1,12:17] <- matrix( c(12.3, 14.6, 16.9, 19.3, 22.3, 26.6) )
    
    # Setting high harvest matrix
    high_harv <- matrix(1, nrow = 17, ncol = 17)    
    high_harv[1,12:17] <- highHarvestFecundity 
    high_harv[cbind(12:17,12:17)] <- highHarvestSurvival # Multiplier for survival rate of Adult trees
    
    plant_mat_low <- plant_S_mat
    plant_mat_high <- plant_S_mat * high_harv
    
    agouti_to_PlantSteepness <- -(log(1-m)-log(m))/((m-0.5)*agoutiCapacity) # Steepness needed for sigmoid(m) = m
    plant_to_AgoutiSteepness <- -(log(1-m)-log(m))/((m-0.5)*adultCapacity) 
    
    r <- numeric(maxt) # maxt is global constant
    plant_mat <- matrix(0, nrow = 17)
    plant_mat[1:4] <- seedlingInit/4   # Initial populations are constants
    plant_mat[5:11] <- saplingInit/7   # So they are not parameters
    plant_mat[12:17] <- adultInit/6 
    agouti_vec <- c(agoutiInit) * 0.5

    harvest_seq <- markovChain(maxt)

    
    N <- 0 # Pop of plants after time maxt

    # Running the simulation to find 'Stochastic Growth Rate'
    for (j in 1:maxt)
    {
      h_j <- harvest_seq[j]
      
      if (h_j == "low") 
      {
        pmat <- plant_mat_low
#        h_off <- lowHunting
        h_off <- constHunt
        
      } 

      else 
      {
        pmat <- plant_mat_high
#        h_off <- highHunting
        h_off <- constHunt
      }

      prevN <- sum(plant_mat)

      p <- sigmoid(plant_to_AgoutiSteepness, adultCapacity/2, sum(plant_mat[12:17]))*delta + (1-delta)
      agouti_vec[(j+1)] <- LogisticGrowthHunt(agoutiGrowth, agouti_vec[(j)],agoutiCapacity,h_off, p)

      if (agouti_vec[j+1] < 0)
      {
        agouti_vec[j+1] <- 0
      }

      plant_animal_mat <- matrix(1, nrow = 17, ncol = 17)
      plant_animal_mat[1,12:17] <- sigmoid(agouti_to_PlantSteepness, agoutiCapacity/2, agouti_vec[(j+1)])*deltaPlant + (1- deltaPlant)
      #  plant_animal_mat[1,12:17] <- linear(m, agouti_vec[(j+1)], b) # A different functional form
      plant_mat <- matrix( c((plant_animal_mat * pmat) %*% plant_mat))

      N <- sum(plant_mat) 
      r[i] <- log(N / prevN) # Calculating Growth Rate
    }

#    stochGrowthRates[i] <- exp(mean(r)) # Collect growth rates into column vector
    popAfterTime[i] <- N # Plant population after time. (not animals)
    
  }
#  return(stochGrowthRates)
  return(popAfterTime)
  
}



animal_sobol <- function(X) # X is matrix of parameters. Columns are each parameter. Rows are different parameter sets.
{
  # Function taking in matrix of parameters
  # Returns (nx1) matrix of stochastic growth rates
  
  numSamples <- nrow(X)
  stochGrowthRates <- numeric(numSamples)
  popAfterTime <- numeric(numSamples)
  
  for (i in 1:numSamples)
  {
    # Unpacking parameters from matrix
    m <- X[i, 1] * (0.1 - 0.03) + 0.03 # Mapping [0,1] to [0.03,0.1]
    delta <- X[i, 2] # No need for mapping since delta is in [0,1] already
    highHarvestFecundity <- X[i, 3] * (0.9 - 0) + 0 # No mapping?
    highHarvestSurvival <- X[i, 4] * (0.9 - 0) + 0 # Mapping to [0,0.9]
    #    lowHunting <- X[i, 5] * (0.25 - 0) + 0 # Mapping to [0,0.25]
    #    highHunting <- X[i, 6] * (1 - 0.25) + 0.25 # Mapping to [0.25,1]
    constHunt <- X[i, 5]
    agoutiGrowth <- X[i, 6] * (1.1 - 0.2) + 0.2 # Mapping to [0.2,1.1]
    adultCapacity <- X[i, 7] * (150 - 50) + 50 # Mapping to [50,150]
    deltaPlant <- X[i, 8] # No need for mapping
    
    ### Using parameters ###
    # Setting low harvest matrix
    plant_S_mat <- matrix( 0, nrow = 17, ncol = 17)
    diag(plant_S_mat) <- c(0.455, 0.587, 0.78, 0.821, 0.941, 0.938, 0.961, 0.946, 0.94, 0.937, 0.936, 0.966, 0.968, 0.971, 0.965, 0.967, 0.985)
    plant_S_mat[cbind(2:17,1:16)] <- matrix(c(0.091, 0.147, 0.134, 0.167, 0.044, 0.047, 0.034, 0.049, 0.055, 0.058, 0.059, 0.029, 0.027, 0.024, 0.020, 0.018))
    plant_S_mat[1,12:17] <- matrix( c(12.3, 14.6, 16.9, 19.3, 22.3, 26.6) )
    
    # Setting high harvest matrix
    high_harv <- matrix(1, nrow = 17, ncol = 17)    
    high_harv[1,12:17] <- highHarvestFecundity 
    high_harv[cbind(12:17,12:17)] <- highHarvestSurvival # Multiplier for survival rate of Adult trees
    
    plant_mat_low <- plant_S_mat
    plant_mat_high <- plant_S_mat * high_harv
    
    agouti_to_PlantSteepness <- -(log(1-m)-log(m))/((m-0.5)*agoutiCapacity) # Steepness needed for sigmoid(m) = m
    plant_to_AgoutiSteepness <- -(log(1-m)-log(m))/((m-0.5)*adultCapacity) 
    
    r <- numeric(maxt) # maxt is global constant
    plant_mat <- matrix(0, nrow = 17)
    plant_mat[1:4] <- seedlingInit/4   # Initial populations are constants
    plant_mat[5:11] <- saplingInit/7   # So they are not parameters
    plant_mat[12:17] <- adultInit/6 
    agouti_vec <- c(agoutiInit) * 0.5
    
    harvest_seq <- markovChain(maxt)
    
    
    N <- 0 # Pop of animals after time maxt
    
    for (j in 1:maxt)
    {
      h_j <- harvest_seq[j]
      
      if (h_j == "low") 
      {
        pmat <- plant_mat_low
        h_off <- constHunt
        
      } 
      
      else 
      {
        pmat <- plant_mat_high
        h_off <- constHunt
      }

      
      p <- sigmoid(plant_to_AgoutiSteepness, adultCapacity/2, sum(plant_mat[12:17]))*delta + (1-delta)
      agouti_vec[(j+1)] <- LogisticGrowthHunt(agoutiGrowth, agouti_vec[(j)],agoutiCapacity,h_off, p)
      
      if (agouti_vec[j+1] < 0)
      {
        agouti_vec[j+1] <- 0
      }
      
      plant_animal_mat <- matrix(1, nrow = 17, ncol = 17)
      plant_animal_mat[1,12:17] <- sigmoid(agouti_to_PlantSteepness, agoutiCapacity/2, agouti_vec[(j+1)])*deltaPlant + (1- deltaPlant)
      plant_mat <- matrix( c((plant_animal_mat * pmat) %*% plant_mat))
      
      N <- agouti_vec[j+1] 
    }
    
    popAfterTime[i] <- N # Plant population after time. (not animals)
    
  }
  #  return(stochGrowthRates)
  return(popAfterTime)
  
}

###=====================================================================
# List of parameters/factors in the order they are used
factList <- c('m', 'delta_a', 'High Harv Germ', 'High Harv Surv', 'Low Hunt', 'High Hunt', 'r_max', 'Adult Plant Capacity', 'delta_p')

# Regular (Monte-Carlo) Sobol
#n <- 100
#X1 <- data.frame(matrix(runif(8 * n), nrow = n))
#X2 <- data.frame(matrix(runif(8 * n), nrow = n))

#result <- sobol(model = plant_sobol, X1 = X1, X2 = X2, order = 1, nboot = 100)
#print(result)


# Lating Hypercube Sampling Sobol
#lhsSobol <- sobolroalhs(model = plant_sobol, factors = 9, N = 10000, p = 1, order = 1, nboot = 1)
#print(lhsSobol)
#plot(lhsSobol)


#Fourier Amplitude Sens Test (Saltelli) --- Kinda Working?
fastPlant <- fast99(model = plant_sobol, factors = 8, n = 10000, q.arg = list(min=0.0, max=1.0))
print(fastPlant)
plot(fastPlant)

fastAnimal <- fast99(model = animal_sobol, factors = 8, n = 10000, q.arg = list(min=0.0, max=1.0))
print(fastAnimal)
plot(fastAnimal)

# indicesFirst <- (fastPlant$D1 / fastPlant$V)
# indicesTotal <- (1 - fastPlant$Dt / fastPlant$V - indicesFirst)
# 
# data <- data.frame(indicesFirst, indicesTotal)
# factList <- c('m', expression(delta[a]), expression(G[t]), expression(S[t]), expression(hat(R)), expression(r[max]), expression(K[2]), expression(delta[p]))
# counts <- table(indicesFirst, indicesTotal)
# barplot(t(as.matrix(data)), names.arg = factList, ylim = c(0,1), legend.text = c('Main Effect', 'Interactions'), xlab = 'Parameters', main = "Variance-Based Sensitivity Analysis")
# par(bg='white')
# dev.copy(png, 'SobolNoBackground.png')
# dev.off()

# Plotting 1st order indices
indicesFirstPlant <- (fastPlant$D1 / fastPlant$V)
indicesFirstAnimal <- (fastAnimal$D1 / fastAnimal$V)

data <- data.frame(indicesFirstPlant, indicesFirstAnimal)
factList <- c('m', expression(delta[a]), expression(G[t]), expression(S[t]), expression(hat(R)), expression(r[max]), expression(K[2]), expression(delta[p]))
counts <- table(indicesFirstPlant, indicesFirstAnimal)
barplot(t(as.matrix(data)), names.arg = factList, ylim = c(0,0.6), legend.text = c('Plant', 'Animal'), xlab = 'Parameters', main = "First-Order Sobol Indices", col = c('yellowgreen', 'coral1'))
par(bg='white')
dev.copy(png, 'SobolNoBackground.png')
dev.off()


# Plotting total-order indices
indicesTotalPlant <- (1 - fastPlant$Dt / fastPlant$V - indicesFirstPlant)
indicesTotalAnimal <- (1 - fastAnimal$Dt / fastAnimal$V - indicesFirstAnimal)

data <- data.frame(indicesTotalPlant, indicesTotalAnimal)
factList <- c('m', expression(delta[a]), expression(G[t]), expression(S[t]), expression(hat(R)), expression(r[max]), expression(K[2]), expression(delta[p]))
counts <- table(indicesTotalPlant, indicesTotalAnimal)
barplot(t(as.matrix(data)), names.arg = factList, ylim = c(0,1.0), legend.text = c('Plant', 'Animal'), xlab = 'Parameters', main = "Total-Order Sobol Indices", col = c('yellowgreen', 'coral1'))
par(bg='white')
dev.copy(png, 'SobolNoBackground.png')
dev.off()
