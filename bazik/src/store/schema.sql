-- Schema SQLite pou devlopman ak tès.
-- Non chan yo swiv menm lojik ak Firestore (`balances`, `wallet_ledger`,
-- `wallet_topup_requests`) pou migrasyon an rete senp.
-- Diferans enpòtan: lajan estoke an SANTIM ANTYE, pa an double.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS exchange_rates (
  currency     TEXT PRIMARY KEY,
  rate_to_htg  REAL NOT NULL,
  updated_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS wallets (
  id             TEXT PRIMARY KEY,          -- enterpriseId_uid
  uid            TEXT NOT NULL,
  enterprise_id  TEXT NOT NULL,
  enterprise_name TEXT NOT NULL DEFAULT '',
  role           TEXT NOT NULL DEFAULT 'agent',
  currency       TEXT NOT NULL DEFAULT 'USD',
  balance_minor  INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS wallet_ledger (
  ledger_id        TEXT PRIMARY KEY,
  idempotency_key  TEXT UNIQUE,             -- de apèl ak menm kle = yon sèl liy
  type             TEXT NOT NULL,
  direction        TEXT NOT NULL CHECK (direction IN ('credit','debit')),
  uid              TEXT NOT NULL,
  role             TEXT NOT NULL DEFAULT 'agent',
  enterprise_id    TEXT NOT NULL,
  enterprise_name  TEXT NOT NULL DEFAULT '',
  amount_minor     INTEGER NOT NULL,
  currency         TEXT NOT NULL,
  before_minor     INTEGER NOT NULL,
  after_minor      INTEGER NOT NULL,
  source_collection TEXT NOT NULL DEFAULT 'bazik',
  source_id        TEXT NOT NULL DEFAULT '',
  tx_id            TEXT NOT NULL DEFAULT '',
  service_name     TEXT NOT NULL DEFAULT '',
  status           TEXT NOT NULL DEFAULT 'posted',
  note             TEXT NOT NULL DEFAULT '',
  created_by       TEXT NOT NULL DEFAULT 'system',
  created_by_role  TEXT NOT NULL DEFAULT 'system',
  created_at       INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ledger_uid ON wallet_ledger (enterprise_id, uid, created_at DESC);

CREATE TABLE IF NOT EXISTS wallet_topup_requests (
  request_id       TEXT PRIMARY KEY,
  type             TEXT NOT NULL DEFAULT 'wallet_topup',
  status           TEXT NOT NULL DEFAULT 'pending',
  processed        INTEGER NOT NULL DEFAULT 0,
  gateway          TEXT NOT NULL DEFAULT 'bazik',
  network          TEXT NOT NULL DEFAULT 'moncash',
  gateway_order_id TEXT UNIQUE,
  gateway_id       TEXT NOT NULL DEFAULT '',
  gateway_status   TEXT NOT NULL DEFAULT 'pending',
  payment_url      TEXT NOT NULL DEFAULT '',
  amount_minor     INTEGER NOT NULL,
  currency         TEXT NOT NULL DEFAULT 'USD',
  amount_htg_minor INTEGER NOT NULL,
  rate_to_htg      REAL NOT NULL,
  target_uid       TEXT NOT NULL,
  target_email     TEXT NOT NULL DEFAULT '',
  target_name      TEXT NOT NULL DEFAULT '',
  target_role      TEXT NOT NULL DEFAULT 'agent',
  enterprise_id    TEXT NOT NULL,
  enterprise_name  TEXT NOT NULL DEFAULT '',
  phone            TEXT NOT NULL DEFAULT '',
  requested_by     TEXT NOT NULL DEFAULT '',
  requested_by_name TEXT NOT NULL DEFAULT '',
  requested_by_role TEXT NOT NULL DEFAULT '',
  note             TEXT NOT NULL DEFAULT '',
  failure_reason   TEXT NOT NULL DEFAULT '',
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  credited_at      INTEGER
);

-- Transfè soti (payout bay yon staff, oswa livrezon bay yon benefisyè).
-- `fee_htg_minor` / `total_htg_minor`: Bazik pran 5% (gade docs/contract.md).
CREATE TABLE IF NOT EXISTS bazik_transfers (
  transfer_id      TEXT PRIMARY KEY,
  reference        TEXT NOT NULL UNIQUE,    -- referenceId nou voye bay Bazik
  kind             TEXT NOT NULL CHECK (kind IN ('payout','delivery')),
  network          TEXT NOT NULL CHECK (network IN ('moncash','natcash')),
  status           TEXT NOT NULL DEFAULT 'pending',
  gateway_id       TEXT NOT NULL DEFAULT '',
  gateway_status   TEXT NOT NULL DEFAULT '',
  amount_minor     INTEGER NOT NULL,        -- deviz wallet la
  currency         TEXT NOT NULL DEFAULT 'USD',
  amount_htg_minor INTEGER NOT NULL,        -- sa benefisyè a resevwa
  fee_htg_minor    INTEGER NOT NULL DEFAULT 0,
  total_htg_minor  INTEGER NOT NULL DEFAULT 0,
  debit_minor      INTEGER NOT NULL DEFAULT 0, -- sa nou retire nan wallet la
  rate_to_htg      REAL NOT NULL,
  uid              TEXT NOT NULL DEFAULT '',
  enterprise_id    TEXT NOT NULL DEFAULT '',
  enterprise_name  TEXT NOT NULL DEFAULT '',
  phone            TEXT NOT NULL DEFAULT '',
  receiver_name    TEXT NOT NULL DEFAULT '',
  tx_id            TEXT NOT NULL DEFAULT '',
  wallet_debited   INTEGER NOT NULL DEFAULT 0,
  refunded         INTEGER NOT NULL DEFAULT 0,
  failure_reason   TEXT NOT NULL DEFAULT '',
  note             TEXT NOT NULL DEFAULT '',
  created_by       TEXT NOT NULL DEFAULT '',
  created_at       INTEGER NOT NULL,
  updated_at       INTEGER NOT NULL,
  settled_at       INTEGER
);

CREATE INDEX IF NOT EXISTS idx_transfers_status ON bazik_transfers (status, created_at);

CREATE TABLE IF NOT EXISTS bazik_events (
  event_id     TEXT PRIMARY KEY,            -- kle idempotans webhook
  type         TEXT NOT NULL DEFAULT '',
  reference    TEXT NOT NULL DEFAULT '',
  status       TEXT NOT NULL DEFAULT '',
  payload      TEXT NOT NULL,
  received_at  INTEGER NOT NULL,
  processed    INTEGER NOT NULL DEFAULT 0,
  processed_at INTEGER,
  result       TEXT NOT NULL DEFAULT ''
);

-- Minimòm pou flux livrezon an (nan pwodiksyon se koleksyon `transactions` la).
CREATE TABLE IF NOT EXISTS transactions (
  tx_id          TEXT PRIMARY KEY,
  enterprise_id  TEXT NOT NULL DEFAULT '',
  staff_uid      TEXT NOT NULL DEFAULT '',
  client_name    TEXT NOT NULL DEFAULT '',
  phone          TEXT NOT NULL DEFAULT '',
  service        TEXT NOT NULL DEFAULT '',
  amount_minor   INTEGER NOT NULL DEFAULT 0,
  currency       TEXT NOT NULL DEFAULT 'USD',
  status         TEXT NOT NULL DEFAULT 'pending',
  gateway_ref    TEXT NOT NULL DEFAULT '',
  commission_applied INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL
);
