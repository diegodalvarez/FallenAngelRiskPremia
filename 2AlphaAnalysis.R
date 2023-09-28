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
  mutate(Date = as.Date(Date)) %>% 
  filter(quote == "Adj Close")

# In this case because I'm not able to get duration neutral I have to use Beta
# I'll also be using TLT as the benchmark

df_tlt <- df_prep %>% 
  filter(ticker == "TLT") %>% 
  select(Date, "TLT" = price) %>% 
  arrange(Date) %>% 
  mutate(TLT = TLT / lag(TLT) - 1)

df_sec <- df_prep %>% 
  filter(ticker %in% c("ANGL", "HYG")) %>% 
  drop_na() %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  select(Date, ticker, rtn) %>% 
  ungroup()

df_agg <- df_prep %>% 
  filter(ticker == "AGG") %>% 
  arrange(Date) %>% 
  mutate(AGG = price / lag(price) - 1) %>% 
  select(Date, AGG)

df_combined <- df_agg %>% 
  left_join(y = df_sec, by = "Date", relationship = "many-to-many") %>% 
  left_join(y = df_tlt, by = "Date", relationship = "many-to-many") %>% 
  drop_na()

df_len <- dim(df_agg)[1]
cutoff_value <- as.integer(df_len / 3)

cutoff_date <- df_combined %>% 
  select(Date) %>% 
  unique() %>% 
  arrange() %>% 
  mutate(n = 1:n()) %>% 
  filter(n == cutoff_value) %>% 
  select(Date) %>% 
  pull()

df_in_sample <- df_combined %>% 
  filter(Date < cutoff_date)

df_out_sample <- df_combined %>% 
  filter(Date >= cutoff_date)

start_date <- min(df_in_sample$Date)
end_date <- max(df_in_sample$Date)

df_in_sample %>% 
  ggplot(aes(x = TLT, y = rtn)) +
  facet_wrap(~ticker, scale = "free") +
  geom_point() +
  geom_smooth(method = "lm") +
  xlab("TLT %") +
  ylab("Index Return %") +
  labs(title = paste("Regression against TLT from", start_date, "to", end_date))

df_in_sample %>% 
  ggplot(aes(x = AGG, y = rtn)) +
  facet_wrap(~ticker, scale = "free") +
  geom_point() +
  geom_smooth(method = "lm") +
  xlab("AGG %") +
  ylab("Index Return %") +
  labs(title = paste("Regression against AGG from", start_date, "to", end_date))

# Unfortunately it seems that both indices are not going to be good candidates for short index
# Instead we'll just hedge out HYG against itself

df_wider <- df_sec %>% 
  pivot_wider(names_from = "ticker", values_from = "rtn") %>% 
  drop_na()

df_len <- dim(df_wider)[1]
cutoff_value <- as.integer(df_len / 3)
cutoff_date <- df_wider %>% 
  mutate(n = 1:n()) %>% 
  filter(n == cutoff_value) %>% 
  select(Date) %>% 
  pull()

df_in_sample <- df_wider %>% 
  filter(Date < cutoff_date)

df_out_sample <- df_wider %>% 
  filter(Date >= cutoff_value)

start_date <- min(df_in_sample$Date)
end_date <- max(df_in_sample$Date)

df_in_sample %>% 
  pivot_longer(!Date, names_to = "ticker", values_to = "rtn") %>% 
  mutate(rtn = rtn * 100) %>% 
  pivot_wider(names_from = "ticker", values_from = "rtn") %>% 
  ggplot(aes(x = HYG, y = ANGL)) +
  geom_point() +
  geom_smooth(method = "lm") +
  xlab("HYG %") +
  ylab("ANGL %") +
  labs(title = paste("Comparing HYG to ANGL from", start_date, "to", end_date))

# we'll use this and then take the rolling out of sample Betas and then hedge them
roll_regress <- roll_lm(
  x = df_out_sample$HYG,
  y = df_out_sample$ANGL,
  width = 30)

coefs <- roll_regress$coefficients %>% 
  as_tibble()

colnames(coefs) <- c("Beta", "Alpha")
df_out <- coefs %>% 
  mutate(date = df_out_sample$Date) %>% 
  drop_na()

start_date <- min(df_out$date)
end_date <- max(df_out$date)

df_out %>% 
  pivot_longer(!date, names_to = "stat", values_to = "value") %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~stat, nrow = 2, scale = "free_y") +
  geom_line() +
  labs(title = paste("30d Rolling Alphas and Betas of Long ANGL and Short HYG from", start_date, "to", end_date))

out_sample_date <- min(df_out_sample$Date)

# I want to compare this alpha to the standard buy IG short Treasuries 
df_agg_wider <- df_prep %>% 
  filter(Date >= out_sample_date) %>% 
  filter(ticker %in% c("AGG", "TLT")) %>% 
  group_by(ticker) %>% 
  arrange(ticker) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  ungroup() %>% 
  select(Date, ticker, rtn) %>% 
  pivot_wider(names_from = "ticker", values_from = "rtn") %>% 
  drop_na()

agg_roll_lm <- roll_lm(
  x = df_agg_wider$AGG,
  y = df_agg_wider$TLT,
  width = 30)

coefs <- agg_roll_lm$coefficients %>% 
  as_tibble()

colnames(coefs) <- c("Beta", "Alpha")
df_agg_out <- coefs %>% 
  mutate(date = df_agg_wider$Date) %>% 
  drop_na()

min_date <- min(df_agg_out$date)
max_date <- max(df_agg_out$date)
df_agg_out %>% 
  pivot_longer(!date, names_to = "stat", values_to = "value") %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~stat, scale = "free_y", nrow = 2) +
  geom_line() +
  labs(title = paste("Long AGG short TLT from", start_date, "to", end_date))

# now combine and compare them although I'd like to DWH 
df_combined <- df_agg_out %>% 
  pivot_longer(!date, names_to = "stat", values_to = "IG Hedge") %>% 
  left_join(
    y = df_out %>% 
      pivot_longer(!date, names_to = "stat", values_to = "ANGL Hedge"),
    by = c("date", "stat"))

df_combined %>% 
  pivot_longer(!c(date, stat)) %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~name+stat, scale = "free_y") +
  geom_line() +
  labs(title = paste("Comparing IG hedge vs. ANGL hedge 30d Rolling OLS from", start_date, "to", end_date))

df_combined %>% 
  pivot_longer(!c(date, stat)) %>% 
  ggplot(aes(x = value)) +
  facet_wrap(~name+stat, scale = "free") +
  geom_histogram() +
  labs(title = paste("Comparing IG hedge vs. ANGL hedge 30d Rolling OLS from", start_date, "to", end_date))

df_stats_wider <- df_combined %>% 
  pivot_longer(!c(date, stat)) %>% 
  mutate(name = str_replace_all(tolower(paste(stat, name)), " ", "_")) %>% 
  select(-stat) %>% 
  pivot_wider(names_from = "name", values_from = "value")

df_stats_wider %>% 
  mutate(
    alpha_corr = roll_cor(alpha_ig_hedge, alpha_angl_hedge, width = 30 * 6),
    beta_corr = roll_cor(beta_ig_hedge, beta_angl_hedge, width = 30 * 6)) %>% 
  select(date, alpha_corr, beta_corr) %>% 
  drop_na() %>% 
  pivot_longer(!date, names_to = "correlation", values_to = "corr") %>% 
  mutate(correlation = str_replace(correlation, "_", " ")) %>% 
  ggplot(aes(x = date, y = corr)) +
  facet_wrap(~correlation, nrow = 2) +
  geom_line() +
  ylab("Correlation") +
  labs(title = paste("6m Rolling Correlation of 30d Rolling OLS from", start_date, "to", end_date))
