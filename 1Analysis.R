require("zoo")
require("roll")
require("MSwM")
require("ggplot2")
require("tidyverse")
require("lubridate")

# path management
parent_dir <- normalizePath("..")
data_dir <- paste0(parent_dir, "\\data")
file_path <- paste0(data_dir, "\\fallen_angels.csv")
df_raw <- read.csv(file_path)

df_prep <- df_raw %>% 
  tibble() %>% 
  rename("quote" = "variable_0", "ticker" = "variable_1", "price" = "value") %>% 
  mutate(Date = as.Date(Date))

df_prep <- df_raw %>% 
  tibble() %>% 
  rename("quote" = "variable_0", "ticker" = "variable_1", "price" = "value") %>% 
  mutate(Date = as.Date(Date))

# we are going to use BND as our benchmark index for calculating betas
df_benchmark <- df_prep %>% 
  filter(quote == "Adj Close", ticker == "BND")

df_securities <- df_prep %>% 
  filter(ticker != "BND")

# want to check and see if they pay dividends
close_rtn <- df_securities %>%
  filter(quote == "Close") %>%
  group_by(ticker) %>%
  mutate(close_rtn = price / lag(price) - 1) %>%
  select(Date, ticker, close_rtn) %>%
  ungroup()

adj_close_rtn <- df_prep %>%
  filter(quote == "Adj Close") %>%
  group_by(ticker) %>%
  mutate(adj_close_rtn = price / lag(price) - 1) %>%
  select(Date, ticker, adj_close_rtn) %>%
  ungroup()

df_dividend <- close_rtn %>%
  left_join(
    adj_close_rtn,
    by = c("ticker", "Date")) %>%
  drop_na() %>%
  mutate(diff = adj_close_rtn - close_rtn)

df_dividend_plot <- df_dividend %>%
  select(Date, ticker, diff)

dividend_plot <- ggplot(df_dividend_plot, aes(x = Date, y = diff, color = ticker)) +
  geom_line() +
  facet_wrap(~ticker) +
  labs(y = "Dividend", title = "Analyzing Dividends for Fixed Income ETFs")

dividend_plot

df_rtn <- df_securities %>%
  filter(quote == "Adj Close") %>%
  select(-quote, -X) %>%
  pivot_wider(names_from = "ticker", values_from = "price") %>%
  drop_na() %>% 
  pivot_longer(!Date, names_to = "ticker", values_to = "price") %>% 
  group_by(ticker) %>%
  mutate(
    rtn = price / lag(price) - 1,
    cum_rtn = (cumprod(1 + replace_na(rtn, 0)) - 1) * 100) 

df_plot <- df_rtn %>%
  select(Date, ticker, cum_rtn) 

return_plot <- ggplot(df_plot, aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  labs(y = "Cumulative Return (%)", title = "Maybe You can catch the Falling Knives") 

return_plot

df_rtn_yoy <- df_rtn %>%
  select(Date, ticker, price) %>%
  mutate(year = format(Date, format = "%Y")) %>%
  group_by(ticker, year) %>%
  mutate(
    rtn = price / lag(price) - 1,
    cum_rtn = (cumprod(1 + replace_na(rtn, 0)) - 1) * 100) 

df_yoy_plot <- df_rtn_yoy %>%
  select(Date, ticker, year, cum_rtn) 

yearly_plot <- ggplot(df_yoy_plot, aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  facet_wrap(~year, scales = "free") +
  labs(y = "Cumulative Return (%)", title = "Cumulative Return Comparison on Year Basis")

yearly_plot

df_spread_rtn <- df_rtn %>%
  mutate(rtn = replace_na(rtn, 0)) %>%
  select(Date, ticker, rtn) %>%
  pivot_wider(names_from = ticker, values_from = rtn) %>%
  mutate(
    angl_agg = (0.5 * ANGL) - (0.5 * AGG),
    angl_hyg = (0.5 * ANGL) - (0.5 * HYG),
    angl_tlt = (0.5 * ANGL) - (0.5 * TLT)) %>%
  select(Date, angl_agg, angl_hyg, angl_tlt) %>%
  pivot_longer(!Date, names_to = "ticker", values_to = "rtn") %>% 
  mutate(ticker = case_when(
    ticker == "angl_agg" ~ "Long ANGL short AGG",
    ticker == "angl_hyg" ~ "Long ANGL short HYG",
    ticker == "angl_tlt" ~ "Long ANGL short TLT"))

df_tot_rtn <- df_spread_rtn %>%
  group_by(ticker) %>%
  mutate(cum_rtn = (cumprod(1 + rtn) - 1) * 100) %>%
  select(Date, ticker, cum_rtn)

spread_graph <- ggplot(df_tot_rtn, aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  labs(y = "Cumulative Return (%)", title = "Buying the Fallen Angel Spread (Long 50% ANGL Short 50% Other, Rebalance Daily)")

spread_graph

df_spread_yoy <- df_spread_rtn %>%
  mutate(year = format(Date, format = "%Y")) %>%
  group_by(year, ticker) %>%
  mutate(cum_rtn = (cumprod(1 + rtn) - 1) * 100) %>%
  select(Date, ticker, cum_rtn, year)

yoy_spread_plot <- ggplot(df_spread_yoy, aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  facet_wrap(~year, scale = "free") +
  labs(y = "Cumulative Return (%)", title = "Fallen Angel spreads per each year")

yoy_spread_plot


first_date <- df_spread_rtn$Date %>% min()
benchmark_rtn <- df_benchmark %>% 
  filter(Date >= first_date) %>% 
  mutate(benchmark_rtn = replace_na(price / lag(price) - 1,0)) %>% 
  select(Date, benchmark_ticker = ticker, benchmark_rtn) 

df_rtn_combined <- df_rtn %>% 
  left_join(benchmark_rtn, by = "Date") %>% 
  mutate(
    rtn = rtn * 100,
    benchmark_rtn = benchmark_rtn * 100)

ggplot(df_rtn_combined, aes(x = benchmark_rtn, y = rtn)) +
  geom_point() +
  geom_smooth(method = "lm") +
  facet_wrap(~ticker, scale = "free") +
  labs(x = "Benchmark Return % (BND)", y = "Security Return %", 
       title = "Individual Securities CAPM")

benchmark_val <- benchmark_rtn$benchmark_rtn
agg_rtns <- (df_rtn_combined %>% filter(ticker == "AGG"))$rtn
angl_rtns <- (df_rtn_combined %>% filter(ticker == "ANGL"))$rtn
hyg_rtns <- (df_rtn_combined %>% filter(ticker == "HYG"))$rtn
tlt_rtns <- (df_rtn_combined %>% filter(ticker == "TLT"))$rtn

agg_lm = lm(agg_rtns~benchmark_val)
summary(agg_lm)

angl_lm = lm(angl_rtns~benchmark_val)
summary(angl_lm)

hyg_lm = lm(hyg_rtns~benchmark_val)
summary(hyg_lm)

tlt_lm = lm(tlt_rtns~benchmark_val)
summary(tlt_lm)

df_spread_rtn %>% 
  group_by(ticker) %>% 
  mutate(cum_rtn = (cumprod(1 + rtn) - 1) * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = ticker))+
  geom_line() + 
  labs(y = "Cumulative Return (%)", title = "Spread Return from 2012 to 2023")

df_spread_rtn %>% 
  mutate(year = format(Date, format = "%Y")) %>% 
  group_by(year, ticker) %>% 
  mutate(cum_rtn = (cumprod(1 + rtn) - 1) * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  facet_wrap(~year, scales = "free") 


df_spread_combined <- df_spread_rtn %>% 
  left_join(benchmark_rtn, by = "Date") %>% 
  mutate(
    rtn = rtn * 100,
    benchmark_rtn = benchmark_rtn * 100)

ggplot(df_spread_combined, aes(x = benchmark_rtn, y = rtn)) +
  geom_point() +
  geom_smooth(method = "lm") +
  facet_wrap(~ticker, scale = "free") +
  labs(y = "Spread Return (%)", x = "Benchmark Return (%)", 
       title = "Spreads Regression vs. Benchmark Bond Index (BND)")

file_path <- paste0(data_dir, "\\gdp.csv")
df_gdp_raw <- read.csv(file_path)

df_gdp_prep <- df_gdp_raw %>% 
  mutate(
    DATE = as.Date(DATE),
    pct_change = value / lag(value) - 1) %>% 
  drop_na()

df_gdp_prep %>% 
  ggplot(aes(x = DATE, y = pct_change)) +
  geom_line() +
  labs(x = "Date (Quarterly)", y = "Q/Q GDP %", title = "Q/Q GDP % Change from 2008 to 2020")

df_gdp_lag <- df_gdp_prep %>% 
  mutate(pct_change_lag = lag(pct_change)) %>% 
  drop_na()

lrm = lm(df_gdp_lag$pct_change ~ df_gdp_lag$pct_change_lag)

rsm = msmFit(lrm, k = 2, p = 0, 
             sw = rep(TRUE, 3),
             control = list(parallel = F))

df_regime <- tibble(
  Date = df_gdp_lag$DATE,
  regime1 = rsm@Fit@filtProb[,1],
  regime2 = rsm@Fit@filtProb[,2],
  diff = regime1 - regime2, # the probs have to sum 1 
  sign = sign(diff),
  lag_signal = lag(sign), # lag signal to avoid signal data snooping
  quarter = case_when(
    quarter(ymd(Date)) == 1 ~ "Q1",
    quarter(ymd(Date)) == 2 ~ "Q2",
    quarter(ymd(Date)) == 3 ~ "Q3",
    quarter(ymd(Date)) == 4 ~ "Q4")) # need to a column to merge on

df_regime %>% 
  select(Date, 'High GDP Growth Regime' = regime1, 'Low GDP Growth Regime' = regime2) %>% 
  pivot_longer(!Date) %>% 
  ggplot(aes(x = Date, y = value)) +
  facet_wrap(~name) +
  geom_line()+
  labs(x = "Filtered Probability")

df_quarter <- tibble(
  Date = seq(from = min(df_spread_rtn$Date), to = max(df_spread_rtn$Date), by = "day")) %>% 
  mutate(
    quarter = case_when(
      quarter(ymd(Date)) == 1 ~ "Q1",
      quarter(ymd(Date)) == 2 ~ "Q2",
      quarter(ymd(Date)) == 3 ~ "Q3",
      quarter(ymd(Date)) == 4 ~ "Q4"),
    year_quarter = paste(format(Date, format = "%Y"), quarter)) %>% 
  select(Date, year_quarter)


df_regime_quarter <- df_regime %>% 
  mutate(
    year_quarter = paste(format(Date, format = "%Y"), quarter)) %>% 
  select(year_quarter, lag_signal) %>% 
  drop_na()

df_encoder <- tibble(
  lag_signal = c(1, -1),
  ticker_to_use = c("Long ANGL short AGG", "Long ANGL short HYG"))

df_signal_quarter <- df_quarter %>% 
  left_join(
    y = df_regime_quarter,
    by = "year_quarter") 

df_strat <- df_spread_rtn %>% 
  left_join(
    df_signal_quarter,
    by = "Date") %>% 
  left_join(
    y = df_encoder,
    by = "lag_signal") %>% 
  filter(ticker == ticker_to_use) %>% 
  mutate(cum_rtn = (cumprod(1 + rtn) - 1) * 100)

df_strat %>% 
  select(Date, "Strat Return" = cum_rtn, "Risk On (1: Long ANGL short AGG) Risk off (-1: Long ANGL short HYG" = lag_signal) %>% 
  pivot_longer(!Date) %>% 
  ggplot(aes(x = Date, y = value)) +
  geom_line() +
  facet_wrap(~name, scale = "free") + 
  labs(
    y = "Cumulative Return (%)", 
    title = "Long ANGL short HYG or AGG via Markov Regime Switching AR GDP Q/Q Model from 2012 to 2023 (Drawdown is pretty bad)")

df_rtn %>% 
  select(Date, ticker, rtn) %>% 
  pivot_wider(names_from = ticker, values_from = rtn) %>% 
  left_join(
    df_strat %>% 
      select(Date, rtn) %>% 
      mutate(ticker = "strat") %>% 
      pivot_wider(names_from = ticker, values_from = rtn),
    by = "Date") %>% 
  pivot_longer(!Date) %>% 
  mutate(year = format(Date, format = "%Y")) %>% 
  group_by(name, year) %>% 
  mutate(cum_rtn = (cumprod(1 + replace_na(value, 0)) - 1) * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = name)) +
  geom_line() +
  facet_wrap(~year, scale = "free") +
  labs(y = "Cumulative Return (%)", title = "Strategy vs Respective Cumulative Return Per %")

df_spread_rtn %>% 
  pivot_wider(names_from = ticker, values_from = rtn) %>% 
  left_join(
    df_strat %>% 
      select(Date, rtn) %>% 
      mutate(ticker = "strat") %>% 
      pivot_wider(names_from = ticker, values_from = rtn),
    how = "Date") %>% 
  pivot_longer(!Date) %>% 
  group_by(name) %>% 
  mutate(cum_rtn = (cumprod(1 + value) - 1) * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = name)) +
  geom_line() +
  labs(y = "Cumulative Return (%)", title = "Strategy vs. Spreads")

df_spread_rtn %>% 
  pivot_wider(names_from = ticker, values_from = rtn) %>% 
  left_join(
    df_strat %>% 
      select(Date, rtn) %>% 
      mutate(ticker = "strat") %>% 
      pivot_wider(names_from = ticker, values_from = rtn),
    how = "Date") %>% 
  pivot_longer(!Date) %>% 
  mutate(year = format(Date, format = "%Y")) %>% 
  group_by(name, year) %>% 
  mutate(cum_rtn = (cumprod(1 + value) - 1) * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = name)) +
  geom_line() +
  facet_wrap(~year, scale = "free") +
  labs(y = "Cumulative Return (%)", title = "Comparison of Spreads vs. Strategy on Year Basis")

df_regress <- df_strat %>% 
  select(Date, rtn) %>% 
  mutate(ticker = "strat") %>% 
  left_join(
    y = df_rtn %>% 
      filter(ticker == "TLT") %>% 
      select(Date, benchmark_ticker = ticker, benchmark_rtn = rtn),
    by = "Date")

lm_strat <- lm(rtn ~ benchmark_rtn, df_regress)
summary(lm_strat)

df_regress %>% 
  ggplot(aes(x = benchmark_rtn, y = rtn)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(x = "Benchmark Return TLT (%)", y = "Strategy Return (%)", title = "Strategy Regression")

rolling_regress <- roll_lm(x = df_regress$benchmark_rtn, y = df_regress$rtn, width = 252)
regress_coefs <- tibble( 
  alpha = rolling_regress$coefficients[, 1],
  beta = rolling_regress$coefficients[, 2]) %>% 
  mutate(Date = df_regress$Date) %>% 
  drop_na() %>% 
  pivot_longer(!Date)

regress_coefs %>% 
  ggplot(aes(x = Date, y = value)) +
  geom_line() +
  facet_wrap(~name, scale = "free") +
  labs(title = "Rolling 1 Year Alpha and Beta of Strat")

regress_coefs %>% 
  ggplot(aes(x = value)) +
  geom_histogram(bins = 100) +
  facet_grid(~name, scale = "free") +
  labs(title = "1y Rolling Alpha & Beta of Strat Distribution")
