"use strict";

/**
 * Zouti pataje: yon store Bazik an memwa (wallets + rejis), ak yon sèvis
 * rechaj ki chita sou MENM rejis la — jan serveur a fè l.
 */

const { createSqliteService } = require("../../bazik/index");
const { createFakeBazikClient } = require("../../bazik/src/fake_client");
const { TEST_CONFIG: BAZIK_TEST_CONFIG, seedAgent, balanceOf } = require("../../bazik/test/helpers");
const { createAirtimeService } = require("../index");
const { createFakeReloadlyClient } = require("../src/fake_client");

const TEST_CONFIG = {
  mode: "fake",
  isFake: true,
  isLive: false,
  authUrl: "https://auth.reloadly.com",
  baseUrl: "https://topups-sandbox.reloadly.com",
  audience: "https://topups-sandbox.reloadly.com",
  clientId: "test",
  clientSecret: "test",
  countryCode: "HT",
  maxRetries: 0,
  requestTimeoutMs: 1000,
};

/** 5 USD = 500 santim. */
const USD = (amount) => Math.round(amount * 100);

function makeAirtime(clientOptions = {}) {
  const bazik = createSqliteService({
    client: createFakeBazikClient(),
    config: { ...BAZIK_TEST_CONFIG },
  });

  const client = createFakeReloadlyClient(clientOptions);
  const service = createAirtimeService({
    ledgerStore: bazik.store,
    client,
    config: { ...TEST_CONFIG },
  });

  return { bazik, service, client, wallets: bazik.store, db: bazik.store._db };
}

/** Yon tranzaksyon Minit Haiti `pending`, jan `POST /api/transactions` kreye l. */
function seedTransaction(db, { txId = "TX_1", enterpriseId = "ENT1", uid = "agent-1", amountMinor = USD(5) } = {}) {
  db.prepare(
    `INSERT INTO transactions (tx_id, enterprise_id, staff_uid, service, phone, amount_minor, currency, status, created_at, updated_at)
     VALUES (?, ?, ?, 'Minit Haiti', '37123456', ?, 'USD', 'pending', ?, ?)`
  ).run(txId, enterpriseId, uid, amountMinor, Date.now(), Date.now());
  return txId;
}

function txStatus(db, txId) {
  return db.prepare("SELECT status FROM transactions WHERE tx_id = ?").get(txId)?.status;
}

function ledgerRows(db, { uid = "agent-1" } = {}) {
  return db
    .prepare("SELECT type, direction, amount_minor FROM wallet_ledger WHERE uid = ? AND type != 'seed' ORDER BY created_at, rowid")
    .all(uid)
    // `node:sqlite` retounen objè san prototip: `deepStrictEqual` ta refize yo.
    .map((row) => ({ ...row }));
}

module.exports = {
  TEST_CONFIG,
  USD,
  makeAirtime,
  seedAgent,
  balanceOf,
  seedTransaction,
  txStatus,
  ledgerRows,
};
