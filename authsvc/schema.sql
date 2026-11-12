-- =============================================================
-- authsvc database schema
-- DB: auth_db
-- Owns: user credentials, sessions, refresh tokens
-- =============================================================

BEGIN;

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------
-- users
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    username    VARCHAR(100) NOT NULL,
    -- store a bcrypt/argon2 hash, NEVER the plaintext password
    password    VARCHAR(255) NOT NULL,
    role        VARCHAR(50)  NOT NULL DEFAULT 'USER',   -- USER, ADMIN, TELLER, ...
    status      VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, LOCKED
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT chk_users_role    CHECK (role   IN ('USER','ADMIN','TELLER','SYSTEM')),
    CONSTRAINT chk_users_status  CHECK (status IN ('ACTIVE','SUSPENDED','LOCKED'))
);

-- -------------------------------------------------------------
-- refresh_tokens / sessions
-- Supports the RefreshToken + Logout RPCs and device_id from LoginRequest.
-- One row per active login session (per device).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    device_id       VARCHAR(255),                       -- optional, from LoginRequest.device_id
    -- store a hash of the refresh token, not the raw value
    refresh_token   VARCHAR(255) NOT NULL,
    user_agent      VARCHAR(512),
    ip_address      INET,
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,                         -- set on logout / rotation
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT fk_sessions_user  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_sessions_token UNIQUE (refresh_token)
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id    ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions (expires_at);
CREATE INDEX IF NOT EXISTS idx_users_status        ON users (status);

COMMIT;
