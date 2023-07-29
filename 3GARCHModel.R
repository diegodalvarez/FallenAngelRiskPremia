# 
# 
# The idea behind this strategy, there are 3 options to chose from, they are all
# going to have a long Fallen Angel Positions. We'll calculate data on the close
# and we will purchase on the following open price.
# 
# For the time being we'll be using the ETFs to get the exposure. In terms of 
# positions and portfolio management, this will be a beta-neutral portfolio.
# 
# In this case the betas will be calculated on a 2y rolling basis against Treasury
# yields. There are 3 positions that we can choose from all will have long Fallen
# Angels:
#   1. Long Fallen Angels Short HYG
#   2. Long Fallen Angels Short IGG
#   3. Long Fallen Angels Short TLT
#   
# We will use a markov regime switching model on the MOVE index which will be
# fitted via GARCH to manage which pairs to select. There are 2 ways we can 
# set it up. 
#   1. Using absolute pairs, meaning we only hold two pairs
#   2. Using markov smoothed probability to adjust the betas

require("arrow")
require("ggplot2")
require("rugarch")
require("tidyverse")

df_raw_prices <- read_parquet(
  "fixed_income_etfs.parquet")

min_date <- df_raw_prices %>% 
  select(symbol, date) %>% 
  group_by(symbol) %>% 
  filter(date == min(date)) %>% 
  ungroup() %>% 
  arrange(date) %>% 
  tail(1) %>% 
  select(date) %>% 
  pull()

df_prices_prep <- df_raw_prices %>% 
  pivot_longer(!c(date, symbol), names_to = "quote", values_to = "price") %>% 
  filter(date >= min_date) %>% 
  group_by(symbol, quote) %>% 
  arrange(date) %>% 
  mutate(
    rtn = replace_na(price / lag(price) - 1, 0),
    cum_rtn = cumprod(1 + replace_na(rtn, 0)) - 1)

# cumulative returns
df_prices_prep %>% 
  mutate(cum_rtn = cum_rtn * 100) %>% 
  filter(quote == "adjusted") %>% 
  ggplot(aes(x = date, y = cum_rtn, group = symbol)) +
  geom_line(aes(col = symbol)) +
  ylab("Cumulative Return (%)") +
  xlab("Date") +
  labs(title = paste("Cumulative Returns With Dividends From", min_date, "to", max(df_prices_prep$date)))

min_date <- min(df_prices_prep$date)
max_date <- max(df_prices_prep$date)

df_prices_prep %>% 
  filter(quote == "adjusted") %>% 
  select(-c(cum_rtn, price)) %>% 
  mutate(
    year = format(as.Date(date), "%Y"),
    day_month = format(as.Date(date), "%d-%m")) %>% 
  group_by(symbol, year) %>% 
  arrange(date) %>% 
  mutate(cum_rtn = (cumprod(1 + rtn) - 1) * 100) %>% 
  ggplot(aes(x = date, y = cum_rtn, color = symbol)) +
  facet_wrap(~year, scale = "free") +
  geom_line() +
  scale_x_date(date_labels = "%b", date_breaks = "3 months") +
  ylab("Cumulative Return (%)") +
  labs(title = paste("Cumulative Returns Per each year from", min_date, "to", max_date))

df_tlt <- df_raw_prices %>% 
  filter(symbol == "TLT") %>% 
  select(symbol, date, adjusted) %>% 
  arrange(date) %>% 
  mutate(rtn = adjusted / lag(adjusted) - 1) %>% 
  drop_na()

df_tlt_vec <- df_tlt %>% 
  select(rtn) %>% 
  pull()

model_specs <- ugarchspec(distribution.model = "std")
garch_model <- ugarchroll(
  spec = model_specs,
  data = df_tlt_vec,
  n.ahead = 1, 
  n.start = 100,
  refit.every = 500,
  refit.window = "recursive",
  solver = "hybrid",
  fit.control = list(),
  keep.coef = TRUE)

df_forecast <- df_tlt %>% 
  mutate(index = 1:n()) %>% 
  arrange(date) %>% 
  filter(index > 100) %>% 
  mutate(
    mean = garch_model@forecast$density[,1],
    std = garch_model@forecast$density[,2])

start_date <- min(df_forecast$date)
end_date <- max(df_forecast$date)

df_forecast %>% 
  select(-c(symbol, index)) %>% 
  pivot_longer(!date, names_to = "name", values_to = "value") %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~name, scale = "free") +
  geom_line() +
  labs(title = paste("TLT GARCH from", start_date, "to", end_date))

df_move <- read_parquet(
  "move_index.parquet") %>% 
  tibble()

df_move_compare <- df_forecast %>%
  inner_join(df_move, by = "date") %>% 
  select(date, symbol, "MOVE" = PX_LAST, std)

df_move_compare %>% 
  ggplot(aes(x = MOVE, y = std)) +
  geom_point() +
  geom_smooth(method = "lm") +
  ylab("TLT Conditional Var (GARCH)") +
  labs(title = paste("Comparison of TLT GARCH Volatility and MOVE from", start_date, "to", end_date))

min_date <- min(df_forecast$date)
max_date <- max(df_forecast$date)

df_forecast %>% 
  ggplot(aes(x = date, y = std)) +
  geom_line() +
  labs(title = paste("TLT Garch Predicted Volatility from", min_date, "to", max_date)) +
  ylab("Predicted Garch")

df_forecast %>% 
  pivot_longer(!c(symbol, date), names_to = "variable", values_to = "value") %>% 
  write_parquet("tlt_garch.parquet")
