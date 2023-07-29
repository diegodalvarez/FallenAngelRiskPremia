require("arrow")
require("MSwM")
require("ggplot2")
require("tidyverse")

df_raw_prices <- read_parquet(
  "fixed_income_etfs.parquet")

df_forecast <- read_parquet(
  "tlt_garch.parquet")

start_date <- min(df_forecast$date)
end_date <- max(df_forecast$date)

df_forecast %>% 
  filter(variable == "std") %>% 
  ggplot(aes(x = date, y = value)) +
  geom_line() +
  labs(title = paste("TLT GARCH Volatility from", start_date, "to", end_date)) +
  ylab("Volatility")

vol <- df_forecast %>% 
  filter(variable == "std") %>% 
  arrange(date) %>% 
  select(value) %>% 
  pull()

vol_lagged <- df_forecast %>% 
  filter(variable == "std") %>% 
  arrange(date) %>% 
  mutate(value = lag(value)) %>% 
  select(value) %>% 
  pull()

ols_model <- lm(vol~vol_lagged)
fitted_model <- msmFit(
  ols_model, 
  k = 3, p = 0, 
  sw = rep(TRUE, 3), 
  control = list(parallel = FALSE))

dates <- df_forecast %>% 
  select(date) %>% 
  arrange(date) %>% 
  unique() %>% 
  pull()

probs <- data.frame(fitted_model@Fit@smoProb) %>% 
  tibble() %>% 
  mutate(date = dates) %>% 
  rename(
    "low_regime" = "X1",
    "medium_regime" = "X2",
    "high_regime" = "X3")

probs_longer <- probs %>% 
  pivot_longer(!date, names_to = "regime", values_to = "value") %>% 
  arrange(date)

probs_longer %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~regime) +
  geom_line()

max_probs <- probs_longer %>% 
  group_by(date) %>% 
  summarise(value = max(value))

regimes <- max_probs %>% 
  inner_join(probs_longer, by = c("date", "value"))

df_namer <- tibble(
  regime = c("low_regime", "medium_regime", "high_regime"),
  regime_name = c("Low Regime", "Medium Regime", "High Regime"),
  cat_var = c(1,2,3))

regime_combined <- regimes %>% 
  inner_join(df_namer, by = "regime") %>% 
  mutate(indicator = 1)

regime_indicator <- regime_combined %>% 
  select(date, regime_name, indicator) %>% 
  pivot_wider(names_from = regime_name, values_from = indicator) %>% 
  pivot_longer(!date, names_to = "regime_name", values_to = "indicator") %>% 
  mutate(indicator = replace_na(indicator, 0))

regime_indicator %>% 
  ggplot(aes(x = date, y = indicator)) +
  facet_wrap(~regime_name) +
  geom_line() +
  labs(title = "Markov Regime Switching Model Indicator")

regime_count <- regime_indicator %>% 
  filter(indicator != 0) %>% 
  select(-date) %>% 
  group_by(regime_name) %>% 
  summarise(sum = sum(indicator))

regime_count %>% 
  ggplot(aes(x = regime_name, y = sum)) +
  geom_bar(stat = "identity") +
  xlab("Regime Name") +
  ylab("Count") +
  labs(title = "Regime Count Using Markov Regime Switching Model")
