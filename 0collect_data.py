# for collecting data
import os
import pandas as pd
import datetime as dt
import yfinance as yf
import pandas_datareader as web

parent_dir = os.path.abspath(os.path.join(os.getcwd(), os.pardir))
data_dir = os.path.join(parent_dir, "data")
fallen_angel_file_path = os.path.join(data_dir, "fallen_angels.csv")
gdp_file_path = os.path.join(data_dir, "gdp.csv")

try:
    
    print("[INFO] Trying to read ETF data from file")
    df = pd.read_csv(filepath_or_buffer = fallen_angel_file_path)
    print("[INFO] File read successfully")
    
except:

    print("[ALERT] File not found, downloading from Yahoo")
    end_date = dt.date(year = 2023, month = 4, day = 17)
    start_date = dt.date(year = end_date.year - 15, month = 1, day = 1)

    tickers = ["TLT", "AGG", "HYG", "ANGL", "BND"]
    df = (yf.download(
        tickers = tickers,
        start = start_date,
        end = end_date)
        [["Close", "Adj Close"]].
        reset_index().
        melt(id_vars = "Date"))
    
    df.to_csv(path_or_buf = fallen_angel_file_path)
    
    print("[INFO] File successfully downloaded")
    
try:
    
    print("[INFO] Trying to read GDP data from file")
    df = pd.read_csv(filepath_or_buffer = gdp_file_path)
    print("[INFO] File read successfully")
    
except: 
    
    print("[ALERT] File not found, downloading from ST. Louis Fred")
    end_date = dt.date(year = 2023, month = 4, day = 17)
    start_date = dt.date(year = end_date.year - 15, month = 1, day = 1)

    tickers = ["GDP"]
    df = (web.DataReader(
        tickers,
        data_source = "fred",
        start = start_date,
        end = end_date).
        reset_index().
        melt(id_vars = "DATE"))
    
    df.to_csv(path_or_buf = gdp_file_path)
    
    print("[INFO] File successfully downloaded")
    
