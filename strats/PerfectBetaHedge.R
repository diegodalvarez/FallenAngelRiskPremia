require("arrow")
require("moments")
require("latex2exp")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
etf_path <- file.path(parent_dir, "data", "etf.parquet")
weighting_path <- file.path(parent_dir, "data", "BetaNeutralWeighting.parquet")
params_path <- file.path(parent_dir, "data", "rollingOLSparams.parquet")

# from background ReadMe.md
good_hedges <- c("AGG", "BSV", "SHYG", "SJNK")

df_rtn <- read_parquet(
  etf_path) %>% 
  filter(quote == "adjusted") %>% 
  group_by(ticker) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup() %>% 
  select(-c(price, quote))

df_weighting <- read_parquet(
  file = weighting_path)

df_angl <- df_rtn %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "long_rtn" = rtn)

df_short_rtn <- df_rtn %>% 
  filter(ticker %in% good_hedges) %>%
  rename("short_rtn" = rtn)

df_combined <- df_angl %>% 
  inner_join(y = df_short_rtn, by = "Date", relationship = "many-to-many") %>% 
  inner_join(y = df_weighting, by = c("Date", "ticker")) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(
    long_weight = lag(long_weight),
    short_weight = lag(short_weight)) %>% 
  drop_na() %>% 
  ungroup() %>% 
  mutate(
    long_weighted_rtn = long_rtn * long_weight,
    short_weighted_rtn = short_rtn * short_weight,
    port_rtn = long_weighted_rtn - short_weighted_rtn,
    beta_exposure = long_weight + (beta * short_weight)) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(
    port_cum_rtn = cumprod(1 + port_rtn) - 1,
    long_cum_rtn = cumprod(1 + long_weighted_rtn) - 1,
    short_cum_rtn = cumprod(1 + short_weighted_rtn) - 1) %>% 
  ungroup()

df_renamer <- tibble(
  legs = c("long_weighted_rtn", "short_weighted_rtn", "port_rtn"),
  new_name = c("Long Weighted Rtn", "Short Weighted Rtn", "Port Rtn"))

start_date <- min(df_combined$Date)
end_date <- max(df_combined$Date)

# let's look at the returns of each per each strat
df_daily_plot <- df_combined %>% 
  select(ticker, long_weighted_rtn, short_weighted_rtn, port_rtn) %>% 
  pivot_longer(!ticker, names_to = "legs", values_to = "rtn") %>% 
  inner_join(y = df_renamer, by = "legs", relationship = "many-to-many")

df_daily_plot %>% 
  ggplot(aes(x = rtn)) +
  facet_wrap(~ticker + new_name, scale = "free", ncol= 3) +
  geom_histogram() +
  labs(
    title = paste("Distribution of Daily Returns of each weighted leg from", start_date, "to", end_date))

df_moments <- df_daily_plot %>% 
  select(-legs) %>% 
  group_by(ticker, new_name) %>% 
  summarise(
    mean = mean(rtn),
    std = sd(rtn),
    skew = skewness(rtn)) %>% 
  ungroup()

df_moments %>% 
  pivot_longer(!c(ticker, new_name)) %>% 
  rename("leg" = new_name) %>% 
  ggplot(aes(x = ticker, y = value, fill = leg)) +
  facet_wrap(~name, ncol = 3, scale = "free") +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = paste("First 3 Moments of returns from", start_date, "to", end_date))

df_combined %>% 
  select(Date, ticker, port_cum_rtn) %>% 
  mutate(port_cum_rtn = port_cum_rtn * 100) %>% 
  ggplot(aes(x = Date, y = port_cum_rtn, color = ticker)) +
  geom_line() +
  labs(title = paste("Portfolio Cumulative Returns", start_date, "to", end_date)) +
  ylab("Cumulative Return (%)")

df_renamer <- tibble(
  rtn_source = c("long_cum_rtn", "port_cum_rtn", "short_cum_rtn"),
  leg = c("Long Cum. Rtn.", "Port Cum. Rtn.", "Short Cum. Rtn"))

df_combined %>% 
  select(Date, ticker, port_cum_rtn, long_cum_rtn, short_cum_rtn) %>% 
  mutate(short_cum_rtn = -short_cum_rtn) %>% 
  pivot_longer(!c(Date, ticker), names_to = "rtn_source", values_to = "cum_rtn") %>% 
  inner_join(y = df_renamer, by = c("rtn_source"), relationship = "many-to-many") %>% 
  mutate(cum_rtn = cum_rtn * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = leg)) +
  facet_wrap(~ticker, scale = "free_y") +
  geom_line() +
  ylab("Cumulative Return (%)") +
  labs(title = paste("Analyzing Portfolio Cumulative Returns by each leg from", start_date, "to", end_date))

# beta exposure
df_combined %>% 
  select(Date, ticker, beta_exposure) %>% 
  ggplot(aes(x = Date, y = beta_exposure, color = ticker)) +
  geom_line() +
  ylab(TeX("$\\beta")) +
  labs(title = paste("Beta Exposure from", start_date, "to", end_date))

df_combined %>% 
  select(Date, ticker, beta_exposure) %>% 
  ggplot(aes(x = Date, y = beta_exposure)) +
  facet_wrap(~ticker, scale = "free_y") +
  geom_line() +
  ylab(TeX("$\\beta")) +
  labs(title = paste("Beta Exposure from", start_date, "to", end_date))

df_combined %>% 
  ggplot(aes(x = beta_exposure)) +
  facet_wrap(~ticker, scale = "free") +
  geom_histogram(bins = 30, binwidth = 0.1) +
  xlab(TeX("$\\beta")) +
  labs(title = paste("Histogram of Beta Exposure from", start_date, "to", end_date))

df_renamer <- tibble(
  name = c("long_weight", "short_beta"),
  position = c("Long Beta", "Short Beta"))

df_combined %>% 
  mutate(short_beta = beta * short_weight) %>% 
  select(Date, ticker, long_weight, short_beta) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  inner_join(y = df_renamer, by = "name", relationship = "many-to-many") %>% 
  ggplot(aes(x = value, fill = position)) +
  facet_wrap(~ticker, ncol = 2, scale = "free") +
  geom_histogram(bins = 20) +
  labs(title = paste("Histogram of weighted Betas of each strategy from", start_date, "to", end_date))

df_rename <- tibble(
  leg = c("long_weight", "short_beta"),
  position = c("Long Beta", "Short Beta"))

df_combined %>% 
  mutate(short_beta = beta * short_weight) %>% 
  select(ticker, long_weight, short_beta) %>% 
  pivot_longer(!c(ticker)) %>% 
  group_by(ticker, name) %>% 
  summarise(
    mean = mean(value),
    std = sd(value),
    skew = skewness(value)) %>% 
  ungroup() %>% 
  rename("leg" = name) %>% 
  pivot_longer(!c(ticker, leg)) %>% 
  inner_join(y = df_rename, by = "leg", relationship = "many-to-many") %>% 
  ggplot(aes(x = position, y = value, fill = ticker)) +
  facet_wrap(~name) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "First 3 moments of the Rolling Beta Distributions")

df_combined %>% 
  mutate(short_beta = beta * short_weight * -1) %>% 
  select(Date, ticker, short_beta, long_weight) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  ggplot(aes(x = Date, y = value, color = name)) +
  facet_wrap(~ticker, scale = "free") +
  geom_line()

df_weigthed_betas <- df_combined %>% 
  mutate(short_beta = beta * short_weight * -1) %>% 
  select(Date, ticker, short_beta, long_weight) %>% 
  pivot_longer(!c(Date, ticker)) %>% 
  rename("leg" = name) %>% 
  inner_join(y = df_rename, by = "leg")

df_weigthed_betas %>% 
  ggplot(aes(x = Date, y = value)) +
  facet_wrap(~position + ticker, scale = "free", nrow = 2) +
  geom_line() +
  labs(title = paste("Comparing weighted betas by position from", start_date, "to", end_date))

df_weigthed_betas %>% 
  ggplot(aes(x = Date, y = value, color = position)) +
  facet_wrap(~ticker, scale = "free_y") +
  geom_line() +
  labs(title = paste("Comparing weighted betas side-by-side from", start_date, "to", end_date))
