/* 
================================================================================
PROJECT: CUSTOMER COHORT & RETENTION ANALYSIS
AUTHOR: Y. Rithvesh
DATE: 11-02-2026
PLATFORM: SQLite (DB Browser for SQLite)
DATASET: Online Retail
================================================================================
*/

-- =============================================================================
-- SECTION 1: DATA CLEANING
-- =============================================================================

DROP TABLE IF EXISTS cleaned_transactions;

CREATE TABLE cleaned_transactions AS
SELECT
    "Customer ID" AS customer_id,
    InvoiceDate,
    Quantity,
    Price,
    Quantity * Price AS revenue
FROM transactions
WHERE "Customer ID" IS NOT NULL
  AND Quantity > 0
  AND Price > 0;


-- =============================================================================
-- SECTION 2: COHORT ASSIGNMENT
-- =============================================================================

DROP TABLE IF EXISTS customer_cohorts;

CREATE TABLE customer_cohorts AS
SELECT
    customer_id,
    MIN(strftime('%Y-%m-01', InvoiceDate)) AS cohort_month
FROM cleaned_transactions
GROUP BY customer_id;


-- =============================================================================
-- SECTION 3: MONTHLY CUSTOMER ACTIVITY
-- =============================================================================

DROP TABLE IF EXISTS customer_monthly_activity;

CREATE TABLE customer_monthly_activity AS
SELECT
    customer_id,
    strftime('%Y-%m-01', InvoiceDate) AS order_month,
    SUM(revenue) AS monthly_revenue
FROM cleaned_transactions
GROUP BY customer_id, order_month;


-- =============================================================================
-- SECTION 4: BUILD COHORT DATASET
-- =============================================================================

DROP TABLE IF EXISTS cohort_activity;

CREATE TABLE cohort_activity AS
SELECT
    c.customer_id,
    c.cohort_month,
    m.order_month,
    m.monthly_revenue
FROM customer_cohorts c
JOIN customer_monthly_activity m
ON c.customer_id = m.customer_id;


-- =============================================================================
-- SECTION 5: COHORT INDEX CALCULATION
-- =============================================================================

DROP TABLE IF EXISTS cohort_indexed;

CREATE TABLE cohort_indexed AS
SELECT
    customer_id,
    cohort_month,
    order_month,
    monthly_revenue,
    (
        (CAST(strftime('%Y', order_month) AS INTEGER) -
         CAST(strftime('%Y', cohort_month) AS INTEGER)) * 12
        +
        (CAST(strftime('%m', order_month) AS INTEGER) -
         CAST(strftime('%m', cohort_month) AS INTEGER))
    ) AS cohort_index
FROM cohort_activity;


-- =============================================================================
-- SECTION 6: RETENTION USER COUNTS
-- =============================================================================

DROP TABLE IF EXISTS cohort_user_counts;

CREATE TABLE cohort_user_counts AS
SELECT
    cohort_month,
    cohort_index,
    COUNT(DISTINCT customer_id) AS active_users
FROM cohort_indexed
GROUP BY cohort_month, cohort_index
ORDER BY cohort_month, cohort_index;


-- =============================================================================
-- SECTION 7: RETENTION TABLE (FINAL FOR PYTHON)
-- =============================================================================

DROP TABLE IF EXISTS retention_table;

CREATE TABLE retention_table AS
SELECT
    cohort_month,
    cohort_index,
    active_users,
    ROUND(
        100.0 * active_users /
        FIRST_VALUE(active_users)
        OVER (PARTITION BY cohort_month ORDER BY cohort_index),
        2
    ) AS retention_percentage
FROM cohort_user_counts;


-- =============================================================================
-- SECTION 8: COHORT REVENUE
-- =============================================================================

DROP TABLE IF EXISTS cohort_revenue;

CREATE TABLE cohort_revenue AS
SELECT
    cohort_month,
    cohort_index,
    SUM(monthly_revenue) AS total_revenue
FROM cohort_indexed
GROUP BY cohort_month, cohort_index;


-- =============================================================================
-- SECTION 9: COHORT SIZE
-- =============================================================================

DROP TABLE IF EXISTS cohort_size;

CREATE TABLE cohort_size AS
SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_users
FROM cohort_indexed
WHERE cohort_index = 0
GROUP BY cohort_month;


-- =============================================================================
-- SECTION 10: ARPU
-- =============================================================================

DROP TABLE IF EXISTS cohort_arpu;

CREATE TABLE cohort_arpu AS
SELECT
    r.cohort_month,
    r.cohort_index,
    ROUND(r.total_revenue * 1.0 / s.cohort_users, 2) AS arpu
FROM cohort_revenue r
JOIN cohort_size s
ON r.cohort_month = s.cohort_month;


-- =============================================================================
-- SECTION 11: CUMULATIVE LTV (FINAL FOR PYTHON)
-- =============================================================================

DROP TABLE IF EXISTS cohort_ltv;

CREATE TABLE cohort_ltv AS
SELECT
    cohort_month,
    cohort_index,
    SUM(arpu) OVER (
        PARTITION BY cohort_month
        ORDER BY cohort_index
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_ltv
FROM cohort_arpu;
