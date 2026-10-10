"use strict";

/**
 * Tablo owner a (`/api/analytics/owner`) ak verifikasyon resi (`/api/receipts`).
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "analytics-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const analyticsRoutes = require("../src/routes/analytics.routes");
const { router: receiptRoutes } = require("../src/routes/receipts.routes");
const transactionRoutes = require("../src/routes/transactions.routes");

const ENT = "ENT_ANALYTICS";
const OTHER = "ENT_OTHER";
let server;
let baseUrl;
const tokens = {};
const uids = {};

function insertTx({ ent = ENT, staff = "agent", service = "MonCash", status = "delivered", amount = 100000, currency = "HTG", fee = 10000, at = Date.now(), id }) {
  const txId = id || `TX_${Math.random().toString(36).slice(2)}`;
  db.getDb()
    .prepare(
      `INSERT INTO transactions
        (tx_id, enterprise_id, staff_uid, staff_name, staff_role, client_name, phone, service,
         amount_minor, currency, sender_fee_minor, fee_mode, fee_pct, agent_share_pct, status,
         gateway_ref, commission_applied, created_at, updated_at,
         commission_agent_minor, commission_owner_minor)
       VALUES (?, ?, ?, ?, 'agent', 'K', '+50937124589', ?, ?, ?, ?, 'sender', 10, 40, ?, '', 0, ?, ?, ?, ?)`
    )
    .run(txId, ent, uids[staff] || staff, staff === "agent" ? "Roseline" : "Wilson", service,
      amount, currency, fee, status, at, at, Math.round(fee * 0.4), fee - Math.round(fee * 0.4));
  return txId;
}

test.before(async () => {
  for (const ent of [ENT, OTHER]) {
    db.getDb()
      .prepare(
        `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
         VALUES (?, 'A', '', 'HTG', 1, ?, ?)`
      )
      .run(ent, Date.now(), Date.now());
  }
  for (const role of ["owner", "admin", "agent"]) {
    const user = await users.createUser({
      email: `${role}@analytics.test`, password: "modpas-solid-2026", role,
      enterpriseId: ENT, enterpriseName: "A",
    });
    tokens[role] = createSession(user.uid).token;
    uids[role] = user.uid;
  }
  uids.agent2 = "AGENT_2";

  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/analytics", analyticsRoutes);
  app.use("/api/receipts", receiptRoutes);
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

async function get(route, role) {
  const r = await fetch(`${baseUrl}${route}`, {
    headers: role ? { authorization: `Bearer ${tokens[role]}` } : {},
  });
  return { status: r.status, json: await r.json() };
}

test("analiz: KPI, seri, gwoup, rezo — sou antrepriz la sèlman", async () => {
  insertTx({ amount: 100000 });                                  // 1000 HTG livre
  insertTx({ amount: 50000, service: "NatCash" });               // 500 HTG livre
  insertTx({ staff: "agent2", status: "failed", amount: 30000 });
  insertTx({ status: "pending", amount: 20000 });
  insertTx({ amount: 200000, at: Date.now() - 40 * 86400000 }); // peryòd anvan (30 j)
  insertTx({ ent: OTHER, amount: 999900 });                      // lòt antrepriz

  const { status, json } = await get("/api/analytics/owner?days=30&currency=HTG", "owner");

  assert.equal(status, 200, JSON.stringify(json));
  const k = json.kpis.current;
  assert.equal(k.count, 4);
  assert.equal(k.delivered, 2);
  assert.equal(k.volume, 1500, "sèlman sa ki livre, pa lòt antrepriz la");
  assert.equal(k.successRate, 0.6667);
  assert.equal(k.pending, 1);
  assert.equal(json.kpis.previous.volume, 2000);
  assert.equal(json.series.length, 30);
  assert.equal(json.series.at(-1).volume.moncash + json.series.at(-1).volume.natcash, 1500);

  const agent = json.groups.find((g) => g.key === uids.agent);
  assert.equal(agent.volume, 1500);
  assert.equal(agent.share, 1);
  assert.equal(json.heatmap.flat().reduce((a, b) => a + b, 0), 4);
  assert.deepEqual(json.networkStats.map((n) => n.network).sort(), ["moncash", "natcash"]);
  assert.equal(json.recent[0].phone, "+509 37 •• •• 89", "nimewo a maske");
});

test("analiz: deviz, gwoup pa rezo ak filtre rezo", async () => {
  const usd = await get("/api/analytics/owner?days=30&currency=USD&groupBy=network", "owner");
  assert.equal(usd.json.currency, "USD");
  assert.ok(usd.json.kpis.current.volume > 10 && usd.json.kpis.current.volume < 13, "1500 HTG ≈ 11 USD");
  assert.deepEqual(usd.json.groups.map((g) => g.key).sort(), ["moncash", "natcash"]);

  const onlyNat = await get("/api/analytics/owner?days=30&networks=natcash", "owner");
  assert.equal(onlyNat.json.kpis.current.volume, 500);
});

test("analiz: owner ak admin sèlman", async () => {
  assert.equal((await get("/api/analytics/owner", "agent")).status, 403);
  assert.equal((await get("/api/analytics/owner", "admin")).status, 200);
  assert.equal((await get("/api/analytics/owner")).status, 401);
});

test("resi: siyati a valide, yon montan chanje refize", async () => {
  const txId = insertTx({ amount: 181250, currency: "HTG" });
  const { json } = await get(`/api/transactions/${txId}`, "agent");

  assert.match(json.receipt.signature, /^[0-9a-f]{16}$/);
  assert.ok(json.receipt.verifyUrl.includes(`/api/receipts/verify?tx=${txId}&s=`));

  const ok = await get(`/api/receipts/verify?tx=${txId}&s=${json.receipt.signature}`);
  assert.equal(ok.status, 200);
  assert.equal(ok.json.valid, true);
  assert.equal(ok.json.amount, 1812.5);

  const forged = await get(`/api/receipts/verify?tx=${txId}&s=0000000000000000`);
  assert.equal(forged.status, 404);
  assert.equal(forged.json.valid, false);

  db.getDb().prepare("UPDATE transactions SET amount_minor = 999999 WHERE tx_id = ?").run(txId);
  const tampered = await get(`/api/receipts/verify?tx=${txId}&s=${json.receipt.signature}`);
  assert.equal(tampered.json.valid, false, "montan an chanje: siyati a pa bon ankò");
});

test("tablo ajan: sèlman tranzaksyon pa l, komisyon nan deviz wallet li", async () => {
  const { json, status } = await get("/api/analytics/agent?days=30", "agent");
  assert.equal(status, 200, JSON.stringify(json));
  // 2 livre + 1 an atant (+ tranzaksyon resi a) pou "agent"; echèk "agent2" a pa konte.
  assert.ok(json.kpis.count >= 3);
  assert.equal(json.kpis.failed, 0, "echèk la se pou agent2");
  assert.equal(json.commissionSeries.length, 7);
  assert.ok(json.inProgress.every((t) => t.phone.includes("••")), "nimewo maske");
  assert.ok(json.inProgress.some((t) => t.status === "pending"));

  const owner = await get("/api/analytics/agent?days=30", "owner");
  assert.equal(owner.json.kpis.count, 0, "owner a pa wè tranzaksyon ajan an nan pwòp tablo ajan l");
});
