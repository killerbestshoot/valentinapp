"use strict";

/**
 * Virement bancaire: kont bank antrepriz la (admin), rechaj ajan pa virement,
 * payout sou kont bank ajan an.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "bank-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const walletRoutes = require("../src/routes/wallets.routes");
const payoutRoutes = require("../src/routes/payouts.routes");
const settingsRoutes = require("../src/routes/settings.routes");
const { getBazikService } = require("../src/bazik_service");

const ENT = "ENT_BANK";
let server;
let baseUrl;
const tokens = {};
const uids = {};

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, 'B', '', 'HTG', 1, ?, ?)`
    )
    .run(ENT, Date.now(), Date.now());
  for (const role of ["owner", "admin", "agent"]) {
    const user = await users.createUser({
      email: `${role}@bank.test`, password: "modpas-solid-2026", role, enterpriseId: ENT, enterpriseName: "B", currency: "HTG",
    });
    tokens[role] = createSession(user.uid).token;
    uids[role] = user.uid;
  }
  await getBazikService().store.creditWallet({
    uid: uids.agent, enterpriseId: ENT, enterpriseName: "B", role: "agent", amountMinor: 500000,
    currency: "HTG", type: "seed", note: "seed", idempotencyKey: "seed:bank",
  });
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/wallets", walletRoutes);
  app.use("/api/payouts", payoutRoutes);
  app.use("/api/settings", settingsRoutes);
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

const call = (method, url, role, body) =>
  fetch(`${baseUrl}${url}`, {
    method,
    headers: { "content-type": "application/json", authorization: `Bearer ${tokens[role]}` },
    body: body ? JSON.stringify(body) : undefined,
  }).then(async (r) => ({ status: r.status, json: await r.json() }));

const balance = async () =>
  (await getBazikService().store.getWallet({ uid: uids.agent, enterpriseId: ENT })).balanceMinor;

test("kont bank: admin konfigire, ajan li sèlman", async () => {
  const account = { bankName: "Unibank", accountName: "VOUPVAPCASH SA", accountNumber: "123-456", currency: "htg" };

  assert.equal((await call("PATCH", "/api/settings/bank-accounts", "agent", { accounts: [account] })).status, 403);
  assert.equal(
    (await call("PATCH", "/api/settings/bank-accounts", "admin", { accounts: [{ bankName: "X" }] })).json.code,
    "invalid_bank_accounts"
  );

  const saved = await call("PATCH", "/api/settings/bank-accounts", "admin", { accounts: [account] });
  assert.equal(saved.status, 200, JSON.stringify(saved.json));
  assert.equal(saved.json.accounts[0].currency, "HTG");
  assert.ok(saved.json.accounts[0].id);

  const seen = await call("GET", "/api/settings/bank-accounts", "agent");
  assert.equal(seen.json.accounts[0].accountNumber, "123-456");
});

test("rechaj pa virement: ajan mande pou tèt li, admin apwouve", async () => {
  // Referans obligatwa.
  const missing = await call("POST", "/api/wallets/topups", "agent", { amount: 100, currency: "HTG", method: "bank" });
  assert.equal(missing.json.code, "missing_bank_reference");

  // Ajan an pa ka vize yon lòt moun ni otoapwouve.
  const created = await call("POST", "/api/wallets/topups", "agent", {
    targetUid: uids.admin, amount: 100, currency: "HTG", method: "bank", bankReference: "TRX-889", autoApprove: true,
  });
  assert.equal(created.status, 200, JSON.stringify(created.json));
  assert.equal(created.json.credited, undefined);

  const row = db.getDb().prepare("SELECT * FROM wallet_topup_requests WHERE request_id = ?").get(created.json.requestId);
  assert.equal(row.target_uid, uids.agent);
  assert.equal(row.network, "bank");
  assert.equal(row.bank_reference, "TRX-889");
  assert.match(row.bank_account, /Unibank · 123-456 \(HTG\)/);

  // Ajan an pa ka apwouve pwòp demann li.
  assert.equal((await call("POST", `/api/wallets/topups/${row.request_id}/approve`, "agent")).status, 403);

  const list = await call("GET", "/api/wallets/topups", "admin");
  const item = list.json.topups.find((t) => t.requestId === row.request_id);
  assert.equal(item.method, "bank");
  assert.equal(item.bankReference, "TRX-889");
});

test("payout bank: detay obligatwa, apwobasyon debite wallet la yon sèl fwa", async () => {
  const incomplete = await call("POST", "/api/payouts", "agent", { amount: 1000, network: "bank", bankName: "BNC" });
  assert.equal(incomplete.json.code, "missing_bank_details");

  const created = await call("POST", "/api/payouts", "agent", {
    amount: 1000, network: "bank", bankName: "BNC", bankAccountName: "Jean Agent", bankAccountNumber: "987654",
  });
  assert.equal(created.status, 200, JSON.stringify(created.json));
  assert.equal(created.json.payout.network, "bank");
  assert.equal(created.json.payout.bankAccountNumber, "987654");

  const before = await balance();
  const id = created.json.payout.requestId;
  const approved = await call("POST", `/api/payouts/${id}/approve`, "admin", { reference: "VIR-42" });
  assert.equal(approved.status, 200, JSON.stringify(approved.json));
  assert.equal(approved.json.payout.status, "approved");
  assert.equal(approved.json.payout.transferId, "VIR-42");
  assert.equal(await balance(), before - 100000);

  // Dezyèm klik: refize, pa gen dezyèm debi.
  assert.equal((await call("POST", `/api/payouts/${id}/approve`, "admin")).json.code, "already_processed");
  assert.equal(await balance(), before - 100000);
});

test("payout bank: sòld ensifizan → failed, anyen pa debite", async () => {
  const created = await call("POST", "/api/payouts", "agent", {
    amount: 3000, network: "bank", bankName: "BNC", bankAccountName: "Jean Agent", bankAccountNumber: "987654",
  });
  const id = created.json.payout.requestId;

  // Sòld la desann ant demann lan ak apwobasyon an.
  await getBazikService().store.debitWallet({
    uid: uids.agent, enterpriseId: ENT, amountMinor: 300000, currency: "HTG", type: "test", idempotencyKey: "drain:bank",
  });
  const before = await balance();

  const res = await call("POST", `/api/payouts/${id}/approve`, "admin");
  assert.equal(res.json.code, "insufficient_funds");
  assert.equal(await balance(), before);
  assert.equal(db.getDb().prepare("SELECT status FROM payout_requests WHERE request_id = ?").get(id).status, "failed");
});
