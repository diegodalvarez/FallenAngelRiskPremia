require("arrow")
require("moments")
require("latex2exp")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
backtest_path <- file.path(parent_dir, "data", "backtest.parquet")
backtest_tca_path <- file.path(parent_dir, "data", "backtestStaticTCA.parquet")
prices_path <- file.path(parent_dir, "data", "ETF.parquet")
weighting_path <- file.path(parent_dir, "data", "BetaNeutralWeighting.parquet")

df_backtest_tca <- read_parquet(backtest_tca_path)
df_backtest <- read_parquet(backtest_path)
df_weighting <- read_parquet(weighting_path)
df_prices <- read_parquet(prices_path)

df_angl <- df_prices %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "long_price" = price, quote)

df_synth <- df_weighting %>% 
  inner_join(y = df_prices, by = c("Date", "ticker")) %>% 
  inner_join(y = df_angl, by = c("Date", "quote")) %>% 
  filter(quote == "adjusted") %>% 
  group_by(ticker) %>% 
  arrange(Date) %>%
  mutate(
    long_rtn = replace_na(long_price / lag(long_price) -1,0),
    short_rtn = replace_na((price / lag(price) - 1) * -1,0),
    long_weighted_rtn = long_rtn * long_weight,
    short_weighted_rtn = short_rtn * short_weight,
    port_rtn = long_weighted_rtn + short_weighted_rtn,
    cum_rtn = (cumprod(1 + port_rtn) - 1) * 100) %>% 
  ungroup() %>% 
  select(ticker, Date, "synth" = cum_rtn)

df_pos <- df_backtest %>% 
  select(ticker, Date, port_end) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(
    port_rtn = replace_na(port_end / lag(port_end) - 1,0),
    cum_rtn = (cumprod(1 + port_rtn) - 1) * 100) %>% 
  ungroup() %>% 
  select(ticker, Date, "pos" = cum_rtn)

df_tca <- df_backtest_tca %>% 
  select(Date, ticker, "tca" = cum_rtn)

df_synth %>% 
  inner_join(y = df_pos, by = c("ticker", "Date")) %>% 
  inner_join(y = df_tca, by = c("ticker", "Date")) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  ggplot(aes(x = Date, y = value, color = name)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line()
  