"use strict";

/**
 * De fonksyonalite:
 *   1. Enskripsyon libè ajan: kont rete `is_active = 0` jiskaske owner apwouve.
 *   2. Majin to echanj: owner mete yon valè 0..0.80 ki soustrè de chak to.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "reg-margin-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const authRoutes = require("../src/routes/auth.routes");
const walletRoutes = require("../src/routes/wallets.routes");
const settingsRoutes = require("../src/routes/settings.routes");
const usersRoutes = require("../src/routes/users.routes");
const { attachUser } = require("../src/auth/middleware");
const settings = require("../src/settings/settings");
const { getBazikService } = require("../src/bazik_service");

const app = express();
app.use(express.json());
app.use(attachUser);
app.use("/api/auth", authRoutes);
app.use("/api/wallets", walletRoutes);
app.use("/api/settings", settingsRoutes);
app.use("/api/users", usersRoutes);

function url(server, path) {
  const { port } = server.address();
  return `http://127.0.0.1:${port}${path}`;
}

async function post(server, path, body, token) {
  const res = await fetch(url(server, path), {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body || {}),
  });
  return { status: res.status, body: await res.json() };
}

async function patch(server, path, body, token) {
  const res = await fetch(url(server, path), {
    method: "PATCH",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body || {}),
  });
  return { status: res.status, body: await res.json() };
}

async function get(server, path, token) {
  const res = await fetch(url(server, path), {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  return { status: res.status, body: await res.json() };
}

async function withServer(fn) {
  const server = app.listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  try {
    return await fn(server);
  } finally {
    server.close();
  }
}

test.after(() => {
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

// --- Enskripsyon ajan ---

test("register-agent: refize si sistèm nan poko bootstrap", async () => {
  await withServer(async (server) => {
    const { status, body } = await post(server, "/api/auth/register-agent", {
      email: "early@example.com",
      password: "modpas-solid-2026",
      displayName: "Twò bonè",
      currency: "USD",
    });

    assert.equal(status, 409);
    assert.equal(body.code, "no_enterprise");
  });
});

test("bootstrap owner la dabò pou prepare antrepriz la", async () => {
  await withServer(async (server) => {
    const { status, body } = await post(server, "/api/auth/bootstrap", {
      email: "owner@example.com",
      password: "modpas-owner-2026",
      displayName: "Owner",
      enterpriseName: "Test Ent",
      currency: "USD",
    });

    assert.equal(status, 200);
    assert.ok(body.token);
  });
});

test("register-agent: kreye kont ki tann apwobasyon", async () => {
  await withServer(async (server) => {
    const { status, body } = await post(server, "/api/auth/register-agent", {
      email: "pending@example.com",
      password: "modpas-ajan-2026",
      displayName: "Ajan Pending",
      currency: "USD",
    });

    assert.equal(status, 200);
    assert.equal(body.ok, true);
    assert.equal(body.pending, true);
    // Pa gen jeton: kont lan pa gen dwa konekte toujou.
    assert.equal(body.token, undefined);
  });
});

test("register-agent: kont ki tann apwobasyon pa ka konekte", async () => {
  await withServer(async (server) => {
    const { status, body } = await post(server, "/api/auth/login", {
      email: "pending@example.com",
      password: "modpas-ajan-2026",
    });

    assert.equal(status, 403);
    assert.equal(body.code, "account_disabled");
  });
});

test("register-agent: apre owner apwouve, konekte travay", async () => {
  await withServer(async (server) => {
    // Owner konekte
    const owner = await post(server, "/api/auth/login", {
      email: "owner@example.com",
      password: "modpas-owner-2026",
    });

    // Jwenn ajan an
    const users = await get(server, "/api/users", owner.body.token);
    const pending = users.body.users.find(
      (u) => u.email === "pending@example.com"
    );
    assert.ok(pending);
    assert.equal(pending.isActive, false);
    assert.equal(pending.createdBy, "self_register");

    // Apwouve
    const activated = await patch(
      server,
      `/api/users/${pending.uid}`,
      { isActive: true },
      owner.body.token
    );
    assert.equal(activated.status, 200);
    assert.equal(activated.body.user.isActive, true);

    // Ajan an konekte kounye a
    const login = await post(server, "/api/auth/login", {
      email: "pending@example.com",
      password: "modpas-ajan-2026",
    });
    assert.equal(login.status, 200);
    assert.ok(login.body.token);
  });
});

// --- Majin to echanj ---

test("majin: default se 0 (okenn soustraksyon)", () => {
  assert.equal(settings.getExchangeMargin(), 0);
});

test("majin: owner ka mete 0..0.80", () => {
  const saved = settings.setExchangeMargin(0.5, "owner-uid");
  assert.equal(saved, 0.5);
  assert.equal(settings.getExchangeMargin(), 0.5);

  settings.setExchangeMargin(0.8, "owner-uid");
  assert.equal(settings.getExchangeMargin(), 0.8);

  settings.setExchangeMargin(0, "owner-uid");
  assert.equal(settings.getExchangeMargin(), 0);
});

test("majin: valè pi gran pase 0.80 oswa negatif refize", () => {
  assert.throws(() => settings.setExchangeMargin(1.0, ""), {
    code: "invalid_margin",
  });
  assert.throws(() => settings.setExchangeMargin(-0.1, ""), {
    code: "invalid_margin",
  });
  assert.throws(() => settings.setExchangeMargin("pa yon nimero", ""), {
    code: "invalid_margin",
  });
});

test("majin: applyMargin soustrè, HTG pa afekte", () => {
  assert.equal(settings.applyMargin(7.6, 0.8), 6.8);
  assert.equal(settings.applyMargin(132, 0.8), 131.2);
  // Pou to ki pi piti pase majin lan, nou kenbe li yon ti kras pozitif.
  assert.ok(settings.applyMargin(0.5, 0.8) > 0);
});

test("majin: /api/wallets/rates aplike majin aktyèl la", async () => {
  settings.setExchangeMargin(0.5, "owner-uid");

  await withServer(async (server) => {
    const owner = await post(server, "/api/auth/login", {
      email: "owner@example.com",
      password: "modpas-owner-2026",
    });

    const { status, body } = await get(
      server,
      "/api/wallets/rates",
      owner.body.token
    );

    assert.equal(status, 200);
    assert.equal(body.margin, 0.5);
    // MXN te 7.25 nan seed, apre majin 0.5 → 6.75.
    assert.ok(Math.abs(body.rates.MXN - 6.75) < 1e-9);
    // HTG = 1 pa afekte.
    assert.equal(body.rates.HTG, 1);
  });

  settings.setExchangeMargin(0, "owner-uid");
});

test("majin: store wrapper aplike majin pou konvèsyon Bazik", async () => {
  settings.setExchangeMargin(0.8, "owner-uid");

  const service = getBazikService();
  const info = await service.store.getRateInfo("MXN");
  // Seed MXN = 7.25, apre 0.8 → 6.45.
  assert.ok(Math.abs(info.rateToHtg - 6.45) < 1e-9);

  const rate = await service.store.getRateToHtg("USD");
  // Seed USD = 132, apre 0.8 → 131.2.
  assert.ok(Math.abs(rate - 131.2) < 1e-9);

  // HTG pa afekte.
  assert.equal(await service.store.getRateToHtg("HTG"), 1);

  settings.setExchangeMargin(0, "owner-uid");
});

test("majin: PATCH /api/settings/exchange-margin (owner sèlman)", async () => {
  await withServer(async (server) => {
    const owner = await post(server, "/api/auth/login", {
      email: "owner@example.com",
      password: "modpas-owner-2026",
    });

    const saved = await patch(
      server,
      "/api/settings/exchange-margin",
      { margin: 0.6 },
      owner.body.token
    );
    assert.equal(saved.status, 200);
    assert.equal(saved.body.margin, 0.6);

    const current = await get(
      server,
      "/api/settings/exchange-margin",
      owner.body.token
    );
    assert.equal(current.body.margin, 0.6);
    assert.equal(current.body.maxMargin, 0.8);

    // Reset pou pwochen tès yo
    await patch(
      server,
      "/api/settings/exchange-margin",
      { margin: 0 },
      owner.body.token
    );
  });
});

test("majin: ajan pa gen aksè pou chanje majin lan", async () => {
  await withServer(async (server) => {
    const owner = await post(server, "/api/auth/login", {
      email: "owner@example.com",
      password: "modpas-owner-2026",
    });

    // Kreye yon ajan
    const createRes = await post(
      server,
      "/api/users",
      {
        email: "agent2@example.com",
        password: "modpas-ajan-2026",
        displayName: "Ajan 2",
        role: "agent",
        currency: "USD",
      },
      owner.body.token
    );
    assert.equal(createRes.status, 200);

    const agent = await post(server, "/api/auth/login", {
      email: "agent2@example.com",
      password: "modpas-ajan-2026",
    });

    const forbidden = await patch(
      server,
      "/api/settings/exchange-margin",
      { margin: 0.5 },
      agent.body.token
    );
    assert.equal(forbidden.status, 403);
  });
});
