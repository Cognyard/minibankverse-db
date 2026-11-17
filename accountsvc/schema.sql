-- =============================================================
-- accountsvc database schema
-- DB: account_db
-- Owns: rekening (account) data, 1 customer -> many accounts
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- accounts
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- soft reference to customersvc.customers.id (no cross-db FK)
    customer_id   UUID         NOT NULL,
    account_no    VARCHAR(32)  NOT NULL,
    account_type  VARCHAR(20)  NOT NULL DEFAULT 'SAVINGS', -- SAVINGS, CHECKING, GIRO
    -- money as NUMERIC to avoid float rounding errors; minor unit handled in app
    balance       NUMERIC(20,2) NOT NULL DEFAULT 0,
    currency      CHAR(3)      NOT NULL DEFAULT 'IDR',
    -- PENDING (giro waiting for approval), ACTIVE, FROZEN, CLOSED (final), REJECTED (final)
    status        VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_accounts_account_no UNIQUE (account_no),
    CONSTRAINT chk_accounts_type      CHECK (account_type IN ('SAVINGS','CHECKING','GIRO')),
    CONSTRAINT chk_accounts_status    CHECK (status IN ('PENDING','ACTIVE','FROZEN','CLOSED','REJECTED')),
    CONSTRAINT chk_accounts_balance   CHECK (balance >= 0)
);

CREATE INDEX IF NOT EXISTS idx_accounts_customer_id ON accounts (customer_id);
CREATE INDEX IF NOT EXISTS idx_accounts_status      ON accounts (status);

-- Databases created before PENDING and REJECTED existed. Safe to run again.
ALTER TABLE accounts DROP CONSTRAINT IF EXISTS chk_accounts_status;
ALTER TABLE accounts ADD CONSTRAINT chk_accounts_status
    CHECK (status IN ('PENDING','ACTIVE','FROZEN','CLOSED','REJECTED'));

COMMIT;
