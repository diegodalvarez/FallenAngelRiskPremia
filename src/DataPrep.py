# -*- coding: utf-8 -*-
"""
Created on Tue Jul 21 23:59:36 2026

@author: Diego
"""

import os
import numpy as np
import pandas as pd
import statsmodels.api as sm
from   statsmodels.regression.rolling import RollingOLS

from tqdm import tqdm
tqdm.pandas()

class DataPrep:
    
    def __init__(self) -> None: 
        
        self.src_path  = os.getcwd()
        self.repo_path = os.path.abspath(os.path.join(self.src_path, ".."))
        self.data_path = os.path.join(self.repo_path, "data")
        self.raw_path  = os.path.join(self.data_path, "RawData")
        self.prep_path = os.path.join(self.data_path, "PrepData")
        
        if os.path.exists(self.prep_path) == False: 
            os.makedirs(self.prep_path)
            
        self.angel_tickers = ["ANGL", "FALN"]
        
        self.target   = 0.1
        self.lookback = 100
        
    def _vol_target(
            self, 
            df      : pd.DataFrame, 
            target  : float = 0.1, 
            lookback: int   = 100,
            lag     : int   = 1) -> pd.DataFrame: 
        
        df_out = (df.apply(
            lambda x: x * (target / (x.ewm(span = lookback, adjust = False).std().shift(lag) * np.sqrt(252)))))
        
        return df_out
    
    def _melt_fa(self, df: pd.DataFrame, tickers: list) -> pd.DataFrame: 
        
        df_out = (df.
            reset_index().
            melt(
                id_vars    = ["date"] + tickers,
                var_name   = "fi_ticker",
                value_name = "fi_rtn").
            melt(
                id_vars    = ["date", "fi_ticker", "fi_rtn"],
                var_name   = "fa_ticker",
                value_name = "fa_rtn"))
        
        return df_out
    
    def _prep_etf_rtn(self) -> pd.DataFrame: 
        
        etf_path = os.path.join(self.raw_path, "PX.parquet")
        df_rtn   = (pd.read_parquet(
            path = etf_path, engine = "pyarrow").
            loc[lambda x: x.Price == "Adj Close"].
            pivot(index = "date", columns = "ticker", values = "value").
            pct_change())
        
        df_perf = (
            df_rtn
            .pipe(self._vol_target, self.target, self.lookback, 0)
            .pipe(self._melt_fa, self.angel_tickers)
            .dropna()
            .assign(hedge = "perfect"))
        
        df_lagged = (
            df_rtn
            .pipe(self._vol_target, self.target, self.lookback, 1)
            .pipe(self._melt_fa, self.angel_tickers)
            .dropna()
            .assign(hedge = "lagged"))
        
        df_raw = (df_rtn.pipe(
            self._melt_fa, self.angel_tickers).
            dropna().
            assign(hedge = "no"))
        
        df_out = (pd.concat([
            df_lagged, df_perf, df_raw]).
            assign(asset = "etf"))
        
        return df_out
    
        
    def _prep_index_rtn(self) -> pd.DataFrame: 
        
        idx_path    = os.path.join(self.raw_path, "IndexTotalReturn.parquet")
        idx_tickers = ["H0CF", "LBUSTRUU", "LF98TRUU"]
        slice_year  = 2000
        
        df_rtn = (pd.read_parquet(
            path = idx_path, engine = "pyarrow").
            assign(security = lambda x: x.security.str.split(" ").str[0]).
            loc[lambda x: x.security.isin(idx_tickers)].
            assign(year = lambda x: x.date.dt.year).
            loc[lambda x: x.year >= slice_year].
            drop(columns = ["year", "period_days"]).
            pivot(index = "date", columns = "security", values = "rtn").
            dropna())
        
        df_perf = (
            df_rtn
            .pipe(self._vol_target, self.target, self.lookback, 0)
            .pipe(self._melt_fa, ["H0CF"])
            .dropna()
            .assign(hedge = "perfect"))
        
        df_lagged = (
            df_rtn
            .pipe(self._vol_target, self.target, self.lookback, 0)
            .pipe(self._melt_fa, ["H0CF"])
            .dropna()
            .assign(hedge = "lagged"))
        
        df_raw = (df_rtn.pipe(
            self._melt_fa, ["H0CF"]).
            assign(hedge = "no"))
        
        df_out = (pd.concat([
            df_perf, df_lagged, df_raw]).
            assign(asset = "index"))
        
        return df_out
    
    def prep_rtn(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting Prepped Returns")
        out_path = os.path.join(self.prep_path, "Rtn.parquet")
        
        if os.path.exists(out_path) == True:
            if verbose: print("Already Have Data\n")
            return None
        
        df_out = (pd.concat([
            self._prep_etf_rtn(),
            self._prep_index_rtn()]))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path)
        
    def _get_rolling_alpha(self, df: pd.DataFrame, window: int = 30) -> pd.DataFrame: 
    
        df_out = (RollingOLS(
            endog  = df.fa_rtn,
            exog   = sm.add_constant(df.fi_rtn),
            window = window)
            .fit()
            .params
            .assign(window = window)
            .merge(right = df, how = "inner", on = ["date"]))
        
        return df_out
        
    def get_alpha(self, window: int = 30, verbose: bool = True) -> pd.DataFrame: 
        
        if verbose: 
            print("Getting the Alpha of Returns Spread")
        
        out_path = os.path.join(self.prep_path, "RtnAlpha.parquet")
        in_path  = os.path.join(self.prep_path, "Rtn.parquet")
        
        if os.path.exists(out_path): 
            if verbose: print("Saving data\n")
            return None
        
        df_alpha = (pd
            .read_parquet(path = in_path, engine = "pyarrow")
            .loc[lambda x: (x.asset == "etf")]
            .drop(columns = ["hedge", "asset"])
            .set_index("date")
            .assign(name = lambda x: x.fi_ticker + "-" + x.fa_ticker)
            .groupby("name")
            .progress_apply(lambda group: self._get_rolling_alpha(group))
            .reset_index())
        
        if verbose: print("\nSaving data\n")
        df_alpha.to_parquet(path = out_path, engine = "pyarrow")
        
    def get_yield_spread(self, verbose: bool = True) -> pd.DataFrame: 
        
        if verbose: 
            print("Getting Yield Spread data")
        
        in_path  = os.path.join(self.raw_path, "BondFundamentalExtra.parquet")
        out_path = os.path.join(self.prep_path, "YldSprd.parquet") 
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        df_spread = (pd
                .read_parquet(path = in_path, engine = "pyarrow")
                .assign(security = lambda x: x.security.str.split(" ").str[0])
                .pivot(index = ["date", "variable"], columns = "security", values = "value")
                .apply(lambda x: np.log(x))
                .reset_index()
                .melt(id_vars = ["date", "variable", "ANGL"])
                .dropna()
                .assign(spread = lambda x: x.ANGL - x.value))
        
        if verbose: print("Saving data\n")
        df_spread.to_parquet(path = out_path, engine = "pyarrow")
        
    def _get_zscore(self, df: pd.DataFrame, window: int) -> pd.DataFrame: 
        
        df_out = (df
                .assign(
                    spread_diff = lambda x: x.spread.diff(),
                    z_score     = lambda x: 
                        (x.spread_diff - x.spread_diff.ewm(span = window, adjust = False).mean()) /
                        x.spread_diff.ewm(span = window, adjust = False).std(),
                    lag_zscore = lambda x: x.z_score.shift()))
            
        return df_out
        
    def get_exogenous_variables(self, window: int = 30, verbose: bool = True) -> None: 
        
        if verbose: print("Getting Exogenous Data")
        
        in_path  = os.path.join(self.raw_path, "ETFData.parquet")
        out_path = os.path.join(self.prep_path, "ExogData.parquet")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        df_out  = (pd
                .read_parquet(path = in_path)
                .assign(security = lambda x: x.security.str.split(" ").str[0])
                .pivot(index = ["date", "variable"], columns = "security", values = "value")
                .reset_index()
                .melt(id_vars = ["date", "variable", "HYG", "JNK"], var_name = "ig_ticker", value_name = "ig_val")
                .melt(id_vars = ["date", "variable", "ig_ticker", "ig_val"], var_name = "hy_ticker", value_name = "hy_val")
                .dropna()
                .assign(
                    spread = lambda x: x.hy_val - x.ig_val,
                    name   = lambda x: x.hy_ticker + "-" + x.ig_ticker + "-" + x.variable)
                .set_index("date")
                .groupby("name")
                .progress_apply(lambda group: self._get_zscore(group, window))
                .reset_index()
                .drop(columns = ["name"]))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
    def _get_zscore(self, df: pd.DataFrame, window: int) -> pd.DataFrame: 
        
        df_out = (df
                .sort_values("date")
                .assign(
                    spread_diff = lambda x: x.spread.diff(),
                    z_score     = lambda x: 
                        (x.spread_diff - x.spread_diff.ewm(span = window, adjust = False).mean()) /
                        x.spread_diff.ewm(span = window, adjust = False).std()))
            
        return df_out
        
    def _get_exog(self, window: int = 30, verbose: bool = True) -> None: 
        
        if verbose: print("Getting Exogenous Data")
        
        in_path  = os.path.join(self.data_path, "RawData", "ETFData.parquet")
        out_path = os.path.join(self.prep_path, "ExogData.parquet")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        df_out = (pd
            .read_parquet(path = in_path, engine = "pyarrow")
            .assign(security = lambda x: x.security.str.split(" ").str[0])
            .pivot(index = ["date", "variable"], columns = "security", values = "value")
            .reset_index()
            .melt(
                id_vars    = ["date", "variable", "HYG", "JNK"], 
                var_name   = "ig_ticker", 
                value_name = "ig_val")
            .melt(
                id_vars    = ["date", "variable", "ig_ticker", "ig_val"],
                var_name   = "hy_ticker",
                value_name = "hy_val")
            .dropna()
            .assign(
                spread = lambda x: x.ig_val - x.hy_val,
                name   = lambda x: x.variable + " " + x.hy_ticker + " " + x.ig_ticker)
            .groupby("name")
            .apply(self._get_zscore, window)
            .reset_index()
            .drop(columns = ["level_1"]))
        
        if verbose: print("Saving data\n")
        df_out.to_parquet(path = out_path, engine = "pyarrow")
        
def main() -> None: 
        
    data_prep = DataPrep()
    data_prep.prep_rtn()
    data_prep.get_alpha()
    data_prep.get_yield_spread()
    data_prep.get_exogenous_variables()
    
if __name__ == "__main__": main()