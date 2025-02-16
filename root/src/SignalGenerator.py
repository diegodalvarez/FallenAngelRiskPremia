# -*- coding: utf-8 -*-
"""
Created on Mon Feb 10 23:06:55 2025

@author: Diego
"""

import os
import numpy as np
import pandas as pd
import statsmodels.api as sm

from tqdm import tqdm
from RiskPremia import RiskPremia

class SignalGenerator(RiskPremia):
    
    def __init__(self) -> None:
        
        super().__init__()

    def get_rtn(self) -> pd.DataFrame: 
        
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
        
    def get_signal(self, window: int = 10) -> pd.DataFrame:
        
        df_signal = (self.get_yld_spread().query(
            "bnd_ticker != ['AGG', 'LQD']").
            drop(columns = ["bnd_val", "bnd_ticker", "angl_val", "angl_ticker"]).
            groupby(["variable", "spread"]).
            apply(self._get_zscore, window).
            reset_index(drop = True).
            rename(columns = {"spread": "ticker_spread"}).
            assign(date = lambda x: pd.to_datetime(x.date).dt.date))
        
        df_out = (df_signal.merge(
            right = self.get_rtn(), how = "inner", on = ["date", "ticker_spread"]).
            assign(signal_rtn = lambda x: np.sign(x.lag_zscore) * x.spread))
        
        return df_out