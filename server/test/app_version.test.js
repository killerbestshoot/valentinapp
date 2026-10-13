"use strict";

/** Yon app twò ansyen pa mache: sèvè a reponn 426 `app_outdated`. */

const test = require("node:test");
const assert = require("node:assert/strict");
const express = require("express");

const { requireAppVersion, versionInfo, MIN_BUILD, LATEST_BUILD } = require("../src/app_version");

let server;
let base;

test.before(async () => {
  const app = express();
  app.get("/api/app/version", (req, res) => res.json({ ok: true, ...versionInfo() }));
  app.use("/api", requireAppVersion);
  app.get("/api/wallets/me", (req, res) => res.json({ ok: true }));
  app.post("/api/bazik/webhook", (req, res) => res.json({ ok: true }));
  server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => server?.close());

const get = (path, headers = {}, method = "GET") =>
  fetch(`${base}${path}`, { method, headers }).then(async (r) => ({ status: r.status, json: await r.json() }));

test("vèsyon aktyèl la pase, yon build anba minimòm lan resevwa 426", async () => {
  assert.equal(LATEST_BUILD >= MIN_BUILD, true);
  assert.equal((await get("/api/wallets/me", { "X-App-Build": String(MIN_BUILD) })).status, 200);

  const old = await get("/api/wallets/me", { "X-App-Build": String(MIN_BUILD - 1), "X-App-Platform": "android" });
  assert.equal(old.status, 426);
  assert.equal(old.json.code, "app_outdated");
  assert.match(old.json.downloadUrl, /voupvapcash\.apk$/);
  assert.match(old.json.message, /twò ansyen/);
});

test("APK anvan mekanis la (Dart san tèt vèsyon) bloke; navigatè ak webhook pa bloke", async () => {
  assert.equal((await get("/api/wallets/me", { "User-Agent": "Dart/3.11 (dart:io)" })).status, 426);
  assert.equal((await get("/api/wallets/me", { "User-Agent": "Mozilla/5.0" })).status, 200);
  assert.equal((await get("/api/bazik/webhook", { "User-Agent": "Dart/3.11 (dart:io)" }, "POST")).status, 200);
});

test("/api/app/version toujou disponib, menm pou yon app ansyen", async () => {
  const res = await get("/api/app/version", { "X-App-Build": "1" });
  assert.equal(res.status, 200);
  assert.equal(res.json.minBuild, MIN_BUILD);
  assert.equal(res.json.latestBuild, LATEST_BUILD);
});

test("APP_MIN_BUILD nan .env ka monte minimòm lan san chanje kòd la", () => {
  assert.equal(versionInfo({ APP_MIN_BUILD: "9" }).minBuild, 9);
  assert.equal(versionInfo({ APP_MIN_BUILD: "x" }).minBuild, MIN_BUILD);
});
