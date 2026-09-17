"use strict";

/**
 * Solvabilite: float ajan yo (dèt) kontre pwovizyon Bazik + Reloadly.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "solvency-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const { getBazikService } = require("../src/bazik_service");
const { getAirtimeService } = require("../src/airtime_service");
const { checkSolvency, solvencyNotification } = require("../src/solvency");

const ENT = "ENT_SOLV";

test.after(() => {
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

/** Float staff yo, an santim, pa deviz. `owner` pa yon dèt. */
async function seedWallets(wallets) {
  const store = getBazikService().store;
  db.getDb().prepare("DELETE FROM wallets WHERE enterprise_id = ?").run(ENT);

  let i = 0;
  for (const [role, currency, balanceMinor] of wallets) {
    i += 1;
    const uid = `${role}-${i}`;
    await store.ensureWallet({ uid, enterpriseId: ENT, role, currency });
    db.getDb()
      .prepare("UPDATE wallets SET balance_minor = ? WHERE enterprise_id = ? AND uid = ?")
      .run(balanceMinor, ENT, uid);
  }
}

/** Pwovizyon pasrèl yo, san rezo. */
function mockGateways({ bazikHtg = null, reloadlyUsd = null, bazikError = null, reloadlyError = null } = {}) {
  const bazik = getBazikService();
  const airtime = getAirtimeService();

  bazik.gatewayWallet = async () => {
    if (bazikError) throw Object.assign(new Error(bazikError), { code: bazikError });
    return { availableMinor: Math.round(bazikHtg * 100), reservedMinor: 0, currency: "HTG" };
  };
  airtime.topups.accountBalance = async () => {
    if (reloadlyError) throw Object.assign(new Error(reloadlyError), { code: reloadlyError });
    return { balanceMinor: Math.round(reloadlyUsd * 100), currency: "USD" };
  };
}

test("kouvri: pwovizyon yo depase dèt yo + tanpon 10%", async () => {
  // 100 USD (13 200 HTG ak to tès la) + 5 000 HTG = 18 200 HTG dèt.
  await seedWallets([["agent", "USD", 10000], ["agent", "HTG", 500000], ["owner", "USD", 900000]]);
  mockGateways({ bazikHtg: 15000, reloadlyUsd: 40 }); // 15 000 + 5 280 = 20 280 HTG

  const result = await checkSolvency({ enterpriseId: ENT });

  assert.equal(result.status, "covered");
  assert.equal(result.ok, true);
  assert.equal(result.liabilities.total, 18200, "wallet owner an PA yon dèt");
  assert.equal(result.coverage.total, 20280, "15 000 HTG Bazik + 40 USD × 132");
  assert.equal(result.gap, -2080, "negatif = pwovizyon anplis");
  assert.equal(solvencyNotification(result), null, "pa gen alèt lè tout bagay kouvri");
});

test("PA KOUVRI: alèt ak montan ki manke a", async () => {
  await seedWallets([["agent", "USD", 100000]]); // 1 000 USD = 132 000 HTG
  mockGateways({ bazikHtg: 50000, reloadlyUsd: 100 }); // 50 000 + 13 200 = 63 200 HTG

  const result = await checkSolvency({ enterpriseId: ENT });

  assert.equal(result.status, "uncovered");
  assert.equal(result.ok, false);
  assert.equal(result.gap, 68800, "132 000 dèt − 63 200 pwovizyon");
  assert.equal(result.ratio, Number((63200 / 132000).toFixed(4)));

  const alert = solvencyNotification(result);
  assert.equal(alert.type, "solvency_uncovered");
  assert.equal(alert.severity, "warning");
  assert.match(alert.title, /PA kouvri/);
  assert.match(alert.title, /manke/);
});

test("jis-jis: kouvri men san tanpon — alèt tou", async () => {
  await seedWallets([["agent", "HTG", 1000000]]); // 10 000 HTG
  mockGateways({ bazikHtg: 10200, reloadlyUsd: 0 }); // 10 200 = 1,02× (mwens pase 1,10)

  const result = await checkSolvency({ enterpriseId: ENT });

  assert.equal(result.status, "thin");
  assert.equal(result.ok, false);
  assert.match(solvencyNotification(result).title, /jis-jis/);
});

test("pasrèl ki pa reponn: `unknown` — nou PA di nou solvab", async () => {
  await seedWallets([["agent", "HTG", 100000]]);
  mockGateways({ bazikError: "network_error", reloadlyUsd: 1000 });

  const result = await checkSolvency({ enterpriseId: ENT });

  assert.equal(result.status, "unknown");
  assert.equal(result.coverage.total, null);
  assert.equal(result.gap, null);
  assert.match(result.reasons.join(" "), /Bazik: network_error/);
  assert.equal(solvencyNotification(result).type, "solvency_unknown");
});

test("deviz san to: `unknown`, e dèt la parèt kanmenm", async () => {
  await seedWallets([["agent", "HTG", 100000]]);
  db.getDb()
    .prepare("UPDATE wallets SET currency = 'XOF' WHERE enterprise_id = ? AND currency = 'HTG'")
    .run(ENT);
  mockGateways({ bazikHtg: 100000, reloadlyUsd: 1000 });

  const result = await checkSolvency({ enterpriseId: ENT });

  assert.equal(result.status, "unknown");
  assert.match(result.reasons.join(" "), /XOF: missing_rate/);
  assert.equal(result.liabilities.byCurrency[0].htg, null);
});

test("Minit Haiti dezaktive: pwovizyon Reloadly konte 0, Bazik sèl kouvri", async () => {
  await seedWallets([["agent", "HTG", 100000]]); // 1 000 HTG
  mockGateways({ bazikHtg: 5000, reloadlyUsd: 0 });
  getAirtimeService().disabled = true;

  const result = await checkSolvency({ enterpriseId: ENT });
  getAirtimeService().disabled = false;

  assert.equal(result.status, "covered");
  assert.equal(result.coverage.reloadly.enabled, false);
  assert.equal(result.coverage.reloadly.htg, 0);
});

test("chak pwovizyon parèt apa: HTG Bazik pa ka peye yon rechaj minit", async () => {
  await seedWallets([["agent", "HTG", 100000]]);
  mockGateways({ bazikHtg: 9000, reloadlyUsd: 5 });

  const result = await checkSolvency({ enterpriseId: ENT });

  assert.equal(result.coverage.bazik.available, 9000);
  assert.equal(result.coverage.bazik.currency, "HTG");
  assert.equal(result.coverage.reloadly.available, 5);
  assert.equal(result.coverage.reloadly.currency, "USD");
  assert.equal(result.coverage.reloadly.htg, 660, "5 USD × 132");
});
