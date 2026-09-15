"use strict";

/**
 * Prepare yon baz dev ak yon ajan ki gen kòb.
 *
 * Kredite yon wallet PA gen wout HTTP espre: si yon moun te ka kredite yon
 * sld ak yon POST, tout rès sistèm nan pa vo anyen. Se yon zouti liy kòmand.
 *
 *   node bazik/scripts/seed_dev_db.js [uid] [enterpriseId] [montan USD]
 */

const path = require("node:path");
const { createSqliteStore } = require("../src/store/sqlite_store");
const money = require("../src/money");

async function main() {
  const [uid = "agent-dev", enterpriseId = "ENT_DEV", amount = "500"] = process.argv.slice(2);

  const file =
    process.env.APP_DB_PATH ||
    process.env.BAZIK_DB_PATH ||
    path.join(__dirname, "..", "..", "server", "data", "app.db");

  const store = createSqliteStore({ file });

  await store.ensureWallet({
    uid,
    enterpriseId,
    enterpriseName: "VOUPVAPCASH Dev",
    role: "agent",
    currency: process.env.WALLET_CURRENCY || "USD",
  });

  const amountMinor = money.toMinor(amount);

  const result = await store.creditWallet({
    uid,
    enterpriseId,
    enterpriseName: "VOUPVAPCASH Dev",
    amountMinor,
    currency: process.env.WALLET_CURRENCY || "USD",
    type: "dev_seed",
    note: "pwovizyon dev",
    createdBy: "seed_script",
    // Kle a chanje chak fwa: si ou rele script la 2 fwa, ou vle 2 kredi.
    idempotencyKey: `dev_seed:${enterpriseId}:${uid}:${Date.now()}`,
  });

  const wallet = await store.getWallet({ uid, enterpriseId });

  console.log(`baz    : ${file}`);
  console.log(`ajan   : ${uid} @ ${enterpriseId}`);
  console.log(`kredi  : +${amount}`);
  console.log(`sld    : ${money.fromMinor(wallet.balanceMinor)} ${wallet.currency}`);
  console.log(`ledger : ${result.ledgerId}`);

  await store.close();
}

main().catch((err) => {
  console.error("SEED FAIL:", err.message);
  process.exit(1);
});
