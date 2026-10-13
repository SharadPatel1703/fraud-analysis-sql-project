-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- ============================================
-- OPTIMIZATION: Additional Indexes
-- ============================================

-- Composite indexes for common queries
CREATE INDEX idx_trans_customer_date ON transactions(customer_id, transaction_date);
CREATE INDEX idx_trans_merchant_date ON transactions(merchant_id, transaction_date);
CREATE INDEX idx_trans_fraud_date ON transactions(is_fraud, transaction_date);
CREATE INDEX idx_trans_amount_fraud ON transactions(amount, is_fraud);

-- Verify indexes
SHOW INDEX FROM transactions;

-- ============================================
-- OPTIMIZATION: Query Performance Check
-- ============================================

-- Analyze query execution plan
EXPLAIN ANALYZE
SELECT 
    t.transaction_id,
    c.name,
    m.merchant_name,
    t.amount
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE t.is_fraud = 1
  AND t.transaction_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- Check table statistics
ANALYZE TABLE transactions;
ANALYZE TABLE customers;
ANALYZE TABLE merchants;
ANALYZE TABLE fraud_flags;
