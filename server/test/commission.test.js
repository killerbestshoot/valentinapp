"use strict";

/**
 * Motè komisyon SQLite.
 *
 * Ansyen motè Firebase la te gen de defo ke tès sa yo fèmen:
 *   - komisyon owner yo t al nan yon wallet fantom `{ent}_OWNER` ke pèsonn pa li;
 *   - okenn liy nan rejis la: sòld yo te enposib pou eksplike.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "commission-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const { getDb, resetDb, now } = require("../src/db/db");
const users = require("../src/auth/users");
const engine = require("../src/commission/engine");
const { getBazikService } = require("../src/bazik_service");
const AppIds = require("../../bazik/src/ids");

test.after(() => {
  resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

let counter = 0;

/** Yon antrepriz ak owner + ajan, pare pou tès. */
async function setup({ agentCurrency = "USD", ownerCurrency = "USD" } = {}) {
  counter += 1;
  const db = getDb();
  const enterpriseId = AppIds.enterprise(`test-${counter}`);

  db.prepare(
    `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
     VALUES (?, 'Test', '', 'USD', 1, ?, ?)`
  ).run(enterpriseId, now(), now());

  const owner = await users.createUser({
    email: `owner${counter}@x.com`,
    password: "modpas-solid-123",
    role: "owner",
    enterpriseId,
    enterpriseName: "Test",
    currency: ownerCurrency,
  });

  db.prepare("UPDATE enterprises SET owner_uid = ? WHERE enterprise_id = ?").run(owner.uid, enterpriseId);

  const agent = await users.createUser({
    email: `agent${counter}@x.com`,
    password: "modpas-solid-123",
    role: "agent",
    enterpriseId,
    enterpriseName: "Test",
    currency: agentCurrency,
  });

  return { enterpriseId, owner, agent };
}

function createTx({ enterpriseId, staffUid, amountMinor, currency = "USD", service = "MonCash", status = "delivered" }) {
  const txId = AppIds.transaction(`tx-${Math.random()}`);
  const commission = engine.computeCommission({ amountMinor, serviceName: service });

  getDb()
    .prepare(
      `INSERT INTO transactions
        (tx_id, enterprise_id, staff_uid, staff_role, client_name, phone, service,
         amount_minor, currency, status, gateway_ref, commission_applied, created_at, updated_at,
         commission_agent_minor, commission_owner_minor, agent_commission_pct, owner_commission_pct)
       VALUES (?, ?, ?, 'agent', 'C', '37123456', ?, ?, ?, ?, '', 0, ?, ?, ?, ?, ?, ?)`
    )
    .run(
      txId, enterpriseId, staffUid, service, amountMinor, currency, status, now(), now(),
      commission.agentMinor, commission.ownerMinor, commission.agentPct, commission.ownerPct
    );

  return txId;
}

async function balance(uid, enterpriseId) {
  const wallet = await getBazikService().store.getWallet({ uid, enterpriseId });
  return wallet ? wallet.balanceMinor : 0;
}

test("to legacy yo: 10% ajan, 20% owner", () => {
  const rates = engine.resolveRates("MonCash");
  assert.equal(rates.agentPct, 10);
  assert.equal(rates.ownerPct, 20);

  // Sèvis enkoni: menm to pa default.
  assert.deepEqual(engine.resolveRates("Sèvis ki pa egziste"), { agentPct: 10, ownerPct: 20 });
});

test("komisyon an kredite ajan an ak VRE owner an", async () => {
  const { enterpriseId, owner, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000 }); // 100 USD

  const result = await engine.applyCommissionToTx(txId);

  assert.equal(result.status, "applied");
  assert.equal(await balance(agent.uid, enterpriseId), 1000, "10 USD");
  assert.equal(await balance(owner.uid, enterpriseId), 2000, "20 USD, sou wallet owner an");
});

test("pa gen wallet fantom `_OWNER`", async () => {
  const { enterpriseId, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000 });

  await engine.applyCommissionToTx(txId);

  const phantom = await getBazikService().store.getWallet({ uid: "OWNER", enterpriseId });
  assert.equal(phantom, null, "ansyen motè a te kredite yon uid literal OWNER");
});

test("chak komisyon ekri nan rejis la", async () => {
  const { enterpriseId, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000 });

  await engine.applyCommissionToTx(txId);

  const entries = await getBazikService().store.listLedger({ uid: agent.uid, enterpriseId });
  const commission = entries.find((e) => e.type === "commission_agent");

  assert.ok(commission, "liy rejis la dwe egziste");
  assert.equal(commission.amount_minor, 1000);
  assert.equal(commission.tx_id, txId);
});

test("yon komisyon pa janm aplike de fwa", async () => {
  const { enterpriseId, owner, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000 });

  await engine.applyCommissionToTx(txId);
  const second = await engine.applyCommissionToTx(txId);

  assert.equal(second.status, "skipped");
  assert.equal(second.reason, "already_applied");
  assert.equal(await balance(agent.uid, enterpriseId), 1000);
  assert.equal(await balance(owner.uid, enterpriseId), 2000);
});

test("aplikasyon konkiran: yon sèl kredi", async () => {
  const { enterpriseId, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000 });

  await Promise.all([
    engine.applyCommissionToTx(txId),
    engine.applyCommissionToTx(txId),
    engine.applyCommissionToTx(txId),
  ]);

  // Kle idempotans yo nan rejis la garanti sa, menm si de pasaj pase gad la.
  assert.equal(await balance(agent.uid, enterpriseId), 1000);
});

test("tranzaksyon ki pa `delivered` pa bay komisyon", async () => {
  const { enterpriseId, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000, status: "pending" });

  const result = await engine.applyCommissionToTx(txId);

  assert.equal(result.reason, "not_delivered");
  assert.equal(await balance(agent.uid, enterpriseId), 0);
});

test("komisyon an konvèti vè deviz wallet la", async () => {
  // Tranzaksyon an MXN, wallet ajan an an USD.
  const { enterpriseId, agent } = await setup({ agentCurrency: "USD" });
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 100000, currency: "MXN" });

  await engine.applyCommissionToTx(txId);

  // 10% de 1000 MXN = 100 MXN = 725 HTG = 5.49 USD
  assert.equal(await balance(agent.uid, enterpriseId), 549);
});

test("to a fikse lè kreyasyon an, pa lè aplikasyon an", async () => {
  const { enterpriseId, agent } = await setup();
  const txId = createTx({ enterpriseId, staffUid: agent.uid, amountMinor: 10000 });

  // Admin nan monte to a APRE tranzaksyon an kreye.
  getDb().prepare("UPDATE services SET commission_agent_pct = 50 WHERE name = 'MonCash'").run();

  await engine.applyCommissionToTx(txId);

  assert.equal(await balance(agent.uid, enterpriseId), 1000, "10% ki te pwomèt la, pa 50%");

  getDb().prepare("UPDATE services SET commission_agent_pct = 10 WHERE name = 'MonCash'").run();
});

test("rattrapage limite ak antrepriz", async () => {
  const first = await setup();
  const other = await setup();

  createTx({ enterpriseId: first.enterpriseId, staffUid: first.agent.uid, amountMinor: 10000 });
  createTx({ enterpriseId: other.enterpriseId, staffUid: other.agent.uid, amountMinor: 10000 });

  await engine.applyPendingCommissions({ enterpriseId: first.enterpriseId });

  assert.equal(await balance(first.agent.uid, first.enterpriseId), 1000);
  assert.equal(await balance(other.agent.uid, other.enterpriseId), 0, "lòt antrepriz la pa touche");
});
