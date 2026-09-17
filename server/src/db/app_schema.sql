-- Schema aplikasyon an (san Firebase).
--
-- ENPÒTAN: fichye baz la se MENM fichye ak `bazik/src/store/schema.sql`.
-- Bazik la deja bay `wallets`, `wallet_ledger`, `wallet_history`,
-- `bazik_transfers`, `bazik_events`, `transactions` ak `exchange_rates`.
-- Isit la nou ajoute sèlman sa ki manke pou app la kanpe pou kont li.
--
-- De baz separe ta vle di de verite sou menm sòld la. Yon sèl fichye.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- Itilizatè yo. `uid` gen menm fòm ak ID Firebase yo te genyen (yon chèn),
-- konsa done ki te ekri anvan rete konpatib.
CREATE TABLE IF NOT EXISTS users (
  uid            TEXT PRIMARY KEY,
  email          TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash  TEXT NOT NULL,
  password_salt  TEXT NOT NULL,
  display_name   TEXT NOT NULL DEFAULT '',
  role           TEXT NOT NULL DEFAULT 'agent'
                 CHECK (role IN ('owner','administrator','admin','agent','client')),
  is_active      INTEGER NOT NULL DEFAULT 1,
  must_change_password INTEGER NOT NULL DEFAULT 0,
  last_login_at  INTEGER,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  created_by     TEXT NOT NULL DEFAULT ''
);

-- Sesyon yo. Nou stoke SHA-256 jeton an, PA jeton an.
-- Si baz la li, pèsonn pa ka vòlè yon sesyon.
CREATE TABLE IF NOT EXISTS sessions (
  token_hash   TEXT PRIMARY KEY,
  uid          TEXT NOT NULL,
  created_at   INTEGER NOT NULL,
  expires_at   INTEGER NOT NULL,
  last_seen_at INTEGER NOT NULL,
  user_agent   TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_uid ON sessions (uid, expires_at);

CREATE TABLE IF NOT EXISTS enterprises (
  enterprise_id TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  owner_uid     TEXT NOT NULL DEFAULT '',
  currency      TEXT NOT NULL DEFAULT 'USD',
  is_active     INTEGER NOT NULL DEFAULT 1,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL
);

-- Ki moun nan ki antrepriz. Menm wòl ak koleksyon Firestore ki te la a.
CREATE TABLE IF NOT EXISTS enterprise_users (
  id             TEXT PRIMARY KEY,
  uid            TEXT NOT NULL,
  enterprise_id  TEXT NOT NULL,
  enterprise_name TEXT NOT NULL DEFAULT '',
  display_name   TEXT NOT NULL DEFAULT '',
  email          TEXT NOT NULL DEFAULT '',
  role           TEXT NOT NULL DEFAULT 'agent',
  is_active      INTEGER NOT NULL DEFAULT 1,
  created_at     INTEGER NOT NULL,
  created_by     TEXT NOT NULL DEFAULT '',
  UNIQUE (uid, enterprise_id),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_enterprise_users_ent
  ON enterprise_users (enterprise_id, is_active);

-- Katalòg sèvis yo (MonCash, NatCash, Western Union, CAM...).
-- `network` vid = sèvis la pa pase sou Bazik, li livre yon lòt jan.
CREATE TABLE IF NOT EXISTS services (
  service_id     TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  code           TEXT NOT NULL DEFAULT '',
  network        TEXT NOT NULL DEFAULT '',
  is_active      INTEGER NOT NULL DEFAULT 1,
  commission_agent_pct REAL NOT NULL DEFAULT 0,
  commission_owner_pct REAL NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL
);

-- Chan anplis sou `transactions` ke bazik/schema.sql pa konnen.
-- (SQLite pa gen "ADD COLUMN IF NOT EXISTS": `db.js` jere sa.)

-- Jounal komisyon yo: yon liy pa tranzaksyon livre.
-- `tx_id` PRIMARY KEY = yon sèl aplikasyon pa tranzaksyon, garanti pa baz la.
CREATE TABLE IF NOT EXISTS commission_logs (
  tx_id              TEXT PRIMARY KEY,
  enterprise_id      TEXT NOT NULL,
  staff_uid          TEXT NOT NULL,
  owner_uid          TEXT NOT NULL DEFAULT '',
  service            TEXT NOT NULL DEFAULT '',
  tx_amount_minor    INTEGER NOT NULL,
  tx_currency        TEXT NOT NULL,
  agent_pct          REAL NOT NULL,
  owner_pct          REAL NOT NULL,
  agent_minor        INTEGER NOT NULL,   -- nan deviz tranzaksyon an
  owner_minor        INTEGER NOT NULL,
  agent_credit_minor INTEGER NOT NULL,   -- nan deviz wallet ajan an
  owner_credit_minor INTEGER NOT NULL,   -- nan deviz wallet owner an
  created_at         INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_commission_logs_ent
  ON commission_logs (enterprise_id, created_at DESC);

-- Demann payout: yon ajan mande pou yo peye l sòld li sou MonCash/NatCash.
-- Wallet la PA debite lè demann lan kreye — sèlman lè yon admin apwouve l,
-- atravè motè transfè Bazik la (debi + voye ann atomik).
CREATE TABLE IF NOT EXISTS payout_requests (
  request_id     TEXT PRIMARY KEY,
  enterprise_id  TEXT NOT NULL,
  staff_uid      TEXT NOT NULL,
  staff_name     TEXT NOT NULL DEFAULT '',
  amount_minor   INTEGER NOT NULL,
  currency       TEXT NOT NULL,
  network        TEXT NOT NULL DEFAULT 'moncash',
  phone          TEXT NOT NULL,
  receiver_name  TEXT NOT NULL DEFAULT '',
  note           TEXT NOT NULL DEFAULT '',
  status         TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','approved','rejected','failed','verifying')),
  transfer_id    TEXT NOT NULL DEFAULT '',
  decided_by     TEXT NOT NULL DEFAULT '',
  decided_at     INTEGER,
  failure_reason TEXT NOT NULL DEFAULT '',
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_payout_requests_ent
  ON payout_requests (enterprise_id, status, created_at DESC);

-- Chak apèl exchangerate-api.com (`src/rates/rates_refresher.js`).
-- Se tab sa a ki garanti "yon apèl pa jou": eta a siviv yon redemaraj.
CREATE TABLE IF NOT EXISTS exchange_rate_fetches (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  attempted_at        INTEGER NOT NULL,
  status              TEXT NOT NULL CHECK (status IN ('success','error','rejected')),
  provider_updated_at INTEGER,
  next_update_at      INTEGER,
  currencies          INTEGER NOT NULL DEFAULT 0,
  error_code          TEXT NOT NULL DEFAULT '',
  error_message       TEXT NOT NULL DEFAULT '',
  permanent           INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_rate_fetches_time ON exchange_rate_fetches (attempted_at DESC);
