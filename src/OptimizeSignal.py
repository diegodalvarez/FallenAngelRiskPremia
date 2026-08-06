# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 12:39:52 2026

@author: Diego
"""

import os
import numpy as np
import pandas as pd

from tqdm import tqdm

class SignalOptimizer:
    
    def __init__(self) -> None: 
        
        self.src_path  = os.getcwd()
        self.repo_path = os.path.abspath(os.path.join(self.src_path, ".."))
        self.data_path = os.path.join(self.repo_path, "data")
        self.sig_path  = os.path.join(self.data_path, "Signal")
        self.opt_path  = os.path.join(self.data_path, "OptimizedSignal")
        
        if not os.path.exists(self.opt_path):
            os.makedirs(self.opt_path)
            
        self.q = 10
            
    def _insample_optimize(self, df: pd.DataFrame, q: int = 10) -> pd.DataFrame: 
        
        df_decile = (df
                .sort_index()
                .assign(
                    decile     = lambda x: pd.qcut(x = x.signal, q = q, labels = [i + 1 for i in range(q)]),
                    lag_decile = lambda x: x.decile.shift())
                .reset_index())
        
        df_sharpe = (df_decile
                [["lag_decile", "spread_rtn"]]
                .reset_index(drop = True)
                .groupby("lag_decile")
                .agg(lambda x: x.mean() / x.std() * np.sqrt(252)))
        
        df_tmp_decile = (df_sharpe
                .reset_index()
                .loc[lambda x: x.lag_decile.isin([1,2,9,10])]
                .assign(group = lambda x: np.where(x.lag_decile <= 2, "lgroup", "ugroup")))
        
        df_out = (df_tmp_decile
                .drop(columns = ["lag_decile"])
                .groupby("group")
                .agg("prod")
                .assign(signal_scaler = lambda x: np.where(x.spread_rtn > 0, 1, 0))
                .drop(columns = ["spread_rtn"])
                .merge(right = df_tmp_decile, how = "outer", on = ["group"])
                .rename(columns = {"spread_rtn": "sharpe"})
                .merge(right = df_decile, how = "outer", on = ["lag_decile"]))
        
        return df_out
    
    def _outsample_optimize(
        self,
        df     : pd.DataFrame,
        q      : int,
        min_obs: int = 5) -> pd.DataFrame:
    
        df = df.sort_index()
    
        opt_dates = (
            df
            .index
            .to_series()
            .groupby(pd.Grouper(freq="W-FRI"))
            .max()
            .dropna()
            .to_list())[min_obs:]
    
        df_out = []
    
        for opt_date in tqdm(opt_dates):
        
            # -------------------------
            # In-sample
            # -------------------------
    
            df_is = df.loc[:opt_date, ["signal", "spread_rtn"]].copy()
    
            # qcut once
            df_is["decile"], bins = pd.qcut(
                df_is["signal"],
                q=q,
                labels=False,
                retbins=True
            )
            
            df_is["decile"] += 1
    
    
            # Lag the decile
            df_is["lag_decile"] = df_is["decile"].shift()
    
            # -------------------------
            # Sharpe by decile
            # -------------------------
    
            df_sharpe = (
                df_is
                .dropna(subset=["lag_decile"])
                .groupby("lag_decile")["spread_rtn"]
                .agg(["mean", "std"])
                .assign(
                    sharpe=lambda x:
                        x["mean"] / x["std"] * np.sqrt(252)
                )
                .reset_index()
                [["lag_decile", "sharpe"]]
            )
    
            # Only extreme deciles
            df_tmp_decile = (
                df_sharpe
                .loc[lambda x: x["lag_decile"].isin([1, 2, 9, 10])]
                .assign(
                    group=lambda x: np.where(
                        x["lag_decile"] <= 2,
                        "lgroup",
                        "ugroup"
                    )
                )
            )
    
            # -------------------------
            # Determine scaler
            # -------------------------
    
            df_signal_scaler = (
                df_tmp_decile
                .groupby("group")["sharpe"]
                .prod()
                .gt(0)
                .astype(int)
                .rename("signal_scaler")
            )
            
            # -------------------------
            # Out-of-sample
            # -------------------------
    
            df_oos = df.loc[
                (df.index > opt_date) &
                (df.index <= opt_date + pd.Timedelta(days=7))
            ].copy()
    
            # Apply IS bins to OOS observations
            df_oos["decile"] = (
                pd.cut(
                    df_oos["signal"],
                    bins=bins,
                    labels=False,
                    include_lowest=True
                ) + 1
            )
    
            # Lag decile exactly as before
            df_oos["lag_decile"] = df_oos["decile"].shift()
            
            df_oos = df_oos.reset_index().merge(
                df_tmp_decile[
                    ["lag_decile", "sharpe", "group"]
                ],
                how="left",
                on="lag_decile"
            )
    
            # Map lgroup / ugroup to OOS deciles
            df_oos["group"] = np.select(
                [
                    df_oos["lag_decile"].isin([1, 2]),
                    df_oos["lag_decile"].isin([9, 10])
                ],
                [
                    "lgroup",
                    "ugroup"
                ],
                default=None
            )
    
            # Map scaler
            df_oos["signal_scaler"] = (
                df_oos["group"]
                .map(df_signal_scaler)
            )
    
            df_oos["opt_date"] = opt_date
    
            df_out.append(df_oos)
    
        return pd.concat(df_out)
            
    def _optimize_signal(self, df: pd.DataFrame, q: int = 10, verbose: bool = True) -> pd.DataFrame: 
        
        if verbose: print("Working on {}".format(df.name))
        
        df_is = (self
                 ._insample_optimize(df, q)
                 .assign(
                     opt_date     = np.nan,
                     sample_group = "in_sample"))
        
        df_os = (self
                 ._outsample_optimize(df, q)
                 .assign(sample_group = "out_sample"))
        
        df_out = pd.concat([df_is, df_os])
        if verbose: print("\n")
        return df_out
    
    def _get_combined_signal_rtn(self) -> pd.DataFrame: 
        
        rtn_path = os.path.join(self.sig_path, "MeanReversionRtn.parquet")
        yld_path = os.path.join(self.sig_path, "YieldReversion.parquet")
        
        df_rtn_mr = (pd
            .read_parquet(path = rtn_path, engine = "pyarrow")
            .drop(columns = ["asset"]))
        
        df_yld_mr = (pd
            .read_parquet(path = yld_path, engine = "pyarrow"))
        
        df_rtn_tmp = (df_rtn_mr
            .assign(signal_name = lambda x: x.name)
            [["date", "signal_name", "signal"]])
        
        df_yld_tmp = (df_yld_mr
            .assign(signal_name = lambda x: "ANGL " + x.security + " " + x.variable)
            [["date", "signal", "signal_name"]])
        
        df_rtn_keep = (df_rtn_mr
            .assign(signal_name = lambda x: x.fa_ticker + " " + x.fi_ticker + " rtn")
            .loc[lambda x: x.hedge == "perfect"]
            [["date", "signal_name", "signal"]])
        
        df_signal_raw = (pd
            .concat([df_rtn_keep, df_yld_tmp]))
        
        df_signal = (df_signal_raw
            [["signal_name"]]
            .drop_duplicates()
            .assign(
                str_split    = lambda x: x.signal_name.str.split(" "),
                spread_name  = lambda x: x.str_split.str[0] + " " + x.str_split.str[1],
                signal_group = lambda x: x.str_split.str[2])
            .drop(columns = ["str_split"])
            .merge(right = df_signal_raw, how = "inner", on = ["signal_name"]))
        
        return df_signal
    
    def optimize_signal(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting Optimized Mean Reversion Signal")
        
        files    = ["MeanReversionRtn.parquet", "YieldReversion.parquet"]
        out_path = os.path.join(self.opt_path, "MeanReversionOptSignal.parquet")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        rtn_path = os.path.join(self.data_path, "PrepData", "Rtn.parquet")
        
        df_rtn = (pd
            .read_parquet(path = rtn_path, engine = "pyarrow")
            .loc[lambda x: (x.asset == "etf") & (x.hedge == "perfect") & (x.fi_ticker != "SJNK")]
            .assign(
                spread_rtn  = lambda x: x.fa_rtn - x.fi_rtn,
                spread_name = lambda x: x.fa_ticker + " " + x.fi_ticker)
            [["date", "hedge", "spread_rtn", "spread_name"]])
        
        df_signal = self._get_combined_signal_rtn()
        
        df_combined = (df_signal
            .merge(right = df_rtn, how = "inner", on = ["date", "spread_name"])
            .dropna()
            .set_index("date")
            .groupby("signal_name")
            .apply(self._optimize_signal)
            .reset_index()
            .drop(columns = ["level_1"]))
    
        if verbose: print("Saving data\n")
        df_combined.to_parquet(path = out_path, engine = "pyarrow")
    
def main() -> None: 
    
    signal_optimizer = SignalOptimizer()
    signal_optimizer.optimize_signal()
    
if __name__ == "__main__": main()