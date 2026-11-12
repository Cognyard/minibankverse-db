-- =============================================================
-- notificationsvc database schema
-- DB: notification_db
-- Owns: notifications dispatched to customers (Kafka consumer side)
-- =============================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- notifications
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- soft reference to customersvc.customers.id (no cross-db FK)
    customer_id   UUID         NOT NULL,
    channel       VARCHAR(20)  NOT NULL DEFAULT 'INAPP',   -- INAPP, EMAIL, SMS, PUSH
    title         VARCHAR(255) NOT NULL,
    message       TEXT         NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'UNREAD',  -- UNREAD, READ, SENT, FAILED
    -- which event triggered this notification, helps dedupe consumer retries
    event_type    VARCHAR(50),                             -- ACCOUNT_CREATED, TRANSFER_SUCCESS, ...
    event_id      VARCHAR(255),                            -- source event id for idempotency
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    read_at       TIMESTAMPTZ,

    CONSTRAINT chk_notifications_channel CHECK (channel IN ('INAPP','EMAIL','SMS','PUSH')),
    CONSTRAINT chk_notifications_status  CHECK (status  IN ('UNREAD','READ','SENT','FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_customer_id ON notifications (customer_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status      ON notifications (status);
-- dedupe guard for at-least-once Kafka delivery
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_event
    ON notifications (event_id) WHERE event_id IS NOT NULL;

COMMIT;
