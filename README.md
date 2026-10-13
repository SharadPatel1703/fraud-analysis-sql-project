# Fraud Detection Analysis in SQL (MySQL 8.0)

A portfolio project that uses SQL to look for fraud patterns in a **synthetic** card-transaction dataset (generated with Python Faker, with fraud patterns deliberately injected).

## What is in this repo

| File | Contents |
|------|----------|
| `sql/01_schema.sql` | Database and 4 related tables: `customers`, `merchants`, `transactions`, `fraud_flags` (primary keys, foreign keys, indexes) |
| `sql/02_data_import_and_verification.sql` | CSV import statements and record-count checks |
| `sql/03_exploratory_analysis.sql` | Dataset overview, amount distribution, customer, merchant, time and device profiles |
| `sql/04_fraud_detection.sql` | Five detection approaches: high-amount z-score, velocity (5+ transactions in an hour), geographic anomaly, unusual hours, high-risk merchants |
| `sql/05_advanced_analytics.sql` | Customer risk score, time-series trends, cohort analysis, precision/recall query |
| `sql/06_stored_procedures.sql` | 3 stored procedures (daily summary, customer risk check, pattern detection) |
| `sql/07_views.sql` | 4 reporting views |
| `sql/08_optimization.sql` | Composite indexes and `EXPLAIN ANALYZE` check |

## SQL techniques used

Multi-table joins, CTEs, window functions (`ROW_NUMBER`, `COUNT/SUM/AVG ... OVER`), correlated subqueries, aggregate and statistical functions (`AVG`, `STDDEV`), date/time functions, stored procedures, views, indexing.

## Data

The dataset is synthetic: roughly 50,000 transactions across 1,000 customers and 200 merchants, with about 6% flagged as fraud. The CSV files are not included in this repository.

## Limitations

- The data is synthetic and the fraud patterns were injected by design, so detection results here say little about real-world performance.
- Fraud is rare (about 6%), so overall accuracy is a misleading metric: a model that flags nothing would score about 94%. Precision and recall are the measures to use, and the query for them is in `sql/05_advanced_analytics.sql`.

## Author

Sharad Patel, https://github.com/SharadPatel1703
