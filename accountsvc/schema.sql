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

-- -------------------------------------------------------------
-- account_transactions
-- One row per transaction id of transactionsvc that reached accountsvc. The primary key makes
-- ApplyTransaction idempotent: the balance update and this insert share one DB tx.
--   APPLIED: the balances changed; the balances right after it are kept for replays.
--   VOIDED:  ResolveTransaction found nothing applied and blocked the id for good.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS account_transactions (
    transaction_id       UUID          PRIMARY KEY,
    status               VARCHAR(20)   NOT NULL,
    kind                 VARCHAR(20),               -- DEPOSIT, WITHDRAWAL, TRANSFER; null when VOIDED
    debit_account_no     VARCHAR(32),
    credit_account_no    VARCHAR(32),
    amount               NUMERIC(20,2),
    currency             CHAR(3),
    debit_balance_after  NUMERIC(20,2),
    credit_balance_after NUMERIC(20,2),
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_account_transactions_status CHECK (status IN ('APPLIED','VOIDED')),
    CONSTRAINT chk_account_transactions_kind   CHECK (kind IS NULL OR kind IN ('DEPOSIT','WITHDRAWAL','TRANSFER'))
);

COMMIT;
