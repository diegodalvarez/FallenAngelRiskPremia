suppressWarnings(require("TTR"))
suppressWarnings(require("roll"))
suppressWarnings(require("dplyr"))
suppressWarnings(require("arrow"))
suppressWarnings(require("ggplot2"))
suppressWarnings(require("tidyverse"))

get_data <- function(){
  
  file_path <- (file.path(
    dirname(dirname(getwd())),
    "data",
    "RawData",
    "RawPrices.parquet"))
  
  df_out <- (read_parquet(
    file_path))
  
  df_sec_group <- tibble(
    security  = c("ANGL", "FALN", "HYG", "JNK"),
    sec_group = c("Angel", "Angel", "HY", "HY"))
  
  df_out <- df_out %>% 
    inner_join(df_sec_group, by = c("security"), relationship = "many-to-many")
  
  return(df_out)
}
df_prices <- get_data()


get_duration_hedge <- function(df_prices, width = 30){
  
  
  df_duration <- df_prices %>% 
    select(date, security, mod_dur, sec_group) %>% 
    drop_na() %>% 
    group_by(security) %>% 
    arrange(date) %>% 
    mutate(smooth_dur = lag(EMA(mod_dur, 25))) %>% 
    drop_na() %>% 
    ungroup()
  
  df_angel <- df_duration %>% 
    select(date, security, smooth_dur, sec_group) %>% 
    filter(sec_group == "Angel") %>% 
    select(date, "angel_sec" = security, "angel_dur" = smooth_dur)
  
  df_hy <- df_duration %>% 
    select(date, security, smooth_dur, sec_group) %>% 
    filter(sec_group == "HY") %>% 
    select(date, "hy_sec" = security, "hy_dur" = smooth_dur)
  
  df_out <- df_angel %>% 
    inner_join(df_hy, by = c("date"), relationship = "many-to-many") %>% 
    mutate(
      tmp1         = angel_dur / (angel_dur + hy_dur),
      angel_weight = angel_dur * tmp1 / hy_dur,
      hy_weight    = 1 - angel_weight) %>% 
    group_by(angel_sec, hy_sec) %>% 
    mutate(
      lag_angel_weight = lag(angel_weight),
      lag_hy_weight    = lag(hy_weight)) %>% 
    drop_na() %>% 
    ungroup()
  
  return(df_out)
}
df_duration_neutral <- get_duration_hedge(df_prices)

get_vol_hedge <- function(df_prices, window = 30){
  
  df_vol <- df_prices %>% 
    select(security, date, PX_rtn, sec_group) %>% 
    group_by(security) %>% 
    arrange(date) %>% 
    mutate(
      vol     = runSD(PX_rtn, n  = window) * sqrt(252),
      lag_vol = lag(vol),
      inv_vol = 1 / lag_vol) %>% 
    drop_na() %>% 
    ungroup()
  
  df_hy <- df_vol %>% 
    filter(sec_group == "HY") %>% 
    select("hy_sec" = security, date, "hy_vol"= inv_vol)
  
  df_angel <- df_vol %>% 
    filter(sec_group == "Angel") %>% 
    select("angel_sec" = security, date, "angel_vol" = inv_vol)
  
  df_out <- df_hy %>% 
    inner_join(df_angel, by = c("date"), relationship = "many-to-many") %>% 
    mutate(
      cum_vol      = hy_vol + angel_vol,
      angel_weight = angel_vol / cum_vol,
      hy_weight    = hy_vol / cum_vol)
  
  return(df_out)
}
df_vol_neutral <- get_vol_hedge(df_prices)

window <- 30
df_hy <- df_prices %>% 
  filter(sec_group == "HY") %>% 
  select("hy_sec" = security, "hy_rtn" = PX_rtn, date) %>% 
  drop_na()

df_angel <- df_prices %>% 
  filter(sec_group == "Angel") %>% 
  select("angel_sec" = security, "angel_rtn" = PX_rtn, date) %>% 
  drop_na()

df_hy %>% 
  inner_join(df_angel, by = c("date"), relationship = "many-to-many") %>% 
  group_by(hy_sec, angel_sec) %>% 
  arrange(date) %>% 
  mutate(
    roll_cov     = runCov(hy_rtn, angel_rtn, n = window),
    roll_var     = runVar(hy_rtn, n = window),
    roll_beta    = roll_cov / roll_var,
    lag_beta     = lag(roll_beta),
    tmp1         = lag_beta / (1 + lag_beta),
    angel_weight = roll_beta * tmp1 / 1,
    hy_weight    = 1 - angel_weight,
    angl_test    = angel_rtn * angel_weight,
    hy_test      = hy_rtn * hy_weight) %>% 
  drop_na() %>% 
  select(-c(roll_cov, roll_var))
  
