-- =============================================================
-- Load each service schema into its own database.
-- Runs after 00-init-databases.sql. Uses psql \connect + \i.
-- Paths are relative to this file's mount point inside the container
-- (/docker-entrypoint-initdb.d), which maps to the database/ folder.
-- =============================================================

\connect auth_db
\i /docker-entrypoint-initdb.d/authsvc/schema.sql

\connect customer_db
\i /docker-entrypoint-initdb.d/customersvc/schema.sql

\connect account_db
\i /docker-entrypoint-initdb.d/accountsvc/schema.sql

\connect beneficiary_db
\i /docker-entrypoint-initdb.d/beneficiarysvc/schema.sql

\connect transaction_db
\i /docker-entrypoint-initdb.d/transactionsvc/schema.sql

\connect notification_db
\i /docker-entrypoint-initdb.d/notificationsvc/schema.sql

\connect audit_db
\i /docker-entrypoint-initdb.d/auditsvc/schema.sql
