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

// --- Chif livrezon an sou resi a ---

/**
 * Yon transfè Bazik jan `openTransfer` ekri l. 10 USD a 132 HTG = 1 320 HTG
 * pou benefisyè a, ak 5% frè = 66 HTG.
 */
function insertTransfer(txId, { feeChargedToWallet = 1 } = {}) {
  const at = Date.now();
  db.getDb()
    .prepare(
      `INSERT INTO bazik_transfers
        (transfer_id, reference, kind, network, status, amount_minor, currency,
         amount_htg_minor, fee_htg_minor, total_htg_minor, debit_minor,
         fee_charged_to_wallet, rate_to_htg, wallet_currency, wallet_rate_to_htg,
         tx_id, created_at, updated_at)
       VALUES (?, ?, 'delivery', 'moncash', 'completed', 1000, 'USD',
               132000, 6600, 138600, ?, ?, 132, 'USD', 132, ?, ?, ?)`
    )
    .run(
      `TR_${txId}`,
      `TR_${txId}`,
      feeChargedToWallet ? 1050 : 1000,
      feeChargedToWallet,
      txId,
      at,
      at
    );
}

test("resi a pote to echanj lan ak montan an gouden", async () => {
  const txId = await create("Resi");
  insertTransfer(txId);

  const { json } = await call("GET", `/api/transactions/${txId}`, { role: "agent" });

  assert.equal(json.delivery.rateToHtg, 132);
  assert.equal(json.delivery.rateCurrency, "USD");
  assert.equal(json.delivery.amountHtg, 1320, "sa benefisyè a resevwa");
});

test("resi a PA pote frè pasrèl la", async () => {
  const txId = await create("San frè pasrèl");
  insertTransfer(txId);

  const { json } = await call("GET", `/api/transactions/${txId}`, { role: "agent" });

  // Frè Bazik la se yon depans antrepriz la. Montre l sou yon resi ta fè
  // kliyan an kwè se nan lajan pa l li soti.
  assert.equal(json.delivery.feeHtg, undefined);
  assert.equal(json.delivery.feePaidBy, undefined);
});

test("yon tranzaksyon san transfè pa gen chif livrezon", async () => {
  const txId = await create("San transfè");

  const { json } = await call("GET", `/api/transactions/${txId}`, { role: "agent" });

  assert.equal(json.delivery, null, "resi a annik sote liy sa yo");
  assert.equal(json.transaction.txId, txId);
});

test("yon transfè ki echwe pa parèt sou resi a", async () => {
  const txId = await create("Echwe");
  insertTransfer(txId);
  db.getDb()
    .prepare("UPDATE bazik_transfers SET status = 'failed' WHERE tx_id = ?")
    .run(txId);

  const { json } = await call("GET", `/api/transactions/${txId}`, { role: "agent" });

  assert.equal(json.delivery, null, "lajan an pa janm rive: pa gen anyen pou di");
});

// --- Frè ANVWAYÈ a peye ---

test("yon tranzaksyon san frè: anvwayè a peye montan an sèlman", async () => {
  const txId = await create("San frè");

  const { json } = await call("GET", `/api/transactions/${txId}`, { role: "agent" });

  assert.equal(json.transaction.senderFee, 0);
  assert.equal(json.transaction.paymentAmount, 10);
  assert.equal(json.transaction.totalPaid, 10);
});

test("Jean voye 2000, li peye 2100: se 2000 ki pati", async () => {
  const created = await call("POST", "/api/transactions", {
    role: "agent",
    body: {
      serviceName: "MonCash",
      customerName: "Vanessa",
      customerPhone: "+50937123456",
      paymentAmount: 2000,
      paymentCurrency: "MXN",
      senderFee: 100,
    },
  });

  assert.equal(created.status, 200);

  const { json } = await call("GET", `/api/transactions/${created.json.transaction.txId}`, {
    role: "agent",
  });

  assert.equal(json.transaction.paymentAmount, 2000, "sa Vanessa resevwa");
  assert.equal(json.transaction.senderFee, 100, "sa Jean peye anplis");
  assert.equal(json.transaction.totalPaid, 2100, "sa Jean soti nan pòch li");
});

test("frè a pa antre nan kalkil komisyon an", async () => {
  // Telefòn diferan: `tx_id` gen ladan l telefòn nan ak milisgond lan, donk
  // de kreyasyon idantik nan menm milisgond lan antre an konfli.
  const sanFrè = await call("POST", "/api/transactions", {
    role: "agent",
    body: {
      serviceName: "MonCash", customerName: "A", customerPhone: "+50937123401",
      paymentAmount: 2000, paymentCurrency: "MXN",
    },
  });

  const akFrè = await call("POST", "/api/transactions", {
    role: "agent",
    body: {
      serviceName: "MonCash", customerName: "B", customerPhone: "+50937123402",
      paymentAmount: 2000, paymentCurrency: "MXN", senderFee: 100,
    },
  });

  assert.equal(sanFrè.status, 200, JSON.stringify(sanFrè.json));
  assert.equal(akFrè.status, 200, JSON.stringify(akFrè.json));

  // Komisyon yo rete sou sa ki pati, jan yo te ye anvan.
  assert.equal(
    akFrè.json.transaction.commissionAgent,
    sanFrè.json.transaction.commissionAgent
  );
});

test("yon frè negatif oswa pa valid refize", async () => {
  const body = {
    serviceName: "MonCash", customerName: "C", customerPhone: "+50937123456",
    paymentAmount: 2000, paymentCurrency: "MXN",
  };

  const negatif = await call("POST", "/api/transactions", {
    role: "agent", body: { ...body, senderFee: -5 },
  });
  assert.equal(negatif.json.code, "invalid_fee");

  const tèks = await call("POST", "/api/transactions", {
    role: "agent", body: { ...body, senderFee: "abc" },
  });
  assert.equal(tèks.json.code, "invalid_fee");
});
