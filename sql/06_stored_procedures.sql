-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- ============================================
-- STORED PROCEDURE 1: Daily Report
-- ============================================

DELIMITER //

CREATE PROCEDURE daily_fraud_summary(IN report_date DATE)
BEGIN
    -- Summary metrics
    SELECT 
        report_date AS report_for_date,
        COUNT(*) AS total_transactions,
        SUM(is_fraud) AS fraud_count,
        ROUND(SUM(is_fraud) * 100.0 / COUNT(*), 2) AS fraud_rate,
        ROUND(SUM(amount), 2) AS total_volume,
        ROUND(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 2) AS fraud_loss
    FROM transactions
    WHERE DATE(transaction_date) = report_date;
    
    -- Top flagged transactions
    SELECT 
        t.transaction_id,
        c.name AS customer_name,
        t.amount,
        TIME(t.transaction_date) AS transaction_time,
        m.merchant_name,
        ff.reason
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    JOIN merchants m ON t.merchant_id = m.merchant_id
    LEFT JOIN fraud_flags ff ON t.transaction_id = ff.transaction_id
    WHERE DATE(t.transaction_date) = report_date
      AND t.is_fraud = 1
    ORDER BY t.amount DESC
    LIMIT 10;
END //

DELIMITER ;

-- Usage: CALL daily_fraud_summary('2024-10-15');

-- ============================================
-- STORED PROCEDURE 2: Customer Risk Check
-- ============================================

DELIMITER //

CREATE PROCEDURE assess_customer_risk(IN customer_id_param INT)
BEGIN
    -- Customer summary
    SELECT 
        c.customer_id,
        c.name,
        c.location,
        c.credit_score,
        COUNT(t.transaction_id) AS total_transactions,
        SUM(t.is_fraud) AS historical_frauds,
        ROUND(AVG(t.amount), 2) AS avg_transaction,
        COUNT(DISTINCT t.location) AS unique_locations,
        MAX(t.transaction_date) AS last_transaction_date,
        LEAST(100, 
            (SUM(t.is_fraud) * 15) +
            (CASE WHEN COUNT(DISTINCT t.location) > 5 THEN 15 ELSE 0 END) +
            (CASE WHEN c.credit_score < 600 THEN 15 ELSE 0 END)
        ) AS risk_score
    FROM customers c
    LEFT JOIN transactions t ON c.customer_id = t.customer_id
    WHERE c.customer_id = customer_id_param
    GROUP BY c.customer_id, c.name, c.location, c.credit_score;
    
    -- Recent activities
    SELECT 
        t.transaction_id,
        t.amount,
        t.transaction_date,
        m.merchant_name,
        t.location,
        CASE WHEN ff.flag_id IS NOT NULL THEN 'Flagged' ELSE 'Normal' END AS status,
        ff.reason
    FROM transactions t
    JOIN merchants m ON t.merchant_id = m.merchant_id
    LEFT JOIN fraud_flags ff ON t.transaction_id = ff.transaction_id
    WHERE t.customer_id = customer_id_param
      AND t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    ORDER BY t.transaction_date DESC
    LIMIT 20;
END //

DELIMITER ;

-- Usage: CALL assess_customer_risk(123);

-- ============================================
-- STORED PROCEDURE 3: Pattern Detection
-- ============================================

DELIMITER //

CREATE PROCEDURE detect_fraud_patterns(IN days_back INT)
BEGIN
    -- High amount anomalies
    SELECT 
        'High Amount Anomaly' AS pattern_type,
        COUNT(DISTINCT t.transaction_id) AS detected_count
    FROM transactions t
    WHERE t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL days_back DAY)
      AND t.amount > (
          SELECT AVG(amount) * 3
          FROM transactions t2
          WHERE t2.customer_id = t.customer_id
      )
    
    UNION ALL
    
    -- Unusual time transactions
    SELECT 
        'Unusual Time',
        COUNT(*)
    FROM transactions
    WHERE (HOUR(transaction_date) BETWEEN 0 AND 5 OR HOUR(transaction_date) = 23)
      AND transaction_date >= DATE_SUB(CURDATE(), INTERVAL days_back DAY)
    
    UNION ALL
    
    -- High-risk merchant transactions
    SELECT 
        'High Risk Merchant',
        COUNT(*)
    FROM transactions t
    JOIN merchants m ON t.merchant_id = m.merchant_id
    WHERE m.risk_level = 'High'
      AND t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL days_back DAY);
END //

DELIMITER ;

-- Usage: CALL detect_fraud_patterns(30);
