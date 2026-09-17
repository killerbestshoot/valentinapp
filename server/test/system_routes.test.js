"use strict";

/**
 * Wout sistèm yo pase pa HTTP: se yo ki garanti "done lajan = owner sèlman".
 * Kache yon chif nan UI a pa pwoteje anyen si API a bay li.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "system-routes-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
delete process.env.RELOADLY_MODE;

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const { getBazikService } = require("../src/bazik_service");
const systemRoutes = require("../src/routes/system.routes");
const airtimeRoutes = require("../src/routes/airtime.routes");

const ENT = "ENT_SYS";
let server;
let baseUrl;
const tokens = {};

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, 'Sys E2E', '', 'USD', 1, ?, ?)`
    )
    .run(ENT, Date.now(), Date.now());

  for (const role of ["owner", "admin", "agent"]) {
    const user = await users.createUser({
      email: `${role}@sys.test`,
      password: "modpas-solid-2026",
      role,
      enterpriseId: ENT,
      enterpriseName: "Sys E2E",
    });
    tokens[role] = createSession(user.uid).token;
    if (role === "owner") {
      db.getDb().prepare("UPDATE enterprises SET owner_uid = ? WHERE enterprise_id = ?").run(user.uid, ENT);
    }
    if (role === "agent") {
      // 5 000 USD float: pi plis pase pwovizyon similatè yo (100 000 HTG + 1 000 USD).
      await getBazikService().store.creditWallet({
        uid: user.uid, enterpriseId: ENT, amountMinor: 500000, currency: "USD",
        type: "seed", idempotencyKey: "sys:agent",
      });
    }
  }

  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/system", systemRoutes);
  app.use("/api/airtime", airtimeRoutes);
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

async function get(route, role) {
  const response = await fetch(`${baseUrl}${route}`, {
    headers: role ? { authorization: `Bearer ${tokens[role]}` } : {},
  });
  const text = await response.text();
  return { status: response.status, text, json: JSON.parse(text) };
}

// --- Pèmisyon Reloadly nan onglet sante a -------------------------------------

test("owner: 6 pèmisyon yo ak tout seksyon yo", async () => {
  const { status, json } = await get("/api/system/reloadly", "owner");

  assert.equal(status, 200);
  assert.deepEqual(
    json.permissions.map((p) => p.scope),
    ["send-topups", "read-operators", "read-promotions", "read-topups-history", "read-prepaid-balance", "read-prepaid-commissions"]
  );
  assert.ok(json.permissions.every((p) => p.granted));
  assert.deepEqual(
    json.permissions.filter((p) => p.ownerOnly).map((p) => p.scope),
    ["read-topups-history", "read-prepaid-balance", "read-prepaid-commissions"]
  );
  assert.equal(json.sections.operators.ok, true);
  assert.equal(json.sections.balance.data.currency, "USD");
  assert.ok(json.sections.commissions.data.length >= 1);
  assert.equal(json.sections.history.ok, true);
});

test("admin: pèmisyon yo vizib, men OKENN chif lajan pa soti nan API a", async () => {
  const { status, json, text } = await get("/api/system/reloadly", "admin");

  assert.equal(status, 200);
  assert.equal(json.permissions.length, 6, "admin nan wè ki pèmisyon kont lan genyen");
  assert.equal(json.sections.operators.ok, true, "operatè yo se done operasyonèl");
  for (const name of ["balance", "commissions", "history"]) {
    assert.deepEqual(json.sections[name], { ok: false, restricted: true }, name);
  }
  assert.ok(!text.includes('"balance":1'), "sòld la pa dwe parèt");
});

test("agent: pa gen aksè ditou", async () => {
  assert.equal((await get("/api/system/reloadly", "agent")).status, 403);
  assert.equal((await get("/api/system/reloadly")).status, 401);
});

// --- Solvabilite ----------------------------------------------------------------

test("owner: sante a pote solvabilite a, e li wè float la pa kouvri", async () => {
  const { json } = await get("/api/system/health", "owner");
  const solvency = json.checks.solvency;

  assert.equal(solvency.status, "uncovered", "5 000 USD float vs pwovizyon similatè yo");
  assert.equal(solvency.currency, "HTG");
  assert.ok(solvency.gap > 0);
  assert.ok(solvency.coverage.bazik.available > 0);
  assert.ok(solvency.coverage.reloadly.available > 0);
});

test("admin: solvabilite a rezève", async () => {
  const { json, text } = await get("/api/system/health", "admin");
  assert.deepEqual(json.checks.solvency, { restricted: true });
  assert.ok(!text.includes('"gap"'));
});

test("notifikasyon: alèt solvabilite pou owner sèlman", async () => {
  const owner = await get("/api/system/notifications", "owner");
  const admin = await get("/api/system/notifications", "admin");

  const alert = owner.json.notifications.find((n) => n.type.startsWith("solvency"));
  assert.ok(alert, "owner dwe wè alèt la");
  assert.equal(alert.severity, "warning");
  assert.match(alert.title, /PA kouvri/);

  assert.ok(!admin.json.notifications.some((n) => n.type.startsWith("solvency")));
});

// --- Sòld Reloadly nan /api/airtime/status ----------------------------------------

test("sòld Reloadly: chif la pou owner, `funded` pou lòt yo", async () => {
  const owner = await get("/api/airtime/status", "owner");
  assert.equal(typeof owner.json.account.balance, "number");
  assert.equal(owner.json.funded, true);

  for (const role of ["admin", "agent"]) {
    const other = await get("/api/airtime/status", role);
    assert.deepEqual(other.json.account, { restricted: true, currency: "USD" }, role);
    assert.equal(other.json.funded, true, "UI a toujou ka avèti anvan yon vant");
    assert.ok(!other.text.includes('"balance"'), role);
  }
});
