# Exploratory Analysis (edaOLS.R)
First begin by examining the returns distribution of each ETF

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/04dcfa25-a34d-48b5-a831-674f746530dd)

And their cumulative returns. It's evident that the ANGL ETF picks up a considerable amount of extra return. Although its a bit speculative to assume, these returns streams are for the most part driven by rates but and their
credit risk premias, since there is a considerable amount of overlapping of securities and returns factors from the fallen angels ETF within the other we could surmise that there are returns (preferably alpha) that can be 
extracted.

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/8696178d-5f00-43fc-b4ce-56a85dd21c9d)

Full sample OLS regressions show that there are possible hedging candidates
![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/c72d7b35-d46c-4916-a3ee-438546982a9a)

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/04d4036c-845b-4596-9344-276e70ac53be)

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/c2204fb2-7bc6-475b-b0c2-d62353fa5842)

# Rolling Alpha and Beta Analysis
Using 30d rolling regression we can examine which betas fit the best. The method determined for beta selection is definitely overfitted (lookahead bias). We begin by using full-sample weekly returns OLS and then using the
four largest betas as hedging candidates.

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/b47e4df0-d2ef-4734-9783-965a817f2e5a)

We can proxy our returns via alpha (assuming perfectly hedged beta) and thus compare our alpha streams to the remaining non-hedge candidates. This rolling correlation measures how much of our returns (proxied by alpha) 
can be attributed to other factors of bond market

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/2db3f3da-422d-425b-8fab-8c2785e13b8b)

Now we examine rolling Betas distribution as a proxy for hedge. Unfortunately BSV (Short term bond index) which is the best hedge has negative beta values which won't always work during in the L/S period.

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/418ec185-c71f-4bd9-b7c4-a1f40bccd787)

Beta's moments. Although BSV can have negative betas the distribution has postive skew implying that there is somewhat conviction for the betas to stay positive. It also has the highest standard deviation meaning that the
portfolio will require the most maintenance. 

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/941375ac-1df6-438d-9549-8778dc627634)

As per the alpha distribution

![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/b542f195-f755-47d5-b78b-b01800be4b8c)

Some of the alpha streams have positive skew and negative skew. This gives me the idea that we can use volatility as a predictor for our hedge leg via skew. All of our alphas are positive as well. 
![image](https://github.com/diegodalvarez/FallenAngelRiskPremia/assets/48641554/0babd68f-09e9-46ce-8813-7d73280aee2c)
