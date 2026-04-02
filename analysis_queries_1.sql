-- ============================================================
--  BANK TRANSACTION ANALYSIS — 10 PORTFOLIO QUERIES
--  SQL Server / SSMS Version (fully T-SQL compatible)
--  Author: Your Name
-- ============================================================

USE BankAnalysis;
GO


-- ============================================================
--  QUERY 1: TOTAL DEPOSITS VS WITHDRAWALS BY MONTH
--  Skills: CASE WHEN, DATEADD/DATEDIFF, GROUP BY
--  Business Question: How does monthly cash flow look?
-- ============================================================

SELECT
    DATEADD(MONTH, DATEDIFF(MONTH, 0, transaction_date), 0)  AS month,
    SUM(CASE WHEN amount > 0 THEN amount       ELSE 0 END)   AS total_deposits,
    SUM(CASE WHEN amount < 0 THEN ABS(amount)  ELSE 0 END)   AS total_withdrawals,
    SUM(amount)                                               AS net_cash_flow,
    COUNT(*)                                                  AS total_transactions
FROM transactions
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, transaction_date), 0)
ORDER BY month;
GO


-- ============================================================
--  QUERY 2: TOP 5 CUSTOMERS BY TOTAL SPENDING
--  Skills: TOP, JOINs, Aggregation, ORDER BY
--  Business Question: Who are our highest-spending customers?
-- ============================================================

SELECT TOP 5
    c.customer_id,
    c.first_name + ' ' + c.last_name     AS customer_name,
    c.occupation,
    b.city,
    COUNT(t.transaction_id)              AS total_transactions,
    SUM(ABS(t.amount))                   AS total_spent,
    ROUND(AVG(ABS(t.amount)), 2)         AS avg_transaction_size
FROM customers c
JOIN accounts     a ON c.customer_id = a.customer_id
JOIN transactions t ON a.account_id  = t.account_id
JOIN branches     b ON c.branch_id   = b.branch_id
WHERE t.amount < 0
GROUP BY c.customer_id, c.first_name, c.last_name, c.occupation, b.city
ORDER BY total_spent DESC;
GO


-- ============================================================
--  QUERY 3: FRAUD / SUSPICIOUS TRANSACTION REPORT
--  Skills: Filtering, JOINs, CASE WHEN, DATEPART
--  Business Question: Which flagged transactions need investigation?
-- ============================================================

SELECT
    t.transaction_id,
    c.first_name + ' ' + c.last_name     AS customer_name,
    t.transaction_date,
    ABS(t.amount)                         AS amount,
    t.transaction_type,
    t.category,
    t.merchant,
    t.location_city,
    CASE
        WHEN ABS(t.amount) > 5000                THEN 'HIGH RISK'
        WHEN ABS(t.amount) BETWEEN 2000 AND 5000 THEN 'MEDIUM RISK'
        ELSE                                          'LOW RISK'
    END AS risk_level,
    CASE
        WHEN DATEPART(HOUR, t.transaction_date) BETWEEN 0 AND 5
        THEN 'Late Night - Suspicious'
        ELSE 'Normal Hours'
    END AS time_flag
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.is_flagged = 1
ORDER BY ABS(t.amount) DESC;
GO


-- ============================================================
--  QUERY 4: RUNNING BALANCE PER ACCOUNT (WINDOW FUNCTION)
--  Skills: SUM() OVER, PARTITION BY, ORDER BY
--  Business Question: Track running balance per account over time
-- ============================================================

SELECT
    t.account_id,
    c.first_name + ' ' + c.last_name     AS customer_name,
    t.transaction_date,
    t.amount,
    t.transaction_type,
    SUM(t.amount) OVER (
        PARTITION BY t.account_id
        ORDER BY t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.account_id IN (1, 2, 3)
ORDER BY t.account_id, t.transaction_date;
GO


-- ============================================================
--  QUERY 5: CUSTOMER SPENDING BY CATEGORY (PIVOT-STYLE)
--  Skills: CASE WHEN pivot, GROUP BY, multi-column aggregation
--  Business Question: How do customers split spending across categories?
-- ============================================================

SELECT
    c.first_name + ' ' + c.last_name              AS customer_name,
    SUM(CASE WHEN t.category = 'Groceries'  THEN ABS(t.amount) ELSE 0 END) AS groceries,
    SUM(CASE WHEN t.category = 'Travel'     THEN ABS(t.amount) ELSE 0 END) AS travel,
    SUM(CASE WHEN t.category = 'Dining'     THEN ABS(t.amount) ELSE 0 END) AS dining,
    SUM(CASE WHEN t.category = 'Online'     THEN ABS(t.amount) ELSE 0 END) AS online,
    SUM(CASE WHEN t.category = 'ATM'        THEN ABS(t.amount) ELSE 0 END) AS atm_withdrawals,
    SUM(CASE WHEN t.category = 'Utilities'  THEN ABS(t.amount) ELSE 0 END) AS utilities,
    SUM(CASE WHEN t.category = 'Healthcare' THEN ABS(t.amount) ELSE 0 END) AS healthcare,
    SUM(ABS(t.amount))                             AS total_spent
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount < 0
GROUP BY c.first_name, c.last_name
ORDER BY total_spent DESC;
GO


-- ============================================================
--  QUERY 6: BRANCH PERFORMANCE ANALYSIS
--  Skills: Multi-table JOINs, GROUP BY, LEFT JOIN
--  Business Question: Which branches generate the most activity?
-- ============================================================

SELECT
    b.branch_name,
    b.city,
    b.region,
    COUNT(DISTINCT c.customer_id)    AS total_customers,
    COUNT(DISTINCT a.account_id)     AS total_accounts,
    COUNT(t.transaction_id)          AS total_transactions,
    ROUND(SUM(a.balance), 2)         AS total_deposits_held,
    ROUND(AVG(a.balance), 2)         AS avg_account_balance
FROM branches b
LEFT JOIN customers    c ON b.branch_id   = c.branch_id
LEFT JOIN accounts     a ON c.customer_id = a.customer_id
LEFT JOIN transactions t ON a.account_id  = t.account_id
GROUP BY b.branch_id, b.branch_name, b.city, b.region
ORDER BY total_deposits_held DESC;
GO


-- ============================================================
--  QUERY 7: HIGH-VALUE CUSTOMERS AT RISK (CTE)
--  Skills: CTEs, customer tier logic, fraud detection
--  Business Question: Which valuable customers have fraud alerts?
-- ============================================================

WITH customer_value AS (
    SELECT
        c.customer_id,
        c.first_name + ' ' + c.last_name   AS customer_name,
        SUM(a.balance)                      AS total_balance,
        COUNT(DISTINCT a.account_id)        AS num_accounts
    FROM customers c
    JOIN accounts a ON c.customer_id = a.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
flagged_customers AS (
    SELECT DISTINCT a.customer_id
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    WHERE t.is_flagged = 1
)
SELECT
    cv.customer_name,
    ROUND(cv.total_balance, 2)   AS total_balance,
    cv.num_accounts,
    CASE
        WHEN cv.total_balance > 100000 THEN 'Platinum'
        WHEN cv.total_balance > 30000  THEN 'Gold'
        ELSE                                'Standard'
    END AS customer_tier,
    'FRAUD ALERT' AS alert_status
FROM customer_value cv
JOIN flagged_customers fc ON cv.customer_id = fc.customer_id
ORDER BY cv.total_balance DESC;
GO


-- ============================================================
--  QUERY 8: MONTH-OVER-MONTH TRANSACTION GROWTH (LAG)
--  Skills: LAG(), CTEs, percentage change calculation
--  Business Question: Is transaction volume growing month on month?
-- ============================================================

WITH monthly_counts AS (
    SELECT
        DATEADD(MONTH, DATEDIFF(MONTH, 0, transaction_date), 0) AS month,
        COUNT(*)         AS txn_count,
        SUM(ABS(amount)) AS total_volume
    FROM transactions
    GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, transaction_date), 0)
)
SELECT
    month,
    txn_count,
    ROUND(total_volume, 2)                                          AS total_volume,
    LAG(txn_count)    OVER (ORDER BY month)                        AS prev_month_count,
    ROUND(LAG(total_volume) OVER (ORDER BY month), 2)              AS prev_month_volume,
    ROUND(
        CAST(txn_count - LAG(txn_count) OVER (ORDER BY month) AS NUMERIC)
        / NULLIF(LAG(txn_count) OVER (ORDER BY month), 0) * 100
    , 2)                                                            AS txn_growth_pct,
    ROUND(
        CAST(total_volume - LAG(total_volume) OVER (ORDER BY month) AS NUMERIC)
        / NULLIF(LAG(total_volume) OVER (ORDER BY month), 0) * 100
    , 2)                                                            AS volume_growth_pct
FROM monthly_counts
ORDER BY month;
GO


-- ============================================================
--  QUERY 9: RANK CUSTOMERS BY SPENDING WITHIN EACH CITY
--  Skills: RANK() OVER, PARTITION BY
--  Business Question: Who are the top spenders in each city?
-- ============================================================

WITH customer_spending AS (
    SELECT
        c.first_name + ' ' + c.last_name   AS customer_name,
        b.city,
        SUM(ABS(t.amount))                  AS total_spent
    FROM transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
    JOIN branches  b ON c.branch_id   = b.branch_id
    WHERE t.amount < 0
    GROUP BY c.first_name, c.last_name, b.city
)
SELECT
    city,
    customer_name,
    ROUND(total_spent, 2)                                            AS total_spent,
    RANK() OVER (PARTITION BY city ORDER BY total_spent DESC)        AS spending_rank
FROM customer_spending
ORDER BY city, spending_rank;
GO


-- ============================================================
--  QUERY 10: EXECUTIVE KPI SUMMARY DASHBOARD
--  Skills: Multiple CTEs, full business KPI summary
--  Business Question: One-stop snapshot for management reporting
-- ============================================================

WITH kpis AS (
    SELECT
        COUNT(DISTINCT c.customer_id)                                          AS total_customers,
        COUNT(DISTINCT a.account_id)                                           AS total_accounts,
        ROUND(SUM(CASE WHEN a.balance > 0 THEN a.balance ELSE 0 END), 2)      AS total_assets_held,
        COUNT(DISTINCT t.transaction_id)                                       AS total_transactions,
        ROUND(SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END), 2)        AS total_deposits,
        ROUND(SUM(CASE WHEN t.amount < 0 THEN ABS(t.amount) ELSE 0 END), 2)   AS total_withdrawals,
        SUM(CASE WHEN t.is_flagged = 1 THEN 1 ELSE 0 END)                     AS flagged_transactions,
        ROUND(AVG(a.balance), 2)                                               AS avg_account_balance
    FROM customers c
    JOIN accounts     a ON c.customer_id = a.customer_id
    JOIN transactions t ON a.account_id  = t.account_id
)
SELECT
    total_customers,
    total_accounts,
    total_assets_held,
    total_transactions,
    total_deposits,
    total_withdrawals,
    ROUND(total_deposits - total_withdrawals, 2)                               AS net_flow,
    flagged_transactions,
    ROUND(CAST(flagged_transactions AS NUMERIC) / total_transactions * 100, 2) AS fraud_rate_pct,
    avg_account_balance
FROM kpis;
GO
