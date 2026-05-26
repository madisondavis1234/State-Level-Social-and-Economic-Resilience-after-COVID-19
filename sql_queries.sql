-- =============================================================
-- SQL Queries: Socioeconomic Effects of COVID-19 in the U.S.
-- Data source: ACS (American Community Survey) via Census API
-- Database: SQLite (social_resilience.db)
-- Tables: acs, state_change
-- =============================================================


-- -------------------------------------------------------------
-- SETUP
-- The SQLite database is created from the cleaned ACS dataframe.
-- Two tables are loaded: acs (full panel) and state_change
-- (pre vs post COVID state-level aggregates).
-- -------------------------------------------------------------

-- conn = sqlite3.connect("social_resilience.db")
-- acs.to_sql("acs", conn, if_exists="replace", index=False)
-- state_change.to_sql("state_change", conn, if_exists="replace", index=False)


-- =============================================================
-- QUERY 1: Preview cleaned ACS table
-- Basic data validity check. Confirms the table loaded correctly
-- and shows column structure before any analysis.
-- Output: first 10 rows of the acs table.
-- =============================================================

-- SELECT * FROM acs LIMIT 10;


-- =============================================================
-- QUERY 2: Count observations by year
-- GROUP BY query. Verifies that each year has the expected number
-- of state-level observations (52: 50 states + DC + PR).
-- Confirms no years are missing or duplicated in the panel.
-- Output: year, row count, and distinct state count per year.
-- =============================================================

-- SELECT
--     year,
--     COUNT(*) AS row_count,
--     COUNT(DISTINCT state_name) AS unique_states
-- FROM acs
-- GROUP BY year
-- ORDER BY year;


-- =============================================================
-- QUERY 3: Average economic conditions by period
-- GROUP BY query. Compares mean income, poverty, and unemployment
-- across Pre-COVID and Post-COVID periods at the national level.
-- Establishes the economic baseline shift caused by the pandemic.
-- Output: period, avg income, avg poverty rate, avg unemployment rate.
-- =============================================================

-- SELECT
--     period,
--     AVG(median_household_income) AS avg_income,
--     AVG(poverty_rate)            AS avg_poverty_rate,
--     AVG(unemployment_rate)       AS avg_unemployment_rate
-- FROM acs
-- GROUP BY period;


-- =============================================================
-- QUERY 4: Average social conditions by period
-- GROUP BY query. Mirrors Query 3 but for social indicators:
-- insurance coverage, housing cost burden, overcrowding, and
-- divorce rate. Shows how household-level stress shifted pre vs
-- post COVID alongside the economic indicators.
-- Output: period, avg uninsured, cost burden, overcrowding,
--         and divorce rates.
-- =============================================================

-- SELECT
--     period,
--     AVG(uninsured_rate)     AS avg_uninsured_rate,
--     AVG(cost_burden_rate)   AS avg_cost_burden_rate,
--     AVG(overcrowding_rate)  AS avg_overcrowding_rate,
--     AVG(divorce_rate)       AS avg_divorce_rate
-- FROM acs
-- GROUP BY period;


-- =============================================================
-- QUERY 5: Pre vs Post-COVID poverty rate change by state (JOIN)
-- Self-join on state_abbreviation, splitting by period.
-- Computes the change in poverty rate per state between the
-- Pre-COVID and Post-COVID periods. Identifies which states
-- saw poverty worsen or improve following the pandemic.
-- Output: state, pre poverty rate, post poverty rate, change.
--         Ordered by largest increase first.
-- =============================================================

-- SELECT
--     pre.state_abbreviation,
--     AVG(pre.poverty_rate)                          AS pre_poverty_rate,
--     AVG(post.poverty_rate)                         AS post_poverty_rate,
--     AVG(post.poverty_rate) - AVG(pre.poverty_rate) AS poverty_rate_change
-- FROM acs AS pre
-- JOIN acs AS post
--     ON pre.state_abbreviation = post.state_abbreviation
-- WHERE pre.period  = 'Pre-COVID'
--   AND post.period = 'Post-COVID'
-- GROUP BY pre.state_abbreviation
-- ORDER BY poverty_rate_change DESC;


-- =============================================================
-- QUERY 6: Pre vs Post-COVID uninsured rate change by state (JOIN)
-- Same self-join structure as Query 5, applied to uninsured rate.
-- Tests whether states lost or gained insurance coverage following
-- COVID. Relevant given job losses and Medicaid expansion dynamics.
-- Output: state, pre uninsured rate, post uninsured rate, change.
--         Ordered by largest increase first.
-- =============================================================

-- SELECT
--     pre.state_abbreviation,
--     AVG(pre.uninsured_rate)                              AS pre_uninsured_rate,
--     AVG(post.uninsured_rate)                             AS post_uninsured_rate,
--     AVG(post.uninsured_rate) - AVG(pre.uninsured_rate)  AS uninsured_rate_change
-- FROM acs AS pre
-- JOIN acs AS post
--     ON pre.state_abbreviation = post.state_abbreviation
-- WHERE pre.period  = 'Pre-COVID'
--   AND post.period = 'Post-COVID'
-- GROUP BY pre.state_abbreviation
-- ORDER BY uninsured_rate_change DESC;


-- =============================================================
-- QUERY 7: Average resilience index and income by state
-- GROUP BY query. Ranks states by their average social resilience
-- index across the full study period. Paired with median household
-- income to show whether higher-income states also score higher
-- on composite resilience.
-- Output: state, avg resilience index, avg income. Ordered by
--         resilience descending.
-- =============================================================

-- SELECT
--     state_abbreviation,
--     AVG(social_resilience_index) AS avg_resilience,
--     AVG(median_household_income) AS avg_income
-- FROM acs
-- GROUP BY state_abbreviation
-- ORDER BY avg_resilience DESC;


-- =============================================================
-- QUERY 8: Window function - rank states by resilience within each year
-- WINDOW function using RANK() partitioned by year.
-- Assigns each state a rank within its year based on resilience
-- index. Allows tracking of which states consistently lead or
-- lag over time, and whether rankings shifted post-COVID.
-- Output: year, state, resilience index, rank within year.
-- =============================================================

-- SELECT
--     year,
--     state_abbreviation,
--     social_resilience_index,
--     RANK() OVER (
--         PARTITION BY year
--         ORDER BY social_resilience_index DESC
--     ) AS yearly_resilience_rank
-- FROM acs
-- ORDER BY year, yearly_resilience_rank;


-- =============================================================
-- QUERY 9: Window function - year-over-year income change by state
-- WINDOW function using LAG() partitioned by state, ordered by year.
-- Computes how much median household income changed from the prior
-- year for each state. Surfaces the COVID income shock in 2021
-- and the speed of recovery across states in subsequent years.
-- Output: state, year, income, change from prior year.
-- =============================================================

-- SELECT
--     state_abbreviation,
--     year,
--     median_household_income,
--     median_household_income - LAG(median_household_income)
--         OVER (PARTITION BY state_abbreviation ORDER BY year)
--         AS income_change_from_prior_year
-- FROM acs
-- ORDER BY state_abbreviation, year;


-- =============================================================
-- QUERY 10: Subquery - states with above-average poverty rate
-- Subquery in WHERE clause computing national average poverty rate.
-- Filters to only state-year observations where poverty exceeds
-- that national average. Used to identify persistently high-poverty
-- geographies and years for targeted analysis.
-- Output: state, year, poverty rate. Ordered by poverty descending.
-- =============================================================

-- SELECT
--     state_abbreviation,
--     year,
--     poverty_rate
-- FROM acs
-- WHERE poverty_rate > (SELECT AVG(poverty_rate) FROM acs)
-- ORDER BY poverty_rate DESC;


-- =============================================================
-- QUERY 11: Subquery - states with above-average housing cost burden
-- Same subquery pattern as Query 10, applied to cost burden rate.
-- Identifies state-year observations where renters are paying
-- more than 30% of income on housing at above-national-average
-- rates. Connects housing stress to broader resilience analysis.
-- Output: state, year, cost burden rate. Ordered descending.
-- =============================================================

-- SELECT
--     state_abbreviation,
--     year,
--     cost_burden_rate
-- FROM acs
-- WHERE cost_burden_rate > (SELECT AVG(cost_burden_rate) FROM acs)
-- ORDER BY cost_burden_rate DESC;


-- =============================================================
-- QUERY 12: Regional resilience ranking
-- GROUP BY query aggregating resilience, uninsured rate, and
-- cost burden rate by Census region. Surfaces whether recovery
-- from COVID was geographically concentrated and which regions
-- lagged on composite social resilience.
-- Output: region, avg resilience, avg uninsured, avg cost burden.
--         Ordered by resilience descending.
-- =============================================================

-- SELECT
--     region,
--     AVG(social_resilience_index) AS avg_resilience,
--     AVG(uninsured_rate)          AS avg_uninsured_rate,
--     AVG(cost_burden_rate)        AS avg_cost_burden_rate
-- FROM acs
-- GROUP BY region
-- ORDER BY avg_resilience DESC;


-- =============================================================
-- QUERY 13: Pre vs Post-COVID divorce, never-married, and widowed
--           rate changes by state (JOIN) - Relationship Section
-- Self-join on state_abbreviation splitting by period.
-- Computes the change in three key relationship status rates per
-- state. Divorce and never-married capture household formation
-- and instability shifts. Widowed rate serves as a COVID
-- mortality signal: states hit hardest by excess deaths should
-- show elevated widowed rates post-2021.
-- Output: state, region, pre/post/change for all three rates.
--         Ordered by divorce change descending. Limited to top 5.
-- =============================================================

-- SELECT
--     pre.state_abbreviation,
--     pre.region,
--     ROUND(AVG(pre.divorce_rate), 4)           AS pre_divorce_rate,
--     ROUND(AVG(post.divorce_rate), 4)          AS post_divorce_rate,
--     ROUND(AVG(post.divorce_rate)
--         - AVG(pre.divorce_rate), 4)           AS divorce_change,
--     ROUND(AVG(pre.never_married_rate), 4)     AS pre_never_married_rate,
--     ROUND(AVG(post.never_married_rate), 4)    AS post_never_married_rate,
--     ROUND(AVG(post.never_married_rate)
--         - AVG(pre.never_married_rate), 4)     AS never_married_change,
--     ROUND(AVG(pre.widowed_rate), 4)           AS pre_widowed_rate,
--     ROUND(AVG(post.widowed_rate), 4)          AS post_widowed_rate,
--     ROUND(AVG(post.widowed_rate)
--         - AVG(pre.widowed_rate), 4)           AS widowed_change
-- FROM acs AS pre
-- JOIN acs AS post
--     ON pre.state_abbreviation = post.state_abbreviation
-- WHERE pre.period  = 'Pre-COVID'
--   AND post.period = 'Post-COVID'
-- GROUP BY pre.state_abbreviation, pre.region
-- ORDER BY divorce_change DESC
-- LIMIT 5;
