-- Rechaj minit (Reloadly Airtime).
--
-- Menm prensip ak `bazik_transfers`: lajan an SANTIM ANTYE, e liy lan ekri nan
-- MENM tranzaksyon ak debi wallet la (`wallet_debited = 1` depi okòmansman).
--
-- `topup_id` se tou `customIdentifier` nou voye bay Reloadly: se li ki pèmèt
-- nou jwenn rechaj la ankò si repons lan pèdi.

CREATE TABLE IF NOT EXISTS airtime_topups (
  topup_id          TEXT PRIMARY KEY,
  status            TEXT NOT NULL DEFAULT 'processing'
                    CHECK (status IN ('processing','completed','failed')),
  gateway_id        TEXT NOT NULL DEFAULT '',   -- transactionId Reloadly
  gateway_status    TEXT NOT NULL DEFAULT '',
  operator_id       INTEGER NOT NULL,
  operator_name     TEXT NOT NULL DEFAULT '',
  country_code      TEXT NOT NULL DEFAULT 'HT',
  phone             TEXT NOT NULL,              -- +509XXXXXXXX
  use_local_amount  INTEGER NOT NULL DEFAULT 0,
  amount_minor      INTEGER NOT NULL,           -- montan tranzaksyon an
  currency          TEXT NOT NULL,              -- deviz tranzaksyon an (sa kliyan an peye)
  send_amount_minor INTEGER NOT NULL DEFAULT 0, -- sa nou voye bay Reloadly
  send_currency     TEXT NOT NULL DEFAULT '',
  conversion_rate   REAL NOT NULL DEFAULT 1,    -- send_currency pou 1 currency
  debit_minor       INTEGER NOT NULL DEFAULT 0, -- sa nou retire nan wallet la
  wallet_currency   TEXT NOT NULL DEFAULT '',
  rates_updated_at  INTEGER,
  estimated_delivered_minor INTEGER NOT NULL DEFAULT 0,
  delivered_minor   INTEGER NOT NULL DEFAULT 0, -- sa Reloadly di li livre
  delivered_currency TEXT NOT NULL DEFAULT '',
  discount_minor    INTEGER NOT NULL DEFAULT 0, -- remiz Reloadly: maj antrepriz la
  discount_currency TEXT NOT NULL DEFAULT '',
  operator_transaction_id TEXT NOT NULL DEFAULT '',
  uid               TEXT NOT NULL,
  enterprise_id     TEXT NOT NULL,
  enterprise_name   TEXT NOT NULL DEFAULT '',
  tx_id             TEXT NOT NULL DEFAULT '',
  wallet_debited    INTEGER NOT NULL DEFAULT 0,
  refunded          INTEGER NOT NULL DEFAULT 0,
  failure_reason    TEXT NOT NULL DEFAULT '',
  note              TEXT NOT NULL DEFAULT '',
  created_by        TEXT NOT NULL DEFAULT '',
  created_at        INTEGER NOT NULL,
  updated_at        INTEGER NOT NULL,
  settled_at        INTEGER
);

CREATE INDEX IF NOT EXISTS idx_airtime_status ON airtime_topups (status, created_at);
CREATE INDEX IF NOT EXISTS idx_airtime_enterprise ON airtime_topups (enterprise_id, created_at DESC);
