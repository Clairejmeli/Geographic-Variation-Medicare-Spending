# CMS Medicare Geographic Variation: SQL Analysis
**Claire Meli** | Independent Coding Sample | 2026

---

## Overview

This script explores geographic variation in Medicare spending using the CMS Medicare Geographic Variation Public Use File (2024). The analysis moves through four progressive stages: data preparation, data quality assessment, per-beneficiary cost calculations, and a final comparative analysis examining which states have the highest intra-state county spending variation and how state average spending compares to the national benchmark.

**Central question:** Are states with high variation in Medicare spending between counties also high-spending states relative to the national average?

---

## File

| File | Description |
|---|---|
| `cms_queries_coding_sample.sql` | Full analysis script: views, data quality checks, cost calculations, window functions, and final comparative output |

> **Note:** Raw data is not included in this submission. See Data Source below for public download instructions.

---

## Data Source

| Dataset | Source | Description |
|---|---|---|
| Medicare Geographic Variation Public Use File (2024) | [CMS.gov](https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-geographic-variation/gv_puf) | National, state, and county-level Medicare spending and utilization data |

**Data note:** CMS suppresses low-value cells with an asterisk (`*`) to protect beneficiary privacy. These values were converted to `NULL` upon data loading; no additional handling was required in the script.

---

## Analysis Structure

### 1. Data Preparation
Two views are created to isolate 2024 data at the county and state level, and to parse the `BENE_GEO_DESC` field into separate state code and county name columns for easier filtering and grouping downstream.

### 2. Data Quality Checks
Before any analysis, the script assesses:
- Count of NULL values in key fields (beneficiary count, total payments, standardized payments)
- Whether NULLs co-occur across fields (indicating suppressed rows rather than random missingness)
- Distribution of NULLs by state to distinguish systematic from random patterns
- Row uniqueness by geography level to confirm no duplicate records

### 3. Per-Beneficiary Cost Calculations
- Standardized cost per beneficiary at the state and county level
- Actual vs. standardized cost ratio to identify where true spending exceeds expected spending
- Both state- and county-level queries are included, with county queries filterable by state code

### 4. State vs. County Rollup Validation
A CTE aggregates county-level costs to the state level and compares the rollup against the reported state total, flagging states where the difference exceeds 1% as a data reconciliation check.

### 5. Final Output: Spending Variation & National Comparison
Window functions (`RANK`, `NTILE`, `PERCENT_RANK`, `AVG/MAX/MIN OVER PARTITION BY`) are used to:
- Rank states by actual vs. standardized cost ratio and assign quartiles
- Calculate the min, max, and average standardized cost per beneficiary within each state
- Compare each state's average cost per beneficiary to the national benchmark
- Rank states simultaneously by intra-state county variation and deviation from national average

---

## Key SQL Features Demonstrated

| Feature | Where Used |
|---|---|
| Views | Data preparation, national cost benchmark |
| CTEs | State rollup validation, final output |
| Window functions | `RANK`, `NTILE`, `PERCENT_RANK`, `AVG/MAX/MIN OVER PARTITION BY` |
| Aggregation | `SUM`, `COUNT`, `ROUND`, `GROUP BY` |
| NULL handling | Data quality checks, filtered calculations |
| CROSS JOIN | Joining national benchmark to state-level results |
| CASE WHEN | Flagging notable differences in rollup validation |
| Subqueries | Cost ratio ranking query |

---

## Requirements

**Database:** SQLite (or any standard SQL environment — queries use standard SQL with minor SQLite-specific syntax)

**To run:**
1. Download the CMS Medicare Geographic Variation Public Use File from the link above
2. Load the CSV into a table named `Medicare_GV_by_National_State_County_2024`
3. Convert `*` values to `NULL` on import
4. Run queries sequentially — views must be created before dependent queries are executed
