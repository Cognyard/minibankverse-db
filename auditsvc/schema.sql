-- =============================================================
-- auditsvc database schema
-- DB: audit_db
-- Owns: audit trail records produced via the common.v1.audit_trail option
-- Format of the option: "MODULE,ACTIVITY_NAME" (e.g. "AUTH,LOGIN")
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- audit_logs
-- Append-only table. Rows are never updated or deleted in normal flow.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id      VARCHAR(100),                            -- correlates with Metadata.trace_id
    module        VARCHAR(50)  NOT NULL,                   -- from audit_trail option, e.g. AUTH
    activity      VARCHAR(100) NOT NULL,                   -- from audit_trail option, e.g. LOGIN
    actor_id      VARCHAR(100),                            -- user id performing the action
    actor_name    VARCHAR(255),
    actor_role    VARCHAR(50),
    resource      VARCHAR(255),                            -- target resource identifier
    ip_address    INET,
    user_agent    VARCHAR(512),
    request_body  JSONB,                                   -- captured request payload
    response_body JSONB,                                   -- captured response payload
    status        VARCHAR(20)  NOT NULL DEFAULT 'SUCCESS', -- SUCCESS, FAILED
    error_message TEXT,                                    -- populated on failure
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT chk_audit_status CHECK (status IN ('SUCCESS','FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_audit_module_activity ON audit_logs (module, activity);
CREATE INDEX IF NOT EXISTS idx_audit_actor_id        ON audit_logs (actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_trace_id        ON audit_logs (trace_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at      ON audit_logs (created_at);

COMMIT;
