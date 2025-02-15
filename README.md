# Not Intended as Investment Advice
# Fallen Angel Risk Premia

## Introduction 
This is a sample portfolio strategy that looks at incorporating fallen angels within a market neutral long short portfolio. The inspiration from this work came from a series of articles that were posted Lombard Odier Investment Management's team regarding adding fallen angel bond exposure. Since I personally believe that alpha streams stemming contrarian positions can provide superior returns, due to their dislcoation I've found some success when mining for this alpha. 

This strategy is constructed using a long short portfolio, and keeping an active long position on fallen angels. I've allowed the flexibility to add in and decrease other fixed income betas by choice of the short leg, whether it be Treasuries to capture the most premia or high yield debt to capture purely the fallen angels. I've personally opted for a GDP-based markov regime switching strategy to pick risk-on and risk-off scenarios to pick up more fixed income risk premia. 

The original LOIM articles can be found here
1. [Why are fallen angels the pick of high yield?](https://am.lombardodier.com/gb/en/contents/news/investment-viewpoints/2023/may/1882-NA-PROD-NA-high-yield.html)
2. [Actively exploiting potential in fallen angels](https://am.lombardodier.com/contents/news/investment-viewpoints/2023/may/1882-NA-PROD-NA-exploiting-pot.html)
3. [Fallen angels: beyond the downgrade](https://am.lombardodier.com/contents/news/investment-viewpoints/2023/april/1882-NA-PROD-NA-beyond-downgrade.html)

The thesis behind the strategy comes from the following
1. Although Catching knives is a common colloquim within markets, where you should not buy a security as it decreases in value since there is a risk it will continue to decrease. I believe that the opportunity exists since fixed income securities inherently have less risk than their equity counterparts. That is because fixed income investors have claims to company's assets (assuminng no unsecured financing) and claims to cashflows before equity investors.
2. Selloffs are likely to occur from mandated investors. Since fixed income securities provide a steady stream of income to a variety of LDI (liability-driven investors) such as pensions, insurance, and wealth funds hold them to do their ALM (asset-liability management). Many of these investors have investment-grade mandates and thus are forced to sell fixed income securities that get downgraded.
3. Credit rating changes in my opinion are lagging indicators. Although credit ratings are meant to analyze future cash flows, a prompt in ratings change will be "observed". It is likely that there is signficant time between when a credit rating change is proposed and when it is implemented, and thus the market price has likely alread priced that in.

## Codebase & Methodology
The majority of this codebase is written in R. There are a couple of small caveats that come Python since my bacground is in python programming. I've wokred on similar long short projects primarily in python [LSPair](https://github.com/diegodalvarez/LSPair) and LSPort (yet to be public). As I progress with this project I'll continue to shift the codebase closer to R since it is originally what I started with. 

When creating this model I first started with fixed income ETFs and 50/50 long short weights. As I progress I'll incorporate beta hedging to be market neutral and more fundamental bottom-up techniques. Unlike Lombard Odier Investment Management, I plan to make the whole model systematic.

## Repo layout
```bash
    FallenAngelRiskPremia
      └───src
          │   YFCollectData.R
          │   rollingOLSParams.R
      └───background
          │   edaOLS.R
          │   AlphaAnalysis.R
      └───strats
          │   fiftyfifty.R
          │   betaNeutral.R
          │   MarkovRegime.R
          │   PositionSizingBetaHedge.R
          │   PositionSizingBetaHedgeGraphs.R
      └───data
          │   etf.parquet
          │   rollingOLSparams.parquet
          │   etf.parquet
```
data files:
* ```etf.parquet```: All of the ETF data
* ```rollingOLSparams.parquet```: OLS Rolling Parameters Data
* ```BetaNeutralWeighting.parquet```: Beta Neutral Weighting Scheme
* ```backtest.parquet```: Holding backtest information for position level information accounting for share price and cash

background files:
* ```edaOLS.R```: Rolling OLS analysis 
* ```AlphaAnalysis.R```: Background on rolling alphas of the from the OLS

src files:
* ```YFCollectData.R```: Collects data from yahoo finance using specifically ETFs and saves etf.parquet
* ```rollingOLSParams.R```: Does Rolling OLS regression and saves parameters rollingOLSParams.parquet

strats files:
* ```fiftyfifty.R```: L/S with 50/50 Spread
* ```betaNeutral.R```: L/S Beta Neutral Weigthing applied back to the signal
* ```PositionSizingBetaHedge.R```: L/S Beta Neutral Weighting but accounting for share price and allocation
* ```PositionSizingBetaHedgeGraphs.R```: Graphs for L/S Beta Neutral Weighting accounting for share price

# Todo
1. Transaction Cost & Slippage
2. Seperating all risk-premias and regressing their returns on fixed income benchmarks to find loadings
3. Portfolio Optimization
4. Portfolio Sizing based on expected z-score
5. Signal Processing enhancements
6. Machine learning enhancements

# Further Reading
1. Jason Thomas, The Credit Risk Premium and Return Predictability in High Yield Bonds [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2037495)
2. Christian Speck, Corporate Bond Risk Premia [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2235168)
3. Asvunant & Richardson, The credit risk premia [here](https://www.aqr.com/-/media/AQR/Documents/Journal-Articles/JFI_Winter_2017_AQR_The-Credit-Risk-Premium.pdf?sc_lang=en)
4. Ng & Phelps, Capturing Credit spread premium [here](https://www.scribd.com/document/223427181/Ng-Phelps-2010-Barclays-Capturing-Credit-Spread-Premium)
5. Altman, Credit Risk Measurement and Management: The Ironic Challenge in the Next Decade [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1296394)
6. Geisecke, Longstaff, Schaefer, Strebulaev, Corporate Bond Default Risk: A 150-Year Perspective [here](https://www.nber.org/papers/w15848)
7. Houweling, Mentink, and Vorst [here](Comparing Possible Proxies of Corporate Bond Liquidity)
8. Bongaerts, De Jong, and Driessen, An Asset Pricing Approach to Liquidity Effects in Corporate Bond Markets [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1762564)
9. Elton, Gruber, Agrawal, and Mann, Factors Affecting the Valuation of Corporate Bonds [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=307139)
10. Houweling, On the Performance of Fixed Income Exchange Traded Funds [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1840559)
11. Haesen and Houweling, On the Nature and Predictability of Corporate Bond Returns [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1914680)
12. Houweling and van Zundert Factor Investing in the Corporate Bond Market [here](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2516322)
