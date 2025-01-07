suppressWarnings(require("TTR"))
suppressWarnings(require("roll"))
suppressWarnings(require("dplyr"))
suppressWarnings(require("arrow"))
suppressWarnings(require("ggplot2"))
suppressWarnings(require("tidyverse"))

data_path   <- "C:\\Users\\Diego\\Desktop\\app_prod\\research\\FallenAngel\\data"
weight_path <- file.path(data_path, "Weights") 

if (!file.exists(weight_path)){
  file_created <- dir.create(weight_path)
}

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
      angel_inv    = 1 / angel_dur,
      hy_inv       = 1 / hy_dur,
      angel_weight = lag(angel_inv / (angel_inv + hy_inv)),
      hy_weight    = lag(hy_inv / (angel_inv + hy_inv))) %>% 
    drop_na() %>% 
    select(-c(angel_inv, hy_inv))
  
  return(df_out)
}
df_duration_neutral <- get_duration_hedge(df_prices)

get_vol_hedge <- function(df_prices, window = 30){
  
  df_duration_neutral <- get_duration_hedge(df_prices)
  
  df_vol <- df_prices %>% 
    select(security, date, PX_rtn, sec_group) %>% 
    group_by(security) %>% 
    arrange(date) %>% 
    mutate(
      vol     = roll_sd(PX_rtn, width = 30),
      inv_vol = lag(1 / vol)) %>% 
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
      hy_weight    = lag(hy_vol / (hy_vol + angel_vol)),
      angel_weight = lag(angel_vol / (hy_vol + angel_vol))) %>% 
    select(-c(hy_vol, angel_vol)) %>% 
    drop_na()
  
  return(df_out)
}
df_vol_neutral <- get_vol_hedge(df_prices)

df_duration_neutral %>% 
  write_parquet(file.path(weight_path, "DurationNeutral.parquet"))

df_vol_neutral %>% 
  write_parquet(file.path(weight_path, "VolNeutral.parquet"))
