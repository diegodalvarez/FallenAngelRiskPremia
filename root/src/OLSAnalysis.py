# -*- coding: utf-8 -*-
"""
Created on Tue Feb 11 19:16:14 2025

@author: Diego
"""

import os
import numpy as np
import pandas as pd
import statsmodels.api as sm
from   statsmodels.regression.rolling import RollingOLS

from tqdm import tqdm
from SignalGenerator import SignalGenerator

class OLSAnalysis(SignalGenerator):
    
    def __init__(self) -> None:
        
        super().__init__()
        self.ols_path = os.path.join(self.data_path, "OLSAnalysis")
        if os.path.exists(self.ols_path) == False: os.makedirs(self.ols_path)
        
        self.sample_size = 0.5
        self.num_samples = 10_000
        
    def _get_ols(self, df: pd.DataFrame, sample_size: float) -> pd.DataFrame:
        
        df_tmp = df.sample(frac = sample_size)
        model  = (sm.OLS(
            endog = df_tmp.signal_rtn,
            exog  = sm.add_constant(df_tmp.lag_zscore)).
            fit())
        
        df_val = (model.params.to_frame(
            name = "val").
            reset_index())
        
        df_out = (model.pvalues.to_frame(
            name = "pval").
            reset_index().
            merge(right = df_val, how = "inner", on = ["index"]).
            rename(columns = {"index": "param"}))
        
        return df_out
        
    def _get_ols_samples(self, df: pd.DataFrame, sample_size: float, num_samples: int) -> pd.DataFrame: 
        
        df_out = (pd.concat([
            self._get_ols(df, sample_size).assign(sim = i + 1) 
            for i in tqdm(range(num_samples), desc = "Working on {}".format(df.name))]))
        
        return df_out
        
    def get_ols_samples(self, verbose: bool = False) -> pd.DataFrame: 
        
        file_path = os.path.join(self.ols_path, "BootstrappedOLS.parquet")
        try:
            
            if verbose == True: print("Trying to find bootstrapped OLS Data data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now") 
            
            df_out = (self.get_signal()[
                ["date", "variable", "ticker_spread", "lag_zscore", "rtn_group", "signal_rtn"]].
                groupby(["variable", "ticker_spread", "rtn_group"]).
                apply(self._get_ols_samples, self.sample_size, self.num_samples).
                reset_index().
                drop(columns = ["level_3"]))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
    
    def _get_expanding_ols(self, df: pd.DataFrame) -> pd.DataFrame:
        
        df_tmp = (df.set_index(
            "date")
            [["lag_zscore", "signal_rtn"]])

        df_out = (RollingOLS(
            endog     = df_tmp.signal_rtn,
            exog      = sm.add_constant(df_tmp.lag_zscore),
            expanding = True).
            fit().
            params.
            rename(columns = {
                "const"     : "lag_alpha",
                "lag_zscore": "lag_beta"}).
            shift().
            merge(right = df, how = "inner", on = ["date"]))
        
        return df_out
    
    def get_expanding_ols(self, verbose: bool = False) -> None:
        
        file_path = os.path.join(self.ols_path, "ExpandingOLS.parquet")
        try:
            
            if verbose == True: print("Trying to find Expanding OLS Data data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now") 
        
            df_out = (self.get_signal()[
                ["date", "variable", "ticker_spread", "lag_zscore", "rtn_group", "signal_rtn", "spread"]].
                groupby(["variable", "ticker_spread", "rtn_group"]).
                apply(self._get_expanding_ols).
                reset_index(drop = True).
                dropna().
                drop(columns = ["signal_rtn"]))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
  
def main() -> None:
    
    OLSAnalysis().get_ols_samples(verbose = True)
    OLSAnalysis().get_expanding_ols(verbose = True)  
    
if __name__ == "__main__": main()