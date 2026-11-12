-- =============================================================
-- beneficiarysvc database schema
-- DB: beneficiary_db
-- Owns: daftar penerima transfer tersimpan (saved transfer recipients)
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- beneficiaries
-- A customer's saved list of transfer destinations.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS beneficiaries (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- soft reference to customersvc.customers.id (no cross-db FK)
    customer_id   UUID         NOT NULL,
    account_no    VARCHAR(32)  NOT NULL,                  -- destination account
    bank_code     VARCHAR(20)  NOT NULL DEFAULT 'INTERNAL', -- INTERNAL or external bank code
    bank_name     VARCHAR(100),
    alias         VARCHAR(100),                           -- user-friendly nickname
    holder_name   VARCHAR(255),                           -- destination account holder name
    is_favorite   BOOLEAN      NOT NULL DEFAULT false,
    status        VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE, DELETED
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT chk_beneficiaries_status CHECK (status IN ('ACTIVE','DELETED')),
    -- a customer should not save the same destination twice
    CONSTRAINT uq_beneficiaries_dest UNIQUE (customer_id, bank_code, account_no)
);

CREATE INDEX IF NOT EXISTS idx_beneficiaries_customer_id ON beneficiaries (customer_id);

COMMIT;
