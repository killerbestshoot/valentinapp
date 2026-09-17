"use strict";

/**
 * Yon tranzaksyon `delivered` FÈMEN.
 *
 * Poukisa: komisyon yo deja peye sou li, liy rejis yo pwente sou li, e lajan an
 * deja pati. Remèt li `pending` ta pèmèt yon dezyèm livrezon (lajan an pati de
 * fwa); efase l ta kite transfè a ak rejis la san esplikasyon.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "tx-routes-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const transactionRoutes = require("../src/routes/transactions.routes");

const ENT = "ENT_TX";
let server;
let baseUrl;
const tokens = {};

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, 'Tx E2E', '', 'USD', 1, ?, ?)`
    )
    .run(ENT, Date.now(), Date.now());

  for (const role of ["owner", "admin", "agent"]) {
    const user = await users.createUser({
      email: `${role}@tx.test`, password: "modpas-solid-2026", role,
      enterpriseId: ENT, enterpriseName: "Tx E2E",
    });
    tokens[role] = createSession(user.uid).token;
  }

  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/transactions", transactionRoutes);
  server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  server?.close();
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

async function call(method, route, { role, body } = {}) {
  const response = await fetch(`${baseUrl}${route}`, {
    method,
    headers: { "content-type": "application/json", ...(role ? { authorization: `Bearer ${tokens[role]}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: response.status, json: await response.json() };
}

const create = async (name = "Kliyan") =>
  (await call("POST", "/api/transactions", {
    role: "agent",
    body: { serviceName: "MonCash", customerName: name, customerPhone: "37123456", paymentAmount: 10, paymentCurrency: "USD" },
  })).json.transaction.txId;

const statusOf = (txId) => db.getDb().prepare("SELECT status FROM transactions WHERE tx_id = ?").get(txId)?.status;

test("yon tranzaksyon livre pa ka retounen `pending`", async () => {
  const txId = await create();

  assert.equal((await call("PATCH", `/api/transactions/${txId}`, { role: "admin", body: { status: "delivered" } })).status, 200);

  const back = await call("PATCH", `/api/transactions/${txId}`, { role: "admin", body: { status: "pending" } });
  assert.equal(back.status, 409);
  assert.equal(back.json.code, "transaction_closed");
  assert.equal(statusOf(txId), "delivered");

  // Menm owner an pa ka.
  const asOwner = await call("PATCH", `/api/transactions/${txId}`, { role: "owner", body: { status: "failed" } });
  assert.equal(asOwner.status, 409);
  assert.equal(statusOf(txId), "delivered");
});

test("yon tranzaksyon livre pa ka efase", async () => {
  const txId = await create();
  await call("PATCH", `/api/transactions/${txId}`, { role: "admin", body: { status: "delivered" } });

  const removed = await call("DELETE", `/api/transactions/${txId}`, { role: "owner" });

  assert.equal(removed.status, 409);
  assert.equal(removed.json.code, "transaction_closed");
  assert.equal(statusOf(txId), "delivered");
});

test("yon tranzaksyon `pending` lye ak lajan k ap deplase pa ka efase", async () => {
  const withTopup = await create("Minit");
  db.getDb()
    .prepare(
      `INSERT INTO airtime_topups (topup_id, status, operator_id, phone, amount_minor, currency, uid, enterprise_id, tx_id, created_at, updated_at)
       VALUES ('AIR_x', 'processing', 173, '+50937123456', 1000, 'USD', 'agent', ?, ?, ?, ?)`
    )
    .run(ENT, withTopup, Date.now(), Date.now());

  const removed = await call("DELETE", `/api/transactions/${withTopup}`, { role: "owner" });
  assert.equal(removed.status, 409);
  assert.equal(removed.json.code, "transaction_has_money");

  const withTransfer = await create("MonCash");
  db.getDb()
    .prepare(
      `INSERT INTO bazik_transfers (transfer_id, reference, kind, network, status, amount_minor, currency, amount_htg_minor, rate_to_htg, enterprise_id, tx_id, created_at, updated_at)
       VALUES ('TRF_x', 'TRF_x', 'delivery', 'moncash', 'processing', 1000, 'USD', 132000, 132, ?, ?, ?, ?)`
    )
    .run(ENT, withTransfer, Date.now(), Date.now());

  assert.equal((await call("DELETE", `/api/transactions/${withTransfer}`, { role: "owner" })).json.code, "transaction_has_money");
});

test("yon tranzaksyon `pending` san lajan ka efase (owner sèlman)", async () => {
  const txId = await create();

  assert.equal((await call("DELETE", `/api/transactions/${txId}`, { role: "admin" })).status, 403);
  assert.equal((await call("DELETE", `/api/transactions/${txId}`, { role: "owner" })).status, 200);
  assert.equal(statusOf(txId), undefined);
});

test("yon ajan pa ka chanje estati pwòp tranzaksyon li", async () => {
  const txId = await create();
  assert.equal((await call("PATCH", `/api/transactions/${txId}`, { role: "agent", body: { status: "delivered" } })).status, 403);
  assert.equal(statusOf(txId), "pending");
});
