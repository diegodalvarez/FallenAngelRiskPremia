# -*- coding: utf-8 -*-
"""
Created on Thu Jan 30 11:27:01 2025

@author: Diego
"""

import os
import pandas as pd
from   DataCollect import DataCollect

class RiskPremia(DataCollect):
    
    def __init__(self) -> None:
        
        super().__init__()
        self.angl_tickers = ["ANGL", "FALN"]
        
        self.prep_path = os.path.join(self.data_path, "premias")
        if os.path.exists(self.prep_path) == False: os.makedirs(self.prep_path)
        
    def calculate_equal_spread(self, verbose: bool = False) -> pd.DataFrame:
        
        file_path = os.path.join(self.prep_path, "EqualReturn.parquet")
        try:
            
            if verbose == True: print("Trying to finding equal return data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now")  
        
            df_px   = self.get_raw_px()
            df_angl = (df_px.query(
                "security == @self.angl_tickers").
                pivot(index = "date", columns = "security", values = "PX").
                pct_change().
                reset_index().
                melt(id_vars = "date").
                dropna().
                rename(columns = {
                    "security": "angl_sec",
                    "value"   : "angl_rtn"}))
            
            df_other = (df_px.query(
                "security != @self.angl_tickers").
                pivot(index = "date", columns = "security", values = "PX").
                pct_change().
                reset_index().
                melt(id_vars = "date").
                dropna().
                rename(columns = {
                    "security": "bnd_sec",
                    "value"   : "bnd_rtn"}))
            
            df_out = (df_other.merge(
                right = df_angl, how = "inner", on = ["date"]).
                assign(spread = lambda x: x.angl_rtn - x.bnd_rtn))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out
    
    def _duration_neutral(self, df: pd.DataFrame) -> pd.DataFrame: 
        
        df_out = (df[
            ["date", "bnd_dur", "angl_dur"]].
            shift().
            set_index("date").
            apply(lambda x: 1 / x).
            dropna().
            assign(cum_vol = lambda x: x.sum(axis = 1)).
            reset_index().
            melt(id_vars = ["date", "cum_vol"]).
            assign(weight = lambda x: x.value / x.cum_vol).
            pivot(index = "date", columns = "variable", values = "weight").
            rename(columns = {
                "angl_dur": "angl_weight",
                "bnd_dur" : "bnd_weight"}))
        
        return df_out
    
    def calculate_duration_neutral_spread(self, verbose: bool = False) -> pd.DataFrame: 
        
        file_path = os.path.join(self.prep_path, "DurNeutralReturn.parquet")
        try:
            
            if verbose == True: print("Trying to find duration neutral return data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now")  
        
            df_rtn = (self.calculate_equal_spread().drop(
                columns = ["spread"]).
                assign(date = lambda x: pd.to_datetime(x.date)))
            
            df_dur = (self.get_bond_data()[
                ["date", "security", "MOD_DUR"]].
                pivot(index = "date", columns = "security", values = "MOD_DUR").
                reset_index().
                melt(id_vars = "date").
                dropna())
            
            df_angl_dur = (df_dur.rename(
                columns = {
                    "security": "angl_sec",
                    "value"   : "angl_dur"}))
            
            df_bnd_dur = (df_dur.rename(
                columns = {
                    "security": "bnd_sec",
                    "value"   : "bnd_dur"}))
            
            df_combined = (df_rtn.merge(
                right = df_bnd_dur, how = "inner", on = ["date", "bnd_sec"]).
                merge(right = df_angl_dur, how = "inner", on = ["date", "angl_sec"]).
                assign(group_var = lambda x: x.angl_sec + "_" + x.bnd_sec))
            
            df_out = (df_combined.groupby(
                "group_var").
                apply(self._duration_neutral).
                reset_index().
                merge(right = df_combined, how = "inner", on = ["date", "group_var"]).
                rename(columns = {"group_var": "spread"}))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
        
        return df_out
    
    def get_yld_spread(self, verbose: bool = False) -> pd.DataFrame: 
        
        file_path = os.path.join(self.prep_path, "YldSpread.parquet")
        try:
            
            if verbose == True: print("Trying to find Yield Data data")
            df_out = pd.read_parquet(path = file_path, engine = "pyarrow")
            if verbose == True: print("Found Data\n")
            
        except: 
        
            if verbose == True: print("Couldn't find data, collecting it now")  
            
            df_longer = (self.get_bond_data().drop(
                columns = ["MOD_DUR"]).
                melt(id_vars = ["date", "security"]))
            
            df_angl = (df_longer.query(
                "security == @self.angl_tickers").
                rename(columns = {
                    "security": "angl_ticker",
                    "value"   : "angl_val"}))
            
            df_bnd = (df_longer.query(
                "security != @self.angl_tickers").
                rename(columns = {
                    "security": "bnd_ticker",
                    "value"   : "bnd_val"}))
            
            df_out = (df_angl.merge(
                right = df_bnd, how = "inner", on = ["date", "variable"]).
                assign(
                    spread     = lambda x: x.angl_ticker + "_" + x.bnd_ticker,
                    spread_val = lambda x: x.angl_val - x.bnd_val))
            
            if verbose == True: print("Saving data\n")
            df_out.to_parquet(path = file_path, engine = "pyarrow")
            
        return df_out

def main() -> None:
        
    RiskPremia().calculate_equal_spread(verbose = True)
    RiskPremia().calculate_duration_neutral_spread(verbose = True)
    RiskPremia().get_yld_spread(verbose = True)
    
#if __name__ == "__main__": main()