require(R6)
require(arrow)
require(readxl)
require(tidyverse)

DataCollect <- R6Class(
  "DataCollect",
  
  public = list(
    
    tickers       = NULL,
    root_path     = NULL,
    repo_path     = NULL,
    note_path     = NULL,
    data_path     = NULL,
    raw_path      = NULL,
    bbg_px_path   = NULL,
    bbg_bond_path = NULL,
    
    initialize = function(){
      
      if ("rstudioapi" %in% installed.packages() && rstudioapi::isAvailable()) {
        wd <- dirname(rstudioapi::getActiveDocumentContext()$path)
      } else {
        wd <- getwd()
      }
      
      setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
      
      self$tickers <- c("ANGL", "FALN", "JNK", "HYG")
      
      self$root_path     <- dirname(getwd())
      self$repo_path     <- dirname(self$root_path)
      self$note_path     <- file.path(self$root_path, "notebooks")
      self$data_path     <- file.path(self$repo_path, "data")
      self$raw_path      <- file.path(self$data_path, "RawData")
      
      
      self$bbg_px_path   <- "/Users/diegoalvarez/Desktop/BBGData/data"
      if (file.exists(self$bbg_px_path) == FALSE){
        self$bbg_px_path  <- "C:\\Users\\Diego\\Desktop\\app_prod\\BBGData\\data"
        }
      
      self$bbg_bond_path  <- "/Users/diegoalvarez/Desktop/BBGData/ETFIndices/BondPricing"
      if (file.exists(self$bbg_bond_path) == FALSE){
        self$bbg_bond_path <- "C:\\Users\\Diego\\Desktop\\app_prod\\BBGData\\ETFIndices\\BondPricing"
        }
      
      if (!dir.exists(self$note_path)){dir.create(self$note_path, recursive = TRUE)}
      if (!dir.exists(self$data_path)){dir.create(self$data_path, recursive = TRUE)}
      if (!dir.exists(self$raw_path)) {dir.create(self$raw_path, recursive = TRUE)}
      
    },
    
    get_px = function(){
      
      paths <- lapply(self$tickers, function(path) file.path(self$bbg_px_path, paste0(path, ".parquet")))
      
      df_tmp <- do.call(rbind, lapply(paths, function(p) read_parquet(p))) %>% 
        select(date, security, "PX_last" = value) %>% 
        mutate(date = as.Date(date))
      
      return(df_tmp)
      
    },
    
    get_bond_attributes = function(){
      
      paths <- lapply(self$tickers, function(path) file.path(self$bbg_bond_path, paste0(path, ".parquet")))
      keep_cols <- c("date", "security", "variable", "value")
      
      df_tmp <- do.call(rbind, lapply(paths, function(p) read_parquet(p, col_select = keep_cols))) %>% 
        pivot_wider(names_from = variable, values_from = value) %>% 
        mutate(date = as.Date(date)) %>% 
        rename(
          "yas_yld"    = "YAS_BOND_YLD",
          "mod_dur"    = "YAS_MOD_DUR",
          "yas_spread" = "YAS_YLD_SPREAD",
          "gspread"    = "YAS_ISPREAD_TO_GOVT",
          "wac"        = "AVERAGE_WEIGHTED_COUPON") 
      
      return(df_tmp)
    },
    
    get_data = function(verbose = FALSE){
      
      file_path = file.path(self$raw_path, "RawPrices.parquet")
      if (file.exists(file_path) == TRUE){
        
        if (verbose == TRUE){print("Found ETF Data")}
        df_out <- read_parquet(file = file_path)
        
      }
      else{
        
        if (verbose == TRUE){print("Getting ETF Data")}
        
        df_px         <- self$get_px()
        df_attributes <- self$get_bond_attributes()
        read_path     <- file.path(dirname(self$bbg_px_path), "root/BBGTickers.xlsx")
        
        df_combined <- df_px %>% 
          inner_join(df_attributes, by = c("date", "security"))
        
        df_out  <- read_excel(path = read_path) %>% 
          select(security = Security, desc = Description) %>% 
          inner_join(df_combined, by = "security") %>% 
          group_by(security) %>% 
          arrange(date) %>% 
          mutate(
            security = str_split(string = security, pattern = " ")[[1]][1],
            PX_diff = PX_last - lag(PX_last),
            PX_rtn = PX_diff / lag(PX_last),
            PX_bps = PX_diff / mod_dur) %>% 
          ungroup()
        
        if (verbose == TRUE){print("Saving data\n")}
        write_parquet(df_out, file_path)
        
        }
    
        return(df_out)
    }
    
  ))

df = DataCollect$new()$get_data(verbose = TRUE)
