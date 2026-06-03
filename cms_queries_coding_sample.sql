/* data was loaded accounting for the fact that * represent NULL values, converted to NULL */
/* =============================================================
   CMS Medicare Geographic Variation Public Use File (2024)
   National, State and County level data

   This script explores geographic variation in Medicare spending using the CMS Medicare Geographic Variation data.
   Analysis includes data quality checks, per-beneficiary cost calculations, comparing of actual versus
   standardized spending, and a final query looking at which states have the highest variation in spending between
   counties and how state average spending per beneficiary costs compare to the national average.

   SOURCE: Centers for Medicare and Medicaid Services (CMS)

   NOTE: CMS suppress values as *, these values were converted to NULL upon loading of the data, so there is no
   code to resolve these values.
   ============================================================= */

/* -------------------------------------------------------------
    create views for just 2024 data at the county and state level
   ------------------------------------------------------------- */
DROP VIEW IF EXISTS county_data_2024;
CREATE VIEW county_data_2024 AS
    SELECT *,
           -- divide place into state code and county name
           substring(BENE_GEO_DESC, 1, 2) AS STATE_CODE,
           substring(BENE_GEO_DESC, 4) AS COUNTY
    FROM Medicare_GV_by_National_State_County_2024
    WHERE year = 2024 AND BENE_GEO_LVL = 'County';

DROP VIEW IF EXISTS all_state_data_2024;
CREATE VIEW all_state_data_2024 AS
    SELECT *
    FROM Medicare_GV_by_National_State_County_2024
    WHERE year = 2024
      AND BENE_GEO_LVL = 'State'
      AND BENE_AGE_LVL = 'All';

/* -------------------------------------------------------------
    check for null/missing values in important fields
   ------------------------------------------------------------- */
-- see how many rows have null values in total beneficiaries and total costs
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE BENES_TOTAL_CNT IS NULL) AS benes_null,
    COUNT(*) FILTER (WHERE TOT_MDCR_PYMT_AMT IS NULL) AS tot_payment_null,
    COUNT(*) FILTER (WHERE TOT_MDCR_STDZD_PYMT_AMT IS NULL) AS tot_payment_stand_null
FROM Medicare_GV_by_National_State_County_2024
WHERE YEAR = 2024;

-- see if total of nulls with benefits and total payments are the same, indicates missing values are aligning
-- in the same place
SELECT COUNT(*) FILTER (WHERE YEAR = 2024) AS total_nulls
FROM Medicare_GV_by_National_State_County_2024
WHERE BENES_TOTAL_CNT IS NULL
  AND TOT_MDCR_PYMT_AMT IS NULL
  AND TOT_MDCR_STDZD_PYMT_AMT IS NULL;
-- count is about the same in the previous query, so more than likely that the null values exist in the same places

-- here is the county with no total cost values if it needs to be looked into
-- SELECT BENE_GEO_DESC, BENES_TOTAL_CNT, TOT_MDCR_PYMT_AMT, TOT_MDCR_STDZD_PYMT_AMT
-- FROM Medicare_GV_by_National_State_County_2024
-- WHERE YEAR = 2024
--   AND BENES_TOTAL_CNT IS NOT NULL
--   AND TOT_MDCR_PYMT_AMT IS NULL
--   AND TOT_MDCR_STDZD_PYMT_AMT IS NULL;

-- get counts of null values by state level to see if any states have more counties with null values than others
-- see if it's more of a pattern or more random
SELECT STATE_CODE, COUNT(*)
FROM county_data_2024
WHERE TOT_MDCR_PYMT_AMT IS NULL
    OR BENES_TOTAL_CNT IS NULL
GROUP BY STATE_CODE;

-- check that there is one row per geography level (i.e., no repeats in any data) expect that COUNT is the same
-- as COUNT DISTINCT
SELECT
    BENE_GEO_LVL,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT BENE_GEO_DESC) AS total_distinct_rows
FROM Medicare_GV_by_National_State_County_2024
WHERE YEAR = 2024
  -- national and state levels are broken down by age categories
  AND BENE_AGE_LVL = 'All'
GROUP BY BENE_GEO_LVL
ORDER BY BENE_GEO_LVL;

        /* output:
           county: 3197 and 3197
           national: 1, 1
           state: 55, 55
         */

/* -------------------------------------------------------------
    - Per-beneficiary spending (standardized costs / beneficiary count)
        cost / beneficiary count
    - Utilization rates (e.g., ED visits per 1,000 beneficiaries)
    - Ranking actual vs. standardized costs to estimate risk of spending per state/geography
   ------------------------------------------------------------- */
-- standardized cost per beneficiary per state
SELECT BENE_GEO_DESC,
       ROUND((TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT),2) AS per_bene_spend
FROM all_state_data_2024
WHERE TOT_MDCR_STDZD_PYMT_AMT IS NOT NULL
    AND BENES_TOTAL_CNT IS NOT NULL
ORDER BY per_bene_spend DESC;

-- if you want to look at counties in each state, remove comment and use state code
-- or, just leave the WHERE statement commented out to see all counties
SELECT STATE_CODE,
       COUNTY,
       ROUND((TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT),2) AS per_bene_spend_county
FROM county_data_2024
WHERE TOT_MDCR_STDZD_PYMT_AMT IS NOT NULL
    AND BENES_TOTAL_CNT IS NOT NULL
    AND STATE_CODE = 'CA'
ORDER BY per_bene_spend_county DESC;

-- compare actual to standardized costs per state and county to see where spending is higher than the standardized
-- cost (costing more money)
SELECT BENE_GEO_DESC,
       ROUND(TOT_MDCR_PYMT_AMT / TOT_MDCR_STDZD_PYMT_AMT,2) AS cost_difference
FROM all_state_data_2024
WHERE TOT_MDCR_PYMT_AMT IS NOT NULL
    AND TOT_MDCR_STDZD_PYMT_AMT IS NOT NULL
ORDER BY cost_difference DESC;

-- if you want to look at counties in each state, comment out code and use state code
-- can leave WHERE statement commented out if you want to look at all counties
SELECT STATE_CODE,
       COUNTY,
       ROUND(TOT_MDCR_PYMT_AMT / TOT_MDCR_STDZD_PYMT_AMT, 2) AS cost_difference_county
FROM county_data_2024
WHERE TOT_MDCR_PYMT_AMT IS NOT NULL
    AND TOT_MDCR_STDZD_PYMT_AMT IS NOT NULL
    AND STATE_CODE = 'WI'
ORDER BY cost_difference_county DESC;

/* -------------------------------------------------------------
   compare state vs. county total values of costs (to see how far off the state totals are,
   state-level rankings by total cost vs. standardized cost
   ------------------------------------------------------------- */

-- count total cost per state based on county data, then join with state table to compare rollup to state value
WITH total_states AS (
    SELECT STATE_CODE, BENE_GEO_DESC,
           SUM(TOT_MDCR_STDZD_PYMT_AMT) AS county_standard
    FROM county_data_2024
    GROUP BY STATE_CODE
)

SELECT TS.STATE_CODE,
       ST.BENE_GEO_DESC,
       TS.county_standard,
       ST.TOT_MDCR_STDZD_PYMT_AMT,
       -- this 0.01 is an arbitrary value, can change calculation
       CASE WHEN ((ST.TOT_MDCR_STDZD_PYMT_AMT - TS.county_standard) / ST.TOT_MDCR_STDZD_PYMT_AMT) > 0.01
           THEN 'Notable Difference'
       ELSE 'Not different' END AS Difference
FROM total_states TS
JOIN all_state_data_2024 ST
    ON TS.STATE_CODE = ST.BENE_GEO_DESC
ORDER BY TS.STATE_CODE;

-- ranking states by actual vs. standardized costs, getting quartiles for cost ratios
SELECT state,
       cost_ratio,
       -- ranking
       RANK() OVER (ORDER BY cost_ratio DESC) AS rank_stand_spending,
       -- split into quartiles
       NTILE(4) OVER (ORDER BY cost_ratio DESC) AS quartile_stand_spending,
       -- percentile ranking
       ROUND((PERCENT_RANK() OVER (ORDER BY cost_ratio)) * 100) AS perc_rank
FROM (
    SELECT BENE_GEO_DESC AS state,
           ROUND(TOT_MDCR_PYMT_AMT / TOT_MDCR_STDZD_PYMT_AMT,2) AS cost_ratio
    FROM all_state_data_2024
    WHERE TOT_MDCR_PYMT_AMT IS NOT NULL
        AND TOT_MDCR_STDZD_PYMT_AMT IS NOT NULL
) AS states_ratios
ORDER BY rank_stand_spending;

/* -------------------------------------------------------------
    Final 'output:
        Spending gap between highest and lowest cost counties in each state, and which have the most variation?
        Rank states by difference between average state cost and national cost and largest cost difference
        between counties
   ------------------------------------------------------------- */
-- get spending per beneficiary nationally
DROP VIEW IF EXISTS national_cost_data;
CREATE VIEW national_cost_data AS
    SELECT TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT AS national_cost_per_bene
    FROM Medicare_GV_by_National_State_County_2024
    WHERE BENE_GEO_DESC = 'National'
      AND YEAR = 2024
      AND BENE_AGE_LVL = 'All';

-- compare highest and lowest standardized cost per beneficiary by county in each state
WITH state_cost_per_bene AS (
    SELECT STATE_CODE,
           COUNTY,
           BENE_GEO_DESC,
           TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT                                     AS stand_cost_per_bene,
           -- get average, maximum, and minimum for each state based on county level data
           AVG(TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT) OVER (PARTITION BY STATE_CODE) AS overall_state_avg_cost,
           MAX(TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT) OVER (PARTITION BY STATE_CODE) AS max_cost_per_bene,
           MIN(TOT_MDCR_STDZD_PYMT_AMT / BENES_TOTAL_CNT) OVER (PARTITION BY STATE_CODE) AS min_cost_per_bene
    FROM county_data_2024
    WHERE BENES_TOTAL_CNT IS NOT NULL
        AND TOT_MDCR_STDZD_PYMT_AMT IS NOT NULL
)

-- are states with high variation in spending also high-spending states overall? (compare to national cost per bene)
SELECT STATE_CODE                                                                     AS State,
       COUNT(SC.COUNTY)                                                               AS num_counties,
       ROUND(SC.max_cost_per_bene, 2)                                                 AS max_cost_per_bene,
       ROUND(SC.min_cost_per_bene, 2)                                                 AS min_cost_per_bene,
       ROUND(SC.max_cost_per_bene - SC.min_cost_per_bene, 2)                          AS cost_per_bene_difference,
       ROUND(SC.overall_state_avg_cost, 2)                                            AS overall_state_avg_cost,
       ROUND(NC.national_cost_per_bene, 2)                                            AS national_cost_per_bene,
       ROUND(SC.overall_state_avg_cost - NC.national_cost_per_bene, 2)                AS cost_difference_from_nat,
       -- in the ORDER BY statement, you can sort by either of these ranks depending on what initial comparisons you
       -- want to look at
       RANK() OVER (ORDER BY overall_state_avg_cost - NC.national_cost_per_bene DESC) AS cost_difference_from_nat_rank,
       RANK() OVER (ORDER BY max_cost_per_bene - min_cost_per_bene DESC)              AS max_county_cost_difference_rank
FROM state_cost_per_bene AS SC
CROSS JOIN national_cost_data NC
GROUP BY STATE_CODE
ORDER BY cost_difference_from_nat_rank;