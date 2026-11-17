-- =============================================================
-- transactionsvc database schema
-- DB: transaction_db
-- Owns: the transaction ledger and its outbox events
-- Idempotency: one row per (initiated_by, idempotency_key); a retried request finds it.
-- Outbox: events are written in the same DB tx as the status change, then relayed to Kafka
--         (Redpanda) by minibankverse-odk/outbox.
-- Safe to run again on an existing database.
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- transactions
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_no     VARCHAR(50)   NOT NULL,                   -- human readable, e.g. TRX20261117A1B2C3D4
    txn_type         VARCHAR(20)   NOT NULL,                   -- DEPOSIT, WITHDRAWAL, TRANSFER
    from_account     VARCHAR(32),                              -- account_no; null for DEPOSIT
    to_account       VARCHAR(32),                              -- account_no; null for WITHDRAWAL
    amount           NUMERIC(20,2) NOT NULL,
    currency         CHAR(3)       NOT NULL DEFAULT 'IDR',
    status           VARCHAR(20)   NOT NULL DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED
    failure_code     VARCHAR(50),                              -- set when FAILED
    description      VARCHAR(255),
    -- user id from the access token (soft reference to authsvc users)
    initiated_by     UUID          NOT NULL,
    -- Idempotency-Key header of the request, and a hash of the request body
    idempotency_key  VARCHAR(100)  NOT NULL,
    request_hash     CHAR(64)      NOT NULL,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_transactions_reference_no UNIQUE (reference_no),
    CONSTRAINT uq_transactions_idempotency  UNIQUE (initiated_by, idempotency_key),
    CONSTRAINT chk_transactions_type   CHECK (txn_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER')),
    CONSTRAINT chk_transactions_status CHECK (status IN ('PENDING','SUCCESS','FAILED')),
    CONSTRAINT chk_transactions_amount CHECK (amount > 0)
);

-- Databases created from the first draft of this file (unused, so empty): add what is new.
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS failure_code    VARCHAR(50);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS initiated_by    UUID         NOT NULL;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100) NOT NULL;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS request_hash    CHAR(64)     NOT NULL;
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS uq_transactions_idempotency;
ALTER TABLE transactions ADD CONSTRAINT uq_transactions_idempotency UNIQUE (initiated_by, idempotency_key);
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS chk_transactions_type;
ALTER TABLE transactions ADD CONSTRAINT chk_transactions_type CHECK (txn_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER'));
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS chk_transactions_status;
ALTER TABLE transactions ADD CONSTRAINT chk_transactions_status CHECK (status IN ('PENDING','SUCCESS','FAILED'));
-- The first draft kept idempotency keys in their own table; they now live on transactions.
DROP TABLE IF EXISTS idempotency_keys;

CREATE INDEX IF NOT EXISTS idx_transactions_from_created ON transactions (from_account, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_to_created   ON transactions (to_account, created_at DESC);
-- the settle worker looks for old PENDING rows
CREATE INDEX IF NOT EXISTS idx_transactions_pending      ON transactions (created_at) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_transactions_created_at   ON transactions (created_at);
-- indexes of the first draft
DROP INDEX IF EXISTS idx_transactions_status;
DROP INDEX IF EXISTS idx_transactions_from_account;
DROP INDEX IF EXISTS idx_transactions_to_account;

-- -------------------------------------------------------------
-- outbox_events (layout required by minibankverse-odk/outbox)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS outbox_events (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id  UUID         NOT NULL,                    -- transaction id; also the Kafka key
    event_type    VARCHAR(50)  NOT NULL,                    -- TRANSACTION_SUCCEEDED, TRANSACTION_FAILED
    topic         VARCHAR(100) NOT NULL,
    payload       JSONB        NOT NULL,                    -- transaction.v1.TransactionEvent as protojson
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',  -- PENDING, PUBLISHED, FAILED
    retry_count   INT          NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at  TIMESTAMPTZ,
    CONSTRAINT chk_outbox_status CHECK (status IN ('PENDING','PUBLISHED','FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_events (status, created_at);

COMMIT;
