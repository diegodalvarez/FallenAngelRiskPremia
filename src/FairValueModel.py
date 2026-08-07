# -*- coding: utf-8 -*-
"""
Created on Thu Aug  6 00:52:31 2026

@author: Diego
"""

import os
import pickle
import pandas as pd
import statsmodels.api as sm
from   sklearn.ensemble import RandomForestRegressor

class FairValue:
    
    def __init__(self) -> None: 
        
        self.src_path   = os.getcwd()
        self.repo_path  = os.path.abspath(os.path.join(self.src_path, ".."))
        self.data_path  = os.path.join(self.repo_path, "data")
        self.model_path = os.path.join(self.data_path, "Models")
        
        if not os.path.exists(self.model_path):
            os.makedirs(self.model_path)
        
        self.slice_year = 2020
        
    def _prep_data(self) -> pd.DataFrame: 
        
        exog_path = os.path.join(self.data_path, "PrepData", "ExogData.parquet")
        rtn_path  = os.path.join(self.data_path, "PrepData", "Rtn.parquet")
        
        df_exog = pd.read_parquet(path = exog_path, engine = "pyarrow")
        df_rtn  = pd.read_parquet(path = rtn_path, engine = "pyarrow")
        
        df_spread = (df_rtn
                .loc[lambda x: 
                     (x.asset == "etf") & 
                     (x.fa_ticker == "ANGL") & 
                     (x.hedge == "perfect") & 
                     (x.fi_ticker == "HYG")]
                .assign(spread = lambda x: 0.5 *  (x.fa_rtn - x.fi_rtn))
                [["date", "spread"]])
            
        df_exog_prep = (df_exog
                .assign(name = lambda x: x.variable + " " + x.hy_ticker + " " + x.ig_ticker)
                .pivot(index = "date", columns = "name", values = "z_score")
                .bfill())
        
        df_combined = (df_spread
                .merge(right = df_exog_prep, how = "inner", on = ["date"])
                .set_index("date"))
        
        return df_combined
        
    def get_linear_full_sample_model(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting Full Sample Linear Model")
        
        out_path = os.path.join(self.model_path, "FullSampleLinearModel.pkl")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        
        df_data = self._prep_data()
        model   = (sm
                .OLS(
                    endog = df_data.spread,
                    exog  = sm.add_constant(df_data.drop(columns = ["spread"])))
                .fit())
        
        if verbose: print("Saving data\n")
        
        with open(out_path, "wb") as f:
            pickle.dump(model, f)
        
    def get_in_sample_linear_model(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting In-Sample Linear Model")
        
        out_path = os.path.join(self.model_path, "InSampleLinearModel.pkl")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        df_data = (self._prep_data()
                   .reset_index()
                   .assign(year = lambda x: x.date.dt.year)
                   .loc[lambda x: x.year <= self.slice_year]
                   .drop(columns = ["year"])
                   .set_index("date"))
        
        model = (sm
                .OLS(
                    endog = df_data.spread,
                    exog  = sm.add_constant(df_data.drop(columns = ["spread"])))
                .fit())

        if verbose: print("Saving data\n")
        
        with open(out_path, "wb") as f:
            pickle.dump(model, f)
            
    def get_in_sample_rf_model(self, verbose: bool = True) -> None: 
        
        if verbose: print("Getting In-Sample Random Forest Model")
        
        out_path = os.path.join(self.model_path, "InSampleRandomForest.pkl")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        df_data = (self._prep_data()
                   .reset_index()
                   .assign(year = lambda x: x.date.dt.year)
                   .loc[lambda x: x.year <= self.slice_year]
                   .drop(columns = ["year"])
                   .set_index("date"))
        
        y, X = df_data.spread, df_data.drop(columns = ["spread"])
        
        rf = RandomForestRegressor(
            n_estimators     = 1_000,
            max_depth        = 5,
            min_samples_leaf = 20,
            max_features     = 0.7,
            random_state     = 42,
            n_jobs           = -1)
        
        rf.fit(X, y)
        
        if verbose: print("Saving data\n")
        with open(out_path, "wb") as f: pickle.dump(rf, f)

def main() -> None:
        
    fv_model = FairValue()
    fv_model.get_linear_full_sample_model()
    fv_model.get_in_sample_linear_model()
    fv_model.get_in_sample_rf_model()
    
if __name__ == "__main__": main()