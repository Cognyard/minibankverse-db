-- =============================================================
-- customersvc database schema
-- DB: customer_db
-- Owns: nasabah (customer) master data
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- customers
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- link back to the auth user that owns this customer profile (soft reference,
    -- no FK because it lives in another service's database)
    user_id     UUID,
    nik         VARCHAR(32)  NOT NULL,                  -- national ID number
    fullname    VARCHAR(255) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    phone       VARCHAR(32)  NOT NULL,
    status      VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, CLOSED
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_customers_nik    UNIQUE (nik),
    CONSTRAINT uq_customers_email  UNIQUE (email),
    CONSTRAINT uq_customers_phone  UNIQUE (phone),
    CONSTRAINT chk_customers_status CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED'))
);

CREATE INDEX IF NOT EXISTS idx_customers_user_id ON customers (user_id);
CREATE INDEX IF NOT EXISTS idx_customers_status  ON customers (status);

COMMIT;
