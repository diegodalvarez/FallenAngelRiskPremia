require("arrow")
require("moments")
require("latex2exp")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
etf_path <- file.path(parent_dir, "data", "etf.parquet")
weighting_path <- file.path(parent_dir, "data", "BetaNeutralWeighting.parquet")
prices_path <- file.path(parent_dir, "data", "etf.parquet")
params_path <- file.path(parent_dir, "data", "rollingOLSparams.parquet")
backtest_path <- file.path(parent_dir, "data", "backtest.parquet")

# from background ReadMe.md
good_hedges <- c("AGG", "BSV", "SHYG", "SJNK")

df_prices <- read_parquet(
  etf_path) %>% 
  filter(quote == "adjusted") %>% 
  select(-quote) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(pnl = price - lag(price)) %>% 
  ungroup()

df_weighting <- read_parquet(
  file = weighting_path)

df_angl <- df_prices %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "long_price" = price, "long_pnl" = pnl)

df_short <- df_prices %>% 
  filter(ticker %in% good_hedges) %>% 
  rename("short_price" = price) %>% 
  mutate(short_pnl = -pnl)

backtest <- function(df_prep, initial_capital){
  
  df_out <- tibble()
  for (i in 1:nrow(df_prep)){
    
    df_tmp <- df_prep %>% filter(index == i)
    
    if (i == 1){
      
      df_tmp <- df_tmp %>% 
        mutate(port_init = initial_capital)
    }else{
      
      port_init <- (df_out %>% filter(index == i -1) %>% select(port_end) %>% pull())
      df_tmp <- df_tmp %>% mutate(port_init = port_init)
      
    }
    
    df_tmp <- df_tmp %>% 
      mutate(
        long_alloc = port_init * long_weight,
        short_alloc = port_init * short_weight,
        long_shares = floor(long_alloc / long_price),
        short_shares = floor(short_alloc / short_price),
        long_position = long_shares * long_price,
        short_position = short_shares * short_price,
        cash = port_init - long_position - short_position,
        long_pos_pnl = long_shares * long_pnl,
        short_pos_pnl = short_shares * short_pnl,
        port_end = long_position + short_position + cash + long_pos_pnl + short_pos_pnl)
    
    df_out <- bind_rows(df_out, df_tmp)
  }
  return(df_out)
}


initial_capital <- 10000000

# let's work with a hypothetical $10m portfolio

df_backtest <- df_angl %>% 
  inner_join(y = df_short, by = "Date", relationship = "many-to-many") %>% 
  inner_join(y = df_weighting, by = c("Date", "ticker")) %>% 
  group_by(ticker) %>% 
  mutate(index = 1:n()) %>% 
  arrange(Date) %>% 
  group_modify(~backtest(., initial_capital = initial_capital)) %>%
  ungroup()

df_backtest %>% write_parquet(
  backtest_path)
