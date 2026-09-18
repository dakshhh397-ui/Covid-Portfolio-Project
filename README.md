# 🦠 COVID-19 Data Analysis using SQL

An end-to-end SQL project analyzing global COVID-19 data — cases, deaths, vaccinations, testing, ICU/hospital strain, and demographic/economic correlations — using **MySQL**.

---

## 📌 Project Overview

This project explores the [Our World in Data](https://ourworldindata.org/covid-deaths) COVID-19 dataset to answer real-world questions like:

- Which countries/continents had the highest case and death counts?
- How did monthly case trends change over time?
- What was the actual infection and death rate relative to population?
- How does testing volume relate to reported death rates?
- Which countries faced the highest ICU/hospital strain?
- Do factors like GDP, median age, diabetes prevalence, and healthcare capacity correlate with death rates?

All analysis is done using raw SQL — joins, CTEs, window functions, aggregate functions, and stored procedures — no external BI tool.

---

## 🗂️ Dataset

| File | Description | Rows |
|------|-------------|------|
| `CovidDeaths1.csv` | Cases, deaths, ICU/hospital data, population & demographic stats by country/date | ~85,000 |
| `CovidVaccinations1.csv` | Vaccination, testing, and stringency index data by country/date | ~85,000 |

**Source:** Our World in Data (OWID) COVID-19 dataset.

---

## 🛠️ Tools Used

- **MySQL 8.0** (Workbench)
- `LOAD DATA INFILE` for bulk CSV import
- SQL window functions (`ROW_NUMBER()`, `LAG()`)
- Common Table Expressions (CTEs)
- Stored Procedures
- Joins & aggregate functions

---

## 🔍 Key Analysis Performed

1. **Global case & death totals** — by location and continent
2. **Month-over-month case growth** — using `LAG()` to compute % change, and a reusable stored procedure `monthly_cases_change_inlocation(location)` to run this for any country
3. **Infection & death rate per population** — cases/deaths as a % of population, and per 100k people
4. **Death rate (case fatality rate)** — `total_deaths / total_cases`
5. **Vaccination rollout** — % of population vaccinated per country, joined `CovidDeaths` with `CovidVaccinations` on location + date
6. **Testing vs. death rate correlation** — using latest `positive_rate`, `tests_per_case`, and `total_tests_per_thousand` per country (via `ROW_NUMBER()` partitioned by location)
7. **Healthcare system strain** — peak ICU/hospital patients per million, and the exact date each country hit its peak
8. **Demographic & economic correlation** — checking whether GDP per capita, median age, diabetes prevalence, hospital beds per capita, and Human Development Index relate to death rate

---

## 💡 Sample Insight

> Countries with **higher testing volume tended to report lower death rates** — e.g., Bahrain (2,397 tests/1,000 people) had a death rate of just 0.37%, the lowest in its comparison group, while countries with no reported testing data (like Afghanistan and Bolivia) showed death rates above 4%. This suggests under-testing likely **inflates apparent fatality rates** by missing mild/asymptomatic cases.

> Population size distorts raw numbers — Andorra had far fewer total cases than Afghanistan, but ~110x more cases **per 100k people**, showing why normalized metrics matter more than raw totals.

---

## 📁 Files in this Repo

- `covid_project.sql` — full SQL script (table setup, data import, all queries & analysis)
- `CovidDeaths1.csv` — cases/deaths dataset
- `CovidVaccinations1.csv` — vaccinations/testing dataset

---

## 🚀 How to Run

1. Create the database and tables in MySQL Workbench.
2. Update the file path in `LOAD DATA INFILE` to match your local `secure_file_priv` directory.
3. Run the script section by section — table creation → data load → analysis queries.

---

## 📬 Connect

If you found this project interesting, feel free to connect with me on LinkedIn or check out more of my work on GitHub!

