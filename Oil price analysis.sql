# 1. Cleaning the oil table

SELECT *
FROM oil;

# 1.1 Getting rid of commas in the numeric fileds of the oil table by the replace() function

UPDATE oil
SET `Daily Oil Consumption (Barrels)` = REPLACE(`Daily Oil Consumption (Barrels)`,',',''),
	`GDP Per Capita ( USD )` = REPLACE(`GDP Per Capita ( USD )`,',',''),
    `Gallons GDP Per Capita Can Buy` = REPLACE(`Gallons GDP Per Capita Can Buy`,',','');
    
# 1.2 Renaming columns and changing some data type in the oil table

ALTER TABLE oil
CHANGE `S#` seq NUMERIC,
CHANGE Country country VARCHAR(255),
CHANGE `Daily Oil Consumption (Barrels)` daily_oil_consumption_barrels NUMERIC,
CHANGE `World Share` world_share_percent NUMERIC,
CHANGE `Yearly Gallons Per Capita` yearly_gallons_per_capita FLOAT,
CHANGE `Price Per Gallon (USD)` price_per_gallon_usd FLOAT,
CHANGE `Price Per Liter (USD)` price_per_liter_usd FLOAT,
DROP `Price Per Liter (PKR)`,
CHANGE `GDP Per Capita ( USD )` gdp_per_capita_usd NUMERIC,
CHANGE `Gallons GDP Per Capita Can Buy` gallons_gdp_per_capita_can_buy NUMERIC,
CHANGE `xTimes Yearly Gallons Per Capita Buy` xtimes_yearly_gallons_per_capita_buy INT;

# 1.3 Checking if there is any missing value in the oil table 
## Counting the total number of rows (including NULLs) in a column can be useful for quickly identifying which rows have missing data. 
## Result: no missing data.

SELECT count(*), count(seq), count(country), count(daily_oil_consumption_barrels), count(world_share_percent), count(yearly_gallons_per_capita), count(price_per_gallon_usd), count(price_per_liter_usd), 
count(gdp_per_capita_usd), count(gallons_gdp_per_capita_can_buy), count(xtimes_yearly_gallons_per_capita_buy)
FROM oil;

# 2. Cleaning the continents table

# 2.1 Renaming some and drops some other columns in the continents table

ALTER TABLE continents
CHANGE `name` country VARCHAR(255),
CHANGE `alpha-2` alpha_2 VARCHAR(20),
CHANGE `alpha-3` alpha_3 VARCHAR(20),
CHANGE `country-code` country_code NUMERIC,
CHANGE `iso_3166-2` iso_3166_2 VARCHAR(20),
CHANGE `sub-region` sub_region VARCHAR(255),
DROP `intermediate-region`,
DROP `region-code`,
DROP `sub-region-code`,
DROP `intermediate-region-code`;

# 2.2 Checking what countries of the oil table are either different or don't exist in the continents table 
## Result: all countries in the oil table also exist in the continent table.

SELECT country
FROM oil
WHERE country NOT IN (SELECT country FROM continents);

# 2.3 Adding a new column into the continents table --- To mark if a country is OPEC or non-OPEC.

ALTER TABLE continents
ADD COLUMN opec VARCHAR(15) AFTER country;
    
# 2.4 Updating OPEC column in the continent table (OPEC (Organization of the Petroleum Exporting Countries): 
# Algeria, Angola, Congo, Equatorial Guinea, Gabon, Iran, Iraq, Kuwait, Libya, Nigeria, Saudi Arabia, United Arab Emirates, Venezuela
## Notes: Equatorial Guinea doesn't exist in the oil table

UPDATE continents
SET opec = 
    CASE 
        WHEN country = 'Algeria' THEN 'yes'
        WHEN country = 'Angola' THEN 'yes'
        WHEN country = 'Congo' THEN 'yes'
        WHEN country = 'Equatorial Guinea' THEN 'yes'  
        WHEN country = 'Gabon' THEN 'yes'
        WHEN country = 'Iran' THEN 'yes'
        WHEN country = 'Iraq' THEN 'yes'
        WHEN country = 'Kuwait' THEN 'yes'
        WHEN country = 'Libya' THEN 'yes'
        WHEN country = 'Nigeria' THEN 'yes'
        WHEN country = 'Saudi Arabia' THEN 'yes'
        WHEN country = 'United Arab Emirates' THEN 'yes'
        WHEN country = 'Venezuela' THEN 'yes'
        ELSE 'no'
    END; 
    
# 2.5 Checking if there is any missing value in the continents table
## Result: no missing data.

SELECT count(*), count(country), count(opec), count(alpha_2), count(alpha_3), count(country_code), count(iso_3166_2), count(region), count(sub_region)
FROM continents;
  
# 3. Analysis  
## Notes: 1 barrel = 42 gallons = 159 liters (amount in liter is rounded)  (1 gallon = 3.785 liters (amount in liter is rounded)

# 3.1 What is the daily average consumption, price and cost by the entire world?
## First I wrote a subquery to create a summary table with the aggregated values and then the outer query interacts with this newly created table to get the daily cost (avg_usd_spent).
## Result: sum_barrel: 96 576 722, sum_gallon: 4 056 222 324, avg_gallon_price_usd: 5.7, avg_usd_spent: 23 120 467 247

SELECT sum_barrel, sum_gallon, avg_gallon_price_usd, round(sum_gallon*avg_gallon_price_usd) AS avg_usd_spent
FROM 
	(SELECT sum(daily_oil_consumption_barrels) AS sum_barrel, sum(daily_oil_consumption_barrels*42) AS sum_gallon, 
	ROUND(avg(price_per_gallon_usd), 2) AS avg_gallon_price_usd
	FROM oil) AS summary_table;

# 3.2 What is the rank of regions by their daily oil consumption? 
## The rank() function ranks the continents by their total consumption. I didn't specify the PARTITION BY clause therefore the entire result set is treated as a single partition.
## Since all countries in the oil table exists in the continent table I used JOIN instead of LEFT JOIN to avoid NULL values from the continents table.
## Result: Asia is the biggest consumer. The order is Asia, Americas, Europe, Africa, Oceania.

SELECT
  sum(oil.daily_oil_consumption_barrels) AS sum_daily_oil_consumption_barrels,
  continents.region,  
  rank ()
  OVER (
    ORDER BY sum(oil.daily_oil_consumption_barrels) DESC
  ) region_rank
FROM
  continents
JOIN
  oil
ON oil.country = continents.country
GROUP BY
  region;     

# 3.3 What is the rank of regions by their total GDP in USD? 
## The order is Europe, Asia, Americas, Oceania, Africa. Europe has the highest GDP per capita but Europe is only the 3rd biggest oil consumer. 

SELECT
  sum(gdp_per_capita_usd) AS sum_gdp_per_capita_usd,
  continents.region,  
  rank ()
  OVER (
    ORDER BY sum(gdp_per_capita_usd) DESC
  ) region_rank
FROM
  continents
JOIN
  oil
ON oil.country = continents.country
GROUP BY
  region; 
   
# 3.4 How many OPEC counries can be found in the regions and what their total GDP per capita in USD in that region?
## Total 13 OPEC countries exists this is why 13 is used inside the arithmetic. This can be misleading though as only 12 OPEC countries listed inside the oil table.
## Result: 46% of the OPEC countries are in Africa but their total GDP per capita in USD is still the lowest among the OPEC countries.
    
SELECT gdp_per_capita_usd, region, counted_opec, round(counted_opec/13*100) AS opec_countries_percent
FROM (
	SELECT oil.gdp_per_capita_usd, continents.region, count(opec) AS counted_opec
	FROM continents    
	JOIN oil 
		ON oil.country = continents.country
	WHERE opec = 'yes'
	GROUP BY region
	ORDER BY counted_opec
    ) AS calculated;   

# 3.5 What is the rank of sub-regions by their daily oil consumption per region?
## I used the PARTITION BY clause to partition the result set into multiple region groups, then on each partition, 
## the data is sorted based on the sum_daily_oil_consumption_barrels column.

SELECT
  continents.region,
  continents.sub_region,
  rank ()
  OVER (
	PARTITION BY region ORDER BY sum(oil.daily_oil_consumption_barrels) DESC    
  ) sub_region_rank
FROM
  continents
JOIN
  oil
ON oil.country = continents.country
GROUP BY
  sub_region;
  
# 3.6 How many OPEC counries can be found in the subregions and what their total GDP per capita in USD? 
## Total 13 OPEC countries exists this is why 13 is used inside the arithmetic. This can be misleading though as only 12 OPEC countries listed inside the oil table.
## Most of the OPEC countries exist in Western Asia (31%) and Sub-Saharan Africa (31%). Sub-Saharan OPEC countries have the lowest GDP among the OPEC countries.

SELECT gdp_per_capita_usd, sub_region, counted_opec, round(counted_opec/13*100) AS opec_countries_percent
FROM (
	SELECT oil.gdp_per_capita_usd, continents.sub_region, count(opec) AS counted_opec
	FROM continents    
	JOIN oil 
		ON oil.country = continents.country
	WHERE opec = 'yes'
	GROUP BY sub_region
	ORDER BY counted_opec
    ) AS calculated;   

# 3.7 What are these Western Asian and Sub-Saharan African OPEC countries GDP, daily consumption and how many USD they spent on oil each day?
## The Western Asian OPEC countries have higher GDP and they are bigger consumers than the Sub-Saharan African OPEC countries.

SELECT country, gdp_per_capita_usd, price_per_gallon_usd, round(daily_oil_consumption_barrels*42*price_per_gallon_usd) AS daily_spent_usd_on_oil
FROM oil    
WHERE 
    country IN (SELECT 
            country
        FROM
            continents
        WHERE
            (sub_region = 'Western Asia'
            OR sub_region = 'Sub-Saharan Africa')
            AND opec = 'yes')
ORDER BY gdp_per_capita_usd DESC;

# 3.8 How many USD the countries spend on oil each day? 
## Result: United States spent the most, following by China. Saudi Arabia on the 17th place is the first OPEC country in the list.
   
SELECT continents.opec, oil.country, oil.daily_oil_consumption_barrels, oil.price_per_gallon_usd, round(daily_oil_consumption_barrels*42*price_per_gallon_usd) AS daily_spent_usd_on_oil
FROM oil   
JOIN continents
 ON oil.country = continents.country
GROUP BY country
ORDER BY daily_spent_usd_on_oil DESC;

# 3.9 United States and China the only countries who have a two-digit world share. How many percent these two countries have together? 
## Result: 33% of world share

SELECT sum(world_share_percent) AS sum_world_share
FROM oil
WHERE world_share_percent > 10
ORDER BY sum_world_share;

# 3.10 How many total world share have the OPEC countries comparing to the non-OPEC countries?
## Result: OPEC countries have total 8% world share, while the non-OPEC countries world share is 82%.

SELECT continents.opec, sum(world_share_percent) AS sum_world_share_percent
FROM oil    
JOIN continents
  ON oil.country = continents.country
GROUP BY opec
ORDER BY sum_world_share_percent;

# 3.11 What are the minimum, average and maximum prices in the OPEC and non-OPEC countries?
## Result: Non-OPEC countries have higher prices in these categories, particulary in the maximum price per gallon.

SELECT min(oil.price_per_gallon_usd) AS min_price_per_gallon_usd, 
ROUND(avg(oil.price_per_gallon_usd), 2) AS avg_price_per_gallon_usd,
max(oil.price_per_gallon_usd) AS max_price_per_gallon_usd, continents.opec
FROM oil
 JOIN continents
  ON oil.country = continents.country
GROUP BY continents.opec;

# 3.12 What OPEC countries have the highest prices per gallon is USD?
## The OPEC countries average price per gallon in USD is 1.82, this is why this number is used in this arithmetic.
## Result: five of the 13 (38%) of the OPEC countries have higher prices than the OPEC average. These countries: United Arab Emirates, Congo, Gabon, Saud Arabia, Iraq.

SELECT country, price_per_gallon_usd
FROM oil    
WHERE price_per_gallon_usd > 1.82 AND
    country IN (SELECT 
            country
        FROM
            continents
        WHERE
            opec = 'yes')
ORDER BY price_per_gallon_usd DESC;

# 3.13 What countries have two-digit prices per gallon? Are these countries OPEC or non-OPEC countries? 
## Result: the countries: North Korea, Tonga, Niue, Hong Kong, Norway, Denmark, Finland and none of them is OPEC.

SELECT continents.opec, oil.country, ROUND(avg(price_per_gallon_usd), 2) AS avg_price_per_gallon_usd, continents.region, continents.sub_region
FROM oil
JOIN continents
 ON oil.country = continents.country
GROUP BY country
HAVING avg(price_per_gallon_usd) > 10
ORDER BY avg(price_per_gallon_usd) DESC;  
           
# 3.14 How many countries oil consumption is above and how many is below the world average?
## First I calculate the average world consumption and then create a CTE,  a named temporary result set that exists only within
## the execution scope of a single SQL statement, and after that I can run query to get the aggregated results.
## Result: the average daily consumuption of the entire world is 533 573.0497 barrels.
## Result: countries above average oil consumption: 33, below average: 148. Less than 20% of countries consum more oil then the world average.

SELECT avg(daily_oil_consumption_barrels) AS avg_daily_oil_consumption_barrels
FROM oil;

WITH cte AS (
	SELECT 
    country, 
    daily_oil_consumption_barrels, 
    CASE 
		WHEN daily_oil_consumption_barrels > 533573.0497 THEN "Above average"
		WHEN daily_oil_consumption_barrels = 533573.0497 THEN "Average"
		ELSE "Below average"
	END AS consumption_status
FROM
    oil
ORDER BY consumption_status)
SELECT consumption_status, count(consumption_status) AS counted_status, ROUND((count(consumption_status)/181*100),2) AS status_in_percent
FROM cte
GROUP BY consumption_status
ORDER BY counted_status;

# 3.15 What are these numbers if OPEC and non-OPEC countriers are being compared? 
## OPEC countries above average: 5, below average: 7 while non-OPEC countries above average: 28, below average: 128.

WITH cte AS (
	SELECT 
    country, 
    daily_oil_consumption_barrels, 
    CASE 
		WHEN daily_oil_consumption_barrels > 533573.0497 THEN "Above average"
		WHEN daily_oil_consumption_barrels = 533573.0497 THEN "Average"
		ELSE "Below average"
	END AS consumption_status
FROM
    oil
ORDER BY consumption_status)
SELECT consumption_status, count(consumption_status) AS counted_status, ROUND((count(consumption_status)/181*100),2) AS status_in_percent, opec
FROM cte
JOIN continents
  ON cte.country = continents.country
GROUP BY opec, consumption_status
ORDER BY counted_status;

# 3.16 What are these numbers if regions are being compared? 
## There are 181 countries in the oil table this is why this number is used in the arithmetic.
## Result: We can find 15 countries in Asia whose consumption is above average, 
## while we can find 43 countries in Africa whose consumption is below average.

WITH cte AS (
	SELECT 
    country, 
    daily_oil_consumption_barrels, 
    CASE 
		WHEN daily_oil_consumption_barrels > 533573.0497 THEN "Above average"
		WHEN daily_oil_consumption_barrels = 533573.0497 THEN "Average"
		ELSE "Below average"
	END AS consumption_status
FROM
    oil
ORDER BY consumption_status)
SELECT consumption_status, count(consumption_status) AS counted_status, ROUND((count(consumption_status)/181*100),2) AS status_in_percent, region
FROM cte
JOIN continents
  ON cte.country = continents.country
GROUP BY region, consumption_status
ORDER BY region;

# 3.17 What are these numbers if regions are being compared? 
## The consumption of subregions with the most OPEC countries are tend to be below average.

WITH cte AS (
	SELECT 
    country, 
    daily_oil_consumption_barrels, 
    CASE 
		WHEN daily_oil_consumption_barrels > 533573.0497 THEN "Above average"
		WHEN daily_oil_consumption_barrels = 533573.0497 THEN "Average"
		ELSE "Below average"
	END AS consumption_status
FROM
    oil
ORDER BY consumption_status)
SELECT consumption_status, count(consumption_status) AS counted_status, ROUND((count(consumption_status)/181*100),2) AS world_status_percent, sub_region, region
FROM cte
JOIN continents
  ON cte.country = continents.country
GROUP BY sub_region, consumption_status
ORDER BY counted_status DESC;

# 3.18 What are those 7 countries that have the highest price per gallon? Are these OPEC or non-OPEC countries?
## Result: North Korea has the highest price and none of these 7 countries are OPEC.

SELECT oil.country, oil.price_per_gallon_usd, continents.opec, continents.region, continents.sub_region
FROM oil
JOIN continents
 ON oil.country = continents.country
ORDER BY price_per_gallon_usd DESC
LIMIT 7;

# 3.19 What are those 7 countries that have the lowest price per gallon? Are these OPEC or non-OPEC countries?
## Result: Venezuela, which is an OPEC country, has the lowest price. 5 countries of these 7 are OPEC.

SELECT oil.country, oil.price_per_gallon_usd, continents.opec, continents.region, continents.sub_region
FROM oil
JOIN continents
 ON oil.country = continents.country
ORDER BY price_per_gallon_usd
LIMIT 7;

# 3.20 What are those 7 countries that have the highest GDP per capita? Are these OPEC or non-OPEC countries?
## Result: None of these countries are OPEC. Luxemburg has the highest GDP and most countries (4 from 7) are in Europe.

SELECT oil.country, oil.gdp_per_capita_usd, continents.opec, continents.region, continents.sub_region
FROM oil
JOIN continents
 ON oil.country = continents.country
ORDER BY gdp_per_capita_usd DESC 
LIMIT 7;

# 3.21 What OPEC countries GDP per capita is lower than 10 000 USD?
## 8 countries most of them from Africa.

SELECT 
    oil.country,
    oil.gdp_per_capita_usd,
    continents.opec,
    continents.region,
    continents.sub_region
FROM
    oil
        JOIN
    continents ON oil.country = continents.country
WHERE
    10000 > gdp_per_capita_usd
        AND opec = 'yes'
ORDER BY gdp_per_capita_usd DESC;





