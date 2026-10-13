-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- ============================================
-- VIEW 1: High-Risk Transactions
-- ============================================

CREATE OR REPLACE VIEW vw_high_risk_transactions AS
SELECT 
    t.transaction_id,
    t.customer_id,
    c.name AS customer_name,
    c.credit_score,
    t.merchant_id,
    m.merchant_name,
    m.category,
    m.risk_level AS merchant_risk,
    t.amount,
    t.transaction_date,
    t.location,
    t.device_used,
    t.is_fraud,
    CASE WHEN ff.flag_id IS NOT NULL THEN 'Flagged' ELSE 'Not Flagged' END AS flag_status,
    ff.reason AS flag_reason,
    -- Risk indicators
    CASE WHEN t.amount > 1000 THEN 1 ELSE 0 END AS high_amount_flag,
    CASE WHEN HOUR(t.transaction_date) BETWEEN 0 AND 5 OR HOUR(t.transaction_date) = 23 
         THEN 1 ELSE 0 END AS unusual_time_flag,
    CASE WHEN m.risk_level = 'High' THEN 1 ELSE 0 END AS high_risk_merchant_flag
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
LEFT JOIN fraud_flags ff ON t.transaction_id = ff.transaction_id
WHERE t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  AND (t.amount > 1000 
       OR m.risk_level = 'High' 
       OR HOUR(t.transaction_date) BETWEEN 0 AND 5 
       OR HOUR(t.transaction_date) = 23);

-- ============================================
-- VIEW 2: Customer Summary
-- ============================================

CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT 
    c.customer_id,
    c.name,
    c.account_type,
    c.location,
    c.credit_score,
    c.age,
    COUNT(t.transaction_id) AS total_transactions,
    ROUND(AVG(t.amount), 2) AS avg_transaction_amount,
    ROUND(SUM(t.amount), 2) AS lifetime_value,
    SUM(t.is_fraud) AS fraud_count,
    ROUND(SUM(t.is_fraud) * 100.0 / NULLIF(COUNT(t.transaction_id), 0), 2) AS fraud_rate,
    COUNT(DISTINCT t.merchant_id) AS unique_merchants,
    COUNT(DISTINCT t.location) AS unique_locations,
    MIN(t.transaction_date) AS first_transaction,
    MAX(t.transaction_date) AS last_transaction,
    DATEDIFF(MAX(t.transaction_date), MIN(t.transaction_date)) AS customer_tenure_days
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.name, c.account_type, c.location, c.credit_score, c.age;

-- ============================================
-- VIEW 3: Merchant Performance
-- ============================================

CREATE OR REPLACE VIEW vw_merchant_performance AS
SELECT 
    m.merchant_id,
    m.merchant_name,
    m.category,
    m.risk_level,
    COUNT(t.transaction_id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_revenue,
    ROUND(AVG(t.amount), 2) AS avg_transaction,
    SUM(t.is_fraud) AS fraud_count,
    ROUND(SUM(t.is_fraud) * 100.0 / NULLIF(COUNT(t.transaction_id), 0), 2) AS fraud_rate,
    COUNT(DISTINCT t.customer_id) AS unique_customers,
    ROUND(SUM(CASE WHEN t.is_fraud = 1 THEN t.amount ELSE 0 END), 2) AS fraud_loss
FROM merchants m
LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.category, m.risk_level;

-- ============================================
-- VIEW 4: Daily Transaction Summary
-- ============================================

CREATE OR REPLACE VIEW vw_daily_summary AS
SELECT 
    DATE(transaction_date) AS transaction_date,
    COUNT(*) AS transaction_count,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate,
    ROUND(AVG(amount), 2) AS avg_amount,
    ROUND(SUM(amount), 2) AS total_volume,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(DISTINCT merchant_id) AS active_merchants
FROM transactions
GROUP BY DATE(transaction_date);
