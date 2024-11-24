require("roll")
require("arrow")
require("dplyr")
require("")
require("tidyverse")

df_raw <- read_parquet(
  "fixed_income_etfs.parquet") %>% 
  tibble()

df_rtns <- df_raw %>% 
  select(symbol, date, adjusted) %>% 
  group_by(symbol) %>% 
  mutate(rtn = adjusted / lag(adjusted) - 1) %>% 
  ungroup() 

df_rtns %>% 
  select(symbol) %>% 
  unique()

df_angl <- df_rtns %>% 
  filter(symbol == "ANGL") %>% 
  select(-c(symbol, adjusted)) %>% 
  rename("angl_rtn" = "rtn")

df_fund_rtn <- df_rtns %>% 
  filter(symbol != "ANGL") %>% 
  select(-adjusted)

df_combined <- df_angl %>% 
  inner_join(df_fund_rtn, by = "date") %>% 
  drop_na()

start_date <- min(df_combined$date)
end_date <- max(df_combined$date)

df_combined %>% 
  ggplot(aes(x = rtn, y = angl_rtn)) +
  facet_wrap(~symbol, scale = "free") +
  geom_point() +
  geom_smooth(method = "lm") +
  ylab("Fallen Angel ETF Returns") +
  xlab("Benchmark ETF Returns") +
  labs(title = paste("Fallen Angel Returns from", start_date, "to", end_date))

sample_df <- df_combined %>% 
  filter(symbol == "AGG") %>% 
  do(mod = roll_lm(x = .$rtn, y = .$angl_rtn, width = 30)[[3]] %>% tibble())

model <- roll_lm(x = df_combined$rtn, y = df_combined$angl_rtn, width = 30)[[3]]

roll_regress <-function(df){

  model_roll <- roll_lm(
    x = df$rtn,
    y = df$angl_rtn,
    width = 30)[[3]]
  
  df_tmp <- as.data.frame(model_roll)
  colnames(df_tmp)[1] = "alpha"
  colnames(df_tmp)[2] = "beta"
  
  df_tibble <- df_tmp %>% 
    tibble() %>% 
    mutate(index = 1:n())
  
  df <- df %>%
    mutate(index = 1:n()) %>%
    left_join(df_tibble, by = "index") %>% 
    select(-index)
  
  return(df)

}

df_params <- df_combined %>% 
  group_by(symbol) %>%
  arrange(date) %>% 
  reframe(roll_regress(.))

df_params %>% 
  select(symbol, date, alpha, beta) %>% 
  pivot_longer(!c(date, symbol), names_to = "variable", values_to = "value") %>% 
  drop_na() %>% 
  ggplot(aes(x = date, y = value)) +
  facet_wrap(~symbol + variable, scale = "free") +
  geom_line()
