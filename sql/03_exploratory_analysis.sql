-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- ============================================
-- EDA 1: Dataset Overview
-- ============================================

SELECT 
    'Total Customers' AS metric, 
    COUNT(*) AS value 
FROM customers
UNION ALL
SELECT 'Total Merchants', COUNT(*) FROM merchants
UNION ALL
SELECT 'Total Transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'Fraudulent Transactions', COUNT(*) FROM transactions WHERE is_fraud = 1
UNION ALL
SELECT 'Legitimate Transactions', COUNT(*) FROM transactions WHERE is_fraud = 0;

-- ============================================
-- EDA 2: Transaction Statistics
-- ============================================

SELECT 
    COUNT(*) AS total_transactions,
    ROUND(MIN(amount), 2) AS min_amount,
    ROUND(MAX(amount), 2) AS max_amount,
    ROUND(AVG(amount), 2) AS avg_amount,
    ROUND(STDDEV(amount), 2) AS stddev_amount,
    -- Fraud vs Legitimate comparison
    ROUND(AVG(CASE WHEN is_fraud = 1 THEN amount END), 2) AS avg_fraud_amount,
    ROUND(AVG(CASE WHEN is_fraud = 0 THEN amount END), 2) AS avg_legit_amount
FROM transactions;

-- ============================================
-- EDA 3: Customer Profile Analysis
-- ============================================

SELECT 
    account_type,
    COUNT(*) AS customer_count,
    ROUND(AVG(age), 1) AS avg_age,
    ROUND(AVG(credit_score), 0) AS avg_credit_score,
    -- Transaction behavior
    ROUND(AVG(trans_count), 2) AS avg_transactions_per_customer
FROM customers c
LEFT JOIN (
    SELECT customer_id, COUNT(*) AS trans_count
    FROM transactions
    GROUP BY customer_id
) t ON c.customer_id = t.customer_id
GROUP BY account_type
ORDER BY customer_count DESC;

-- ============================================
-- EDA 4: Merchant Analysis
-- ============================================

SELECT 
    category,
    risk_level,
    COUNT(*) AS merchant_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM merchants
GROUP BY category, risk_level
ORDER BY merchant_count DESC;

-- ============================================
-- EDA 5: Temporal Coverage
-- ============================================

SELECT 
    MIN(transaction_date) AS earliest_transaction,
    MAX(transaction_date) AS latest_transaction,
    DATEDIFF(MAX(transaction_date), MIN(transaction_date)) AS days_covered,
    COUNT(DISTINCT DATE(transaction_date)) AS unique_days,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT DATE(transaction_date)), 2) AS avg_trans_per_day
FROM transactions;

-- ============================================
-- EDA 6: Device & Channel Analysis
-- ============================================

SELECT 
    device_used,
    COUNT(*) AS transaction_count,
    ROUND(AVG(amount), 2) AS avg_transaction_amount,
    SUM(is_fraud) AS fraud_count,
    ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate
FROM transactions
GROUP BY device_used
ORDER BY fraud_rate DESC;
