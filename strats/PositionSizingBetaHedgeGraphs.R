require("arrow")
require("moments")
require("latex2exp")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
backtest_path <- file.path(parent_dir, "data", "backtest.parquet")

df_raw <- read_parquet(backtest_path) 

df_cum_rtn <- df_raw %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(
    rtn = replace_na(port_end / lag(port_end) - 1,0),
    cum_rtn = (cumprod(1 + rtn) - 1) * 100) 

start_date <- min(df_cum_rtn$Date)
end_date <- max(df_cum_rtn$Date)

df_cum_rtn %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  labs(title = paste("Cumulative L/S Beta Neutral Returns from", start_date, "to", end_date)) +
  ylab("Cumulative Return (%)")

df_beta <- df_raw %>% 
  select(ticker, Date, port_end, long_position, short_position, beta) %>% 
  mutate(
    long_beta = long_position / port_end,
    short_beta = short_position / port_end * beta,
    beta_exposure = long_beta + short_beta) 

df_beta %>% 
  ggplot(aes(x = Date, y = beta_exposure)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line() +
  ylab("Beta") +
  labs(title = paste("Beta Exposure across strategies from", start_date, "to", end_date))