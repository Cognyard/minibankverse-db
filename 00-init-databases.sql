-- =============================================================
-- Bootstrap: create one database per service (database-per-service)
-- Runs first (00-) via /docker-entrypoint-initdb.d on a fresh volume.
-- =============================================================

CREATE DATABASE auth_db;
CREATE DATABASE customer_db;
CREATE DATABASE account_db;
CREATE DATABASE beneficiary_db;
CREATE DATABASE transaction_db;
CREATE DATABASE notification_db;
CREATE DATABASE audit_db;
