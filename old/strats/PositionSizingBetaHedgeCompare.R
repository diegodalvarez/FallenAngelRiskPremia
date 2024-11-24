require("arrow")
require("moments")
require("latex2exp")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
backtest_path <- file.path(parent_dir, "data", "backtest.parquet")
beta_neutral_path <- file.path(parent_dir, "data", "BetaNeutralWeighting.parquet")
prices_path <- file.path(parent_dir, "data", "etf.parquet")

df_position <- read_parquet(backtest_path) 
df_weighting <- read_parquet(beta_neutral_path)
df_prices <- read_parquet(prices_path)

df_cum_rtn <- df_position %>% 
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

df_beta <- df_position %>% 
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

# now calculate synthetic returns
df_rtn <- df_prices %>% 
  filter(quote == "adjusted") %>% 
  select(-quote) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup() %>% 
  select(-price)

df_port <- df_weighting %>% 
  inner_join(df_rtn, by = c("Date", "ticker")) %>% 
  rename("short_rtn" = "rtn") %>% 
  inner_join(
    df_rtn %>% 
      filter(ticker == "ANGL") %>% 
      select(-ticker), 
    by = c("Date")) %>% 
  rename("long_rtn" = "rtn") %>% 
  mutate(short_rtn = short_rtn * -1) %>% 
  mutate(
    port_rtn = (long_weight * long_rtn) + (short_rtn * short_weight),
    port_beta = long_weight + (beta * short_weight)) %>% 
  select(ticker, Date, port_rtn, port_beta)

df_diff_rtn <- df_cum_rtn %>% 
  ungroup() %>% 
  select(ticker, Date, "pos_rtn" = rtn) %>% 
  inner_join(df_port, by =  c("ticker", "Date")) %>% 
  select(-port_beta) %>% 
  mutate(diff = pos_rtn - port_rtn) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(
    pos_cum = (cumprod(1 + pos_rtn) - 1) * 100,
    port_cum = (cumprod(1 + port_rtn) - 1) * 100,
    diff_cum = (cumprod(1 + diff) - 1) * 100) %>% 
  ungroup()

start_date <- min(df_diff_rtn$Date)
end_date <- max(df_diff_rtn$Date)

df_diff_rtn %>% 
  select(ticker, Date, pos_rtn, port_rtn) %>% 
  rename("Position" = pos_rtn, "Synthetic" = port_rtn) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  ggplot(aes(x = Date, y = value, color = name)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line() +
  ylab("Daily Return (%)") +
  labs(title = paste("Comparing Returns from synthetic returns and portfolio of $10m from", start_date, "to", end_date))

df_diff_rtn %>% 
  select(ticker, Date, pos_cum, port_cum) %>% 
  rename("Position" = pos_cum, "Synthetic" = port_cum) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  ggplot(aes(x = Date, y = value, color = name)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line() +
  ylab("Cumulative Return (%)") +
  labs(title = paste(
    "Comapring Cum. Rtn. from synthetic returns and portfolio of $10m from", start_date, "to", end_date))

df_diff_rtn %>% 
  ggplot(aes(x = Date, y = diff, color = ticker)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line() +
  ylab("%") +
  labs(title = paste(
    "Comparing Daily Return difference between synthetic returns and portfolio of $10m from", start_date, "to", end_date))

df_diff_rtn %>% 
  ggplot(aes(x = Date, y = diff_cum, color = ticker)) +
  geom_line() +
  ylab("Cumulative Return (%)") +
  labs(title = paste("Cumulative Returns Lost accounting for position size and stock from", start_date, "to", end_date))

df_beta_compare <- df_weighting %>% 
  mutate(synth_beta = long_weight + (short_weight * beta)) %>% 
  inner_join(df_beta, by = c("ticker", "Date")) %>% 
  select(ticker, Date, synth_beta, "pos_beta" = beta_exposure) %>% 
  mutate(beta_leakage = synth_beta - pos_beta)

df_beta_compare %>%
  rename("Synthetic" = synth_beta, "Position" = pos_beta) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  ggplot(aes(x = Date, y = value, color = name)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line() +
  ylab("Beta") +
  labs(title = paste("Comparing Synthetic returns Beta vs. $10m Portfolio from", start_date, "to", end_date))

df_beta_compare %>% 
  ggplot(aes(x = Date, y = beta_leakage)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line() +
  labs(title = paste(
    "Difference of Beta exposure between\nsynthetic and $10m portfolio from", start_date, "to", end_date)) +
  ylab("Beta")

df_diff_rtn %>% 
  inner_join(df_beta_compare, by = c("Date", "ticker")) %>% 
  ggplot(aes(x = beta_leakage, y = diff)) +
  facet_wrap(~ticker, scale = "free") +
  geom_smooth(method = "lm") +
  geom_point() +
  ylab("Returns Difference (%)") +
  xlab("Beta Difference") +
  labs(title = paste(
    "Comparing difference of Beta Exposure vs. difference of returns\nfrom", start_date, "to", end_date))

df_position %>% 
  select(ticker, Date, port_end, cash) %>% 
  mutate(cash_holding = cash / port_end) %>% 
  inner_join(df_diff_rtn, by = c("Date", "ticker")) %>% 
  ggplot(aes(x = cash_holding, y = diff)) +
  facet_wrap(~ticker, scale = "free") +
  geom_smooth(method = "lm") +
  geom_point() +
  xlab("Cash Holding") +
  ylab("Returns Difference") + 
  labs(title = paste(
    "Comparing cash holding and returns difference from", start_date, "to", end_date))

