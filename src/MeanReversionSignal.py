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
        
    def _mean_reversion(self, df: pd.DataFrame, var_name: str, window: int) -> pd.DataFrame: 
        
        df_out = (df.sort_values(
            "date").
            assign(
                signal = lambda x: (
                    x[var_name]- x[var_name].ewm(span = window, adjust = False).mean()) / 
                    x[var_name].ewm(span = window, adjust = False).std(),
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
            apply(self._mean_reversion, "spread_rtn", window).
            reset_index().
            drop(columns = ["level_1"]))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
    def get_yld_mean_reversion(self, window: int = 30, verbose: bool = True) -> pd.DataFrame: 
        
        if verbose: print("Getting Yield Mean Reversion Signal")
        yld_path = os.path.join(self.data_path, "PrepData", "YldSprd.parquet")
        out_path = os.path.join(self.sig_path, "YieldReversion.parquet")
        
        if os.path.exists(out_path):
            if verbose: print("Saving data\n")
            return None
        
        df_out = (pd
                .read_parquet(path = yld_path, engine = "pyarrow")
                .assign(name = lambda x: x.security + "-" + x.variable)
                .groupby("name")
                .apply(self._mean_reversion, "spread", window)
                .reset_index(drop = True))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")

def main() -> None: 
        
    mean_reversion = MeanReversion()
    mean_reversion.get_rtn_mean_reversion()
    mean_reversion.get_yld_mean_reversion()
    
if __name__ == "__main__": main()