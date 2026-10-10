"use strict";

/** Owner a mete sòld yon wallet sou yon montan egzak, ak tras nan rejis la. */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "adjust-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const walletRoutes = require("../src/routes/wallets.routes");
const { getBazikService } = require("../src/bazik_service");

const ENT = "ENT_ADJ";
let server;
let baseUrl;
const tokens = {};
const uids = {};

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, 'A', '', 'USD', 1, ?, ?)`
    )
    .run(ENT, Date.now(), Date.now());
  for (const [role, currency] of [["owner", "USD"], ["admin", "HTG"], ["agent", "MXN"]]) {
    const user = await users.createUser({
      email: `${role}@adj.test`, password: "modpas-solid-2026", role, enterpriseId: ENT, enterpriseName: "A", currency,
    });
    tokens[role] = createSession(user.uid).token;
    uids[role] = user.uid;
  }
  await getBazikService().store.creditWallet({
    uid: uids.agent, enterpriseId: ENT, enterpriseName: "A", role: "agent", amountMinor: 600000,
    currency: "MXN", type: "seed", note: "seed", idempotencyKey: "seed:adj",
  });
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/wallets", walletRoutes);
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

const adjust = (uid, body, role = "owner") =>
  fetch(`${baseUrl}/api/wallets/${uid}/adjust`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${tokens[role]}` },
    body: JSON.stringify(body),
  }).then(async (r) => ({ status: r.status, json: await r.json() }));

test("6000 → 15 MXN: yon liy ajisteman nan rejis la", async () => {
  assert.equal((await adjust(uids.agent, { balance: 15 })).json.code, "note_required");
  assert.equal((await adjust(uids.agent, { balance: 15, note: "korije sòld tès" }, "admin")).status, 403);

  const ok = await adjust(uids.agent, { balance: 15, note: "korije sòld tès" });
  assert.equal(ok.status, 200, JSON.stringify(ok.json));
  assert.equal(ok.json.wallet.balance, 15);
  assert.equal(ok.json.adjustment, -5985);

  const line = db.getDb()
    .prepare("SELECT type, amount_minor, direction, note FROM wallet_ledger WHERE uid = ? ORDER BY rowid DESC LIMIT 1")
    .get(uids.agent);
  assert.equal(line.type, "adjustment");
  assert.equal(line.amount_minor, 598500);
  assert.equal(line.direction, "debit");
  assert.match(line.note, /korije sòld tès/);
});

test("menm sòld: anyen pa chanje; negatif refize; lòt antrepriz 404", async () => {
  const same = await adjust(uids.agent, { balance: 15, note: "pa gen chanjman" });
  assert.equal(same.json.adjustment, 0);
  assert.equal((await adjust(uids.agent, { balance: -1, note: "negatif" })).json.code, "invalid_amount");
  assert.equal((await adjust("UID_INKONI", { balance: 1, note: "pa egziste" })).status, 404);
});

test("wallet owner a ka monte san kontwòl solvabilite (se antrepriz la menm)", async () => {
  const ok = await adjust(uids.owner, { balance: 52.27, note: "aliyen ak Bazik" });
  assert.equal(ok.status, 200, JSON.stringify(ok.json));
  assert.equal(ok.json.wallet.balance, 52.27);
});
