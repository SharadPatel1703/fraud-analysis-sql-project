-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- ============================================
-- FRAUD DETECTION 1: High Amount Anomalies
-- ============================================

WITH customer_baselines AS (
    SELECT 
        customer_id,
        AVG(amount) AS avg_amount,
        STDDEV(amount) AS stddev_amount
    FROM transactions
    WHERE transaction_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY customer_id
    HAVING COUNT(*) >= 5  -- Minimum transaction history
)
SELECT 
    t.transaction_id,
    t.customer_id,
    c.name AS customer_name,
    t.amount AS transaction_amount,
    cb.avg_amount AS customer_avg_amount,
    ROUND(t.amount / cb.avg_amount, 2) AS amount_ratio,
    ROUND((t.amount - cb.avg_amount) / NULLIF(cb.stddev_amount, 0), 2) AS z_score,
    t.transaction_date,
    t.is_fraud AS actual_fraud,
    m.merchant_name,
    m.category
FROM transactions t
JOIN customer_baselines cb ON t.customer_id = cb.customer_id
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.amount > (cb.avg_amount + 3 * COALESCE(cb.stddev_amount, 0))
ORDER BY amount_ratio DESC
LIMIT 100;

-- ============================================
-- FRAUD DETECTION 2: Velocity Attacks
-- ============================================

WITH transaction_velocity AS (
    SELECT 
        t1.customer_id,
        t1.transaction_id,
        t1.transaction_date,
        t1.amount,
        t1.is_fraud,
        COUNT(t2.transaction_id) AS transactions_in_last_hour
    FROM transactions t1
    LEFT JOIN transactions t2 
        ON t1.customer_id = t2.customer_id
        AND t2.transaction_date BETWEEN 
            DATE_SUB(t1.transaction_date, INTERVAL 1 HOUR) 
            AND t1.transaction_date
    GROUP BY t1.transaction_id, t1.customer_id, t1.transaction_date, t1.amount, t1.is_fraud
    HAVING transactions_in_last_hour >= 5
)
SELECT 
    tv.customer_id,
    c.name,
    c.location,
    tv.transaction_id,
    tv.transaction_date,
    tv.amount,
    tv.transactions_in_last_hour,
    tv.is_fraud AS actual_fraud,
    CASE 
        WHEN tv.transactions_in_last_hour >= 10 THEN 'Critical'
        WHEN tv.transactions_in_last_hour >= 7 THEN 'High'
        ELSE 'Medium'
    END AS risk_level
FROM transaction_velocity tv
JOIN customers c ON tv.customer_id = c.customer_id
ORDER BY tv.transactions_in_last_hour DESC
LIMIT 100;

-- ============================================
-- FRAUD DETECTION 3: Geographic Anomalies
-- ============================================

WITH customer_primary_location AS (
    SELECT 
        customer_id,
        location,
        COUNT(*) AS transaction_count,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS location_rank
    FROM transactions
    GROUP BY customer_id, location
)
SELECT 
    t.transaction_id,
    t.customer_id,
    c.name AS customer_name,
    t.location AS transaction_location,
    cpl.location AS usual_location,
    t.amount,
    t.transaction_date,
    HOUR(t.transaction_date) AS hour_of_day,
    t.is_fraud AS actual_fraud,
    m.merchant_name,
    m.category,
    COUNT(*) OVER (
        PARTITION BY t.customer_id, DATE(t.transaction_date)
    ) AS locations_today
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
JOIN customer_primary_location cpl 
    ON t.customer_id = cpl.customer_id 
    AND cpl.location_rank = 1
WHERE t.location != cpl.location
ORDER BY t.transaction_date DESC
LIMIT 100;

-- ============================================
-- FRAUD DETECTION 4: Unusual Time Patterns
-- ============================================

SELECT 
    t.transaction_id,
    t.customer_id,
    c.name AS customer_name,
    t.amount,
    t.transaction_date,
    HOUR(t.transaction_date) AS transaction_hour,
    CASE 
        WHEN HOUR(t.transaction_date) BETWEEN 0 AND 2 THEN 'Midnight-2AM'
        WHEN HOUR(t.transaction_date) BETWEEN 3 AND 5 THEN '3AM-5AM'
        ELSE '11PM-Midnight'
    END AS time_block,
    t.is_fraud AS actual_fraud,
    m.merchant_name,
    m.category,
    t.device_used
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE HOUR(t.transaction_date) IN (23, 0, 1, 2, 3, 4, 5)
ORDER BY t.amount DESC
LIMIT 100;

-- Fraud rate by hour analysis
SELECT 
    HOUR(transaction_date) AS hour_of_day,
    COUNT(*) AS transaction_count,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate,
    ROUND(AVG(amount), 2) AS avg_amount
FROM transactions
GROUP BY HOUR(transaction_date)
ORDER BY fraud_rate DESC;

-- ============================================
-- FRAUD DETECTION 5: High-Risk Merchant Analysis
-- ============================================

-- Merchant-level fraud analysis
SELECT 
    m.merchant_id,
    m.merchant_name,
    m.category,
    m.risk_level,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.is_fraud) AS fraud_count,
    ROUND(SUM(t.is_fraud) * 100.0 / COUNT(t.transaction_id), 2) AS fraud_rate,
    ROUND(AVG(t.amount), 2) AS avg_transaction,
    ROUND(SUM(CASE WHEN t.is_fraud = 1 THEN t.amount ELSE 0 END), 2) AS total_fraud_amount
FROM merchants m
LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category, m.risk_level
HAVING total_transactions > 10
ORDER BY fraud_rate DESC
LIMIT 30;

-- Category-level risk analysis
SELECT 
    m.category,
    COUNT(DISTINCT m.merchant_id) AS merchant_count,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.is_fraud) AS fraud_count,
    ROUND(SUM(t.is_fraud) * 100.0 / COUNT(t.transaction_id), 2) AS fraud_rate,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount
FROM merchants m
LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.category
ORDER BY fraud_rate DESC;

-- Combined risk factors
SELECT 
    t.transaction_id,
    t.customer_id,
    c.name AS customer_name,
    m.merchant_name,
    m.category,
    m.risk_level,
    t.amount,
    t.transaction_date,
    HOUR(t.transaction_date) AS hour,
    t.is_fraud AS actual_fraud,
    (CASE WHEN m.risk_level = 'High' THEN 1 ELSE 0 END +
     CASE WHEN t.amount > 1000 THEN 1 ELSE 0 END +
     CASE WHEN HOUR(t.transaction_date) BETWEEN 0 AND 5 OR HOUR(t.transaction_date) = 23 THEN 1 ELSE 0 END
    ) AS risk_factors
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE m.risk_level = 'High'
ORDER BY risk_factors DESC, t.amount DESC
LIMIT 100;
