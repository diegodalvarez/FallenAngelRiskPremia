require("roll")
require("arrow")
require("ggplot2")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
etf_path <- file.path(parent_dir, "data", "etf.parquet")

df_rtn <- read_parquet(
  etf_path) %>% 
  filter(quote == "adjusted") %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  ungroup() %>% 
  drop_na()

# we are going to use the 4 ETFs outlined for hedging and in this case 
# use 50-50 split rebalanced daily 

hedgers <- c("AGG", "BSV", "SHYG", "SJNK")

angl_rtn <- df_rtn %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "angl_rtn" = rtn)

df_hedge <- df_rtn %>% 
  filter(ticker %in% hedgers) %>% 
  select(-quote)

df_combined <- angl_rtn %>% 
  inner_join(y = df_hedge, by = "Date", relationship = "many-to-many") %>% 
  mutate(port_rtn = (angl_rtn * 0.5) - (rtn * 0.5)) %>% 
  group_by(ticker) %>% 
  mutate(cum_rtn = cumprod(1 + port_rtn) - 1) %>% 
  ungroup()

start_date <- min(df_combined$Date)
end_date <- max(df_combined$Date)

# let's examine performance
df_combined %>% 
  mutate(cum_rtn = cum_rtn * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  ylab("Cumulative Return (%)") %>% 
  labs(title = paste("Playback of returns 50-50 split using all possible data from", start_date, "to", end_date))

#let's cut it all in one piece just to compare
df_cut <- df_combined %>% 
  select(Date, ticker, port_rtn) %>% 
  pivot_wider(names_from = "ticker", values_from = "port_rtn") %>% 
  drop_na() %>% 
  pivot_longer(!Date, names_to = "ticker", values_to = "port_rtn") %>% 
  group_by(ticker) %>% 
  mutate(cum_rtn = cumprod(1 + port_rtn) - 1) %>% 
  ungroup()

start_date <- min(df_cut$Date)
end_date <- max(df_cut$Date)

df_cut %>% 
  mutate(cum_rtn = cum_rtn  * 100) %>% 
  ggplot(aes(x = Date, y = cum_rtn, color = ticker)) +
  geom_line() +
  ylab("Cumulative Returns (%)") +
  labs(title = paste("Playback of returns 50-50 split same start date from", start_date, "to", end_date))

df_rr <- df_combined %>% 
  select(Date, ticker, port_rtn) %>% 
  group_by(ticker) %>% 
  mutate(
    roll_mean = roll_mean(x = port_rtn, width = 30),
    roll_std = roll_sd(x = port_rtn, width = 30),
    rr = roll_mean / roll_std) %>% 
  drop_na() %>% 
  ungroup()

df_rr %>% 
  ggplot(aes(x = Date, y = rr, color = ticker)) +
  geom_line() +
  labs(title = paste("30d Rolling Mean / 30d Rolling Standard Deviation from", start_date, "to", end_date)) +
  ylab("Return/Risk")

df_combined %>% 
  ggplot(aes(x = port_rtn)) +
  facet_wrap(~ticker) +
  geom_histogram(bins = 30)

df_rtn_moment <- df_combined %>% 
  select(ticker, port_rtn) %>% 
  group_by(ticker) %>% 
  summarise(
    mean = mean(port_rtn),
    std = sd(port_rtn),
    skew = skewness(port_rtn),
    kurtosis = kurtosis(port_rtn))

df_rtn_moment %>% 
  pivot_longer(!ticker) %>% 
  ggplot(aes(x = ticker, y = value)) +
  facet_wrap(~name, scale = "free") +
  geom_bar(stat = "identity") +
  labs(title = paste("First 4 moments of returns distribution from", start_date, "to", end_date))

df_rr %>% 
  ggplot(aes(x = rr)) +
  facet_wrap(~ticker, scale = "free") +
  geom_histogram(bins = 30) +
  labs(title = paste("Distribution of Rolling 30d Mean / Rolling 30d Std from", start_date, "to", end_date))

df_rr_moments <- df_rr %>% 
  select(ticker, rr) %>% 
  group_by(ticker) %>% 
  summarise(
    mean = mean(rr),
    std = sd(rr),
    skew = skewness(rr),
    kurtosis = kurtosis(rr)) 

df_rr_moments %>% 
  pivot_longer(!ticker) %>% 
  ggplot(aes(x = ticker, y = value)) +
  facet_wrap(~name, scale = "free") +
  geom_bar(stat = "identity") +
  labs(title = paste("First 4 Moments of returns distribution from", start_date, "to", end_date))
