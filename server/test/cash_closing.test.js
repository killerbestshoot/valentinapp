"use strict";

/** Fèmti kès: kès atann kalkile pa sèvè a, ekar, validasyon, verou, CSV. */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "cash-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const cashRoutes = require("../src/routes/cash.routes");

const ENT = "ENT_CASH";
const DATE = "2026-10-12";
// 2026-10-12 15:00 lè Ayiti (UTC−4) = 19:00 UTC.
const AT = Date.parse("2026-10-12T19:00:00Z");
let server;
let baseUrl;
const tokens = {};
const uids = {};

function seedTx(id, { uid = uids.agent, currency = "MXN", amount, fee = 0, status = "delivered", at = AT }) {
  db.getDb()
    .prepare(
      `INSERT INTO transactions (tx_id, enterprise_id, staff_uid, service, phone, amount_minor, sender_fee_minor, currency, status, created_at, updated_at)
       VALUES (?, ?, ?, 'MonCash', '37123456', ?, ?, ?, ?, ?, ?)`
    )
    .run(id, ENT, uid, amount, fee, currency, status, at, at);
}

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, 'C', '', 'HTG', 1, ?, ?)`
    )
    .run(ENT, Date.now(), Date.now());
  for (const role of ["owner", "admin", "agent"]) {
    const user = await users.createUser({
      email: `${role}@cash.test`, password: "modpas-solid-2026", role, enterpriseId: ENT, enterpriseName: "C", currency: "HTG",
    });
    tokens[role] = createSession(user.uid).token;
    uids[role] = user.uid;
  }
  // Jounen an: 2 vant MXN (frè anplis), 1 USD, 1 MXN echwe (ranbouse), 1 nan jou anvan an.
  seedTx("T1", { amount: 200000, fee: 20000 });
  seedTx("T2", { amount: 100000, fee: 10000, status: "pending" });
  seedTx("T3", { currency: "USD", amount: 5000, fee: 500 });
  seedTx("T4", { amount: 50000, fee: 5000, status: "failed" });
  seedTx("T5", { amount: 99900, at: Date.parse("2026-10-12T03:00:00Z") }); // 11 oktòb 23:00 lè Ayiti

  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/cash", cashRoutes);
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
  }).then(async (r) => ({ status: r.status, json: r.headers.get("content-type")?.includes("json") ? await r.json() : await r.text() }));

test("kès atann: lavant pa deviz, jou lokal Ayiti, echwe yo pa konte", async () => {
  const res = await call("GET", `/api/cash/expected?date=${DATE}`, "agent");
  assert.equal(res.status, 200, JSON.stringify(res.json));
  const mxn = res.json.currencies.find((c) => c.currency === "MXN");
  const usd = res.json.currencies.find((c) => c.currency === "USD");
  assert.equal(mxn.sales, 3300, "2000+200 + 1000+100; T4 echwe, T5 jou anvan");
  assert.equal(mxn.txCount, 2);
  assert.equal(mxn.pendingCount, 1);
  assert.equal(mxn.refundedCount, 1);
  assert.equal(usd.sales, 55);

  // Yon ajan pa ka gade kès yon lòt moun.
  assert.equal((await call("GET", `/api/cash/expected?date=${DATE}&uid=${uids.admin}`, "agent")).status, 403);
});

test("voye fèmti: chak deviz ki gen lavant obligatwa, ekar mande yon nòt", async () => {
  const onlyMxn = await call("POST", "/api/cash/closings", "agent", {
    date: DATE, lines: [{ currency: "MXN", opening: 500, deposit: 0, counted: 3800 }],
  });
  assert.equal(onlyMxn.json.code, "missing_currency");

  const short = await call("POST", "/api/cash/closings", "agent", {
    date: DATE,
    lines: [
      // Ajan an voye "sales" fo: sèvè a inyore l.
      { currency: "MXN", opening: 500, deposit: 2000, counted: 1750, sales: 99999 },
      { currency: "USD", opening: 0, counted: 55 },
    ],
  });
  assert.equal(short.json.code, "variance_note_required");

  const ok = await call("POST", "/api/cash/closings", "agent", {
    date: DATE,
    note: "Mwen bay monnen 50 MXN pa erè",
    lines: [{ currency: "MXN", opening: 500, deposit: 2000, counted: 1750 }, { currency: "USD", opening: 0, counted: 55 }],
  });
  assert.equal(ok.status, 200, JSON.stringify(ok.json));
  const mxn = ok.json.closing.lines.find((l) => l.currency === "MXN");
  assert.equal(mxn.sales, 3300);
  assert.equal(mxn.expected, 1800, "500 + 3300 − 2000");
  assert.equal(mxn.variance, -50);
  assert.equal(ok.json.closing.balanced, false);
  assert.equal(ok.json.closing.status, "submitted");
});

test("validasyon: pa pwòp kès ou, rejte mande yon nòt, valide fèmen jounen an", async () => {
  const list = await call("GET", `/api/cash/closings?from=${DATE}&to=${DATE}`, "owner");
  assert.equal(list.json.pending, 1);
  assert.equal(list.json.variance.MXN, -50);
  const id = list.json.closings[0].closingId;

  assert.equal((await call("POST", `/api/cash/closings/${id}/validate`, "agent")).status, 403);
  assert.equal((await call("POST", `/api/cash/closings/${id}/reject`, "admin", { note: "" })).json.code, "note_required");

  const rejected = await call("POST", `/api/cash/closings/${id}/reject`, "admin", { note: "Rekonte USD la" });
  assert.equal(rejected.json.closing.status, "rejected");

  // Ajan an refè l: li tounen `submitted`.
  const redo = await call("POST", "/api/cash/closings", "agent", {
    date: DATE, note: "Mwen bay monnen 50 MXN pa erè",
    lines: [{ currency: "MXN", opening: 500, deposit: 2000, counted: 1750 }, { currency: "USD", counted: 55 }],
  });
  assert.equal(redo.json.closing.status, "submitted");

  const validated = await call("POST", `/api/cash/closings/${id}/validate`, "owner", { note: "OK" });
  assert.equal(validated.json.closing.status, "validated");

  const locked = await call("POST", "/api/cash/closings", "agent", {
    date: DATE, lines: [{ currency: "MXN", opening: 500, deposit: 2000, counted: 1800 }, { currency: "USD", counted: 55 }],
  });
  assert.equal(locked.status, 409);
  assert.equal(locked.json.code, "closing_locked");
});

test("fon kès demen = kach konte jodi a; ekspòtasyon CSV", async () => {
  const next = await call("GET", "/api/cash/expected?date=2026-10-13", "agent");
  const mxn = next.json.currencies.find((c) => c.currency === "MXN");
  assert.equal(mxn.suggestedOpening, 1750);

  assert.equal((await call("GET", `/api/cash/closings.csv?from=${DATE}&to=${DATE}`, "agent")).status, 403);
  const csv = await call("GET", `/api/cash/closings.csv?from=${DATE}&to=${DATE}`, "owner");
  assert.equal(csv.status, 200);
  assert.match(csv.json, /Dat,Ajan,Deviz/);
  assert.match(csv.json, /2026-10-12,.*,MXN,500\.00,3300\.00,2,2000\.00,1800\.00,1750\.00,-50\.00,validated/);
});

test("pa gen fèmti pou yon jou ki poko rive", async () => {
  const res = await call("POST", "/api/cash/closings", "agent", { date: "2099-01-01", lines: [{ currency: "HTG", counted: 0 }] });
  assert.equal(res.json.code, "future_date");
});
