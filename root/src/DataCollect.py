# -*- coding: utf-8 -*-
"""
Created on Thu Jan 30 11:07:55 2025

@author: Diego
"""

import os
import numpy as np
import pandas as pd
import yfinance as yf

class DataCollect: 
    
    def __init__(self):
        
        self.dir       = os.path.dirname(os.path.abspath(__file__))  
        self.root_path = os.path.abspath(
            os.path.join(os.path.abspath(
                os.path.join(self.dir, os.pardir)), os.pardir))
        
        self.data_path = os.path.join(self.root_path, "data")
        self.raw_path  = os.path.join(self.data_path, "raw")
        
        if os.path.exists(self.data_path) == False: os.makedirs(self.data_path)
        if os.path.exists(self.raw_path) == False: os.makedirs(self.raw_path)
        
        self.etf_tickers = ["ANGL", "FALN", "JNK", "HYG", "AGG", "LQD", "SJNK"]        
        self.bbg_path    = r"C:\Users\Diego\Desktop\app_prod\BBGData\data"
        self.fund_path   = r"C:\Users\Diego\Desktop\app_prod\BBGData\ETFIndices\BondPricing"
        
        self.bad_variables = ["AVERAGE_WEIGHTED_COUPON"]
        self.clean_window  = 30
        
    def get_raw_px(self, verbose: bool = False) -> pd.DataFrame:
        
        file_path = os.path.join(self.raw_path, "PX.parquet")
        try:
            
            if verbose == True: print("Trying to find raw PX data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now")  
        
            df_out = (yf.download(
                tickers = self.etf_tickers)
                ["Adj Close"].
                reset_index().
                melt(id_vars = ["Date"]).
                dropna().
                rename(columns = {
                    "Date"  : "date",
                    "Ticker": "security",
                    "value" : "PX"}).
                assign(date = lambda x: pd.to_datetime(x.date).dt.date))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
    
    def get_bond_data(self, verbose: bool = False) -> pd.DataFrame: 
        
        file_path = os.path.join(self.raw_path, "BondFundamentals.parquet")
        try:
            
            if verbose == True: print("Trying to find Bond Fundamentals data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now")  
        
            paths = [os.path.join(
                self.fund_path, ticker + ".parquet")
                for ticker in self.etf_tickers]
            
            renamer = {
                "YAS_YLD_SPREAD"         : "YAS",
                "YAS_BOND_YLD"           : "YLD",
                "YAS_ISPREAD_TO_GOVT"    : "ISPREAD",
                "YAS_MOD_DUR"            : "MOD_DUR"}
            
            df_out = (pd.read_parquet(
                path = paths, engine = "pyarrow").
                assign(security = lambda x: x.security.str.split(" ").str[0]).
                query("variable != @self.bad_variables").
                pivot(index = ["date", "security"], columns = "variable", values = "value").
                rename(columns = renamer).
                reset_index())
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
    
    def _clean(self, df: pd.DataFrame, window: int) -> pd.DataFrame:
        
        df_out = (df.assign(
            diff_val = lambda x: x.value.diff(),
            mean_val    = lambda x: x.diff_val.mean(),
            std_val     = lambda x: x.diff_val.std(),
            z_score     = lambda x: np.abs((x.diff_val - x.mean_val) / x.std_val),
            tmp         = lambda x: np.where(x.z_score > 4, np.nan, x.value),
            replace_val = lambda x: x.tmp.ewm(span = 2, adjust = False).mean()).
            drop(columns = ["diff_val", "mean_val", "std_val", "z_score", "tmp"]).
            rename(columns = {"replace_val": "new_val"}).
            assign(
                mean_val    = lambda x: x.new_val.rolling(window = window).mean(),
                std_val     = lambda x: x.new_val.rolling(window = window).std(),
                z_score     = lambda x: np.abs((x.new_val - x.mean_val) / x.std_val),
                tmp         = lambda x: np.where(x.z_score > 4, np.nan, x.new_val),
                replace_val = lambda x: x.tmp.ewm(span = 2, adjust = False).mean()).
            drop(columns = ["new_val", "mean_val", "std_val", "z_score", "tmp"]))
        
        return df_out
    
    def clean_bond_fundamentals(self, verbose: bool = False) -> pd.DataFrame:
        
        file_path = os.path.join(self.raw_path, "CleanedBondFundamentals.parquet")
        try:
            
            if verbose == True: print("Trying to find Bond Fundamentals data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now")  
        
            df_longer = (self.get_bond_data().melt(
                id_vars = ["date", "security"]))
            
            df_dur = (df_longer.query(
                "variable == 'MOD_DUR'"))
            
            df_clean = (df_longer.query(
                "variable != 'MOD_DUR'").
                groupby(["security", "variable"]).
                apply(self._clean, self.clean_window).
                reset_index(drop = True).
                drop(columns = ["value"]).
                rename(columns = {"replace_val": "value"}))
            
            df_out = (pd.concat([
                df_dur, df_clean]))
        
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
        
def main() -> None:
           
    DataCollect().get_raw_px(verbose = True)
    DataCollect().get_bond_data(verbose = True)
    DataCollect().clean_bond_fundamentals(verbose = True)
    
if __name__ == "__main__": main()