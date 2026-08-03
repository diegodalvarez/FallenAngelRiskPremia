# -*- coding: utf-8 -*-
"""
Created on Thu Jan 30 11:07:55 2025

@author: Diego
"""

import os
import numpy as np
import pandas as pd
import yfinance as yf
import datetime as dt

from tqdm import tqdm

class DataCollect: 
    
    def __init__(self):
        
        self.src_path  = os.getcwd()
        self.repo_path = os.path.abspath(os.path.join(self.src_path,".."))
        self.data_path = os.path.join(self.repo_path, "data")
        self.raw_path  = os.path.join(self.data_path, "RawData")
        
        if os.path.exists(self.data_path) == False: os.makedirs(self.data_path)
        if os.path.exists(self.raw_path)  == False: os.makedirs(self.raw_path)
        
        self.blp_path    = r"A:\BlpData\FixedIncomeFundamentals"
        self.fund_fields = ["YAS_BOND_YLD", "YAS_MOD_DUR"]
        self.bbg_path    = r"A:\2026BlpAdHocData\Combined"
        self.etf_path    = os.path.join(self.bbg_path, "MiscETFs")
        self.cred_path   = r"A:\BBGData\credit_indices_data"
        
        #self.etf_tickers = ["ANGL", "FALN", "JNK", "HYG", "AGG", "LQD", "SJNK"]
        self.idx_tickers = [""]
        self.start_date  = dt.date(year = 1990, month = 1, day = 1)
        self.end_date    = dt.date(year = 2026, month = 7, day = 20)
        
    def get_raw_px(self, verbose: bool = True) -> None:
        
        if verbose: print("Running ETF Px")
        
        out_path = os.path.join(self.raw_path, "PX.parquet")
        
        if os.path.exists(out_path) == True: 
            if verbose: print("Already have data\n")
            return None
        
        if verbose: print("Collecting Pricing data from Yahoo")
        
        ticker_path = os.path.join(self.data_path, "FATickerGuide.xlsx")
        etf_tickers = (pd.read_excel(
            io = ticker_path).
            ETF.
            to_list())
        
        df_out = (yf.download(
            tickers     = etf_tickers,
            start       = self.start_date,
            end         = self.end_date,
            auto_adjust = False).
            reset_index().
            melt(id_vars = [("Date","")]).
            rename(columns = {
                ("Date", ""): "date",
                "Ticker"    : "ticker"}).
            dropna())
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
    def get_clean_bond_fundamentals(self, verbose: bool = True) -> None: 
        
        if verbose: 
            print("Getting Cleaned Bond Data")
        
        in_path  = os.path.join(self.blp_path, "CleanedBondFundamentals.parquet")
        out_path = os.path.join(self.raw_path, "CleanedBondFundamentals.parquet")
        
        if os.path.exists(out_path) == True: 
            if verbose: print("Already have data")
            return None
        
        if verbose: 
            print("Saving data\n")
            
        (pd.read_parquet(path = in_path, engine = "pyarrow").to_parquet(path = out_path))
        
    def get_extra_bond_fundamental(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting Extra Bond Fundamentals")
        
        out_path = os.path.join(self.raw_path, "BondFundamentalExtra.parquet")
        
        if os.path.exists(out_path) == True: 
            if verbose: print("Already have data\n")
            return None
        
        if verbose: print("Collecting data\n")
        
        paths = ([
            os.path.join(self.blp_path, field, ticker + ".parquet") 
            for field in self.fund_fields
            for ticker in self.etf_tickers])
        
        df_lists = []
        
        for path in tqdm(paths): 
            
            try:
                df_add = (pd.read_parquet(
                    path = path, engine = "pyarrow").
                    melt(id_vars = ["date", "security"]))
                
                df_lists.append(df_add)
                
            except: pass
        
        if verbose: print("\nSaving data\n")
        
        df_out = pd.concat(df_lists)
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
    def get_etf_info(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting extra ETF Info")
        
        out_path = os.path.join(self.raw_path, "ETFData.parquet")
        
        if os.path.exists(out_path) == True: 
            if verbose: print("Already have data\n")
            return None
        
        tickers  = ["{} US Equity".format(ticker) for ticker in self.etf_tickers]
        etf_path = os.path.join(self.etf_path, "Misc1.parquet")
        df_out   = (pd.read_parquet(
            path = etf_path, engine = "pyarrow").
            query("security == @tickers"))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
    def _get_rtn(self, df: pd.DataFrame) -> pd.DataFrame: 
        
        df_out = (df.sort_values(
            "date").
            assign(
                rtn         = lambda x: x.PX_LAST.pct_change(),
                period_days = lambda x: (x.date - x.date.shift()).dt.days))
        
        return df_out
    
    def _lag_day(self, df: pd.DataFrame) -> pd.DataFrame: 
        
        df_out = (df.assign(
            period_days = lambda x: (x.date - x.date.shift()).dt.days))
     
        return df_out
        
    def get_index_total_return(self, verbose: bool = True) -> None: 
        
        if verbose: 
            print("Getting Index Total Return Data")
        
        fi_path     = os.path.join(self.bbg_path, "FixedIncomeIndex")
        bbg_tr_path = os.path.join(fi_path, "BloombergTR.parquet")
        ticker_path = os.path.join(self.data_path, "FATickerGuide.xlsx")
        rtn_path    = os.path.join(fi_path, "DAY_TO_DAY_TOT_RETURN_GROSS_DVDS.parquet")
        truu_path   = os.path.join(fi_path, "TRUU.parquet")
        van_path    = os.path.join(self.raw_path, "VanEckData.xlsx")
        out_path    = os.path.join(self.raw_path, "IndexTotalReturn.parquet")
        
        if os.path.exists(out_path) == True: 
            if verbose: print("Saving data\n")
            return None
        
        df_ticker = (pd.read_excel(
            io         = ticker_path, 
            sheet_name = "TRUU Benchmark"))
        
        tickers = df_ticker.ticker.drop_duplicates().sort_values().to_list()
        
        df_bbg  = pd.read_parquet(path = bbg_tr_path, engine = "pyarrow")
        df_rtn  = pd.read_parquet(path = rtn_path, engine = "pyarrow")
        df_truu = pd.read_parquet(path = truu_path, engine = "pyarrow")
        
        df_bbg_rtn = (df_bbg.query(
            "security == @tickers").
            sort_values("date").
            groupby("security").
            apply(self._get_rtn).
            reset_index().
            drop(columns = ["level_1", "PX_LAST"]))
        
        df_rtn_raw = (df_rtn.query(
            "security == @tickers").
            rename(columns = {"DAY_TO_DAY_TOT_RETURN_GROSS_DVDS": "rtn"}).
            assign(rtn = lambda x: x.rtn / 100))

        df_rtn_prep = (df_rtn_raw[
            ["security", "date"]].
            drop_duplicates().
            groupby("security").
            apply(self._lag_day).
            reset_index().
            drop(columns = ["level_1"]).
            merge(right = df_rtn_raw, how = "inner", on = ["date", "security"]))

        df_truu_rtn = (df_truu.query(
            "security == @tickers").
            groupby("security").
            apply(self._get_rtn).
            reset_index().
            drop(columns = ["level_1", "PX_LAST"]))
        
        df_ice = (pd.read_excel(
            io = van_path, skiprows = 1)
            [["Date", "Index Value"]].
            rename(columns = {
                "Date"       : "date",
                "Index Value": "PX_LAST"}).
            sort_values("date").
            assign(
                security    = "H0CF Index",
                period_days = lambda x: (x.date - x.date.shift()).dt.days,
                rtn = lambda x: x.PX_LAST.pct_change()).
            drop(columns = ["PX_LAST"]))
        
        df_combined = (pd.concat([
            df_bbg_rtn, df_rtn_prep, df_truu_rtn, df_ice]).
            drop_duplicates().
            groupby(["date", "security"]).
            agg("mean").
            reset_index())
        
        if verbose: 
            print("Saving data\n")
        
        df_combined.to_parquet(path = out_path, engine = "pyarrow")
        
def main() -> None:
           
    data_collect = DataCollect()
    data_collect.get_raw_px()
    data_collect.get_clean_bond_fundamentals()
    data_collect.get_extra_bond_fundamental()
    data_collect.get_etf_info()
    data_collect.get_index_total_return()
    
if __name__ == "__main__": main()