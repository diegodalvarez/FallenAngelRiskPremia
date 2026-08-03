# -*- coding: utf-8 -*-
"""
Created on Thu Jul 23 15:56:07 2026

@author: Diego
"""

import os
import pandas as pd

class MeanReversion:
    
    def __init__(self) -> None: 
        
        self.src_path  = os.getcwd()
        self.repo_path = os.path.abspath(os.path.join(self.src_path, ".."))
        self.data_path = os.path.join(self.repo_path, "data")
        self.prep_path = os.path.join(self.data_path, "PrepData")
        self.sig_path  = os.path.join(self.data_path, "Signal")
        
        if os.path.exists(self.sig_path) == False: os.makedirs(self.sig_path)
        
    def _rtn_mr(self, df: pd.DataFrame, window: int) -> pd.DataFrame: 
        
        df_out = (df.sort_values(
            "date").
            assign(
                signal = lambda x: (
                    x.spread_rtn - x.spread_rtn.ewm(span = window, adjust = False).mean()) / 
                    x.spread_rtn.ewm(span = window, adjust = False).std(),
                lag_signal = lambda x: x.signal.shift()))
        
        return df_out
        
    def get_rtn_mean_reversion(self, window: int = 30, verbose: bool = True) -> pd.DataFrame: 
        
        if verbose: print("Getting Mean Reversion Signal")
        
        rtn_path = os.path.join(self.prep_path, "Rtn.parquet")
        out_path = os.path.join(self.sig_path, "MeanReversionRtn.parquet")
        
        if os.path.exists(out_path) == True:
            if verbose: print("Already have data\n")
            return None
        
        df_out = (pd.read_parquet(
            path = rtn_path, engine = "pyarrow").
            loc[lambda x: x.asset == "etf"].
            assign(
                spread_rtn = lambda x: 0.5 * (x.fa_rtn - x.fi_rtn),
                name       = lambda x: x.fi_ticker + " " + x.fa_ticker + " " + x.hedge).
            groupby("name").
            apply(self._rtn_mr, window).
            reset_index().
            drop(columns = ["level_1"]))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
mean_reversion = MeanReversion()
mean_reversion.get_rtn_mean_reversion()