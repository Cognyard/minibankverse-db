# Database & Local Infrastructure

Skema database dan infrastruktur lokal untuk mini banking platform. Mengikuti pola
**database-per-service**: tiap service punya database sendiri di satu instance PostgreSQL,
dan tidak boleh mengakses database milik service lain secara langsung.

## Layout

```text
database/
├── 00-init-databases.sql     # CREATE DATABASE untuk tiap service
├── 01-load-schemas.sql       # \connect + \i tiap schema per DB
├── authsvc/schema.sql        # users, sessions
├── customersvc/schema.sql    # customers
├── accountsvc/schema.sql     # accounts
├── beneficiarysvc/schema.sql # beneficiaries
├── transactionsvc/schema.sql # transactions, idempotency_keys, outbox_events
├── notificationsvc/schema.sql# notifications
└── auditsvc/schema.sql       # audit_logs

deploy/
├── docker-compose.yml        # postgres, redis, kafka, kafka-ui, pgadmin
└── .env.example              # copy ke .env
```

## Database per service

| Service          | Database          | Tabel |
|------------------|-------------------|-------|
| authsvc          | `auth_db`         | `users`, `sessions` |
| customersvc      | `customer_db`     | `customers` |
| accountsvc       | `account_db`      | `accounts` |
| beneficiarysvc   | `beneficiary_db`  | `beneficiaries` |
| transactionsvc   | `transaction_db`  | `transactions`, `idempotency_keys`, `outbox_events` |
| notificationsvc  | `notification_db` | `notifications` |
| auditsvc         | `audit_db`        | `audit_logs` |

Redis dan Kafka dipakai bersama (bukan per-service):
- **Redis** — cache + idempotency key store (session/token cache, idempotency di transactionsvc).
- **Kafka** — event bus (`account-events`, `transaction-events`, `notification-events`).

## Catatan desain

- **UUID** sebagai primary key (`gen_random_uuid()` dari ekstensi `pgcrypto`).
- **Uang** disimpan sebagai `NUMERIC(20,2)`, bukan `float`, supaya tidak ada error pembulatan.
- **Cross-service reference** (misal `accounts.customer_id`) disimpan sebagai UUID biasa
  **tanpa foreign key**, karena datanya ada di database service lain. Integritas dijaga
  di level aplikasi / event.
- **Password** disimpan sebagai hash (bcrypt/argon2), tidak pernah plaintext.
- **Refresh token** di tabel `sessions` sebaiknya disimpan sebagai hash juga.
- **Outbox pattern** (`outbox_events`) + **idempotency_keys** di transactionsvc untuk
  distributed transaction yang aman (roadmap Phase 6 & distributed transactions).
- **auditsvc** menyimpan audit trail yang dihasilkan dari opsi `common.v1.audit_trail`
  pada proto (`"MODULE,ACTIVITY"`, misal `"AUTH,LOGIN"`).

## Cara menjalankan

Dari root repo ini:

```bash
cp .env.example .env         # sesuaikan kredensial bila perlu
docker compose up -d
```

Service & port:

| Service   | URL / Port                        | Kredensial default |
|-----------|-----------------------------------|--------------------|
| PostgreSQL| `localhost:5432` (`POSTGRES_PORT`) | `postgres` / `postgres` |
| Redis     | `localhost:6379`                  | — |
| Kafka     | `localhost:9092` (dari host)      | — |
| Kafka UI  | http://localhost:8085             | — |
| pgAdmin   | http://localhost:8086             | `admin@banking.local` / `admin` |

> Init script (`00-*`, `01-*`) hanya dijalankan **sekali saat volume masih kosong**.
> Kalau skema diubah dan ingin dibuat ulang dari nol:
>
> ```bash
> docker compose down -v   # hapus semua volume + data
> docker compose up -d
> ```

## Contoh koneksi dari service (Go)

Tiap service pakai connection string ke database-nya sendiri, contoh untuk authsvc:

```text
postgres://postgres:postgres@localhost:5432/auth_db?sslmode=disable
```

Dari container lain di network `banking-net`, host-nya `postgres` (bukan `localhost`):

```text
postgres://postgres:postgres@postgres:5432/auth_db?sslmode=disable
```

Kafka bootstrap:
- dari host: `localhost:9092`
- dari container lain: `kafka:9094`
