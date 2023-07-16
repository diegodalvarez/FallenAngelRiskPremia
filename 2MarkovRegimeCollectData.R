require("Rblpapi")
require("tidyquant")
require("tidyverse")

tickers <- c("ANGL", "AGG", "TLT", "HYG")
start_date <- as.Date("01-01-2011", format = "%m-%d-%Y")
end_date <- Sys.Date()

df_raw_prices <- tq_get(
  tickers,
  get = "stock.prices",
  from = start_date)

df_raw_prices %>% 
  write_parquet("fixed_income_etfs.parquet")

tickers <- c("MOVE Index")
con <- blpConnect()
raw_df <- bdh(
  securities = tickers,
  fields = "PX_LAST",
  start.date = start_date,
  end.date = end_date)

raw_df %>% 
  write_parquet("move_index.parquet")
