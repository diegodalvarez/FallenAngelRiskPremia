require("arrow")
require("lpSolve")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
param_path <- file.path(parent_dir, "data", "rollingOLSparams.parquet")
out_path <- file.path(parent_dir, "data", "BetaNeutralWeighting.parquet")

# from background ReadMe.md
good_hedges <- c("AGG", "BSV", "SHYG", "SJNK")

df_beta <- read_parquet(
  file = param_path) %>% 
  filter(ticker %in% good_hedges) %>% 
  select(-alpha)

neutralize_beta <- function(neg_beta){
  
  pos_beta <- 1
  
  obj.in <- c(pos_beta, neg_beta)
  const.mat <- matrix(
    data = c(pos_beta, neg_beta, 1,0,0,1,1,1),
    nrow = 4,
    byrow = TRUE)
  const.rhs <- c(0,0,0,1)
  const.dir <- c("=", ">", ">", "=")
  
  optimize <- lp(
    direction = "min",
    objective.in = obj.in,
    const.mat = const.mat,
    const.dir = const.dir,
    const.rhs = const.rhs)
  
  out <- round(optimize$solution,4)[1]
  return(out)
}

find_beta <- function(df){
  
  raw_beta <- df %>% select(beta) %>% pull()
  long_weight <- neutralize_beta(raw_beta)
  
  df_out <- df %>% 
    mutate(
      long_weight = long_weight,
      short_weight = 1 - long_weight)
  
  return(df_out)
  
}

df_weighting <- df_beta %>% 
  mutate(beta = beta * -1) %>% 
  group_by(ticker, Date) %>% 
  group_modify(~find_beta(.)) %>% 
  ungroup()

df_weighting %>% 
  write_parquet(out_path)
