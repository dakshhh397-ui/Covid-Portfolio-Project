/* ============================================================
   COVID-19 DATA ANALYSIS PROJECT — DOCUMENTED SQL SCRIPT
   Database: MySQL 8.0
   Tables: coviddeaths, covidvaccinations
   Source Data: Our World in Data (OWID) COVID-19 Dataset
   ============================================================ */


/* ------------------------------------------------------------
   1. DATABASE & TABLE SETUP
   ------------------------------------------------------------ */

-- Check which directory MySQL allows LOAD DATA INFILE to read from
SHOW VARIABLES LIKE "secure_file_priv";

-- Create the project database
CREATE DATABASE covid_project;

-- Confirm tables exist inside the database
SHOW TABLES;

-- Empty the tables before a fresh data load (structure stays intact)
TRUNCATE coviddeaths;
TRUNCATE covidvaccinations;

-- Quick look at raw table contents
SELECT * FROM covidvaccinations;
SELECT * FROM coviddeaths;


/* ------------------------------------------------------------
   2. BULK DATA IMPORT FROM CSV
   ------------------------------------------------------------ */

-- Import vaccination + testing data
LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/covidvaccinations.csv"
INTO TABLE covidvaccinations
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;                       -- skip header row

-- Import cases + deaths data
LOAD DATA INFILE "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Coviddeaths.csv"
INTO TABLE coviddeaths
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


/* ------------------------------------------------------------
   3. BASIC CASE & DEATH EXPLORATION
   ------------------------------------------------------------ */

-- Raw daily case data by country
SELECT continent, location, date, total_cases, new_cases 
FROM coviddeaths;

-- Peak total cases + sum of new cases per COUNTRY
-- (continent IS NOT NULL excludes aggregate rows like "Asia", "World")
SELECT location, MAX(total_cases), SUM(new_cases) 
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 2 DESC;

-- Same metric but for CONTINENT-LEVEL aggregate rows
-- (OWID stores continent totals with continent = NULL)
SELECT location, MAX(total_cases), SUM(new_cases) 
FROM coviddeaths
WHERE continent IS NULL
GROUP BY location
ORDER BY 2 DESC;

-- Raw daily death data by country
SELECT continent, location, date, total_deaths, new_deaths
FROM coviddeaths;

-- Peak total deaths + sum of new deaths per country
SELECT location, MAX(total_deaths), SUM(new_deaths) 
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 2 DESC;

-- Fix data types: CSV import brings numeric columns in as text/varchar
ALTER TABLE coviddeaths 
    MODIFY COLUMN total_deaths DOUBLE,
    MODIFY COLUMN new_deaths DOUBLE;

-- Continent-level death totals (continent IS NULL = aggregate rows)
SELECT location, MAX(total_deaths), SUM(new_deaths) 
FROM coviddeaths
WHERE continent IS NULL
GROUP BY location
ORDER BY 2 DESC;


/* ------------------------------------------------------------
   4. MONTH-OVER-MONTH CASE GROWTH (WINDOW FUNCTION: LAG)
   ------------------------------------------------------------ */

-- Step 1 (monthly_cases CTE): aggregate new_cases by year+month+location
-- Step 2 (previous_cases_diff CTE): use LAG() to pull previous month's
--         total and compute the difference
-- Final SELECT: convert the difference into a percentage change
WITH monthly_cases AS (
    SELECT location, YEAR(date) t_year, MONTH(date) t_month, SUM(new_cases) AS total_cases
    FROM coviddeaths
    WHERE continent IS NOT NULL
    GROUP BY YEAR(date), MONTH(date), location
    ORDER BY 1,2
),
previous_cases_diff AS (
    SELECT *,
        LAG(total_cases) OVER() AS previous_cases,
        total_cases - LAG(total_cases) OVER() AS cases_diff
    FROM monthly_cases
)
SELECT *, cases_diff*100/previous_cases AS percentage_change 
FROM previous_cases_diff;


-- Reusable version: a STORED PROCEDURE that runs the same logic
-- for any single country passed in as a parameter
CREATE PROCEDURE monthly_cases_change_inlocation(loc TEXT)
WITH monthly_cases AS (
    SELECT YEAR(date) t_year, MONTH(date) t_month, SUM(new_cases) AS total_cases
    FROM coviddeaths
    WHERE continent IS NOT NULL AND location = loc
    GROUP BY YEAR(date), MONTH(date)
    ORDER BY 1,2
),
previous_cases_diff AS (
    SELECT *,
        LAG(total_cases) OVER() AS previous_cases,
        total_cases - LAG(total_cases) OVER() AS cases_diff
    FROM monthly_cases
)
SELECT *, cases_diff*100/previous_cases AS percentage_change 
FROM previous_cases_diff;

-- Example call: get India's monthly case trend
CALL monthly_cases_change_inlocation("india");


/* ------------------------------------------------------------
   5. POPULATION-NORMALIZED INFECTION & DEATH RATES
   ------------------------------------------------------------ */

-- Full raw view: cases + deaths against population
SELECT continent, location, date, population,
       total_cases, new_cases, total_deaths, new_deaths 
FROM coviddeaths;

-- % of population infected (peak) and cumulative case % of population
SELECT location, population,
       MAX(total_cases)*100/population,
       SUM(new_cases)*100/population 
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 2 DESC;

-- % of population that died (peak) and cumulative death % of population
SELECT location, population,
       MAX(total_deaths)*100/population,
       SUM(new_deaths)*100/population 
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 2 DESC;

-- Case Fatality Rate (CFR): deaths as a % of confirmed cases
SELECT location, MAX(total_deaths)*100/MAX(total_cases) death_rate_perc
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 2 DESC;


/* ------------------------------------------------------------
   6. VACCINATION ANALYSIS
   ------------------------------------------------------------ */

-- Sanity check: India's vaccination data
SELECT * FROM covidvaccinations
WHERE location = "india";

-- Fix data types for vaccination numeric columns
ALTER TABLE covidvaccinations 
    MODIFY COLUMN total_vaccinations DOUBLE,
    MODIFY new_vaccinations DOUBLE;

-- Total & cumulative vaccination doses per country
SELECT location, MAX(total_vaccinations), SUM(new_vaccinations) 
FROM covidvaccinations
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY 2 DESC;

-- JOIN coviddeaths + covidvaccinations on location + date
-- to calculate vaccination % of population
SELECT cd.location, population,
       MAX(cv.total_vaccinations)*100/population,
       SUM(cv.new_vaccinations)*100/population  
FROM coviddeaths AS cd 
JOIN covidvaccinations AS cv 
    ON cd.location = cv.location AND cd.date = cv.date
GROUP BY cd.location, population
ORDER BY 2 DESC;

-- Full combined view of both tables joined together
SELECT * FROM coviddeaths AS cd 
JOIN covidvaccinations AS cv 
    ON cd.location = cv.location AND cd.date = cv.date;

SELECT * FROM covidvaccinations;
SELECT * FROM coviddeaths;

-- Overall death rate per country: total deaths vs total cases
SELECT location, MAX(total_deaths) total_deaths,
       MAX(total_cases) total_cases,
       MAX(total_deaths)*100/MAX(total_cases) death_rate 
FROM coviddeaths
GROUP BY location
ORDER BY 4 DESC;


/* ------------------------------------------------------------
   7. LATEST SNAPSHOT PER COUNTRY (WINDOW FUNCTION: ROW_NUMBER)
   ------------------------------------------------------------ */

-- Rows where testing data (positive_rate) was actually reported
SELECT * FROM covidvaccinations
WHERE positive_rate IS NOT NULL;

-- Get the most recent (latest date) testing snapshot per country
-- ROW_NUMBER() partitions by location and orders by date DESC,
-- so row_num = 1 is always the latest reported record
WITH testing AS (
    SELECT location, date, positive_rate, tests_per_case, total_tests_per_thousand,
        ROW_NUMBER() OVER(PARTITION BY location ORDER BY date DESC) AS row_num
    FROM covidvaccinations
    WHERE continent IS NOT NULL AND positive_rate IS NOT NULL
)
SELECT * FROM testing
WHERE row_num = 1;

-- Fix data types for testing-related columns
ALTER TABLE covidvaccinations 
    MODIFY COLUMN positive_rate DOUBLE,
    MODIFY COLUMN tests_per_case DOUBLE,
    MODIFY COLUMN total_tests_per_thousand DOUBLE;

-- Get the latest cumulative case/death snapshot per country
-- (since totals only increase, the latest date = final totals)
WITH deaths_rate AS (
    SELECT location, date, population, total_cases, total_deaths,
        ROW_NUMBER() OVER(PARTITION BY location ORDER BY date DESC) AS row_num
    FROM coviddeaths
    WHERE continent IS NOT NULL
)
SELECT * FROM deaths_rate
WHERE row_num = 1;


/* ------------------------------------------------------------
   8. COMBINED TESTING + DEATH RATE ANALYSIS (RIGHT JOIN)
   ------------------------------------------------------------ */

-- Combine latest testing snapshot with latest death/case snapshot
-- RIGHT JOIN keeps every country from deaths_rate even if it has
-- no testing data reported (testing data is much sparser)
WITH testing AS (
    SELECT location, positive_rate, tests_per_case, total_tests_per_thousand,
        ROW_NUMBER() OVER(PARTITION BY location ORDER BY date DESC) AS row_num
    FROM covidvaccinations
    WHERE positive_rate IS NOT NULL
),
deaths_rate AS (
    SELECT location, population, total_cases, total_deaths,
        ROW_NUMBER() OVER(PARTITION BY location ORDER BY date DESC) AS row_num
    FROM coviddeaths
    WHERE continent IS NOT NULL
)
SELECT d.location, population, total_cases, total_deaths,
    ROUND(total_deaths / total_cases * 100, 2) death_rate_pct,
    ROUND(total_cases / population * 100000, 2) cases_per_100k,
    t.positive_rate, t.tests_per_case, t.total_tests_per_thousand 
FROM testing AS t 
RIGHT JOIN deaths_rate AS d
    ON t.location = d.location AND t.row_num = 1
WHERE d.row_num = 1 
ORDER BY t.positive_rate DESC;

/* --------------------------------------------------------------
   INSIGHT — What this query's results show:

   Afghanistan: 59,745 cases, 2,625 deaths -> 4.39% death rate,
     but only 153 cases per 100k people (population ~39M) --
     very few confirmed infections relative to population size,
     likely due to limited testing infrastructure. True case
     count was probably much higher.

   Andorra: tiny population, only 13,232 total cases, but that's
     17,125 cases per 100k people -- over 17% of its entire
     population had a confirmed case. Compare to Afghanistan's
     153 per 100k -- a ~110x difference in exposure rate that
     raw case counts alone would never reveal. This is why
     cases_per_100k matters more than raw totals when comparing
     countries.

   Azerbaijan, Bahrain, Bulgaria: the only countries in this
     batch with non-blank total_tests_per_thousand (318, 2397,
     361 respectively) -- meaning most countries in this list
     never reported testing volume data to the source, not that
     testing didn't happen.

   Bahrain: death rate is just 0.37%, the lowest in the list,
     while its testing volume (2,397 tests/1,000 people) is by
     far the highest shown. Pattern: more testing tends to
     correlate with lower apparent death rates, because mild and
     asymptomatic cases get caught instead of only severe
     hospital cases. Bahrain's low death rate is likely a more
     accurate reflection of the virus's true fatality rate than
     Afghanistan's 4.39%, which is probably inflated by
     under-testing.

   Bolivia (4.26%) and Bosnia (4.31%): both have no testing data
     and high death rates -- consistent with the under-testing
     pattern described above.
   -------------------------------------------------------------- */


/* ------------------------------------------------------------
   9. HEALTHCARE SYSTEM STRAIN (ICU / HOSPITAL DATA)
   ------------------------------------------------------------ */

-- Peak ICU/hospital load reported per country
-- HAVING filters out countries that never reported this data at all
SELECT
    location,
    MAX(icu_patients_per_million) AS peak_icu_per_million,
    MAX(hosp_patients_per_million) AS peak_hosp_per_million,
    MAX(weekly_icu_admissions) AS peak_weekly_icu_admissions,
    MAX(weekly_hosp_admissions) AS peak_weekly_hosp_admissions
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location
HAVING peak_icu_per_million IS NOT NULL 
    OR peak_hosp_per_million IS NOT NULL
ORDER BY peak_icu_per_million DESC, peak_hosp_per_million DESC;

-- Fix data types for ICU/hospital columns
ALTER TABLE coviddeaths 
    MODIFY COLUMN icu_patients_per_million DOUBLE,
    MODIFY COLUMN hosp_patients_per_million DOUBLE;

-- Find each country's PEAK ICU value AND the exact date it happened
-- (ROW_NUMBER ordered by icu_patients_per_million DESC per location)
WITH icu_ranked AS (
    SELECT
        location, date, icu_patients_per_million,
        ROW_NUMBER() OVER (PARTITION BY location ORDER BY icu_patients_per_million DESC) AS rn
    FROM coviddeaths
    WHERE continent IS NOT NULL
      AND icu_patients_per_million IS NOT NULL
)
SELECT location, date AS peak_icu_date, icu_patients_per_million AS peak_value
FROM icu_ranked
WHERE rn = 1
ORDER BY peak_value DESC;


/* ------------------------------------------------------------
   10. DEMOGRAPHIC / ECONOMIC CORRELATION WITH DEATH RATE
   ------------------------------------------------------------
   Tests whether gdp_per_capita, median_age, diabetes_prevalence,
   hospital_beds_per_thousand, or human_development_index show
   any relationship with a country's death rate.
   ------------------------------------------------------------ */

WITH latest_deaths AS (
    SELECT 
        location, total_cases, total_deaths, population,
        gdp_per_capita, median_age, diabetes_prevalence,
        hospital_beds_per_thousand, human_development_index,
        cardiovasc_death_rate, aged_65_older,
        ROW_NUMBER() OVER (PARTITION BY location ORDER BY date DESC) AS rn
    FROM coviddeaths
    WHERE continent IS NOT NULL
)
SELECT
    location,
    ROUND(total_deaths / total_cases * 100, 2) AS death_rate_pct,
    ROUND(total_cases / population * 100000, 2) AS cases_per_100k,
    gdp_per_capita, median_age, diabetes_prevalence,
    hospital_beds_per_thousand, human_development_index, cardiovasc_death_rate
FROM latest_deaths
WHERE rn = 1 AND total_cases > 1000   -- exclude countries with too small a sample size
ORDER BY death_rate_pct DESC;

/* ============================================================
   END OF SCRIPT
   ============================================================ */
