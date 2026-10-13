-- MySQL 8.0. Extracted unchanged from the original project write-up.

-- Create database
CREATE DATABASE IF NOT EXISTS fraud_detection;
USE fraud_detection;

-- Customers Table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50),
    registration_date DATE,
    location VARCHAR(100),
    age INT,
    credit_score INT,
    INDEX idx_location (location),
    INDEX idx_registration_date (registration_date)
);

-- Merchants Table
CREATE TABLE merchants (
    merchant_id INT PRIMARY KEY,
    merchant_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    risk_level VARCHAR(20),
    INDEX idx_category (category),
    INDEX idx_risk_level (risk_level)
);

-- Transactions Table
CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    merchant_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    transaction_date DATETIME NOT NULL,
    transaction_type VARCHAR(20),
    location VARCHAR(100),
    device_used VARCHAR(50),
    is_fraud TINYINT(1) DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id),
    INDEX idx_customer_id (customer_id),
    INDEX idx_merchant_id (merchant_id),
    INDEX idx_transaction_date (transaction_date),
    INDEX idx_is_fraud (is_fraud),
    INDEX idx_amount (amount),
    INDEX idx_location (location)
);

-- Fraud Flags Table
CREATE TABLE fraud_flags (
    flag_id INT PRIMARY KEY,
    transaction_id INT NOT NULL,
    flag_date DATETIME NOT NULL,
    reason TEXT,
    verified BOOLEAN,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    INDEX idx_transaction_id (transaction_id),
    INDEX idx_flag_date (flag_date),
    INDEX idx_verified (verified)
);
