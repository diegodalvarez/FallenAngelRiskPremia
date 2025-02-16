# Sytematically Fallen Angel Risk Premia

## Introduction 
Long-Short trading strategy for fallen angels. This model trades the spread between high yield. The in-sample sharpe is around 2 while the out-of-sample sharpe is round 1.3. The results are built using ETFs rather than the underlying bonds. The data was collected from Bloomberg Terminal, and the calculations can be found in this GitHub repo. The technical writeup that goes into the results can be found below. 

## Brief Overview
Fallen Angels outperform their respective bond benchmarks.
![image](https://github.com/user-attachments/assets/cefe56cd-db2f-468e-bfff-4c7895298f23)

Taking the returns differential shows the compensation for buying fallen angels while being short a respective ETF. 
![image](https://github.com/user-attachments/assets/78ba0d3b-45d1-47ca-8573-2693b06d35ba)

The main portfolio of interest is long fallen angels and short high yield. This because fallen angels have high-yield like returns while having better credit quality (by definition) and investment grade bond attributes (usually non-callable and longer maturities). Below are the dollar neutral and duration neutral returns of the portfolio.
![image](https://github.com/user-attachments/assets/00fdf6fe-12f5-4649-9863-8a3cad847e4c)
![image](https://github.com/user-attachments/assets/51eaa624-a9a3-470f-957e-6d8444812461)

Equal weight returns across each pair. 
![image](https://github.com/user-attachments/assets/5e691fa2-a335-44fd-b3c2-851ee06d8211)
![image](https://github.com/user-attachments/assets/f0cb71f0-54a1-49e8-b700-08b571f787d6)



|         | PDF          |
|----------------|---------------------|
| Technical Writeup containing methodology & results | <a href="https://github.com/diegodalvarez/FallenAngelRiskPremia/blob/main/FallenAngelWriteup.pdf">![image](https://github.com/user-attachments/assets/abe487db-026c-4455-b8d8-746108d637e7)
</a> |

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
