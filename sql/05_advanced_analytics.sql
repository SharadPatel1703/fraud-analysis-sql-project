-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- ============================================
-- ADVANCED ANALYTICS 1: Customer Risk Score
-- ============================================

WITH customer_behavior AS (
    SELECT 
        customer_id,
        COUNT(*) AS total_transactions,
        SUM(is_fraud) AS historical_frauds,
        ROUND(AVG(amount), 2) AS avg_transaction,
        ROUND(STDDEV(amount), 2) AS amount_volatility,
        COUNT(DISTINCT location) AS unique_locations,
        COUNT(DISTINCT merchant_id) AS unique_merchants,
        COUNT(DISTINCT DATE(transaction_date)) AS active_days,
        SUM(CASE WHEN HOUR(transaction_date) BETWEEN 0 AND 5 OR HOUR(transaction_date) = 23 
                 THEN 1 ELSE 0 END) AS late_night_transactions,
        MAX(amount) AS max_transaction
    FROM transactions
    WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY customer_id
),
risk_scoring AS (
    SELECT 
        c.customer_id,
        c.name,
        c.location,
        c.account_type,
        c.credit_score,
        c.age,
        cb.total_transactions,
        cb.historical_frauds,
        cb.avg_transaction,
        cb.unique_locations,
        cb.late_night_transactions,
        -- Risk score calculation (0-100)
        LEAST(100, 
            (cb.historical_frauds * 15) +  -- Historical fraud weight
            (CASE WHEN cb.amount_volatility > cb.avg_transaction * 2 THEN 15 ELSE 0 END) +
            (CASE WHEN cb.unique_locations > 5 THEN 15 
                  WHEN cb.unique_locations > 3 THEN 10 
                  ELSE 0 END) +
            (CASE WHEN cb.late_night_transactions > 10 THEN 15 
                  WHEN cb.late_night_transactions > 5 THEN 10 
                  ELSE 0 END) +
            (CASE WHEN c.credit_score < 600 THEN 15 
                  WHEN c.credit_score < 700 THEN 10 
                  ELSE 0 END) +
            (CASE WHEN cb.max_transaction > cb.avg_transaction * 10 THEN 10 ELSE 0 END)
        ) AS risk_score
    FROM customers c
    LEFT JOIN customer_behavior cb ON c.customer_id = cb.customer_id
    WHERE cb.total_transactions IS NOT NULL
)
SELECT 
    customer_id,
    name,
    location,
    account_type,
    credit_score,
    total_transactions,
    historical_frauds,
    avg_transaction,
    unique_locations,
    late_night_transactions,
    risk_score,
    CASE 
        WHEN risk_score >= 70 THEN 'Critical Risk'
        WHEN risk_score >= 50 THEN 'High Risk'
        WHEN risk_score >= 30 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_category
FROM risk_scoring
ORDER BY risk_score DESC
LIMIT 100;

-- ============================================
-- ADVANCED ANALYTICS 2: Time Series Trends
-- ============================================

-- Monthly fraud trends
SELECT 
    DATE_FORMAT(transaction_date, '%Y-%m') AS month,
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate,
    ROUND(AVG(amount), 2) AS avg_amount,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS fraud_loss
FROM transactions
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY month;

-- Day of week patterns
SELECT 
    DAYNAME(transaction_date) AS day_of_week,
    DAYOFWEEK(transaction_date) AS day_number,
    COUNT(*) AS transaction_count,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate,
    ROUND(AVG(amount), 2) AS avg_amount
FROM transactions
GROUP BY DAYNAME(transaction_date), DAYOFWEEK(transaction_date)
ORDER BY day_number;

-- Hourly distribution
SELECT 
    HOUR(transaction_date) AS hour,
    COUNT(*) AS transaction_count,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate,
    ROUND(AVG(amount), 2) AS avg_amount
FROM transactions
GROUP BY HOUR(transaction_date)
ORDER BY hour;

-- Rolling 7-day fraud rate
WITH daily_stats AS (
    SELECT 
        DATE(transaction_date) AS transaction_day,
        COUNT(*) AS daily_transactions,
        SUM(is_fraud) AS daily_frauds,
        ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS daily_fraud_rate
    FROM transactions
    GROUP BY DATE(transaction_date)
)
SELECT 
    transaction_day,
    daily_transactions,
    daily_frauds,
    daily_fraud_rate,
    ROUND(AVG(daily_fraud_rate) OVER (
        ORDER BY transaction_day 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_fraud_rate
FROM daily_stats
ORDER BY transaction_day;

-- ============================================
-- ADVANCED ANALYTICS 3: Cohort Analysis
-- ============================================

WITH customer_cohorts AS (
    SELECT 
        c.customer_id,
        DATE_FORMAT(c.registration_date, '%Y-%m') AS cohort_month,
        c.location,
        c.credit_score
    FROM customers c
),
cohort_metrics AS (
    SELECT 
        cc.cohort_month,
        COUNT(DISTINCT cc.customer_id) AS cohort_size,
        COUNT(t.transaction_id) AS total_transactions,
        SUM(t.is_fraud) AS fraud_count,
        ROUND(AVG(t.amount), 2) AS avg_transaction,
        ROUND(SUM(t.amount), 2) AS total_volume,
        COUNT(DISTINCT CASE WHEN t.transaction_id IS NOT NULL THEN cc.customer_id END) AS active_customers
    FROM customer_cohorts cc
    LEFT JOIN transactions t ON cc.customer_id = t.customer_id
    GROUP BY cc.cohort_month
)
SELECT 
    cohort_month,
    cohort_size,
    active_customers,
    ROUND(active_customers * 100.0 / cohort_size, 2) AS activation_rate,
    total_transactions,
    ROUND(total_transactions * 1.0 / cohort_size, 2) AS transactions_per_customer,
    fraud_count,
    ROUND(fraud_count * 100.0 / NULLIF(total_transactions, 0), 2) AS fraud_rate,
    avg_transaction,
    total_volume
FROM cohort_metrics
ORDER BY cohort_month;

-- Credit score cohort analysis
SELECT 
    CASE 
        WHEN c.credit_score >= 800 THEN 'Excellent (800+)'
        WHEN c.credit_score >= 740 THEN 'Very Good (740-799)'
        WHEN c.credit_score >= 670 THEN 'Good (670-739)'
        WHEN c.credit_score >= 580 THEN 'Fair (580-669)'
        ELSE 'Poor (<580)'
    END AS credit_tier,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.is_fraud) AS fraud_count,
    ROUND(SUM(t.is_fraud) * 100.0 / COUNT(t.transaction_id), 2) AS fraud_rate,
    ROUND(AVG(t.amount), 2) AS avg_transaction
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY credit_tier
ORDER BY MIN(c.credit_score) DESC;

-- ============================================
-- ADVANCED ANALYTICS 4: Detection Performance
-- ============================================

WITH detection_results AS (
    SELECT 
        SUM(CASE WHEN t.is_fraud = 1 AND ff.flag_id IS NOT NULL THEN 1 ELSE 0 END) AS true_positive,
        SUM(CASE WHEN t.is_fraud = 0 AND ff.flag_id IS NOT NULL THEN 1 ELSE 0 END) AS false_positive,
        SUM(CASE WHEN t.is_fraud = 1 AND ff.flag_id IS NULL THEN 1 ELSE 0 END) AS false_negative,
        SUM(CASE WHEN t.is_fraud = 0 AND ff.flag_id IS NULL THEN 1 ELSE 0 END) AS true_negative
    FROM transactions t
    LEFT JOIN fraud_flags ff ON t.transaction_id = ff.transaction_id
)
SELECT 
    true_positive AS TP,
    false_positive AS FP,
    false_negative AS FN,
    true_negative AS TN,
    ROUND(true_positive * 100.0 / NULLIF(true_positive + false_positive, 0), 2) AS precision_percent,
    ROUND(true_positive * 100.0 / NULLIF(true_positive + false_negative, 0), 2) AS recall_percent,
    ROUND((true_positive + true_negative) * 100.0 / 
          NULLIF(true_positive + false_positive + false_negative + true_negative, 0), 2) AS accuracy_percent,
    ROUND(2 * (true_positive * 1.0 / NULLIF(true_positive + false_positive, 0)) * 
              (true_positive * 1.0 / NULLIF(true_positive + false_negative, 0)) /
          NULLIF((true_positive * 1.0 / NULLIF(true_positive + false_positive, 0)) + 
           (true_positive * 1.0 / NULLIF(true_positive + false_negative, 0)), 0), 2) AS f1_score
FROM detection_results;

-- Performance by fraud reason
SELECT 
    ff.reason,
    COUNT(*) AS flags_raised,
    SUM(CASE WHEN t.is_fraud = 1 THEN 1 ELSE 0 END) AS true_frauds,
    ROUND(SUM(CASE WHEN t.is_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS precision_rate
FROM fraud_flags ff
JOIN transactions t ON ff.transaction_id = t.transaction_id
GROUP BY ff.reason
ORDER BY precision_rate DESC;
