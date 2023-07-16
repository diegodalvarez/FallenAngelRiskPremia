require("arrow")
require("tidyverse")
require("tidyquant")

# path management
parent_dir <- normalizePath("..")
data_dir <- paste0(parent_dir, "\\data")
file_path <- paste0(data_dir, "\\fallen_angels.parquet")
df_raw <- read.csv(file_path)

if (!file.exists(data_dir)){dir.create(data_dir)}
if (!file.exists(parent_dir)){dir.create(file_path)}

tickers <- c("AGG", "ANGL", "BND", "HYG", "TLT")
start_date <- as.Date("2008-01-01")

df_raw <- tq_get(
  tickers,
  get = "stock.prices",
  from = start_date)

df_out <- df_raw %>% 
  select(symbol, date, close, adjusted) %>% 
  pivot_longer(!c(symbol, date)) %>% 
  select("Date" = date, "ticker" = symbol, "price" = value, "quote" = name)

df_out %>% write_parquet(file_path)