require("arrow")
require("tidyverse")
require("tidyquant")

# path management
parent_dir <- normalizePath("..")
out_path <- file.path(parent_dir, "data", "etf.parquet")

tickers <- c(
  "AGG", "ANGL", "BND", "HYG", "TLT", "SJNK", "SHYG", "JNK", "BSV", "BIV", 
  "SHY")

start_date <- as.Date("2008-01-01")

df_raw <- tq_get(
  tickers,
  get = "stock.prices",
  from = start_date)

df_out <- df_raw %>% 
  select(symbol, date, close, adjusted) %>% 
  pivot_longer(!c(symbol, date)) %>% 
  select("Date" = date, "ticker" = symbol, "price" = value, "quote" = name)

df_out %>% write_parquet(out_path)

