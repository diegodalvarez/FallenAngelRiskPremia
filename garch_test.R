library(rugarch)

# get data
data(sp500ret)

# parameters we want to pass through the GARCH model
spec = ugarchspec(
  distribution.model = "std")

mod = ugarchspec(
  spec,
  data = sp500ret,
  n.ahead = 1,
  n.start = 1000,
  refit.every = 500,
  refit.window = "recursive",
  nsolver = "hybrid",
  fit.control = list(),
  calcaulte.VaR = TRUE,
  VaR.alpha = c(0.01, 0.025, 0.05),
  keep.coef = TRUE,
  report(mod, type = "VaR", VaR.alpha = 0.01, conf.level = 0.05),
  report(mod, type = "fpm"))

data(sp500ret)
spec = ugarchspec(distribution.model = "std")
mod = ugarchroll(spec, data = sp500ret, n.ahead = 1, 
                 n.start = 1000,  refit.every = 500, refit.window = "recursive", 
                 solver = "hybrid", fit.control = list(),
                 calculate.VaR = TRUE, VaR.alpha = c(0.01, 0.025, 0.05),
                 keep.coef = TRUE)
report(mod, type="VaR", VaR.alpha = 0.01, conf.level = 0.95) 
report(mod, type="fpm")

forecast <- mod@forecast$density$Sigma
