require("roll")
require("arrow")
require("moments")
require("ggplot2")
require("corrplot")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
etf_path <- file.path(parent_dir, "data", "etf.parquet")
param_path <- file.path(parent_dir, "data", "rollingOLSparams.parquet")

df_raw <- read_parquet(etf_path) %>% as_tibble()
df_roll <- read_parquet(param_path) %>% as_tibble()

# we are technically using look-ahead bias to find which hedge to use but
# its likely that the same determination would be true, its not worth going 
# in and out of sample to clean data to find the same results

df_adjusted <- df_raw %>% 
  filter(quote == "adjusted") %>% 
  select(-quote) %>% 
  pivot_wider(names_from = "ticker", values_from = "price") %>% 
  drop_na() %>% 
  pivot_longer(!Date, names_to = "ticker", values_to = "price")

# let's use the top 5 best hedges using weekly returns
df_weekly_rtn <- df_adjusted %>% 
  mutate(weekday = weekdays(Date)) %>% 
  filter(weekday == "Monday") %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  ungroup() %>% 
  drop_na()

df_angl <- df_weekly_rtn %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "angl_rtn" = rtn)

df_exog <- df_weekly_rtn %>% 
  filter(ticker != "ANGL") %>% 
  select(Date, ticker, "rtn")

df_combined <- df_exog %>% 
  left_join(y = df_angl, by = "Date", relationship = "many-to-many")

run_lm <- function(df){
  
  regress <- lm("angl_rtn ~ rtn", data = df)
  regress
  
  coefs <- coef(regress) %>% as_tibble() %>% t()
  colnames(coefs) <- c("Alpha", "Beta")
  coefs <- coefs %>% as_tibble()
  
  return(coefs)
}

df_params <- df_combined %>% 
  group_by(ticker) %>% 
  group_modify(~run_lm(.)) %>% 
  ungroup()

min_date <- min(df_combined$Date)
max_date <- max(df_combined$Date)

df_params %>% 
  pivot_longer(!ticker, names_to = "parameter", values_to = "value") %>% 
  ggplot(aes(x = ticker, y = value)) +
  facet_wrap(~parameter, scale = "free", nrow = 2) +
  geom_bar(stat = "identity") +
  labs(title = paste("Weekly Returns Regression from", min_date, "to", max_date))

# we'll find which best hedges by getting the top 4 highest betas via OLS
hedges <- df_params %>% 
  arrange(Beta) %>% 
  tail(4) %>% 
  select(ticker) %>% 
  pull()

df_hedges <- df_roll %>% 
  filter(ticker %in% hedges)

start_date <- min(df_hedges$Date)
end_date <- max(df_hedges$Date)

df_hedges %>%
  pivot_longer(!c(ticker, Date), names_to = "parameter", values_to = "value") %>% 
  ggplot(aes(x = Date, y = value, color = ticker)) +
  facet_wrap(~parameter, scale = "free_y", nrow = 2) +
  geom_line() +
  labs(title = paste(
    "Lookback of Historical Alphas and Betas of best Fallen Angel Hedges\nfrom", start_date, "to", end_date))

alpha_corr <- cor(df_hedges %>% 
                    select(ticker, alpha, Date) %>% 
                    pivot_wider(names_from = "ticker", values_from = "alpha") %>% 
                    select(-Date))

beta_corr <- cor(df_hedges %>% 
                    select(ticker, beta, Date) %>% 
                    pivot_wider(names_from = "ticker", values_from = "beta") %>% 
                    select(-Date))

corrplot(alpha_corr, method = "number")
corrplot(beta_corr, method = "number")

df_rtn <- df_adjusted %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup()

# here is the main idea we have these alpha streams which can be considered 
# perfect hedging to extract returns we'll use the alpha streams as a proxy 
# for our returns streams. Of course our alpha streams may are not fully uncorrelated
# therefore let's look at the rolling alphas compare to the returns

df_non_hedge <- df_rtn %>% 
  filter(!ticker %in% hedges) %>% 
  filter(ticker != "ANGL") %>% 
  select(-price)

df_alpha_streams <- df_hedges %>% 
  select("alpha_param" = ticker, alpha, Date)

df_alpha_corr <- df_alpha_streams %>% 
  left_join(y = df_non_hedge, by = "Date", relationship = "many-to-many") %>% 
  group_by(alpha_param, ticker) %>% 
  mutate(corr = roll_cor(alpha, rtn, width = 30 * 3)) %>% 
  drop_na() %>% 
  ungroup() %>% 
  select(alpha_param, ticker, Date, corr)

start_date <- min(df_alpha_corr$Date)
end_date <- max(df_alpha_corr$Date)

df_alpha_corr %>% 
  ggplot(aes(x = Date, y = corr, color = ticker)) +
  facet_wrap(~alpha_param, scale = "free") +
  geom_line() +
  ylab("Correlation") +
  labs(
    title = paste(
      "3 Month Rolling correlation of good hedges alpha to non-hedges returns\nfrom", start_date, "to", end_date, "(Alpha Leakage)"))

# in other words this means that if we can "perfectly" hedge out our beta the
# the returns proxied by alpha should be able to be not correlated to our other
# indices

df_hedges %>% 
  pivot_longer(!c(ticker, Date), names_to = "param", values_to = "value") %>% 
  filter(param == "beta") %>% 
  ggplot(aes(x = value)) +
  facet_wrap(~ticker, scale = "free") +
  geom_histogram(bins = 40) +
  ylab("30d Rolling Beta") +
  labs(title = "Beta Distribution (Hedging Maintenance)")

beta_moments <- df_hedges %>% 
  pivot_longer(!c(ticker, Date), names_to = "param", values_to = "value") %>% 
  filter(param == "beta") %>% 
  group_by(ticker) %>% 
  summarise(
    mean = mean(value),
    std = sd(value),
    skew = skewness(value),
    kurtosis = kurtosis(value))

beta_moments %>% 
  pivot_longer(!ticker, names_to = "stat", values_to = "value") %>% 
  ggplot(aes(x = ticker, y = value)) +
  facet_wrap(~stat, scale = "free") +
  geom_bar(stat = "identity") +
  labs(title = "30d Hedging (Beta) Moments")

# it seems that one of the downsides is that we are likely to have higher hedging
# changes for BSV

df_hedges %>% 
  pivot_longer(!c(ticker, Date), names_to = "param", values_to = "value") %>% 
  filter(param == "alpha") %>% 
  ggplot(aes(x = value)) +
  facet_wrap(~ticker, scale = "free") +
  geom_histogram(bins = 40) +
  ylab("30d Rolling Alpha") +
  labs(title = "Returns (proxied by alpha) Distribution")

alpha_moments <- df_hedges %>% 
  pivot_longer(!c(ticker, Date), names_to = "param", values_to = "value") %>% 
  filter(param == "alpha") %>% 
  group_by(ticker) %>% 
  summarise(
    mean = mean(value),
    std = sd(value),
    skew = skewness(value),
    kurtosis = kurtosis(value))

alpha_moments %>% 
  pivot_longer(!ticker, names_to = "stat", values_to = "value") %>% 
  ggplot(aes(x = ticker, y = value)) +
  facet_wrap(~stat, scale = "free") +
  geom_bar(stat = "identity") +
  labs(title = "30d Alpha (Returns proxy) Moments")

# it also appears that BSV our best hedge has negative skew which implies that 
# we are running a short volatility strategy

# we can use Markov Regime Switching MOVE GARCH as a proxy to move skew on and off