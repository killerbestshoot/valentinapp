"use strict";

/**
 * De règ:
 *   1. Owner/admin pa ka kredite yon staff plis pase sa pwovizyon Bazik la ka
 *      kouvri (float tout staff + nouvo kredi ≤ Bazik). Sinon: ensolvab.
 *   2. Yon staff ki poko janm fè okenn mouvman ka efase; lòt yo, non.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "credit-guard-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const authRoutes = require("../src/routes/auth.routes");
const walletRoutes = require("../src/routes/wallets.routes");
const usersRoutes = require("../src/routes/users.routes");
const { attachUser } = require("../src/auth/middleware");
const { getBazikService } = require("../src/bazik_service");

const app = express();
app.use(express.json());
app.use(attachUser);
app.use("/api/auth", authRoutes);
app.use("/api/wallets", walletRoutes);
app.use("/api/users", usersRoutes);

let server;
let ownerToken;
const staff = {};

async function call(method, route, body, token = ownerToken) {
  const { port } = server.address();
  const res = await fetch(`http://127.0.0.1:${port}${route}`, {
    method,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

/** Pwovizyon Bazik la, san rezo. */
function bazikHas(htg, error = null) {
  getBazikService().gatewayWallet = async () => {
    if (error) throw Object.assign(new Error(error), { code: error });
    return { availableMinor: Math.round(htg * 100), reservedMinor: 0, currency: "HTG" };
  };
}

function balanceOf(uid) {
  const row = db.getDb().prepare("SELECT balance_minor FROM wallets WHERE uid = ?").get(uid);
  return row ? row.balance_minor / 100 : null;
}

async function createAgent(key) {
  const { status, body } = await call("POST", "/api/users", {
    email: `${key}@example.com`,
    password: "modpas-ajan-2026",
    displayName: key,
    role: "agent",
    currency: "HTG",
    mustChangePassword: false,
  });
  assert.equal(status, 200, JSON.stringify(body));
  staff[key] = body.user.uid;
  return body.user.uid;
}

test.before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once("listening", resolve));

  const boot = await call(
    "POST",
    "/api/auth/bootstrap",
    {
      email: "owner@example.com",
      password: "modpas-owner-2026",
      displayName: "Owner",
      enterpriseName: "Test Ent",
      currency: "HTG",
    },
    null
  );
  assert.equal(boot.status, 200, JSON.stringify(boot.body));
  ownerToken = boot.body.token;

  await createAgent("a");
  await createAgent("b");
});

test.after(() => {
  server.close();
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

test("kredi dirèk ki rantre nan pwovizyon Bazik la pase", async () => {
  bazikHas(10000);

  const { status, body } = await call("POST", "/api/wallets/topups", {
    targetUid: staff.a,
    amount: 6000,
    currency: "HTG",
    autoApprove: true,
  });

  assert.equal(status, 200, JSON.stringify(body));
  assert.equal(body.credited, true);
  assert.equal(balanceOf(staff.a), 6000);
});

test("kredi dirèk ki depase pwovizyon an refize, ak maksimòm nan", async () => {
  bazikHas(10000); // 6 000 deja pwomèt → 4 000 rete

  const { status, body } = await call("POST", "/api/wallets/topups", {
    targetUid: staff.b,
    amount: 5000,
    currency: "HTG",
    autoApprove: true,
  });

  assert.equal(status, 409);
  assert.equal(body.code, "insufficient_coverage");
  assert.equal(body.maxCreditHtg, 4000);
  assert.equal(balanceOf(staff.b), 0, "pa okenn kòb pa antre");

  const left = db
    .getDb()
    .prepare("SELECT COUNT(*) AS n FROM wallet_topup_requests WHERE target_uid = ? AND processed = 0")
    .get(staff.b).n;
  assert.equal(left, 0, "demann ki echwe a pa rete an atant");
});

test("apwobasyon yon demann tcheke pwovizyon an LÈ L APWOUVE", async () => {
  // Demann lan kreye lè Bazik te gen anpil; li apwouve lè l pa genyen ankò.
  bazikHas(100000);
  const created = await call("POST", "/api/wallets/topups", {
    targetUid: staff.b,
    amount: 5000,
    currency: "HTG",
  });
  assert.equal(created.status, 200);

  bazikHas(10000);
  const refused = await call("POST", `/api/wallets/topups/${created.body.requestId}/approve`);
  assert.equal(refused.status, 409);
  assert.equal(refused.body.code, "insufficient_coverage");
  assert.equal(balanceOf(staff.b), 0);

  // Demann lan rete an atant: owner ka re-eseye lè l fin mete kòb sou Bazik.
  bazikHas(11000);
  const ok = await call("POST", `/api/wallets/topups/${created.body.requestId}/approve`);
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.equal(balanceOf(staff.b), 5000);
});

test("de apwobasyon paralèl pa ka tou de konte sou menm kòb la", async () => {
  bazikHas(14000); // 11 000 pwomèt → 3 000 rete

  const ids = [];
  for (let i = 0; i < 2; i += 1) {
    const r = await call("POST", "/api/wallets/topups", {
      targetUid: staff.a,
      amount: 2000,
      currency: "HTG",
    });
    ids.push(r.body.requestId);
  }

  const results = await Promise.all(
    ids.map((id) => call("POST", `/api/wallets/topups/${id}/approve`))
  );

  assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
  assert.equal(balanceOf(staff.a), 8000);
});

test("Bazik pa reponn: kredi a refize (nou pa devine)", async () => {
  bazikHas(0, "gateway_timeout");

  const { status, body } = await call("POST", "/api/wallets/topups", {
    targetUid: staff.a,
    amount: 1,
    currency: "HTG",
    autoApprove: true,
  });

  assert.equal(status, 503);
  assert.equal(body.code, "solvency_unknown");
});

test("wallet owner an pa yon dèt: li pa bloke", async () => {
  bazikHas(0);
  const me = await call("GET", "/api/users");
  const owner = me.body.users.find((u) => u.role === "owner");

  const { status } = await call("POST", "/api/wallets/topups", {
    targetUid: owner.uid,
    amount: 1000,
    currency: "HTG",
    autoApprove: true,
  });

  assert.equal(status, 200);
});

// --- Efase yon ajan ---

test("efase: yon ajan ki gen istorik refize", async () => {
  const { status, body } = await call("DELETE", `/api/users/${staff.a}`);

  assert.equal(status, 409);
  assert.equal(body.code, "has_history");
  assert.ok(db.getDb().prepare("SELECT 1 FROM users WHERE uid = ?").get(staff.a));
});

test("efase: yon ajan ki poko fè anyen disparèt nèt", async () => {
  const uid = await createAgent("c");

  const { status, body } = await call("DELETE", `/api/users/${uid}`);

  assert.equal(status, 200, JSON.stringify(body));
  for (const [table, column] of [
    ["users", "uid"],
    ["enterprise_users", "uid"],
    ["wallets", "uid"],
  ]) {
    const row = db.getDb().prepare(`SELECT 1 FROM ${table} WHERE ${column} = ?`).get(uid);
    assert.equal(row, undefined, `${table} toujou gen ajan an`);
  }

  // Imel la libere: ka kreye kont lan ankò.
  await createAgent("c");
});

test("efase: pa pwòp kont ou, pa yon owner", async () => {
  const me = await call("GET", "/api/users");
  const owner = me.body.users.find((u) => u.role === "owner");

  const { status, body } = await call("DELETE", `/api/users/${owner.uid}`);
  assert.equal(status, 403);
  assert.equal(body.code, "cannot_modify_self");
});
