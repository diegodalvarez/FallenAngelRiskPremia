# -*- coding: utf-8 -*-
"""
Created on Mon Aug  3 13:25:49 2026

@author: Diego
"""

import os
import pickle
import pandas as pd
import statsmodels.api as sm

class FactorAnalysis:
    
    def __init__(self) -> None: 
        
        self.src_path  = os.getcwd()
        self.repo_path = os.path.abspath(os.path.join(self.src_path, ".."))
        self.data_path = os.path.join(self.repo_path, "data")
        self.fact_path = os.path.join(self.data_path, "FactorAnalysis")
        
        if not os.path.exists(self.fact_path):
            os.makedirs(self.fact_path)
        
    def mean_reversion_analysis(self, verbose: bool = True) -> None: 
        
        if verbose: print("Mean Reversion Factor Analysis")
        
        in_path  = os.path.join(self.data_path, "Signal", "MeanReversionRtn.parquet")
        out_path = os.path.join(self.fact_path, "MeanReversionSignals.pkl")
        
        if os.path.exists(out_path):
            if verbose: print("Already have data\n")
            return None
        
        df_prep = (pd
                .read_parquet(path = in_path, engine = "pyarrow")
                .drop(columns = ["fi_ticker", "fi_rtn", "fa_ticker", "fa_rtn", "hedge", "asset"])
                .melt(id_vars = ["date", "name", "spread_rtn"], var_name = "signal_type")
                .assign(group_var = lambda x: x.name + " " + x.signal_type)
                .set_index("date"))
        
        groups = df_prep.group_var.drop_duplicates().sort_values().to_list()
        models = {}
        
        for group in groups: 
            
            df_input = (df_prep
                    .loc[lambda x: x.group_var == group]
                    [["spread_rtn", "value"]]
                    .dropna())
            
            model = (sm
                    .OLS(
                        endog = df_input.spread_rtn, 
                        exog  = sm.add_constant(df_input.value))
                    .fit())
            
            models[group] = model
            
        if verbose: print("Saving models\n")
        with open(out_path, "wb") as f:
            pickle.dump(models, f, protocol=pickle.HIGHEST_PROTOCOL)
            
    def get_ols_params(self, models: dict) -> pd.DataFrame:
        
        df_params_list = []
        for key in models.keys():
        
            tmp_model = models[key]
            df_param  = tmp_model.params.to_frame(name = "param_val").reset_index()
            df_pvalue = tmp_model.pvalues.to_frame(name = "pvalue").reset_index()
            df_tvalue = tmp_model.tvalues.to_frame(name = "tvalue").reset_index()
        
            df_add = (df_param
                .merge(right = df_pvalue, how = "inner", on = ["index"])
                .merge(right = df_tvalue, how = "inner", on = ["index"])
                .rename(columns = {"index": "param_name"})
                .assign(
                    r2        = tmp_model.rsquared, 
                    group_var = key))
        
            df_params_list.append(df_add)
        
        df_params = pd.concat(df_params_list)
        return df_params

def main() -> None: 
        
    factor = FactorAnalysis()
    factor.mean_reversion_analysis()
    
if __name__ == "__main__": main()