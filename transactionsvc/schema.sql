-- =============================================================
-- transactionsvc database schema
-- DB: transaction_db
-- Owns: financial transactions, idempotency keys, outbox events
-- Implements: Idempotency + Outbox pattern (roadmap Phase 6 & Phase 12)
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- transactions
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_no  VARCHAR(50)   NOT NULL,                  -- business reference, human readable
    txn_type      VARCHAR(20)   NOT NULL,                  -- TRANSFER, TOPUP, DEBIT, CREDIT
    from_account  VARCHAR(32),                             -- null for TOPUP/CREDIT into system
    to_account    VARCHAR(32),                             -- null for pure DEBIT
    amount        NUMERIC(20,2) NOT NULL,
    currency      CHAR(3)       NOT NULL DEFAULT 'IDR',
    status        VARCHAR(20)   NOT NULL DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED, REVERSED
    description   VARCHAR(255),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT uq_transactions_reference_no UNIQUE (reference_no),
    CONSTRAINT chk_transactions_type   CHECK (txn_type IN ('TRANSFER','TOPUP','DEBIT','CREDIT')),
    CONSTRAINT chk_transactions_status CHECK (status IN ('PENDING','SUCCESS','FAILED','REVERSED')),
    CONSTRAINT chk_transactions_amount CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_transactions_from_account ON transactions (from_account);
CREATE INDEX IF NOT EXISTS idx_transactions_to_account   ON transactions (to_account);
CREATE INDEX IF NOT EXISTS idx_transactions_status       ON transactions (status);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at   ON transactions (created_at);

-- -------------------------------------------------------------
-- idempotency_keys
-- Guarantees a client retry does not create duplicate transactions.
-- The Idempotency-Key header maps to one row; the response is cached.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS idempotency_keys (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key  VARCHAR(255) NOT NULL,
    request_hash     VARCHAR(255) NOT NULL,                 -- hash of the request payload
    transaction_id   UUID,                                  -- resulting transaction, once created
    response_body    JSONB,                                 -- cached response for replay
    status_code      INT,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at       TIMESTAMPTZ,

    CONSTRAINT uq_idempotency_key UNIQUE (idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_expires_at ON idempotency_keys (expires_at);

-- -------------------------------------------------------------
-- outbox_events
-- Transactional outbox: events written in the same DB tx as the
-- transaction, then relayed to Kafka by a publisher worker.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS outbox_events (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id  UUID         NOT NULL,                    -- e.g. transaction id
    event_type    VARCHAR(50)  NOT NULL,                    -- TRANSFER_SUCCESS, TRANSFER_FAILED
    topic         VARCHAR(100) NOT NULL,                    -- target kafka topic
    payload       JSONB        NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'PENDING',  -- PENDING, PUBLISHED, FAILED
    retry_count   INT          NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    published_at  TIMESTAMPTZ,

    CONSTRAINT chk_outbox_status CHECK (status IN ('PENDING','PUBLISHED','FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox_events (status, created_at);

COMMIT;
