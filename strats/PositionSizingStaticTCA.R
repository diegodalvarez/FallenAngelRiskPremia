require("arrow")
require("moments")
require("latex2exp")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
backtest_path <- file.path(parent_dir, "data", "backtest.parquet")
out_path <- file.path(parent_dir, "data", "backtestStaticTCA.parquet")

df_position <- read_parquet(backtest_path) 

tca_cost <- 0.21

#need to account for TCA affecting port_init

df_backtest <- df_position %>% 
  select(long_shares, short_shares, port_end, Date, ticker) %>% 
  mutate(
    long_change = coalesce(abs(long_shares - lag(long_shares)), long_shares),
    short_change = coalesce(abs(short_shares - lag(short_shares)), short_shares),
    long_tca = long_change * tca_cost,
    short_tca = short_change * tca_cost,
    port_tca = port_end - long_tca - short_tca) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(
    rtn = replace_na(port_tca / lag(port_tca) - 1,0),
    cum_rtn = (cumprod(1 + rtn) - 1) * 100) %>% 
  ungroup()

df_backtest %>% 
  select(Date, ticker, port_end, port_tca) %>% 
  mutate(diff = port_end - port_tca) %>% 
  ggplot(aes(x = Date, y = diff)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line()
 
df_backtest %>% write_parquet(out_path)