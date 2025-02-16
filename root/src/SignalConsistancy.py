# -*- coding: utf-8 -*-
"""
Created on Wed Feb 12 11:36:15 2025

@author: Diego
"""

import os
import sys
import numpy as np
import pandas as pd
import statsmodels.api as sm
from   statsmodels.regression.rolling import RollingOLS
from   RiskPremia import RiskPremia

from tqdm import tqdm
tqdm.pandas()

import warnings
warnings.simplefilter(action='ignore', category=RuntimeWarning)

class SignalConsistancy(RiskPremia): 
    
    def __init__(self) -> None:
        
        super().__init__()
        self.consist_path = os.path.join(self.data_path, "SignalConsistancy")
        if os.path.exists(self.consist_path) == False: os.makedirs(self.consist_path)
        
        self.max_window = 250
        
    def _get_rtn(self) -> pd.DataFrame:
        
        df_dollar_tmp = (self.calculate_equal_spread().assign(
            ticker_spread = lambda x: x.angl_sec + "_" + x.bnd_sec,
            rtn_group     = "dollar_neutral").
            drop(columns = ["bnd_sec", "angl_sec", "bnd_rtn", "angl_rtn"]))
    
        df_dur_tmp = (self.calculate_duration_neutral_spread().assign(
            rtn_group     = "duration_neutral",
            date          = lambda x: pd.to_datetime(x.date).dt.date,
            spread        = lambda x: (x.angl_weight * x.angl_rtn) - (x.bnd_rtn *  x.bnd_weight),
            ticker_spread = lambda x: x.angl_sec + "_" + x.bnd_sec)
            [["date", "spread", "ticker_spread", "rtn_group"]])
    
        df_out = (pd.concat([df_dollar_tmp, df_dur_tmp]))
        return df_out
    
    def _get_zscore(self, df: pd.DataFrame, window: int) -> pd.DataFrame: 
        
        df_out = (df.sort_values(
            "date").
            assign(
                roll_mean  = lambda x: x.spread_val.ewm(span = window, adjust = False).mean(),
                roll_std   = lambda x: x.spread_val.ewm(span = window, adjust = False).std(),
                z_score    = lambda x: (x.spread_val - x.roll_mean) / x.roll_std,
                lag_zscore = lambda x: x.z_score.shift()).
            dropna().
            drop(columns = ["roll_mean", "roll_std", "z_score"]))
        
        return df_out
    
    def _generate_signal(self, window: int = 10) -> pd.DataFrame: 
    
        df_tmp = (self.get_yld_spread().query(
            "bnd_ticker != ['AGG', 'LQD']").
            groupby(["spread", "variable"]).
            apply(self._get_zscore, window).
            reset_index(drop = True)
            [["date", "variable", "angl_ticker", "bnd_ticker", "lag_zscore", "spread"]].
            rename(columns = {
                "angl_ticker": "angl_sec",
                "bnd_ticker" : "bnd_sec",
                "spread"     : "ticker_spread"}).
            assign(date = lambda x: pd.to_datetime(x.date)).
            drop(columns = ["angl_sec", "bnd_sec"]))
        
        return df_tmp
    
    def get_zscore_signals(self, verbose: bool = False) -> pd.DataFrame:
        
        file_path = os.path.join(self.consist_path, "ExpandingZScore.parquet")
        try:
            
            if verbose == True: print("Trying to find Expanding Z-Score data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now") 
    
            df_out = (pd.concat([
                self._generate_signal(window = i + 2).assign(window = i + 2) 
                for i in tqdm(range(self.max_window))]).
                assign(date = lambda x: pd.to_datetime(x.date).dt.date))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
        
        return df_out
    
    def _get_expanding_oos_rtn(self, df: pd.DataFrame) -> pd.DataFrame: 
        
        df_tmp = (df.sort_values(
            "date").
            set_index("date"))
        
        df_out = (RollingOLS(
            endog     = df_tmp.spread,
            exog      = sm.add_constant(df_tmp.lag_zscore),
            expanding = True).
            fit().
            params.
            shift().
            rename(columns = {
                "const"     : "lag_alpha",
                "lag_zscore": "lag_beta"}).
            merge(right = df_tmp, how = "inner", on = ["date"]).
            dropna())
        
        return df_out
    
    def get_expanding_ols(self, verbose: bool = False) -> pd.DataFrame: 
        
        file_path = os.path.join(self.consist_path, "ExpandingOLS.parquet")
        try:
            
            if verbose == True: print("Trying to find Expanding OLS data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now") 
        
            df_out = (self.get_zscore_signals().merge(
                right = self._get_rtn(), how = "inner", on = ["date", "ticker_spread"]).
                groupby(["variable", "window", "rtn_group", "ticker_spread"]).
                progress_apply(lambda group: self._get_expanding_oos_rtn(group)).
                drop(columns = ["variable", "window", "rtn_group", "ticker_spread"]).
                reset_index())
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
    
    def get_sharpe(self, verbose: bool = False) -> pd.DataFrame:
        
        file_path = os.path.join(self.consist_path, "SharpeComparison.parquet")
        try:
            
            if verbose == True: print("Trying to find IS & OOS Sharpe data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now") 
        
            df_is = (self.get_zscore_signals().merge(
                right = self._get_rtn(), how = "inner", on = ["date", "ticker_spread"]).
                assign(signal_rtn = lambda x: np.sign(x.lag_zscore) * x.spread)
                [["date", "variable", "window", "rtn_group", "signal_rtn"]].
                groupby(["date", "variable", "window", "rtn_group"]).
                agg("mean").
                reset_index()
                [["variable", "rtn_group", "signal_rtn", "window"]].
                groupby(["variable", "rtn_group", "window"]).
                agg(["mean", "std"])
                ["signal_rtn"].
                reset_index().
                rename(columns = {
                    "mean": "mean_rtn",
                    "std" : "std_rtn"}).
                assign(is_sharpe = lambda x: x.mean_rtn / x.std_rtn * np.sqrt(252)).
                drop(columns = ["mean_rtn", "std_rtn"]))
            
            df_oos = (self.get_expanding_ols().assign(
                signal_rtn = lambda x: np.sign(x.lag_beta * x.lag_zscore) * x.spread)
                [["date", "variable", "rtn_group", "signal_rtn", "window"]].
                groupby(["date", "variable", "rtn_group", "window"]).
                agg("mean").
                reset_index().
                drop(columns = ["date"]).
                groupby(["variable", "rtn_group", "window"]).
                agg(["mean", "std"])
                ["signal_rtn"].
                reset_index().
                rename(columns = {
                    "mean": "mean_rtn",
                    "std" : "std_rtn"}).
                assign(oos_sharpe = lambda x: x.mean_rtn / x.std_rtn * np.sqrt(252)).
                drop(columns = ["mean_rtn", "std_rtn"]))
            
            df_out = (df_oos.merge(
                right = df_is, how = "inner", on = ["variable", "rtn_group", "window"]))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
        
        return df_out
    
    def _get_average_holding(self, df: pd.DataFrame) -> pd.DataFrame: 
        
        df_tmp = (df.sort_values(
            "date").
            assign(
                value   = lambda x: np.sign(x.value),
                lag_val = lambda x: x.value.shift()).
            dropna())
        
        df_trade = (df_tmp.query(
            "value != lag_val")
            [["date"]])
        
        mean_val = (df_trade.assign(
            trade = ["trade{}".format(i + 1) for i in range(len(df_trade))]).
            merge(right = df_tmp, how = "outer", on = ["date"]).
            sort_values("date").
            assign(trade = lambda x: x.trade.ffill())
            [["trade", "date"]].
            groupby("trade").
            agg("count").
            date.
            mean())
        
        return mean_val
    
    def get_holding_period(self, verbose: bool = False) -> pd.DataFrame: 
        
        file_path = os.path.join(self.consist_path, "HoldingDays.parquet")
        try:
            
            if verbose == True: print("Trying to find IS & OOS Holding Periods")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now") 
        
            df_out = (self.get_expanding_ols().assign(
                oos_signal = lambda x: np.sign(x.lag_beta) * x.lag_zscore).
                rename(columns = {"lag_zscore": "is_signal"}).
                query("rtn_group == rtn_group.min()")
                [["variable", "window", "ticker_spread", "date", "is_signal", "oos_signal"]].
                rename(columns = {"variable": "yld_var"}).
                melt(id_vars = ["yld_var", "window", "date", "ticker_spread"]).
                groupby(["yld_var", "window", "variable", "ticker_spread"]).
                progress_apply(lambda group: self._get_average_holding(group)).
                to_frame(name = "holding_period").
                reset_index())
        
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
        
        return df_out

def main() -> None:    

    SignalConsistancy().get_zscore_signals(verbose = True)
    SignalConsistancy().get_expanding_ols(verbose = True)
    SignalConsistancy().get_sharpe(verbose = True)
    SignalConsistancy().get_holding_period(verbose = True)
    
if __name__ == "__main__": main()
