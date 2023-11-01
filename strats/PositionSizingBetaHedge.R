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

# from background ReadMe.md
good_hedges <- c("AGG", "BSV", "SHYG", "SJNK")

df_prices <- read_parquet(
  etf_path) %>% 
  filter(quote == "adjusted") %>% 
  select(-quote) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  ungroup()

df_weighting <- read_parquet(
  file = weighting_path)

df_angl <- df_prices %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "long_price" = price, "long_rtn" = rtn)

df_short <- df_prices %>% 
  filter(ticker %in% good_hedges) %>% 
  rename("short_price" = price) %>% 
  mutate(short_rtn = -rtn) %>% 
  select(-rtn)

initial_capital <- 10000000

# let's work with a hypothetical $10m portfolio

df_prep <- df_angl %>% 
  inner_join(y = df_short, by = "Date", relationship = "many-to-many") %>% 
  inner_join(y = df_weighting, by = c("Date", "ticker")) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(date_idx = 1:n()) %>% 
  filter(date_idx %in% c(1:3) & ticker == "AGG") %>% 
  select(-date_idx) %>% 
  ungroup()

df_remaining <- df_prep %>% 
  filter(Date != min(Date))

#df_first <- 

df_prep %>% 
  filter(Date == min(Date)) %>% 
  mutate(
    prev_port_value = initial_capital,
    long_alloc = initial_capital * long_weight,
    short_alloc = initial_capital * short_weight,
    long_position = floor(long_alloc / long_price),
    short_position = floor(short_alloc / short_price),
    long_value = long_position * long_price,
    short_value = short_position * short_price,
    cash = prev_port_value - long_value - short_value,
    long_pnl = long_value * (1 + long_rtn),
    short_pnl = short_value * (1 + short_rtn))
  
  # mutate(
  #   long_alloc = initial_capital * long_weight,
  #   short_alloc = initial_capital * short_weight,
  #   long_position = floor(long_alloc / long_price),
  #   short_position = floor(short_alloc / short_price),
  #   long_value = long_position * long_price,
  #   short_value = short_position * short_price,
  #   position_value = long_value + short_value,
  #   prev_position_value = replace_na(lag(position_value,1),initial_capital),
  #   cash = prev_position_value - position_value,
  #   port_value = cash + long_value + short_value)

