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

// --- Frè platfòm nan (owner a fikse l, obligatwa) ---

const setPolicy = ({ feePct = 5, minHtg = 0, share = 40 } = {}) =>
  db.getDb()
    .prepare("UPDATE services SET fee_pct = ?, fee_min_htg_minor = ?, agent_share_pct = ? WHERE name = 'MonCash'")
    .run(feePct, Math.round(minHtg * 100), share);

let phoneSeq = 10;
const txBody = (extra = {}) => ({
  serviceName: "MonCash", customerName: "Vanessa", customerPhone: `+509371234${phoneSeq++}`,
  paymentAmount: 2000, paymentCurrency: "MXN", ...extra,
});

test("anvwayè a peye: 5% sou 2000 MXN = 100, kliyan an peye 2100, benefisyè a resevwa 2000", async () => {
  setPolicy();
  const { status, json } = await call("POST", "/api/transactions", { role: "agent", body: txBody({ feeMode: "sender" }) });

  assert.equal(status, 200, JSON.stringify(json));
  assert.equal(json.transaction.feeMode, "sender");
  assert.equal(json.transaction.fee, 100);
  assert.equal(json.transaction.paymentAmount, 2000, "sa benefisyè a resevwa");
  assert.equal(json.transaction.totalPaid, 2100, "sa kliyan an soti nan pòch li");
  assert.equal(json.transaction.commissionAgent, 40, "40% frè a");
  assert.equal(json.transaction.commissionOwner, 60, "rès frè a");
});

test("dedwi: 5% sou 2000 MXN = 100, kliyan an peye 2000, benefisyè a resevwa 1900", async () => {
  setPolicy();
  const { json } = await call("POST", "/api/transactions", { role: "agent", body: txBody({ feeMode: "deducted" }) });

  assert.equal(json.transaction.feeMode, "deducted");
  assert.equal(json.transaction.fee, 100);
  assert.equal(json.transaction.paymentAmount, 1900);
  assert.equal(json.transaction.totalPaid, 2000);
  assert.equal(json.transaction.commissionAgent + json.transaction.commissionOwner, 100, "komisyon yo = frè a, pa plis");
});

test("ajan an pa ka bese frè a: `senderFee` nan kò a inyore", async () => {
  setPolicy();
  const { json } = await call("POST", "/api/transactions", { role: "agent", body: txBody({ senderFee: 0, fee: 0 }) });

  assert.equal(json.transaction.fee, 100);
  assert.equal(json.transaction.feeMode, "sender", "pa defo: anvwayè a peye");
});

test("frè minimòm nan aplike sou ti montan yo", async () => {
  setPolicy({ minHtg: 725 }); // 725 HTG = 100 MXN a 7,25
  const { json } = await call("POST", "/api/transactions", { role: "agent", body: txBody({ paymentAmount: 200 }) });

  assert.equal(json.transaction.fee, 100, "5% sou 200 = 10, men minimòm nan se 100");
  assert.equal(json.quote.minApplied, true);

  const tooSmall = await call("POST", "/api/transactions", {
    role: "agent", body: txBody({ paymentAmount: 100, feeMode: "deducted" }),
  });
  assert.equal(tooSmall.json.code, "amount_below_fee", "benefisyè a pa t ap resevwa anyen");
  setPolicy();
});

test("devi a bay menm chif yo san li pa anrejistre anyen", async () => {
  setPolicy();
  const before = db.getDb().prepare("SELECT COUNT(*) AS n FROM transactions").get().n;
  const { status, json } = await call("POST", "/api/transactions/quote", {
    role: "agent", body: txBody({ feeMode: "deducted" }),
  });

  assert.equal(status, 200, JSON.stringify(json));
  assert.deepEqual(
    [json.quote.fee, json.quote.netAmount, json.quote.totalPaid, json.quote.agentCommission],
    [100, 1900, 2000, 40]
  );
  assert.equal(db.getDb().prepare("SELECT COUNT(*) AS n FROM transactions").get().n, before);
});

test("yon chanjman to pita pa chanje frè yon tranzaksyon ki deja kreye", async () => {
  setPolicy();
  const { json } = await call("POST", "/api/transactions", { role: "agent", body: txBody() });
  setPolicy({ feePct: 20 });

  const after = await call("GET", `/api/transactions/${json.transaction.txId}`, { role: "agent" });
  assert.equal(after.json.transaction.fee, 100);
  setPolicy();
});

// --- Lis: filtre estati + rechèch ---

test("rechèch pa non, nimewo (moso), referans; ak filtre estati", async () => {
  const mk = async (name, phone) =>
    (await call("POST", "/api/transactions", {
      role: "agent",
      body: { serviceName: "MonCash", customerName: name, customerPhone: phone, paymentAmount: 10, paymentCurrency: "USD" },
    })).json.transaction.txId;
  const mirlande = await mk("Mirlande Jean", "+50937124589");
  const wesner = await mk("Wesner Louis", "+50941887720");
  db.getDb().prepare("UPDATE transactions SET status = 'failed' WHERE tx_id = ?").run(wesner);

  const ids = async (query) =>
    (await call("GET", `/api/transactions?limit=200&${query}`, { role: "owner" })).json.transactions.map((t) => t.txId);

  assert.deepEqual(await ids("q=mirlande"), [mirlande], "non, san konsidere majiskil");
  assert.deepEqual(await ids("q=4589"), [mirlande], "4 dènye chif nimewo a");
  assert.deepEqual(await ids("q=%2B509%2041%2088"), [wesner], "nimewo ak +509 ak espas");
  assert.deepEqual(await ids(`q=${wesner.slice(-6)}`), [wesner], "moso referans lan");
  assert.deepEqual(await ids("q=Wesner&status=failed"), [wesner]);
  assert.deepEqual(await ids("q=Wesner&status=delivered"), []);
  assert.deepEqual(await ids("q=%25"), [], "yon % se yon karaktè, pa yon jokè");
});
