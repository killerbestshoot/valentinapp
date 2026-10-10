"use strict";

/**
 * Frè platfòm nan: owner a fikse l, kliyan an peye l (oswa li dedwi), e se
 * NAN LI komisyon ajan an ak pati owner a soti. Frè pasrèl la tonbe sou pati
 * owner a.
 *
 * Egzanp referans lan: 5% sou 2000 MXN = 100 MXN; ajan an 40% (40 MXN), owner
 * a rès la (60 MXN) mwens sa Bazik pran.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "platform-fee-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const { getDb, resetDb, now } = require("../src/db/db");
const users = require("../src/auth/users");
const engine = require("../src/commission/engine");
const fees = require("../src/commission/fees");
const { getBazikService } = require("../src/bazik_service");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const { commissions: commissionRoutes, services: serviceRoutes } = require("../src/routes/commissions.routes");
const AppIds = require("../../bazik/src/ids");

let server;
let baseUrl;

test.before(async () => {
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/commissions", commissionRoutes);
  app.use("/api/services", serviceRoutes);
  server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  server?.close();
  resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

let counter = 0;

async function setup({ walletCurrency = "MXN", agentFloatMinor = 1_000_000 } = {}) {
  counter += 1;
  const db = getDb();
  const enterpriseId = AppIds.enterprise(`fee-${counter}`);
  db.prepare(
    `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
     VALUES (?, 'Fee Test', '', ?, 1, ?, ?)`
  ).run(enterpriseId, walletCurrency, now(), now());

  const make = (role) =>
    users.createUser({
      email: `${role}${counter}@fee.test`, password: "modpas-solid-123", role,
      enterpriseId, enterpriseName: "Fee Test", currency: walletCurrency,
    });
  const owner = await make("owner");
  db.prepare("UPDATE enterprises SET owner_uid = ? WHERE enterprise_id = ?").run(owner.uid, enterpriseId);
  const agent = await make("agent");

  const store = getBazikService().store;
  await store.creditWallet({
    uid: agent.uid, enterpriseId, enterpriseName: "Fee Test", role: "agent",
    amountMinor: agentFloatMinor, currency: walletCurrency, type: "test_float",
    note: "float tès", sourceCollection: "test", sourceId: `float-${counter}`,
    createdBy: "test", createdByRole: "system", idempotencyKey: `test-float:${counter}`,
  });

  return { enterpriseId, owner, agent, token: createSession(owner.uid).token };
}

function policy({ feePct = 5, share = 40, minHtg = 0 } = {}) {
  getDb()
    .prepare("UPDATE services SET fee_pct = ?, agent_share_pct = ?, fee_min_htg_minor = ? WHERE name = 'MonCash'")
    .run(feePct, share, Math.round(minHtg * 100));
}

/** Kreye tranzaksyon an jan wout la fè l, ak frè a kalkile pa `fees`. */
async function createTx({ enterpriseId, agent }, { amountMinor = 200000, mode = "sender", currency = "MXN" } = {}) {
  const fee = await fees.computeFee({ inputMinor: amountMinor, currency, mode, serviceName: "MonCash" });
  const txId = AppIds.transaction(`fee-tx-${Math.random()}`);
  getDb()
    .prepare(
      `INSERT INTO transactions
        (tx_id, enterprise_id, enterprise_name, staff_uid, staff_name, staff_role, client_name, phone,
         service, amount_minor, currency, sender_fee_minor, fee_mode, fee_pct, agent_share_pct,
         status, gateway_ref, commission_applied, created_at, updated_at,
         commission_agent_minor, commission_owner_minor)
       VALUES (?, ?, 'Fee Test', ?, 'Ajan', 'agent', 'Benefisyè', '37123456', 'MonCash', ?, ?, ?, ?, ?, ?,
               'pending', '', 0, ?, ?, ?, ?)`
    )
    .run(txId, enterpriseId, agent.uid, fee.netMinor, currency, fee.feeMinor, fee.mode, fee.feePct,
      fee.agentSharePct, now(), now(), fee.agentMinor, fee.ownerMinor);
  return { txId, fee };
}

/** Voye l bay Bazik (fake), epi fèmen l jan webhook la ta fè l (`settle`). */
async function deliver(ctx, txId, settle = "completed") {
  const tx = getDb().prepare("SELECT * FROM transactions WHERE tx_id = ?").get(txId);
  const service = getBazikService();
  const sent = await service.transfers.send({
    kind: "delivery", network: "moncash", amountMinor: tx.amount_minor, currency: tx.currency,
    uid: ctx.agent.uid, enterpriseId: ctx.enterpriseId, phone: "+50937123456", receiverName: "Benefisyè",
    txId, idempotencySeed: `tx:${txId}`, platformFeeMinor: tx.sender_fee_minor, chargeFeeToWallet: false,
  });
  if (settle) {
    await service.store.settleTransfer({ transferId: sent.transfer.transferId, status: settle, failureReason: settle === "failed" ? "tès" : "" });
  }
  return sent;
}

const balance = async (uid, enterpriseId) =>
  (await getBazikService().store.getWallet({ uid, enterpriseId }))?.balanceMinor ?? 0;

test("devi: 5% sou 2000 MXN, de mòd yo", async () => {
  policy();
  const sender = await fees.computeFee({ inputMinor: 200000, currency: "MXN", mode: "sender", serviceName: "MonCash" });
  assert.deepEqual(
    [sender.feeMinor, sender.netMinor, sender.totalMinor, sender.agentMinor, sender.ownerMinor],
    [10000, 200000, 210000, 4000, 6000]
  );

  const deducted = await fees.computeFee({ inputMinor: 200000, currency: "MXN", mode: "deducted", serviceName: "MonCash" });
  assert.deepEqual(
    [deducted.feeMinor, deducted.netMinor, deducted.totalMinor],
    [10000, 190000, 200000]
  );
});

test("pati ajan + pati owner = frè a egzakteman, menm ak awondi", async () => {
  policy({ feePct: 3.3, share: 33.3 });
  for (const inputMinor of [101, 777, 12345, 99999]) {
    const f = await fees.computeFee({ inputMinor, currency: "MXN", mode: "sender", serviceName: "MonCash" });
    assert.equal(f.agentMinor + f.ownerMinor, f.feeMinor, `santim pèdi sou ${inputMinor}`);
  }
  policy();
});

test("wallet ajan an debite montan an + frè a, pa frè pasrèl la", async () => {
  policy();
  const ctx = await setup();
  const before = await balance(ctx.agent.uid, ctx.enterpriseId);
  const { txId } = await createTx(ctx);

  const result = await deliver(ctx, txId, null);

  assert.equal(result.transfer.debitMinor, 210000, "2000 + 100 frè, an MXN");
  assert.equal(await balance(ctx.agent.uid, ctx.enterpriseId), before - 210000);
});

test("livre: ajan an resevwa 40% frè a, owner a rès la mwens Bazik", async () => {
  // 20% frè: owner a kouvri Bazik (5%) ak pati pa l (60% × 20% = 12%).
  policy({ feePct: 20 });
  const ctx = await setup();
  const { txId, fee } = await createTx(ctx);
  const start = await balance(ctx.agent.uid, ctx.enterpriseId);

  await deliver(ctx, txId);
  const agentBefore = await balance(ctx.agent.uid, ctx.enterpriseId);
  assert.equal(start - agentBefore, 240000, "2000 + 400 frè debite");
  const result = await engine.applyCommissionToTx(txId);

  assert.equal(result.status, "applied");
  assert.equal(fee.feeMinor, 40000);
  assert.equal(await balance(ctx.agent.uid, ctx.enterpriseId) - agentBefore, 16000, "40% × 400 MXN");

  const log = getDb().prepare("SELECT * FROM commission_logs WHERE tx_id = ?").get(txId);
  assert.equal(log.fee_minor, 40000);
  assert.ok(log.gateway_cost_minor > 0, "frè Bazik la anrejistre");
  assert.equal(log.owner_net_minor, 24000 - log.gateway_cost_minor);
  assert.equal(await balance(ctx.owner.uid, ctx.enterpriseId), log.owner_net_minor);
  policy();
});

test("frè a pa kouvri Bazik: owner a peye diferans lan, ajan an toujou touche", async () => {
  // 5% frè, owner 60% = 3% < 5% Bazik.
  policy();
  const ctx = await setup();
  const store = getBazikService().store;
  await store.creditWallet({
    uid: ctx.owner.uid, enterpriseId: ctx.enterpriseId, enterpriseName: "Fee Test", role: "owner",
    amountMinor: 100000, currency: "MXN", type: "test_float", note: "float owner",
    sourceCollection: "test", sourceId: `owner-${counter}`, createdBy: "test", createdByRole: "system",
    idempotencyKey: `test-owner-float:${counter}`,
  });
  const { txId } = await createTx(ctx);

  await deliver(ctx, txId);
  const agentBefore = await balance(ctx.agent.uid, ctx.enterpriseId);
  const result = await engine.applyCommissionToTx(txId);

  const log = getDb().prepare("SELECT * FROM commission_logs WHERE tx_id = ?").get(txId);
  assert.ok(log.owner_net_minor < 0, "pèt la vizib");
  assert.equal(await balance(ctx.agent.uid, ctx.enterpriseId) - agentBefore, 4000);
  assert.equal(await balance(ctx.owner.uid, ctx.enterpriseId), 100000 + log.owner_net_minor);
  assert.equal(result.ownerShortfall * 100, -log.owner_net_minor);
});

test("transfè ki echwe: ajan an ranbouse montan an + frè a, pa gen komisyon", async () => {
  policy();
  const ctx = await setup();
  const before = await balance(ctx.agent.uid, ctx.enterpriseId);
  const { txId } = await createTx(ctx);

  await deliver(ctx, txId, "failed");

  assert.equal(getDb().prepare("SELECT status FROM transactions WHERE tx_id = ?").get(txId).status, "failed");
  assert.equal(await balance(ctx.agent.uid, ctx.enterpriseId), before, "2100 MXN remèt");
  assert.equal((await engine.applyCommissionToTx(txId)).reason, "not_delivered");
});

test("owner a chanje frè a; yon to pa valid refize", async () => {
  const ctx = await setup();
  const patch = (body) =>
    fetch(`${baseUrl}/api/services/moncash_ht`, {
      method: "PATCH",
      headers: { "content-type": "application/json", authorization: `Bearer ${ctx.token}` },
      body: JSON.stringify(body),
    }).then(async (r) => ({ status: r.status, json: await r.json() }));

  const ok = await patch({ feePct: 8, agentSharePct: 25, feeMinHtg: 150 });
  assert.equal(ok.status, 200, JSON.stringify(ok.json));
  assert.equal(ok.json.service.feePct, 8);
  assert.equal(ok.json.service.agentSharePct, 25);
  assert.equal(ok.json.service.feeMinHtg, 150);
  assert.equal(ok.json.service.ownerMarginPct, 1, "8% × 75% = 6% − 5% Bazik");

  assert.equal((await patch({ feePct: 0 })).json.code, "invalid_fee_pct", "frè a obligatwa");
  assert.equal((await patch({ agentSharePct: 120 })).json.code, "invalid_agent_share");
  policy();
});

test("ekran an dirèk: komisyon chak ajan, livre ak an atant", async () => {
  policy({ feePct: 20 });
  const ctx = await setup();
  const delivered = await createTx(ctx);
  await deliver(ctx, delivered.txId);
  await engine.applyCommissionToTx(delivered.txId);
  await createTx(ctx, { amountMinor: 100000 }); // an atant

  const r = await fetch(`${baseUrl}/api/commissions/live?days=1&currency=MXN`, {
    headers: { authorization: `Bearer ${ctx.token}` },
  });
  const json = await r.json();

  assert.equal(r.status, 200, JSON.stringify(json));
  const row = json.agents.find((a) => a.staffUid === ctx.agent.uid);
  assert.ok(row, "ajan an nan lis la");
  assert.equal(row.count, 1);
  assert.equal(row.fee, 400);
  assert.equal(row.agentCommission, 160);
  assert.equal(row.pendingCount, 1);
  assert.equal(row.pendingAgent, 80, "40% × 20% × 1000 MXN");
  assert.equal(json.totals.agentCommission, 160);
  policy();
});
