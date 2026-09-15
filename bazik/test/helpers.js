"use strict";

/** Zouti pataje pou tès yo: yon sèvis SQLite an memwa, ak yon similatè Bazik. */

const { createSqliteService } = require("../index");
const { createFakeBazikClient } = require("../src/fake_client");

const TEST_CONFIG = {
  mode: "fake",
  isFake: true,
  isLive: false,
  baseUrl: "https://api.bazik.io",
  userId: "test",
  secretKey: "test",
  webhookSecret: "whsec_test_secret",
  walletCurrency: "USD",
  maxRetries: 0,
  maxRequestsPerMinute: 1000,
  requestTimeoutMs: 1000,
};

/**
 * Yon sèvis konplè an memwa.
 * To a fikse a 132 HTG pou 1 USD (menm valè ak seed Dart la).
 */
function makeService(clientOptions = {}) {
  const client = createFakeBazikClient(clientOptions);
  const service = createSqliteService({ client, config: { ...TEST_CONFIG } });
  return { service, client, store: service.store };
}

/** Yon ajan ki gen kòb nan wallet li. */
async function seedAgent(store, { uid = "agent-1", enterpriseId = "ENT1", balanceMinor = 100000 } = {}) {
  await store.ensureWallet({ uid, enterpriseId, enterpriseName: "Test SA", role: "agent", currency: "USD" });

  if (balanceMinor > 0) {
    await store.creditWallet({
      uid,
      enterpriseId,
      amountMinor: balanceMinor,
      currency: "USD",
      type: "seed",
      note: "seed tès",
      idempotencyKey: `seed:${enterpriseId}:${uid}`,
    });
  }

  return { uid, enterpriseId };
}

async function balanceOf(store, { uid, enterpriseId }) {
  const wallet = await store.getWallet({ uid, enterpriseId });
  return wallet ? wallet.balanceMinor : 0;
}

module.exports = { makeService, seedAgent, balanceOf, TEST_CONFIG };
