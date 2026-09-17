"use strict";

/**
 * Wout Minit Haiti, pase pa HTTP pou vre (Express + sesyon + SQLite).
 *
 * Se wout la ki garanti règ sa yo, pa kliyan an:
 *   - montan, deviz ak nimewo soti nan TRANZAKSYON AN, pa nan kò demann lan
 *   - yon tranzaksyon MonCash pa ka livre an minit
 *   - an pwodiksyon san kle Reloadly: 503, pa similasyon
 *   - yon 401 Reloadly pa dekonekte ajan an (502, pa 401)
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "airtime-routes-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
delete process.env.RELOADLY_MODE;
delete process.env.RELOADLY_CLIENT_ID;
delete process.env.RELOADLY_CLIENT_SECRET;

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const { getBazikService } = require("../src/bazik_service");
const { getAirtimeService, resetAirtimeService } = require("../src/airtime_service");
const { ReloadlyError } = require("../../reloadly/index.js");
const airtimeRoutes = require("../src/routes/airtime.routes");

let server;
let baseUrl;

test.before(async () => {
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/airtime", airtimeRoutes);

  await new Promise((resolve) => {
    server = app.listen(0, "127.0.0.1", resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  server?.close();
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

async function agentWithSession({ email, enterpriseId = "ENT_A", balanceMinor = 10000 }) {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, ?, '', 'USD', 1, ?, ?) ON CONFLICT(enterprise_id) DO NOTHING`
    )
    .run(enterpriseId, `Ent ${enterpriseId}`, Date.now(), Date.now());

  const user = await users.createUser({
    email,
    password: "modpas-solid-2026",
    role: "agent",
    enterpriseId,
    enterpriseName: `Ent ${enterpriseId}`,
  });

  await getBazikService().store.creditWallet({
    uid: user.uid,
    enterpriseId,
    amountMinor: balanceMinor,
    currency: "USD",
    type: "seed",
    idempotencyKey: `seed:${user.uid}`,
  });

  return { ...user, enterpriseId, token: createSession(user.uid).token };
}

function seedTransaction({ txId, enterpriseId, uid, service = "Minit Haiti", amountMinor = 500, phone = "37123456", status = "pending" }) {
  db.getDb()
    .prepare(
      `INSERT INTO transactions (tx_id, enterprise_id, staff_uid, service, phone, amount_minor, currency, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'USD', ?, ?, ?)`
    )
    .run(txId, enterpriseId, uid, service, phone, amountMinor, status, Date.now(), Date.now());
}

async function call(method, route, { token, body } = {}) {
  const response = await fetch(`${baseUrl}${route}`, {
    method,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: response.status, json: await response.json() };
}

const balance = async (agent) =>
  (await getBazikService().store.getWallet({ uid: agent.uid, enterpriseId: agent.enterpriseId })).balanceMinor;

test("livrezon: montan ak nimewo soti nan TRANZAKSYON AN, kò demann lan inyore", async () => {
  const agent = await agentWithSession({ email: "a1@example.com" });
  seedTransaction({ txId: "TX_R1", enterpriseId: agent.enterpriseId, uid: agent.uid, amountMinor: 500 });

  const { status, json } = await call("POST", "/api/airtime/topups", {
    token: agent.token,
    // Yon kliyan malen: tranzaksyon 5 USD, li mande 50 USD sou yon lòt nimewo.
    body: { txId: "TX_R1", amount: 50, phone: "33999999" },
  });

  assert.equal(status, 200, JSON.stringify(json));
  assert.equal(json.topup.status, "completed");
  assert.equal(json.topup.amount, 5);
  assert.equal(json.topup.phone, "+50937123456");
  const tx = db.getDb().prepare("SELECT status, commission_applied FROM transactions WHERE tx_id = 'TX_R1'").get();
  assert.equal(tx.status, "delivered");
  assert.equal(tx.commission_applied, 1, "komisyon aplike apre livrezon an");

  // 100 − 5 (minit) + 0,50 (komisyon ajan 10% `minit_ht`).
  assert.equal(await balance(agent), 10000 - 500 + 50);
});

test("yon tranzaksyon MonCash pa ka livre an minit", async () => {
  const agent = await agentWithSession({ email: "a2@example.com" });
  seedTransaction({ txId: "TX_R2", enterpriseId: agent.enterpriseId, uid: agent.uid, service: "MonCash" });

  const { status, json } = await call("POST", "/api/airtime/topups", { token: agent.token, body: { txId: "TX_R2" } });

  assert.equal(status, 400);
  assert.equal(json.code, "not_airtime_transaction");
  assert.equal(await balance(agent), 10000);
});

test("tranzaksyon yon lòt antrepriz: 404, pa gen debi", async () => {
  const agent = await agentWithSession({ email: "a3@example.com", enterpriseId: "ENT_A" });
  const other = await agentWithSession({ email: "b3@example.com", enterpriseId: "ENT_B" });
  seedTransaction({ txId: "TX_R3", enterpriseId: other.enterpriseId, uid: other.uid });

  const { status } = await call("POST", "/api/airtime/topups", { token: agent.token, body: { txId: "TX_R3" } });

  assert.equal(status, 404);
  assert.equal(await balance(agent), 10000);
});

test("tranzaksyon deja livre (make manyèl): 409, pa gen dezyèm livrezon", async () => {
  const agent = await agentWithSession({ email: "a4@example.com" });
  seedTransaction({ txId: "TX_R4", enterpriseId: agent.enterpriseId, uid: agent.uid, status: "delivered" });

  const { status, json } = await call("POST", "/api/airtime/topups", { token: agent.token, body: { txId: "TX_R4" } });

  assert.equal(status, 409);
  assert.equal(json.code, "transaction_closed");
  assert.equal(await balance(agent), 10000);
});

test("Reloadly refize: repons lan pote rechaj la (ranbouse) pou UI a", async () => {
  const agent = await agentWithSession({ email: "a5@example.com" });
  seedTransaction({ txId: "TX_R5", enterpriseId: agent.enterpriseId, uid: agent.uid, phone: "37000000" });

  const { status, json } = await call("POST", "/api/airtime/topups", { token: agent.token, body: { txId: "TX_R5" } });

  assert.equal(status, 400);
  assert.equal(json.topup.status, "failed");
  assert.equal(json.topup.refunded, true);
  assert.equal(await balance(agent), 10000);
});

test("devi: operatè + montan livre, san debi", async () => {
  const agent = await agentWithSession({ email: "a6@example.com" });

  const { status, json } = await call("POST", "/api/airtime/quote", {
    token: agent.token,
    body: { phone: "3712 3456", amount: 5, currency: "USD" },
  });

  assert.equal(status, 200, JSON.stringify(json));
  assert.equal(json.quote.operator.name, "Digicel Haiti");
  assert.equal(json.quote.estimatedDelivered, 607.3, "5 USD × 121,46 (to sandbox Digicel)");
  assert.equal(await balance(agent), 10000);

  const low = await call("POST", "/api/airtime/quote", {
    token: agent.token,
    body: { phone: "37123456", amount: 0.5, currency: "USD" },
  });
  assert.equal(low.status, 400);
  assert.equal(low.json.code, "amount_too_low");
});

test("yon 401 Reloadly (move kle) tounen 502: sesyon ajan an pa dwe tonbe", async () => {
  const agent = await agentWithSession({ email: "a7@example.com" });
  const client = getAirtimeService().client;
  const original = client.detectOperator;
  client.detectOperator = async () => {
    throw new ReloadlyError("unauthorized", "invalid client", { status: 401 });
  };

  try {
    const { status, json } = await call("GET", "/api/airtime/operators/detect?phone=37123499", { token: agent.token });
    assert.equal(status, 502);
    assert.equal(json.code, "unauthorized");
  } finally {
    client.detectOperator = original;
  }
});

test("an pwodiksyon san kle Reloadly: 503, okenn similasyon, okenn debi", async () => {
  const agent = await agentWithSession({ email: "a8@example.com" });
  seedTransaction({ txId: "TX_R8", enterpriseId: agent.enterpriseId, uid: agent.uid });

  const previous = process.env.NODE_ENV;
  process.env.NODE_ENV = "production";
  resetAirtimeService();

  try {
    const send = await call("POST", "/api/airtime/topups", { token: agent.token, body: { txId: "TX_R8" } });
    assert.equal(send.status, 503);
    assert.equal(send.json.code, "airtime_unavailable");

    const status = await call("GET", "/api/airtime/status", { token: agent.token });
    assert.equal(status.json.enabled, false);
    assert.equal(await balance(agent), 10000);
  } finally {
    process.env.NODE_ENV = previous;
    resetAirtimeService();
  }
});

test("san sesyon: 401 (pa gen aksè anonim)", async () => {
  const { status } = await call("POST", "/api/airtime/quote", { body: { phone: "37123456", amount: 5 } });
  assert.equal(status, 401);
});
