require("roll")
require("arrow")
require("ggplot2")
require("tidyverse")

# path management
parent_dir <- normalizePath("..")
etf_path <- file.path(parent_dir, "data", "etf.parquet")
out_path <- file.path(parent_dir, "data", "rollingOLSparams.parquet")

df_raw <- read_parquet(etf_path) %>% 
  as_tibble()

df_rtn <- df_raw %>% 
  filter(quote == "adjusted") %>% 
  select(-quote) %>% 
  pivot_wider(names_from = "ticker", values_from = "price") %>% 
  drop_na() %>% 
  pivot_longer(!Date, names_to = "ticker", values_to = "price") %>% 
  group_by(ticker) %>% 
  arrange(Date) %>% 
  mutate(rtn = price / lag(price) - 1) %>% 
  drop_na() %>% 
  ungroup()

df_angl <-  df_rtn %>% 
  filter(ticker == "ANGL") %>% 
  select(Date, "angl_rtn" = rtn)

df_exog <- df_rtn %>% 
  filter(ticker != "ANGL") %>% 
  select(-price)

df_regress <- df_exog %>% 
  left_join(y = df_angl, by = "Date", relationship = "many-to-many")

roll_regress <- function(df){
  
  df <- df %>% arrange(Date)
  
  roll_regress <- roll_lm(
    x = df$rtn, y = df$angl_rtn, width = 30)
  
  coefs <- coef(roll_regress) %>% 
    as_tibble()
  
  colnames(coefs) <- c("alpha", "beta")
  coef_out <- coefs %>% 
    mutate(Date = df$Date) %>% 
    drop_na()
  
  return(coef_out)
}

df_roll <- df_regress %>% 
  group_by(ticker) %>% 
  group_modify(~roll_regress(.)) %>% 
  ungroup() 

df_roll %>% 
  write_parquet(out_path)



