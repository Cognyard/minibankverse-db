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
    -- the auth user that owns this customer profile (soft reference, no FK because it lives in
    -- another service's database). One user owns at most one customer.
    user_id     UUID         NOT NULL,
    nik         VARCHAR(32)  NOT NULL,                  -- national ID number
    fullname    VARCHAR(255) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    phone       VARCHAR(32)  NOT NULL,
    status      VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, CLOSED
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_customers_user_id UNIQUE (user_id),
    CONSTRAINT uq_customers_nik    UNIQUE (nik),
    CONSTRAINT uq_customers_email  UNIQUE (email),
    CONSTRAINT uq_customers_phone  UNIQUE (phone),
    CONSTRAINT chk_customers_status CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED'))
);

CREATE INDEX IF NOT EXISTS idx_customers_status  ON customers (status);

-- Databases created before user_id was required and unique. Safe to run again; it fails only if
-- existing rows have no user_id or share one, which must be fixed by hand.
ALTER TABLE customers ALTER COLUMN user_id SET NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_customers_user_id') THEN
        ALTER TABLE customers ADD CONSTRAINT uq_customers_user_id UNIQUE (user_id);
    END IF;
END
$$;

COMMIT;
