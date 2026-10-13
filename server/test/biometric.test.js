"use strict";

/** Koneksyon byometrik: kle pa aparèy, revoke lè modpas la chanje. */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "bio-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const authRoutes = require("../src/routes/auth.routes");

let server;
let base;
let token;

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES ('ENT_BIO', 'B', '', 'HTG', 1, ?, ?)`
    )
    .run(Date.now(), Date.now());
  const user = await users.createUser({
    email: "bio@test.ht", password: "modpas-solid-2026", role: "agent", enterpriseId: "ENT_BIO", enterpriseName: "B",
  });
  token = createSession(user.uid).token;
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/auth", authRoutes);
  server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  server?.close();
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

const call = (method, url, body, auth) =>
  fetch(`${base}${url}`, {
    method,
    headers: { "content-type": "application/json", ...(auth ? { authorization: `Bearer ${auth}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  }).then(async (r) => ({ status: r.status, json: await r.json() }));

test("aktive byometri: kle a bay yon sèl fwa, sèvè a kenbe hach li sèlman", async () => {
  assert.equal((await call("POST", "/api/auth/biometric/enroll", { label: "moto g24" })).status, 401);

  const enrolled = await call("POST", "/api/auth/biometric/enroll", { label: "moto g24" }, token);
  assert.equal(enrolled.status, 200);
  const { deviceId, secret } = enrolled.json;
  const row = db.getDb().prepare("SELECT * FROM biometric_devices WHERE device_id = ?").get(deviceId);
  assert.notEqual(row.secret_hash, secret, "pa janm kle a an klè");

  const login = await call("POST", "/api/auth/biometric/login", { deviceId, secret });
  assert.equal(login.status, 200, JSON.stringify(login.json));
  assert.ok(login.json.token);
  assert.equal(login.json.user.email, "bio@test.ht");

  const wrong = await call("POST", "/api/auth/biometric/login", { deviceId, secret: "move-kle" });
  assert.equal(wrong.status, 401);
  assert.equal(wrong.json.code, "biometric_revoked");
});

test("chanje modpas revoke tout kle byometrik yo", async () => {
  const { deviceId, secret } = (await call("POST", "/api/auth/biometric/enroll", {}, token)).json;
  const changed = await call(
    "POST", "/api/auth/change-password",
    { currentPassword: "modpas-solid-2026", newPassword: "nouvo-modpas-2026" }, token
  );
  assert.equal(changed.status, 200, JSON.stringify(changed.json));
  const after = await call("POST", "/api/auth/biometric/login", { deviceId, secret });
  assert.equal(after.json.code, "biometric_revoked");
});

test("dezaktive byometri sou aparèy la", async () => {
  const fresh = (await call("POST", "/api/auth/login", { email: "bio@test.ht", password: "nouvo-modpas-2026" })).json.token;
  const { deviceId, secret } = (await call("POST", "/api/auth/biometric/enroll", {}, fresh)).json;
  assert.equal((await call("DELETE", `/api/auth/biometric/${deviceId}`, null, fresh)).status, 200);
  assert.equal((await call("POST", "/api/auth/biometric/login", { deviceId, secret })).status, 401);
});
