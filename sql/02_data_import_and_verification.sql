-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- Enable local file import
SET GLOBAL local_infile = 1;

-- Import customers
LOAD DATA LOCAL INFILE '/path/to/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Import merchants
LOAD DATA LOCAL INFILE '/path/to/merchants.csv'
INTO TABLE merchants
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Import transactions
LOAD DATA LOCAL INFILE '/path/to/transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Import fraud_flags
LOAD DATA LOCAL INFILE '/path/to/fraud_flags.csv'
INTO TABLE fraud_flags
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Check record counts
SELECT 'customers' AS table_name, COUNT(*) AS records FROM customers
UNION ALL
SELECT 'merchants', COUNT(*) FROM merchants
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'fraud_flags', COUNT(*) FROM fraud_flags;

-- Quick data preview
SELECT * FROM transactions LIMIT 10;
