require("arrow")
require("ggplot2")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
etf_path <- file.path(parent_dir, "data", "etf.parquet")

df_raw <- read_parquet(etf_path) %>% 
  as_tibble()

plot_hist <- function(df_rtn, freq){
  
  start_date <- min(df_rtn$Date)
  end_date <- max(df_rtn$Date)
  
  # plot hist
  df_rtn %>% 
    mutate(rtn = rtn * 100) %>% 
    ggplot(aes(x = rtn)) +
    facet_wrap(~ticker, scale = "free") + 
    geom_histogram(bins = 40) + 
    xlab("Daily Return (%)") +
    labs(title = paste(freq, "Returns Distribution from", start_date, "to", end_date))
  
}

get_cum_rtn <- function(df_rtn){
  
  df_cum <- df_rtn %>% 
    group_by(ticker) %>% 
    arrange(Date) %>%  
    mutate(cum_rtn = cumprod(1 + rtn) - 1) %>% 
    ungroup()
  
  return(df_cum)
}

plot_cum_rtn <- function(df_cum){
  
  start_date <- min(df_cum$Date)
  end_date <- max(df_cum$Date)
  
  df_cum %>% 
    mutate(cum_rtn = cum_rtn * 100) %>% 
    ggplot(aes(x = Date, y = cum_rtn, color = ticker)) +
    geom_line() +
    ylab("Return (%)") +
    labs(title = paste("Cumulative Returns from", start_date, "to", end_date))
  
}

plot_ols <- function(df_rtn, freq){
  
  start_date <- min(df_rtn$Date)
  end_date <- max(df_rtn$Date)
  
  # Run Regression
  angl_rtn <- df_rtn %>%
    filter(ticker == "ANGL") %>%
    rename("angl_rtn" = rtn) %>%
    select(Date, angl_rtn)
  
  df_exog <- df_rtn %>%
    filter(ticker != "ANGL") %>%
    select(-price)
  
  df_regress <- df_exog %>%
    left_join(y = angl_rtn, by = "Date", relationship = "many-to-many")
  
  df_regress %>%
    mutate(
      rtn = rtn * 100,
      angl_rtn = angl_rtn * 100) %>%
    ggplot(aes(x = rtn, y = angl_rtn)) +
    facet_wrap(~ticker, scale = "free") +
    geom_point() +
    geom_smooth(method = "lm", formula = "y ~ x") +
    ylab("Fallen Angel Return (%)") +
    xlab("Possible Hedge Return (%)") +
    labs(title = paste(
      "OLS", freq,  "Regression of possible Fallen Angel Hedges from", start_date, "to", end_date))
}

df_adjusted <- df_raw %>% 
  filter(quote == "adjusted") %>% 
  select(-quote) %>% 
  pivot_wider(names_from = "ticker", values_from = "price") %>% 
  drop_na() %>% 
  pivot_longer(!Date, names_to = "ticker", values_to = "price")

df_daily_rtn <- df_adjusted %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup()

plot_hist(df_daily_rtn, "Daily")
daily_df_cum <- get_cum_rtn(df_daily_rtn)
plot_cum_rtn(daily_df_cum)

plot_ols(df_daily_rtn, "Daily")

df_weekly_rtn <- df_adjusted %>% 
  mutate(weekday = weekdays(Date)) %>% 
  filter(weekday == "Monday") %>% 
  select(-weekday) %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup()

plot_ols(df_weekly_rtn, "Weekly")

df_monthly <- df_adjusted %>% 
  mutate(month_year = format(Date, "%Y_%m")) %>% 
  group_by(month_year) %>% 
  filter(Date == min(Date)) %>% 
  ungroup() %>% 
  group_by(ticker) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup()
  
plot_ols(df_monthly, "monthly")